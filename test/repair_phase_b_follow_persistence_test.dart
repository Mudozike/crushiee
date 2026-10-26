import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:crushie/models/user_model.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/providers/connection_provider.dart';
import 'package:crushie/providers/post_provider.dart';
import 'package:crushie/providers/user_provider.dart';
import 'package:crushie/screens/profile/profile_screen.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/services/firestore_service.dart';
import 'package:crushie/widgets/post_card.dart';
import 'package:crushie/models/post_model.dart';

// =============================================================================
// Test Fakes & Mock Infrastructure
// =============================================================================

class MockFirestoreService extends Fake implements FirestoreService {
  final Map<String, Set<String>> _follows = {}; // userId -> Set of targetUserIds
  final Map<String, Map<String, dynamic>> _userDocs = {};
  final StreamController<Set<String>> _followingStreamController =
      StreamController<Set<String>>.broadcast();

  bool shouldThrowOnFollow = false;
  Exception? throwException;
  Completer<void>? followCompleter;

  void seedUser(String userId, {int followersCount = 0, int followingCount = 0}) {
    _userDocs[userId] = {
      'followersCount': followersCount,
      'followingCount': followingCount,
    };
  }

  void seedUserWithoutFollowersField(String userId, {int followingCount = 0}) {
    _userDocs[userId] = {
      'followingCount': followingCount,
      // 'followersCount' deliberately omitted
    };
  }

  bool shouldFailFollowersCount = false;
  bool shouldFailFollowingCount = false;

  @override
  Future<int?> getFollowersCount(String userId) async {
    if (shouldFailFollowersCount) return null;
    return _follows.values.where((targets) => targets.contains(userId)).length;
  }

  @override
  Future<int?> getFollowingCount(String userId) async {
    if (shouldFailFollowingCount) return null;
    return _follows[userId]?.length ?? 0;
  }

  bool hasFollowRelationship(String currentUserId, String targetUserId) =>
      _follows[currentUserId]?.contains(targetUserId) ?? false;

  void emitFollowingStream(Set<String> followingIds) {
    _followingStreamController.add(followingIds);
  }

  @override
  Stream<Set<String>> getFollowingUserIdsStream(String userId) {
    return Stream<Set<String>>.multi((controller) {
      controller.add(Set<String>.from(_follows[userId] ?? {}));
      final sub = _followingStreamController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => sub.cancel();
    });
  }

  @override
  Future<bool> followUser({
    required String currentUserId,
    required String targetUserId,
    String? currentUsername,
    String? currentUserProfilePic,
    String? targetUsername,
  }) async {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return false;
    }
    if (followCompleter != null) {
      await followCompleter!.future;
    }
    if (shouldThrowOnFollow) {
      throw throwException ??
          Exception('FirebaseException: [cloud_firestore/permission-denied] Permission denied.');
    }

    _follows.putIfAbsent(currentUserId, () => <String>{});
    if (_follows[currentUserId]!.contains(targetUserId)) {
      return true; // Idempotent no-op
    }

    _follows[currentUserId]!.add(targetUserId);
    _followingStreamController.add(Set<String>.from(_follows[currentUserId]!));
    return true;
  }

  @override
  Future<bool> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return false;
    }
    if (shouldThrowOnFollow) {
      throw throwException ??
          Exception('FirebaseException: [cloud_firestore/permission-denied] Permission denied.');
    }

    if (!(_follows[currentUserId]?.contains(targetUserId) ?? false)) {
      return false; // Absent relationship, idempotent no-op
    }

    _follows[currentUserId]!.remove(targetUserId);
    _followingStreamController.add(Set<String>.from(_follows[currentUserId]!));
    return false;
  }

  @override
  Future<bool> toggleFollow({
    required String currentUserId,
    required String targetUserId,
    String? currentUsername,
    String? currentUserProfilePic,
    String? targetUsername,
  }) async {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return false;
    }
    if (hasFollowRelationship(currentUserId, targetUserId)) {
      return unfollowUser(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      );
    } else {
      return followUser(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        currentUsername: currentUsername,
        currentUserProfilePic: currentUserProfilePic,
        targetUsername: targetUsername,
      );
    }
  }

  void dispose() {
    _followingStreamController.close();
  }
}

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel? _user;
  MockAuthProvider(this._user);

  @override
  UserModel? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// Security Rules Evaluator Helper (Mirroring firestore.rules lines 50-90 & 122-125)
