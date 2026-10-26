import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  final DatabaseService _db;
  final StorageService _storage;
  final FirestoreService _firestoreService;

  StreamSubscription<Set<String>>? _followingSubscription;
  String? _subscribedUserId;
  final Map<String, Set<String>> _inFlightFollowOps = {};
  final Map<String, Map<String, bool>> _reconciliationGuards = {};

  UserProvider({
    DatabaseService? db,
    StorageService? storage,
    FirestoreService? firestoreService,
  })  : _db = db ?? DatabaseService(),
        _storage = storage ?? StorageService(),
        _firestoreService = firestoreService ?? FirestoreService() {
    _db.addListener(_onDbChanged);
  }

  void _onDbChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _followingSubscription?.cancel();
    _db.removeListener(_onDbChanged);
    super.dispose();
  }

  void initUserFollowing(String userId) {
    if (userId.trim().isEmpty) return;
    if (_subscribedUserId == userId && _followingSubscription != null) return;
    _subscribedUserId = userId;
    _followingSubscription?.cancel();
    try {
      _followingSubscription = _firestoreService
          .getFollowingUserIdsStream(userId)
          .listen((followingIds) {
        final reconciled = Set<String>.from(followingIds);
        // Retain optimistic state for any in-flight or recently completed operations
        // until the server stream catches up and confirms the expected state.
        final guards = _reconciliationGuards[userId];
        if (guards != null) {
          final confirmed = <String>[];
          for (final entry in guards.entries) {
            final targetId = entry.key;
            final expected = entry.value;
            final inStream = followingIds.contains(targetId);
            if (inStream == expected) {
              // Server stream now reflects our expected state!
              confirmed.add(targetId);
            } else {
              // Server stream is STALE (older than recent follow/unfollow).
              // Preserve the optimistic state so the stale snapshot does not overwrite it.
              if (expected) {
                reconciled.add(targetId);
              } else {
                reconciled.remove(targetId);
              }
            }
          }
          for (final c in confirmed) {
            guards.remove(c);
          }
          if (guards.isEmpty) {
            _reconciliationGuards.remove(userId);
          }
        }
        _db.setFollowingUserIds(reconciled);
        notifyListeners();
      }, onError: (e) {
        debugPrint('[USER_PROVIDER] Error in following stream: $e');
      });
    } catch (e) {
      debugPrint('[USER_PROVIDER] Error starting following stream: $e');
    }
  }

  void clear() {
    _followingSubscription?.cancel();
    _followingSubscription = null;
    _subscribedUserId = null;
    _inFlightFollowOps.clear();
    _reconciliationGuards.clear();
    _db.clearFollowing();
    notifyListeners();
  }

  UserModel? getUser(String userId) => _db.getUser(userId);

  Stream<Set<String>> getFollowingUserIdsStream(String userId) {
    return _firestoreService.getFollowingUserIdsStream(userId);
  }

  Set<String> get followingUserIds => _db.followingUserIds;
  int get followingCount => _db.followingCount;

  Future<int?> getFollowersCount(String userId) async {
    return _firestoreService.getFollowersCount(userId);
  }

  Future<int?> getFollowingCount(String userId) async {
    if (_subscribedUserId == userId) {
      return _db.followingCount;
    }
    return _firestoreService.getFollowingCount(userId);
  }

  bool isFollowing(String targetUserId) {
    return _db.isFollowing(targetUserId);
  }

  bool isFollowPending(String targetUserId, {String? currentUserId}) {
    if (currentUserId != null) {
      return _inFlightFollowOps[currentUserId]?.contains(targetUserId) ?? false;
    }
    return _inFlightFollowOps.values.any((targets) => targets.contains(targetUserId));
  }

  void _addInFlight(String actingUserId, String targetUserId) {
    _inFlightFollowOps.putIfAbsent(actingUserId, () => <String>{}).add(targetUserId);
  }

  void _removeInFlight(String actingUserId, String targetUserId) {
    final set = _inFlightFollowOps[actingUserId];
    if (set != null) {
      set.remove(targetUserId);
      if (set.isEmpty) {
        _inFlightFollowOps.remove(actingUserId);
      }
    }
  }

  void _setReconciliationGuard(String actingUserId, String targetUserId, bool expected) {
    _reconciliationGuards.putIfAbsent(actingUserId, () => <String, bool>{})[targetUserId] = expected;
  }

  void _removeReconciliationGuard(String actingUserId, String targetUserId) {
    final map = _reconciliationGuards[actingUserId];
    if (map != null) {
      map.remove(targetUserId);
      if (map.isEmpty) {
        _reconciliationGuards.remove(actingUserId);
      }
    }
  }

  Future<bool> toggleFollow(String currentUserId, String targetUserId,
      {String? targetUsername}) async {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return false;
    }
    if (isFollowPending(targetUserId, currentUserId: currentUserId)) {
      return _db.isFollowing(targetUserId);
    }
    final wasFollowing = _db.isFollowing(targetUserId);
    final targetState = !wasFollowing;
    _addInFlight(currentUserId, targetUserId);
    _setReconciliationGuard(currentUserId, targetUserId, targetState);
    notifyListeners();

    initUserFollowing(currentUserId);

    // Optimistic local update with explicit boolean state
    _db.setFollowState(currentUserId, targetUserId, targetState);
    notifyListeners();

    // Persist to Cloud Firestore
    try {
      final nowFollowing = await _firestoreService.toggleFollow(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        targetUsername: targetUsername,
      );
      _setReconciliationGuard(currentUserId, targetUserId, nowFollowing);
      _db.setFollowState(currentUserId, targetUserId, nowFollowing);
      notifyListeners();
      return nowFollowing;
    } catch (e) {
      debugPrint('[USER_PROVIDER] Failed to toggle follow in Firestore: $e');
      _removeReconciliationGuard(currentUserId, targetUserId);
      // Rollback optimistic update
      _db.setFollowState(currentUserId, targetUserId, wasFollowing);
      notifyListeners();
      rethrow;
    } finally {
      _removeInFlight(currentUserId, targetUserId);
      notifyListeners();
    }
  }

  Future<bool> followUser(String currentUserId, String targetUserId,
      {String? targetUsername}) async {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return false;
    }
    if (isFollowing(targetUserId)) {
      return true; // Already following
    }
    if (isFollowPending(targetUserId, currentUserId: currentUserId)) {
      return _db.isFollowing(targetUserId);
    }
    _addInFlight(currentUserId, targetUserId);
    _setReconciliationGuard(currentUserId, targetUserId, true);
    notifyListeners();

    initUserFollowing(currentUserId);

    final wasFollowing = _db.isFollowing(targetUserId);
    _db.setFollowState(currentUserId, targetUserId, true);
    notifyListeners();

    try {
      final nowFollowing = await _firestoreService.followUser(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        targetUsername: targetUsername,
      );
      _setReconciliationGuard(currentUserId, targetUserId, nowFollowing);
      _db.setFollowState(currentUserId, targetUserId, nowFollowing);
      notifyListeners();
      return nowFollowing;
    } catch (e) {
      debugPrint('[USER_PROVIDER] Failed to follow in Firestore: $e');
      _removeReconciliationGuard(currentUserId, targetUserId);
      _db.setFollowState(currentUserId, targetUserId, wasFollowing);
      notifyListeners();
      rethrow;
    } finally {
      _removeInFlight(currentUserId, targetUserId);
      notifyListeners();
    }
  }

  Future<bool> unfollowUser(String currentUserId, String targetUserId) async {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return false;
    }
    if (!isFollowing(targetUserId)) {
      return false; // Absent relationship
    }
    if (isFollowPending(targetUserId, currentUserId: currentUserId)) {
      return _db.isFollowing(targetUserId);
    }
    _addInFlight(currentUserId, targetUserId);
    _setReconciliationGuard(currentUserId, targetUserId, false);
    notifyListeners();

    initUserFollowing(currentUserId);

    final wasFollowing = _db.isFollowing(targetUserId);
    _db.setFollowState(currentUserId, targetUserId, false);
    notifyListeners();

    try {
      final nowFollowing = await _firestoreService.unfollowUser(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      );
      _setReconciliationGuard(currentUserId, targetUserId, nowFollowing);
      _db.setFollowState(currentUserId, targetUserId, nowFollowing);
      notifyListeners();
      return nowFollowing;
    } catch (e) {
      debugPrint('[USER_PROVIDER] Failed to unfollow in Firestore: $e');
      _removeReconciliationGuard(currentUserId, targetUserId);
      _db.setFollowState(currentUserId, targetUserId, wasFollowing);
      notifyListeners();
      rethrow;
    } finally {
      _removeInFlight(currentUserId, targetUserId);
      notifyListeners();
    }
  }

  int getDailyConnections(String userId) {
    final user = _db.getUser(userId);
    return user?.activeDailyConnections ?? 0;
  }

  int getMonthlyConnections(String userId) {
    final user = _db.getUser(userId);
    return user?.activeMonthlyConnections ?? 0;
  }

  Future<String?> uploadVerificationPhoto({
    required String userId,
    required XFile file,
  }) async {
    try {
      final String? photoUrl = await _storage.uploadVerificationPhoto(
        userId: userId,
        file: file,
      );
      final user = _db.getUser(userId);
      if (user != null) {
        _db.updateUser(user.copyWith(verificationPhoto: photoUrl));
      }
      notifyListeners();
      return photoUrl;
    } catch (e) {
      debugPrint('Failed to upload verification photo: $e');
      return null;
    }
  }

  void verifyUserWithPhoto(String userId, String photoUrl, {int days = 30}) {
    final user = _db.getUser(userId);
    if (user != null) {
      final expiry = DateTime.now().add(Duration(days: days));
      _db.updateUser(user.copyWith(
        isVerified: true,
        verifiedExpiry: expiry,
        verificationPhoto: photoUrl,
      ));
      notifyListeners();
    }
  }

  // --- BLOCKING ---

  bool isUserBlocked(String currentUserId, String targetUserId) {
    return _db.isUserBlocked(currentUserId, targetUserId);
  }

  Stream<Set<String>> getBlockedUserIdsStream(String userId) {
    return _firestoreService.getBlockedUserIdsStream(userId);
  }

  Future<void> blockUser(String currentUserId, String targetUserId,
      {String? targetUsername}) async {
    if (currentUserId == targetUserId) return;

    // Optimistic local update
    _db.blockUser(currentUserId, targetUserId);
    notifyListeners();

    // Persist to Firestore
    try {
      await _firestoreService.blockUser(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        targetUsername: targetUsername,
      );
    } catch (e) {
      debugPrint('[USER_PROVIDER] Failed to block user in Firestore: $e');
      rethrow;
    }
  }

  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    // Optimistic local update
    _db.unblockUser(currentUserId, targetUserId);
    notifyListeners();

    // Persist to Firestore
    try {
      await _firestoreService.unblockUser(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      );
    } catch (e) {
      debugPrint('[USER_PROVIDER] Failed to unblock user in Firestore: $e');
      rethrow;
    }
  }
}
