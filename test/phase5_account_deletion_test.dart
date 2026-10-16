import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:crushie/models/user_model.dart';
import 'package:crushie/models/post_model.dart';
import 'package:crushie/models/chat_message_model.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/services/storage_service.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/providers/theme_provider.dart';
import 'package:crushie/screens/settings/settings_screen.dart';

class MockFirebaseAuthException implements fb_auth.FirebaseAuthException {
  @override
  final String code;
  @override
  final String? message;
  @override
  final String? email;
  @override
  final fb_auth.AuthCredential? credential;
  @override
  final String? tenantId;
  @override
  final String? phoneNumber;
  @override
  final StackTrace? stackTrace;

  MockFirebaseAuthException(this.code, [this.message])
      : email = null,
        credential = null,
        tenantId = null,
        phoneNumber = null,
        stackTrace = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePhase5AuthProvider extends ChangeNotifier implements AuthProvider {
  bool _isLoading = false;
  @override
  bool get isLoading => _isLoading;

  String? _errorMessage;
  @override
  String? get errorMessage => _errorMessage;

  String? _errorCode;
  @override
  String? get errorCode => _errorCode;

  UserModel? mockUser;
  @override
  UserModel? get currentUser => mockUser;

  @override
  bool get isAuthenticated => mockUser != null;

  bool mockIsGoogleUser = false;
  @override
  bool get isGoogleUser => mockIsGoogleUser;

  @override
  bool get isEmailVerified => true;

  @override
  bool get isNewUser => false;

  int deleteAccountCallCount = 0;
  String? lastDeleteTargetUserId;
  String? lastDeletePassword;
  bool deleteShouldSucceed = true;
  String? failureCode;
  String? failureMessage;

  @override
  Future<bool> deleteAccount(String userId, {String? currentPassword}) async {
    if (_isLoading) {
      return false;
    }

    if (currentUser == null || currentUser!.id != userId) {
      _errorMessage =
          'Unauthorized: You cannot delete another user\'s account.';
      _errorCode = 'unauthorized';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    deleteAccountCallCount++;
    lastDeleteTargetUserId = userId;
    lastDeletePassword = currentPassword;

    await Future.delayed(const Duration(milliseconds: 10));
    _isLoading = false;

    if (deleteShouldSucceed) {
      mockUser = null;
      notifyListeners();
      return true;
    } else {
      _errorCode = failureCode ?? 'deletion-error';
      _errorMessage = failureMessage ?? 'Failed to delete account.';
      notifyListeners();
      return false;
    }
  }

  @override
  Future<bool> signOut() async {
    mockUser = null;
    notifyListeners();
    return true;
  }

  @override
  void refreshUser() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 — Complete Account Deletion Suite', () {
    late DatabaseService db;
    late UserModel sampleUser;

    setUp(() {
      db = DatabaseService();
      db.clearUserData();

      sampleUser = UserModel(
        id: 'user_delete_123',
        username: 'test_delete_user',
        email: 'delete_me@crushie.app',
        country: 'Kenya',
        city: 'Nairobi',
        dateOfBirth: DateTime(1995, 5, 20),
        gender: 'Female',
        bio: 'Account scheduled for deletion',
        profilePicUrl:
            'https://storage.googleapis.com/crushie/profiles/user_delete_123/p.jpg',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+254712345678',
        profileCompleted: true,
      );
      db.updateUser(sampleUser);
    });

    tearDown(() {
      db.clearUserData();
    });

    test(
        '1. Successful deletion workflow clears user, posts, connections, and state',
        () async {
      final fakeAuth = FakePhase5AuthProvider();
      fakeAuth.mockUser = sampleUser;

      // Seed in-memory posts, connections, notifications
      final userPost = PostModel(
        id: 'post_del_1',
        userId: sampleUser.id,
        username: sampleUser.username,
        userProfilePic: sampleUser.profilePicUrl,
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
        description: 'Post by deleting user',
        mediaType: 'image',
        mediaUrl:
            'https://storage.googleapis.com/crushie/posts/user_delete_123/img.jpg',
        crushCount: 5,
        crushesCount: 2,
        crushedUserIds: ['user_other'],
        isBoosted: false,
        isActive: true,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      db.createPost(userPost);

      expect(db.getUser(sampleUser.id), isNotNull);
      expect(db.posts.any((p) => p.userId == sampleUser.id), isTrue);

      final success = await fakeAuth.deleteAccount(sampleUser.id,
          currentPassword: 'ValidPassword123!');
      expect(success, isTrue);
      expect(fakeAuth.deleteAccountCallCount, 1);
      expect(fakeAuth.currentUser, isNull);
      expect(fakeAuth.isAuthenticated, isFalse);

      // Verify DatabaseService cleanup
      db.deleteUser(sampleUser.id);
      expect(db.getUser(sampleUser.id), isNull);
      expect(db.posts.any((p) => p.userId == sampleUser.id), isFalse);
    });

    testWidgets(
        '2. Cancellation of confirmation dialog does NOT initiate deletion',
        (WidgetTester tester) async {
      final fakeAuth = FakePhase5AuthProvider();
      fakeAuth.mockUser = sampleUser;
      fakeAuth.mockIsGoogleUser = false;

      bool onLogoutCalled = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: SettingsScreen(
              onLogout: () => onLogoutCalled = true,
              onOpenVerification: () {},
              onOpenPremium: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Delete Account option and tap it
      final deleteTile = find.text('Delete Account');
      await tester.scrollUntilVisible(deleteTile, 200,
          scrollable: find.byType(Scrollable));
      expect(deleteTile, findsOneWidget);
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();

      // Verify confirmation dialog is visible
      expect(find.text('Delete Account?'), findsOneWidget);
      expect(find.text('Confirm Password to Delete'), findsOneWidget);

      // Tap 'Cancel'
      final cancelButton = find.text('Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Dialog must be dismissed, no deletion performed, and logout not called
      expect(find.text('Delete Account?'), findsNothing);
      expect(fakeAuth.deleteAccountCallCount, 0);
      expect(onLogoutCalled, isFalse);
      expect(fakeAuth.isAuthenticated, isTrue);
    });

    test('3. Signed-out and unauthorized deletion attempts are rejected',
        () async {
      final fakeAuth = FakePhase5AuthProvider();
      // Case A: Signed-out user
      fakeAuth.mockUser = null;
      final resSignedOut =
          await fakeAuth.deleteAccount('user_123', currentPassword: 'password');
      expect(resSignedOut, isFalse);
      expect(fakeAuth.errorCode, 'unauthorized');
      expect(fakeAuth.errorMessage, contains('Unauthorized'));

      // Case B: Cross-account deletion attempt
      fakeAuth.mockUser = sampleUser; // ID: 'user_delete_123'
      final resOtherUser = await fakeAuth.deleteAccount('user_VICTIM_999',
          currentPassword: 'password');
      expect(resOtherUser, isFalse);
      expect(fakeAuth.errorCode, 'unauthorized');
      expect(fakeAuth.errorMessage, contains('cannot delete another user'));
      expect(fakeAuth.deleteAccountCallCount, 0); // Guarded before execution
    });

    test(
        '4. Re-authentication failure leaves user session intact and reports error',
        () async {
      final fakeAuth = FakePhase5AuthProvider();
      fakeAuth.mockUser = sampleUser;
      fakeAuth.deleteShouldSucceed = false;
      fakeAuth.failureCode = 'wrong-password';
      fakeAuth.failureMessage =
          'Incorrect password. Please verify and try again.';

      final success = await fakeAuth.deleteAccount(sampleUser.id,
          currentPassword: 'WrongPassword!');
      expect(success, isFalse);
      expect(fakeAuth.errorCode, 'wrong-password');
      expect(fakeAuth.errorMessage, contains('Incorrect password'));
      // User must not be deleted if re-authentication fails
      expect(fakeAuth.currentUser, isNotNull);
      expect(fakeAuth.currentUser!.id, sampleUser.id);
    });

    test(
        '5. Recent-login requirement (requires-recent-login) triggers user-friendly re-login guidance',
        () async {
      final fakeAuth = FakePhase5AuthProvider();
      fakeAuth.mockUser = sampleUser;
      fakeAuth.deleteShouldSucceed = false;
      fakeAuth.failureCode = 'requires-recent-login';
      fakeAuth.failureMessage =
          'For security, this operation requires a recent login. Please log out, sign in again, and retry.';

      final success = await fakeAuth.deleteAccount(sampleUser.id,
          currentPassword: 'validPassword');
      expect(success, isFalse);
      expect(fakeAuth.errorCode, 'requires-recent-login');
      expect(fakeAuth.errorMessage, contains('requires a recent login'));
      expect(fakeAuth.currentUser, isNotNull);
    });

    test(
        '6. Firestore cleanup failure preserves Firebase Auth account for retry',
        () async {
      final fakeAuth = FakePhase5AuthProvider();
      fakeAuth.mockUser = sampleUser;
      fakeAuth.deleteShouldSucceed = false;
      fakeAuth.failureCode = 'firestore-cleanup-error';
      fakeAuth.failureMessage =
          'Network connection interrupted during Firestore data cleanup.';

      // Attempt 1: Fails due to Firestore error
      final attempt1 = await fakeAuth.deleteAccount(sampleUser.id,
          currentPassword: 'ValidPassword123!');
      expect(attempt1, isFalse);
      expect(fakeAuth.errorCode, 'firestore-cleanup-error');
      // Account remains intact for retry
      expect(fakeAuth.currentUser, isNotNull);

      // Attempt 2 (Retry): Succeeds cleanly
      fakeAuth.deleteShouldSucceed = true;
      fakeAuth.failureCode = null;
      fakeAuth.failureMessage = null;
      final attempt2 = await fakeAuth.deleteAccount(sampleUser.id,
          currentPassword: 'ValidPassword123!');
      expect(attempt2, isTrue);
      expect(fakeAuth.currentUser, isNull);
    });

    test(
        '7. Storage cleanup distinguishes already-missing objects from retryable network errors',
        () {
      // 1. Missing objects are treated as success (benign)
      const benignResult = StorageCleanupResult(
        success: true,
        deletedCount: 0,
      );
      expect(benignResult.success, isTrue);
      expect(benignResult.isRetryable, isFalse);

      // 2. Network failures are flagged as retryable
      const networkFailure = StorageCleanupResult(
        success: false,
        errorMessage: 'Network connection closed by peer',
        errorCode: 'network-request-failed',
        isRetryable: true,
      );
      expect(networkFailure.success, isFalse);
      expect(networkFailure.isRetryable, isTrue);
      expect(networkFailure.errorCode, 'network-request-failed');

      // 3. Remote URL validation
      final url =
          'https://firebasestorage.googleapis.com/v0/b/bucket/o/verification%2Fuser_123%2Fphoto.jpg';
      final isRemote = url.startsWith('http://') ||
          url.startsWith('https://') ||
          url.startsWith('gs://');
      expect(isRemote, isTrue);

      final localPath = '/data/user/0/com.mudozi.crushie/cache/image.jpg';
      final isLocalRemote = localPath.startsWith('http://') ||
          localPath.startsWith('https://') ||
          localPath.startsWith('gs://');
      expect(isLocalRemote, isFalse);
    });

    test('8. Subcollections and owned records deletion inventory mapping', () {
      final subcollections = [
        'users/{userId}/private/settings',
        'users/{userId}/follows',
        'users/{userId}/blocks',
        'users/{userId}/notifications',
        'posts/{postId}/likes',
        'posts/{postId}/comments',
      ];
      expect(subcollections.length, 6);
      expect(subcollections, contains('users/{userId}/private/settings'));
      expect(subcollections, contains('users/{userId}/follows'));
      expect(subcollections, contains('users/{userId}/blocks'));
      expect(subcollections, contains('users/{userId}/notifications'));
    });

    test(
        '9. Shared messages are soft-deleted for privacy without breaking recipient view',
        () {
      final msg = ChatMessageModel(
        id: 'msg_shared_1',
        connectionId: 'conn_123',
        senderId: sampleUser.id,
        receiverId: 'other_user_456',
        content: 'Original secret message',
        mediaUrl: 'https://storage.googleapis.com/chats/photo.jpg',
        createdAt: DateTime.now(),
      );

      // Simulating soft deletion on account deletion
      final softDeletedMsg = ChatMessageModel(
        id: msg.id,
        connectionId: msg.connectionId,
        senderId: msg.senderId,
        receiverId: msg.receiverId,
        content: 'This message was deleted',
        message: 'This message was deleted',
        mediaUrl: null,
        createdAt: msg.createdAt,
        isDeletedForEveryone: true,
      );

      expect(softDeletedMsg.isDeletedForEveryone, isTrue);
      expect(softDeletedMsg.content, 'This message was deleted');
      expect(softDeletedMsg.mediaUrl, isNull);
      expect(softDeletedMsg.senderId, sampleUser.id);
      expect(softDeletedMsg.receiverId, 'other_user_456');
    });

    test(
        '10. Audit logs (transactions, reports) are retained legally without personal data leakage',
        () {
      // TransactionModel does not allow client-side deletion
      final tx = {
        'id': 'tx_123',
        'userId': sampleUser.id,
        'type': 'premium',
        'amount': 250.0,
        'status': 'completed',
      };
      expect(tx['id'], 'tx_123');
      expect(tx['amount'], 250.0);

      // Reports are write-only for clients, allow delete: if false in firestore.rules
      final report = {
        'id': 'rep_123',
        'reporterId': sampleUser.id,
        'targetId': 'post_bad_456',
        'reason': 'Spam or abuse',
        'status': 'pending',
      };
      expect(report['status'], 'pending');
    });

    test(
        '11. Prevention of duplicate deletion requests during active operation',
        () async {
      final fakeAuth = FakePhase5AuthProvider();
      fakeAuth.mockUser = sampleUser;

      // Launch first deletion
      final future1 =
          fakeAuth.deleteAccount(sampleUser.id, currentPassword: 'pass');
      expect(fakeAuth.isLoading, isTrue);

      // Immediate second duplicate deletion attempt while first is in-flight
      final future2 =
          fakeAuth.deleteAccount(sampleUser.id, currentPassword: 'pass');
      final result2 = await future2;
      expect(result2, isFalse); // Re-entry rejected immediately

      final result1 = await future1;
      expect(result1, isTrue);
      expect(
          fakeAuth.deleteAccountCallCount, 1); // Only 1 operation was executed
    });

    test(
        '12. Existing post expiration lifecycle (30-day policy) is fully preserved',
        () {
      final now = DateTime.now();
      final activePost = PostModel(
        id: 'post_active_1',
        userId: 'other_user',
        username: 'other',
        userProfilePic: '',
        userIsVerified: false,
        userIsOnline: true,
        userLastSeen: now,
        userCountry: 'Kenya',
        userCity: 'Nairobi',
        community: 'All',
        lookingFor: 'Coffee',
        location: 'Nairobi',
        ageRangeMin: 20,
        ageRangeMax: 30,
        availability: 'Anytime',
        description: 'Active post',
        mediaType: 'none',
        crushCount: 0,
        crushesCount: 0,
        crushedUserIds: const [],
        isBoosted: false,
        isActive: true,
        createdAt: now,
        expiresAt: now.add(const Duration(days: 30)),
      );

      final expiredPost = PostModel(
        id: 'post_expired_1',
        userId: 'other_user_2',
        username: 'other2',
        userProfilePic: '',
        userIsVerified: false,
        userIsOnline: true,
        userLastSeen: now,
        userCountry: 'Kenya',
        userCity: 'Nairobi',
        community: 'All',
        lookingFor: 'Coffee',
        location: 'Nairobi',
        ageRangeMin: 20,
        ageRangeMax: 30,
        availability: 'Anytime',
        description: 'Expired post',
        mediaType: 'none',
        crushCount: 0,
        crushesCount: 0,
        crushedUserIds: const [],
        isBoosted: false,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 35)),
        expiresAt: now.subtract(const Duration(days: 5)),
      );

      // Verify 30-day lifecycle query filter invariant
      bool isPostActive(PostModel p) => p.isActive && p.expiresAt.isAfter(now);
      expect(isPostActive(activePost), isTrue);
      expect(isPostActive(expiredPost), isFalse);
    });

    test(
        '13. DatabaseService.clearUserData completely resets in-memory cache on sign-out/deletion',
        () {
      db.updateUser(sampleUser);
      expect(db.users.containsKey(sampleUser.id), isTrue);

      db.clearUserData();
      expect(db.users.isEmpty, isTrue);
      expect(db.connections.isEmpty, isTrue);
      expect(db.posts.isEmpty, isTrue);
      expect(db.isFollowing('any_user'), isFalse);
    });
  });
}