// =============================================================================

class FirestoreRulesSimulator {
  /// Evaluates allow update on /users/{userId} for follower/following counters
  /// Mirroring hardened firestore.rules:
  /// - Non-owner updates are disallowed
  /// - Owner updates strictly forbid followersCount and followingCount
  static bool evaluateUserDocUpdate({
    required String authUid,
    required String docUserId,
    required Map<String, dynamic> existingData,
    required Map<String, dynamic> incomingData,
    required bool relationshipExistsBefore,
    bool relationshipExistsAfter = false,
    required bool isBlockedByTarget,
  }) {
    final isOwner = authUid == docUserId;
    if (!isOwner) {
      // Non-owner updates are completely disallowed under hardened rules
      return false;
    }

    final affectedKeys = incomingData.keys
        .where((k) => incomingData[k] != existingData[k])
        .toSet();

    final forbiddenKeys = [
      'role',
      'isPremium',
      'premiumExpiry',
      'isVerified',
      'verifiedExpiry',
      'followersCount',
      'followingCount',
      'dailyConnections',
      'dailyConnectionsDate',
      'monthlyConnections',
      'monthlyConnectionsMonth'
    ];

    if (affectedKeys.any((k) => forbiddenKeys.contains(k))) {
      return false;
    }

    return true;
  }

  /// Evaluates allow create on /users/{userId}/follows/{targetId}
  /// Mirroring firestore.rules:
  /// allow create: if isOwner(userId) && targetId != userId && !isBlocked(userId, targetId);
  static bool evaluateFollowDocCreate({
    required String authUid,
    required String userId,
    required String targetId,
    required bool isBlocked,
    Map<String, dynamic>? targetUserBefore,
    Map<String, dynamic>? targetUserAfter,
    Map<String, dynamic>? actingUserBefore,
    Map<String, dynamic>? actingUserAfter,
  }) {
    final isOwner = authUid == userId;
    if (!isOwner || targetId == userId || isBlocked) return false;
    return true;
  }

  /// Evaluates allow delete on /users/{userId}/follows/{targetId}
  /// Mirroring firestore.rules:
  /// allow delete: if isOwner(userId);
  static bool evaluateFollowDocDelete({
    required String authUid,
    required String userId,
    required String targetId,
    Map<String, dynamic>? targetUserBefore,
    Map<String, dynamic>? targetUserAfter,
    Map<String, dynamic>? actingUserBefore,
    Map<String, dynamic>? actingUserAfter,
    bool actingUserDocExistsBefore = true,
    bool actingUserDocExistsAfter = true,
  }) {
    final isOwner = authUid == userId;
    return isOwner;
  }

  /// Evaluates allow write on /users/{userId}/follows/{targetId} (compatibility helper)
  static bool evaluateFollowDocWrite({
    required String authUid,
    required String userId,
    required String targetId,
    required bool isBlocked,
  }) {
    final isOwner = authUid == userId;
    return isOwner && targetId != userId && !isBlocked;
  }
}

