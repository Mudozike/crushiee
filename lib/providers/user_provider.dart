import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final StorageService _storage = StorageService();
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<Set<String>>? _followingSubscription;
  String? _subscribedUserId;
  final Set<String> _pendingFollowOperations = {};

  UserProvider() {
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
        _db.setFollowingUserIds(followingIds);
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
    _pendingFollowOperations.clear();
    _db.clearFollowing();
    notifyListeners();
  }

  UserModel? getUser(String userId) => _db.getUser(userId);

  Stream<Set<String>> getFollowingUserIdsStream(String userId) {
    return _firestoreService.getFollowingUserIdsStream(userId);
  }

  bool isFollowing(String targetUserId) {
    return _db.isFollowing(targetUserId);
  }

  Future<bool> toggleFollow(String currentUserId, String targetUserId,
      {String? targetUsername}) async {
    if (currentUserId == targetUserId) return false;
    final opKey = '${currentUserId}_$targetUserId';
    if (_pendingFollowOperations.contains(opKey)) return false;
    _pendingFollowOperations.add(opKey);

    initUserFollowing(currentUserId);

    final wasFollowing = _db.isFollowing(targetUserId);
    // Optimistic local update
    _db.toggleFollow(currentUserId, targetUserId);
    notifyListeners();

    // Persist to Cloud Firestore
    try {
      final nowFollowing = await _firestoreService.toggleFollow(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        targetUsername: targetUsername,
      );
      if (_db.isFollowing(targetUserId) != nowFollowing) {
        _db.toggleFollow(currentUserId, targetUserId);
        notifyListeners();
      }
      return nowFollowing;
    } catch (e) {
      debugPrint('[USER_PROVIDER] Failed to toggle follow in Firestore: $e');
      // Rollback optimistic update
      if (_db.isFollowing(targetUserId) != wasFollowing) {
        _db.toggleFollow(currentUserId, targetUserId);
        notifyListeners();
      }
      rethrow;
    } finally {
      _pendingFollowOperations.remove(opKey);
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