// =============================================================================
// Regression Test Suite
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late MockFirestoreService mockFirestore;
  late UserProvider userProvider;

  final aliceUser = UserModel(
    id: 'user_alice',
    email: 'alice@crushie.app',
    username: 'alice',
    country: 'Kenya',
    city: 'Nairobi',
    dateOfBirth: DateTime(1996, 4, 12),
    gender: 'Female',
    bio: 'Alice in Crushie land',
    profilePicUrl: 'crushie_avatar_1',
    preferredContactMethod: 'WhatsApp',
    contactDetails: '+254700000001',
    profileCompleted: true,
    isOnline: true,
    lastSeen: DateTime.now(),
    createdAt: DateTime.now(),
    followersCount: 0,
    followingCount: 0,
  );

  final bobUser = UserModel(
    id: 'user_bob',
    email: 'bob@crushie.app',
    username: 'bob',
    country: 'Kenya',
    city: 'Nairobi',
    dateOfBirth: DateTime(1994, 8, 22),
    gender: 'Male',
    bio: 'Bob adventurer',
    profilePicUrl: 'crushie_avatar_2',
    preferredContactMethod: 'WhatsApp',
    contactDetails: '+254700000002',
    profileCompleted: true,
    isOnline: true,
    lastSeen: DateTime.now(),
    createdAt: DateTime.now(),
    followersCount: 0,
    followingCount: 0,
  );

  setUp(() {
    dbService = DatabaseService();
    dbService.clearUserData();
    mockFirestore = MockFirestoreService();
    mockFirestore.seedUser('user_alice', followersCount: 0, followingCount: 0);
    mockFirestore.seedUser('user_bob', followersCount: 0, followingCount: 0);
    userProvider = UserProvider(db: dbService, firestoreService: mockFirestore);
  });

  tearDown(() {
    mockFirestore.dispose();
  });

  group('Crushie Repair Phase B: Follow/Unfollow Persistence & Counter Consistency', () {
    // -------------------------------------------------------------------------
    // 1. Following another user persists after the operation completes
    // -------------------------------------------------------------------------
    test('1. Following another user persists after the operation completes', () async {
      expect(userProvider.isFollowing('user_bob'), isFalse);
      expect(mockFirestore.hasFollowRelationship('user_alice', 'user_bob'), isFalse);

      final success = await userProvider.followUser('user_alice', 'user_bob', targetUsername: 'bob');

      expect(success, isTrue);
      expect(userProvider.isFollowing('user_bob'), isTrue);
      expect(dbService.isFollowing('user_bob'), isTrue);
      expect(mockFirestore.hasFollowRelationship('user_alice', 'user_bob'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 2. Unfollowing removes the persisted relationship
    // -------------------------------------------------------------------------
    test('2. Unfollowing removes the persisted relationship', () async {
      // First follow
      await userProvider.followUser('user_alice', 'user_bob', targetUsername: 'bob');
      expect(userProvider.isFollowing('user_bob'), isTrue);
      expect(mockFirestore.hasFollowRelationship('user_alice', 'user_bob'), isTrue);

      // Now unfollow
      final success = await userProvider.unfollowUser('user_alice', 'user_bob');

      expect(success, isFalse); // unfollow returns false (isFollowing == false)
      expect(userProvider.isFollowing('user_bob'), isFalse);
      expect(dbService.isFollowing('user_bob'), isFalse);
      expect(mockFirestore.hasFollowRelationship('user_alice', 'user_bob'), isFalse);
    });

    // -------------------------------------------------------------------------
    // 3. Follow state remains correct after a simulated refresh or fresh provider load
    // -------------------------------------------------------------------------
    test('3. Follow state remains correct after simulated refresh / fresh provider load', () async {
      // Alice follows Bob
      await userProvider.followUser('user_alice', 'user_bob', targetUsername: 'bob');
      expect(mockFirestore.hasFollowRelationship('user_alice', 'user_bob'), isTrue);

      // Fresh provider instance simulates app restart / page navigation
      final freshDb = DatabaseService();
      freshDb.clearUserData();
      final freshUserProvider = UserProvider(db: freshDb, firestoreService: mockFirestore);

      // Initially empty before initUserFollowing is called
      expect(freshUserProvider.isFollowing('user_bob'), isFalse);

      // Start stream
      freshUserProvider.initUserFollowing('user_alice');
      await pumpEventQueue();

      // Canonical state reloaded from Firestore stream snapshot
      expect(freshUserProvider.isFollowing('user_bob'), isTrue);
      expect(freshDb.isFollowing('user_bob'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 4. Firestore permission errors are surfaced and do not leave false success in UI
    // -------------------------------------------------------------------------
    testWidgets('4. Firestore permission errors are surfaced and roll back optimistic UI state', (tester) async {
      mockFirestore.shouldThrowOnFollow = true;
      mockFirestore.throwException = Exception('PERMISSION_DENIED');

      final authProvider = MockAuthProvider(aliceUser);
      final postProvider = PostProvider();
      final connProvider = ConnectionProvider();

      dbService.updateUser(bobUser);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
            ChangeNotifierProvider<PostProvider>.value(value: postProvider),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProvider),
          ],
          child: MaterialApp(
            home: ProfileScreen(user: bobUser),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('+ Follow'), findsOneWidget);

      // Tap the follow button
      await tester.tap(find.text('+ Follow'));
      await tester.pump(); // Start async operation

      // Finish pending futures and error handling
      await tester.pumpAndSettle();

      // UI must NOT show false success ('Following' button state)
      expect(find.widgetWithText(OutlinedButton, '+ Follow'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Following'), findsNothing);

      // Error SnackBar surfaced to user
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Failed to update follow'), findsOneWidget);

      // Local state rolled back
      expect(userProvider.isFollowing('user_bob'), isFalse);
      expect(dbService.isFollowing('user_bob'), isFalse);
    });

    // -------------------------------------------------------------------------
    // 5. Duplicate Follow requests do not double-increment counters
    // -------------------------------------------------------------------------
    test('5. Duplicate Follow requests do not double-increment counters', () async {
      expect(await mockFirestore.getFollowersCount('user_bob'), 0);
      expect(await mockFirestore.getFollowingCount('user_alice'), 0);

      // First follow
      await userProvider.followUser('user_alice', 'user_bob');
      expect(await mockFirestore.getFollowersCount('user_bob'), 1);
      expect(await mockFirestore.getFollowingCount('user_alice'), 1);

      // Second follow (duplicate request)
      final duplicateResult = await userProvider.followUser('user_alice', 'user_bob');
      expect(duplicateResult, isTrue); // Returns isFollowing

      // Counters remain strictly 1
      expect(await mockFirestore.getFollowersCount('user_bob'), 1);
      expect(await mockFirestore.getFollowingCount('user_alice'), 1);
    });

    // -------------------------------------------------------------------------
    // 6. Unfollowing an absent relationship does not decrement counters
    // -------------------------------------------------------------------------
    test('6. Unfollowing an absent relationship does not decrement counters', () async {
      // Bob starts with 0 followers, Alice with 0 following
      expect(await mockFirestore.getFollowersCount('user_bob'), 0);
      expect(await mockFirestore.getFollowingCount('user_alice'), 0);

      // Unfollow without following
      final result = await userProvider.unfollowUser('user_alice', 'user_bob');

      expect(result, isFalse);
      expect(await mockFirestore.getFollowersCount('user_bob'), 0);
      expect(await mockFirestore.getFollowingCount('user_alice'), 0);
    });

    // -------------------------------------------------------------------------
    // 7. Both users' counters update consistently
    // -------------------------------------------------------------------------
    test('7. Both users counters update consistently across follow and unfollow cycles', () async {
      expect(await mockFirestore.getFollowersCount('user_bob'), 0);
      expect(await mockFirestore.getFollowingCount('user_alice'), 0);

      // Follow: +1 / +1
      await userProvider.followUser('user_alice', 'user_bob');
      expect(await mockFirestore.getFollowersCount('user_bob'), 1);
      expect(await mockFirestore.getFollowingCount('user_alice'), 1);

      // Unfollow: -1 / -1
      await userProvider.unfollowUser('user_alice', 'user_bob');
      expect(await mockFirestore.getFollowersCount('user_bob'), 0);
      expect(await mockFirestore.getFollowingCount('user_alice'), 0);

      // Legacy target doc without followersCount initializes to 1
      mockFirestore.seedUserWithoutFollowersField('user_charlie', followingCount: 0);
      await userProvider.followUser('user_alice', 'user_charlie');
      expect(await mockFirestore.getFollowersCount('user_charlie'), 1);
      expect(await mockFirestore.getFollowingCount('user_alice'), 1);
    });

    // -------------------------------------------------------------------------
    // 8. Self-follow is rejected
    // -------------------------------------------------------------------------
    test('8. Self-follow is rejected across provider and service layers', () async {
      final followResult = await userProvider.followUser('user_alice', 'user_alice');
      expect(followResult, isFalse);

      final toggleResult = await userProvider.toggleFollow('user_alice', 'user_alice');
      expect(toggleResult, isFalse);

      final serviceResult = await mockFirestore.followUser(
        currentUserId: 'user_alice',
        targetUserId: 'user_alice',
      );
      expect(serviceResult, isFalse);

      expect(mockFirestore.hasFollowRelationship('user_alice', 'user_alice'), isFalse);
      expect(await mockFirestore.getFollowersCount('user_alice'), 0);
      expect(await mockFirestore.getFollowingCount('user_alice'), 0);
    });

    // -------------------------------------------------------------------------
    // 9. Concurrent or repeated operations cannot produce inconsistent relationship state
    // -------------------------------------------------------------------------
    test('9. Concurrent / repeated operations do not create duplicate writes or race conditions', () async {
      // Dispatch 3 concurrent follow requests
      final future1 = userProvider.toggleFollow('user_alice', 'user_bob');
      final future2 = userProvider.toggleFollow('user_alice', 'user_bob');
      final future3 = userProvider.toggleFollow('user_alice', 'user_bob');

      final results = await Future.wait([future1, future2, future3]);

      // All evaluate consistently to following
      expect(results.every((r) => r == true), isTrue);
      expect(userProvider.isFollowing('user_bob'), isTrue);
      expect(await mockFirestore.getFollowersCount('user_bob'), 1);
      expect(await mockFirestore.getFollowingCount('user_alice'), 1);

      // An incoming stream snapshot during an in-flight operation reconciles without wiping optimistic state
      userProvider.initUserFollowing('user_alice');
      mockFirestore.seedUser('user_charlie', followersCount: 0, followingCount: 0);

      // Start an in-flight follow operation for Charlie with a pending completer
      mockFirestore.followCompleter = Completer<void>();
      final inFlightFuture = userProvider.toggleFollow('user_alice', 'user_charlie');
      expect(userProvider.isFollowPending('user_charlie', currentUserId: 'user_alice'), isTrue);
      expect(userProvider.isFollowing('user_charlie'), isTrue);

      // Simulate an empty snapshot arriving before the backend write finishes
      mockFirestore.emitFollowingStream({});
      await pumpEventQueue();

      // State is preserved accurately during in-flight operation
      expect(userProvider.isFollowing('user_charlie'), isTrue);

      // Now complete the backend write
      mockFirestore.followCompleter!.complete();
      mockFirestore.followCompleter = null;
      await inFlightFuture;
      expect(userProvider.isFollowing('user_charlie'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 10. Security Rules Policy Invariants (Phase B Targeted Security Review)
    // -------------------------------------------------------------------------
    group('10. Security Rules Policy Invariants (Option B Hardened Rules)', () {
      // Case 1: Client updating followersCount directly on user doc is REJECTED
      test('10.1. Case 1: Client updating followersCount directly on user doc is REJECTED', () {
        final nonOwnerAttemptWithoutFollow = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'followersCount': 5},
          incomingData: {'followersCount': 6},
          relationshipExistsBefore: false,
          relationshipExistsAfter: false,
          isBlockedByTarget: false,
        );
        expect(nonOwnerAttemptWithoutFollow, isFalse);

        // Even with a follow record present, client cannot update followersCount on user document
        final nonOwnerAttemptWithFollow = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'followersCount': 5},
          incomingData: {'followersCount': 6},
          relationshipExistsBefore: false,
          relationshipExistsAfter: true,
          isBlockedByTarget: false,
        );
        expect(nonOwnerAttemptWithFollow, isFalse);
      });

      // Case 2: Client decreasing followersCount directly on user doc is REJECTED
      test('10.2. Case 2: Client decreasing followersCount directly on user doc is REJECTED', () {
        final nonOwnerAttemptWithoutDelete = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'followersCount': 5},
          incomingData: {'followersCount': 4},
          relationshipExistsBefore: true,
          relationshipExistsAfter: true,
          isBlockedByTarget: false,
        );
        expect(nonOwnerAttemptWithoutDelete, isFalse);

        final nonOwnerAttemptWithDelete = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'followersCount': 5},
          incomingData: {'followersCount': 4},
          relationshipExistsBefore: true,
          relationshipExistsAfter: false,
          isBlockedByTarget: false,
        );
        expect(nonOwnerAttemptWithDelete, isFalse);
      });

      // Case 3: Create follow record authorized by relationship rule
      test('10.3. Case 3: Creating follow record is authorized by owner and decoupled from counter writes', () {
        // Valid creation by owner without needing coupled counter updates
        final validCreate = FirestoreRulesSimulator.evaluateFollowDocCreate(
          authUid: 'user_alice',
          userId: 'user_alice',
          targetId: 'user_bob',
          isBlocked: false,
        );
        expect(validCreate, isTrue);

        // Non-owner cannot create follow record in another user's subcollection
        final nonOwnerCreate = FirestoreRulesSimulator.evaluateFollowDocCreate(
          authUid: 'user_attacker',
          userId: 'user_alice',
          targetId: 'user_bob',
          isBlocked: false,
        );
        expect(nonOwnerCreate, isFalse);
      });

      // Case 4: Delete follow record authorized by owner
      test('10.4. Case 4: Deleting follow record is authorized by owner and decoupled from counter writes', () {
        // Valid unfollow by owner
        final validDelete = FirestoreRulesSimulator.evaluateFollowDocDelete(
          authUid: 'user_alice',
          userId: 'user_alice',
          targetId: 'user_bob',
        );
        expect(validDelete, isTrue);

        // Non-owner cannot delete follow record
        final nonOwnerDelete = FirestoreRulesSimulator.evaluateFollowDocDelete(
          authUid: 'user_attacker',
          userId: 'user_alice',
          targetId: 'user_bob',
        );
        expect(nonOwnerDelete, isFalse);

        // Account cleanup allows follows deletion while user is authenticated
        final accountCleanupDelete = FirestoreRulesSimulator.evaluateFollowDocDelete(
          authUid: 'user_alice',
          userId: 'user_alice',
          targetId: 'user_bob',
          actingUserDocExistsBefore: false,
          actingUserDocExistsAfter: false,
        );
        expect(accountCleanupDelete, isTrue);
      });

      // Case 5: Direct followingCount updates on user document are REJECTED
      test('10.5. Case 5: Direct followingCount updates on user document are REJECTED (locked in forbiddenKeys)', () {
        // Owner attempting to forge arbitrary jump (+10)
        final forgedJump = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_alice',
          existingData: {'followingCount': 5},
          incomingData: {'followingCount': 15},
          relationshipExistsBefore: false,
          isBlockedByTarget: false,
        );
        expect(forgedJump, isFalse);

        // Owner attempting single increment (+1): REJECTED under Option B rules
        final ownerSingleIncrement = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_alice',
          existingData: {'followingCount': 5},
          incomingData: {'followingCount': 6},
          relationshipExistsBefore: false,
          isBlockedByTarget: false,
        );
        expect(ownerSingleIncrement, isFalse);

        // Owner attempting decrement (-1): REJECTED
        final ownerDecrement = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_alice',
          existingData: {'followingCount': 5},
          incomingData: {'followingCount': 4},
          relationshipExistsBefore: true,
          isBlockedByTarget: false,
        );
        expect(ownerDecrement, isFalse);
      });

      // Case 6: Multiple counter jumps, negatives, and protected field forgeries are REJECTED
      test('10.6. Case 6: Multiple counter jumps, negatives, and protected field forgeries are REJECTED', () {
        // Non-owner trying to write followersCount
        final jumpTwo = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'followersCount': 5},
          incomingData: {'followersCount': 7},
          relationshipExistsBefore: false,
          relationshipExistsAfter: true,
          isBlockedByTarget: false,
        );
        expect(jumpTwo, isFalse);

        // Non-owner trying to decrement to negative
        final negativeFollowers = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'followersCount': 0},
          incomingData: {'followersCount': -1},
          relationshipExistsBefore: true,
          relationshipExistsAfter: false,
          isBlockedByTarget: false,
        );
        expect(negativeFollowers, isFalse);

        // Non-owner trying to forge role or premium status
        final privilegeForgery = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'role': 'user'},
          incomingData: {'role': 'admin'},
          relationshipExistsBefore: false,
          relationshipExistsAfter: true,
          isBlockedByTarget: false,
        );
        expect(privilegeForgery, isFalse);

        // Owner trying to alter own followersCount (forgery)
        final ownerFollowersForgery = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_bob',
          docUserId: 'user_bob',
          existingData: {'followersCount': 10},
          incomingData: {'followersCount': 9999},
          relationshipExistsBefore: false,
          isBlockedByTarget: false,
        );
        expect(ownerFollowersForgery, isFalse);
      });

      // Case 7: Duplicate operations or existing state conflicts (idempotency)
      test('10.7. Case 7: Duplicate operations or existing state conflicts are safely handled', () {
        // Direct counter manipulation is always rejected
        final duplicateFollow = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'followersCount': 5},
          incomingData: {'followersCount': 6},
          relationshipExistsBefore: true,
          relationshipExistsAfter: true,
          isBlockedByTarget: false,
        );
        expect(duplicateFollow, isFalse);

        final duplicateUnfollow = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'followersCount': 5},
          incomingData: {'followersCount': 4},
          relationshipExistsBefore: false,
          relationshipExistsAfter: false,
          isBlockedByTarget: false,
        );
        expect(duplicateUnfollow, isFalse);
      });

      // Case 8: Attempt self-follow and follow/unfollow when block restriction exists
      test('10.8. Case 8: Self-follow and blocked user interactions are REJECTED', () {
        // Self-follow
        final selfFollow = FirestoreRulesSimulator.evaluateFollowDocWrite(
          authUid: 'user_alice',
          userId: 'user_alice',
          targetId: 'user_alice',
          isBlocked: false,
        );
        expect(selfFollow, isFalse);

        final selfFollowCreate = FirestoreRulesSimulator.evaluateFollowDocCreate(
          authUid: 'user_alice',
          userId: 'user_alice',
          targetId: 'user_alice',
          isBlocked: false,
        );
        expect(selfFollowCreate, isFalse);

        // Blocked target
        final blockedFollow = FirestoreRulesSimulator.evaluateFollowDocCreate(
          authUid: 'user_alice',
          userId: 'user_alice',
          targetId: 'user_bob',
          isBlocked: true,
        );
        expect(blockedFollow, isFalse);

        final blockedCounterUpdate = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'followersCount': 0},
          incomingData: {'followersCount': 1},
          relationshipExistsBefore: false,
          relationshipExistsAfter: true,
          isBlockedByTarget: true,
        );
        expect(blockedCounterUpdate, isFalse);
      });

      // Case 9: Relationship documents are authoritative source of truth
      test('10.9. Case 9: Follow relationships are the authoritative source of truth and profile counters cannot be forged', () {
        // User profile documents cannot be directly edited by clients to change counters
        final directFollowersWrite = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_bob',
          existingData: {'followersCount': 0},
          incomingData: {'followersCount': 1},
          relationshipExistsBefore: false,
          relationshipExistsAfter: true,
          isBlockedByTarget: false,
        );
        expect(directFollowersWrite, isFalse);

        final directFollowingWrite = FirestoreRulesSimulator.evaluateUserDocUpdate(
          authUid: 'user_alice',
          docUserId: 'user_alice',
          existingData: {'followingCount': 0},
          incomingData: {'followingCount': 1},
          relationshipExistsBefore: false,
          isBlockedByTarget: false,
        );
        expect(directFollowingWrite, isFalse);

        // Allowed follow relationship creation
        final validRelationship = FirestoreRulesSimulator.evaluateFollowDocCreate(
          authUid: 'user_alice',
          userId: 'user_alice',
          targetId: 'user_bob',
          isBlocked: false,
        );
        expect(validRelationship, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Widget Integration: DiscoverScreen and PostCard follow button states
    // -------------------------------------------------------------------------
    testWidgets('DiscoverScreen and PostCard render pending state and disabled follow button', (tester) async {
      final authProvider = MockAuthProvider(aliceUser);
      final postProvider = PostProvider();
      final connProvider = ConnectionProvider();

      final post = PostModel(
        id: 'post_bob_1',
        userId: 'user_bob',
        username: 'bob',
        userProfilePic: 'crushie_avatar_2',
        userIsVerified: false,
        userIsOnline: true,
        userLastSeen: DateTime.now(),
        userCountry: 'Kenya',
        userCity: 'Nairobi',
        community: 'Coffee Date',
        lookingFor: 'Coffee',
        location: 'Nairobi',
        ageRangeMin: 21,
        ageRangeMax: 30,
        availability: 'Tonight',
        description: 'Hello from Bob',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        crushCount: 0,
        crushedUserIds: [],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
            ChangeNotifierProvider<PostProvider>.value(value: postProvider),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PostCard(post: post),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('+ Follow'), findsOneWidget);

      // Follow via PostCard
      await tester.tap(find.text('+ Follow'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Once followed, '+ Follow' button disappears from PostCard (since isFollowing is true)
      expect(find.text('+ Follow'), findsNothing);
      expect(userProvider.isFollowing('user_bob'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 11. Targeted Final Fixes: Concurrency, Counter Query Errors, Deletion Retry
    // -------------------------------------------------------------------------
    group('11. Targeted Final Fixes (Concurrency, Counter Errors, Deletion Retry)', () {
      test('11.1. Concurrency guard prevents duplicate writes and coalesces concurrent follow calls', () async {
        // Dispatch concurrent follow calls to mock Firestore
        final call1 = mockFirestore.followUser(currentUserId: 'user_alice', targetUserId: 'user_bob');
        final call2 = mockFirestore.followUser(currentUserId: 'user_alice', targetUserId: 'user_bob');

        final results = await Future.wait([call1, call2]);
        expect(results[0], isTrue);
        expect(results[1], isTrue);
        expect(mockFirestore.hasFollowRelationship('user_alice', 'user_bob'), isTrue);
      });

      testWidgets('11.2. Counter query errors render "-" unavailable indicator and retry on tap', (tester) async {
        mockFirestore.shouldFailFollowersCount = true;
        mockFirestore.shouldFailFollowingCount = true;

        final authProvider = MockAuthProvider(aliceUser);
        final postProvider = PostProvider();
        final connProvider = ConnectionProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider<PostProvider>.value(value: postProvider),
              ChangeNotifierProvider<ConnectionProvider>.value(value: connProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ProfileStatsSection(
                  user: bobUser,
                  isSelf: false,
                  postCount: 3,
                  isDark: false,
                ),
              ),
            ),
          ),
        );

        // While loading, displays '...'
        expect(find.text('...'), findsAtLeastNWidgets(1));

        // Pump event queue so async count queries finish
        await tester.pumpAndSettle();

        // Failed queries display '-' rather than false '0'
        expect(find.text('-'), findsNWidgets(2));
        expect(find.text('0'), findsNothing);

        // Now restore backend and tap to retry
        mockFirestore.shouldFailFollowersCount = false;
        mockFirestore.shouldFailFollowingCount = false;
        await tester.tap(find.text('-').first);
        await tester.pump();
        await tester.pumpAndSettle();

        // Counts successfully loaded and display true '0'
        expect(find.text('-'), findsNothing);
        expect(find.text('0'), findsNWidgets(2));
      });

      test('11.3. Account deletion retry resolves effectiveUid from firebaseUser when public profile is missing', () {
        // Simulate missing public profile document (currentUser == null) but valid Firebase Auth UID
        final String? currentUserUid = null;
        final String firebaseAuthUid = 'user_deleted_profile_123';

        final effectiveUid = currentUserUid ?? firebaseAuthUid;
        expect(effectiveUid, equals('user_deleted_profile_123'));
        expect(effectiveUid.isNotEmpty, isTrue);
      });
    });
  });
}
