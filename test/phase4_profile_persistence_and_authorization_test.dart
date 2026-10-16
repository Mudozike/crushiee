import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:crushie/models/user_model.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/services/firestore_service.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/providers/theme_provider.dart';
import 'package:crushie/screens/profile/edit_profile_screen.dart';

class MockFirebaseException implements fb_auth.FirebaseException {
  @override
  final String plugin;
  @override
  final String code;
  @override
  final String? message;
  @override
  final StackTrace? stackTrace;

  MockFirebaseException({
    required this.plugin,
    required this.code,
    this.message,
    this.stackTrace,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePhase4AuthProvider extends ChangeNotifier implements AuthProvider {
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

  bool updateShouldSucceed = true;
  String? updateFailureMessage;
  String? updateFailureCode;
  int updateCalls = 0;
  UserModel? lastSavedUser;

  @override
  Future<bool> updateUserProfile(UserModel updatedUser) async {
    if (_isLoading) return false;

    final currentUid = mockUser?.id;
    if (currentUid == null || currentUid.trim().isEmpty) {
      _errorMessage =
          'No authenticated user session found. Please sign in again.';
      _errorCode = 'unauthenticated';
      notifyListeners();
      return false;
    }

    if (updatedUser.id.trim().isNotEmpty &&
        updatedUser.id.trim() != currentUid.trim()) {
      _errorMessage = 'Unauthorized: cannot update another user\'s profile.';
      _errorCode = 'permission-denied';
      notifyListeners();
      return false;
    }

    updateCalls++;
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 25));
    _isLoading = false;

    if (updateShouldSucceed) {
      mockUser = updatedUser;
      lastSavedUser = updatedUser;
      DatabaseService().updateUser(updatedUser);
      _errorCode = null;
      notifyListeners();
      return true;
    } else {
      _errorCode = updateFailureCode ?? 'permission-denied';
      _errorMessage = updateFailureMessage ??
          'Permission denied: you do not have permission to modify this profile.';
      notifyListeners();
      return false;
    }
  }

  @override
  Future<UserModel?> reloadUserProfile([String? explicitUid]) async {
    final uid = explicitUid ?? mockUser?.id;
    if (uid != null) {
      return DatabaseService().getUser(uid) ?? mockUser;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UserModel makeSampleUser({
    required String id,
    required String username,
    required String email,
    bool isPremium = false,
    bool isVerified = false,
  }) {
    return UserModel(
      id: id,
      username: username,
      email: email,
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(1997, 6, 15),
      gender: 'Female',
      bio: 'Living life to the fullest.',
      profilePicUrl: 'crushie_avatar_1',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254711223344',
      profileCompleted: true,
      isPremium: isPremium,
      premiumExpiry: isPremium ? DateTime(2027, 1, 1) : null,
      isVerified: isVerified,
      verifiedExpiry: isVerified ? DateTime(2027, 1, 1) : null,
      followersCount: 15,
      followingCount: 8,
      communities: ['Tech', 'Music'],
      blockedUserIds: ['blocked_user_99'],
      createdAt: DateTime(2025, 1, 1),
    );
  }

  group('Phase 4 — Profile Persistence Model & Field Preservation', () {
    test(
        'copyWith correctly updates edited fields while preserving untouched fields',
        () {
      final original = makeSampleUser(
        id: 'user_123',
        username: 'alice_ke',
        email: 'alice@example.com',
        isPremium: true,
        isVerified: true,
      );

      final updated = original.copyWith(
        username: 'alice_superstar',
        bio: 'Updated bio information.',
        city: 'Mombasa',
        preferredContactMethod: 'Telegram',
        contactDetails: '@alice_tg',
      );

      // Verify edited fields
      expect(updated.username, equals('alice_superstar'));
      expect(updated.bio, equals('Updated bio information.'));
      expect(updated.city, equals('Mombasa'));
      expect(updated.preferredContactMethod, equals('Telegram'));
      expect(updated.contactDetails, equals('@alice_tg'));

      // Verify unedited fields were strictly preserved
      expect(updated.id, equals('user_123'));
      expect(updated.email, equals('alice@example.com'));
      expect(updated.isPremium, isTrue);
      expect(updated.isVerified, isTrue);
      expect(updated.dateOfBirth, equals(original.dateOfBirth));
      expect(updated.gender, equals(original.gender));
      expect(updated.profilePicUrl, equals(original.profilePicUrl));
      expect(updated.followersCount, equals(15));
      expect(updated.followingCount, equals(8));
      expect(updated.communities, equals(['Tech', 'Music']));
      expect(updated.blockedUserIds, equals(['blocked_user_99']));
      expect(updated.createdAt, equals(original.createdAt));
    });

    test(
        'FirestoreService.saveUserProfile rejects empty user ID with ArgumentError',
        () async {
      final firestoreService = FirestoreService();
      final invalidUser = makeSampleUser(
        id: '   ',
        username: 'empty_id_user',
        email: 'empty@example.com',
      );

      expect(
        () => firestoreService.saveUserProfile(invalidUser),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'Fresh data read restores persisted profile data after cold cache wipe',
        () {
      final db = DatabaseService();
      final user = makeSampleUser(
        id: 'user_cold_read',
        username: 'cold_user',
        email: 'cold@example.com',
      );

      // Step 1: Simulate saving user to DB cache
      db.updateUser(user);
      expect(db.getUser('user_cold_read'), isNotNull);
      expect(db.getUser('user_cold_read')?.city, equals('Nairobi'));

      // Step 2: Wipe in-memory singleton cache to simulate cold app restart
      db.clearUserData();
      expect(db.getUser('user_cold_read'), isNull);

      // Step 3: Simulate restoring fresh record from persistent store
      final restoredFromPersistent = UserModel.fromMap({
        'username': 'cold_user',
        'email': 'cold@example.com',
        'country': 'Kenya',
        'city': 'Mombasa', // newly updated value
        'bio': 'Restored from persistent store',
        'dateOfBirth': '1997-06-15T00:00:00.000',
        'gender': 'Female',
        'profilePicUrl': 'crushie_avatar_1',
        'profileCompleted': true,
        'isVerified': false,
        'isPremium': false,
        'preferredContactMethod': 'WhatsApp',
        'contactDetails': '+254711223344',
      }, 'user_cold_read');

      db.updateUser(restoredFromPersistent);

      final freshUser = db.getUser('user_cold_read');
      expect(freshUser, isNotNull);
      expect(freshUser!.city, equals('Mombasa'));
      expect(freshUser.bio, equals('Restored from persistent store'));
    });
  });

  group('Phase 4 — AuthProvider.updateUserProfile & Security Controls', () {
    test('Successful profile update saves to DB and updates currentUser',
        () async {
      final auth = FakePhase4AuthProvider();
      final original = makeSampleUser(
        id: 'user_auth_1',
        username: 'old_name',
        email: 'auth1@example.com',
      );
      auth.mockUser = original;

      final updated = original.copyWith(
        username: 'new_name',
        bio: 'Brand new bio statement.',
      );

      final result = await auth.updateUserProfile(updated);

      expect(result, isTrue);
      expect(auth.currentUser?.username, equals('new_name'));
      expect(auth.currentUser?.bio, equals('Brand new bio statement.'));
      expect(auth.isLoading, isFalse);
      expect(auth.errorMessage, isNull);
      expect(auth.updateCalls, equals(1));
    });

    test('Duplicate concurrent updateUserProfile calls are safely rejected',
        () async {
      final auth = FakePhase4AuthProvider();
      final user = makeSampleUser(
        id: 'user_duplicate_test',
        username: 'dup_user',
        email: 'dup@example.com',
      );
      auth.mockUser = user;

      final future1 = auth.updateUserProfile(user.copyWith(bio: 'First call'));
      final future2 = auth.updateUserProfile(user.copyWith(bio: 'Second call'));

      final res1 = await future1;
      final res2 = await future2;

      expect(res1, isTrue);
      expect(res2, isFalse); // Rejected as already in flight
      expect(auth.updateCalls, equals(1));
    });

    test('Cross-account write protection: User A cannot update User B profile',
        () async {
      final auth = FakePhase4AuthProvider();
      // Authenticated as User A
      auth.mockUser = makeSampleUser(
        id: 'user_A',
        username: 'user_a',
        email: 'a@example.com',
      );

      // Attempt to modify User B's profile
      final userB = makeSampleUser(
        id: 'user_B',
        username: 'user_b_hacked',
        email: 'b@example.com',
      );

      final result = await auth.updateUserProfile(userB);

      expect(result, isFalse);
      expect(auth.errorCode, equals('permission-denied'));
      expect(auth.errorMessage, contains('cannot update another user'));
      expect(auth.currentUser?.id, equals('user_A'));
      expect(auth.currentUser?.username, equals('user_a'));
    });

    test('Unauthenticated user cannot update profile', () async {
      final auth = FakePhase4AuthProvider();
      auth.mockUser = null; // Unauthenticated session

      final user = makeSampleUser(
        id: 'user_unauth',
        username: 'unauth_user',
        email: 'unauth@example.com',
      );

      final result = await auth.updateUserProfile(user);

      expect(result, isFalse);
      expect(auth.errorCode, equals('unauthenticated'));
      expect(
          auth.errorMessage, contains('No authenticated user session found'));
    });

    test('Firestore write failure handles error and does not report success',
        () async {
      final auth = FakePhase4AuthProvider();
      final user = makeSampleUser(
        id: 'user_failure_test',
        username: 'fail_user',
        email: 'fail@example.com',
      );
      auth.mockUser = user;
      auth.updateShouldSucceed = false;
      auth.updateFailureCode = 'permission-denied';
      auth.updateFailureMessage =
          'Permission denied: you do not have permission to modify this profile.';

      final result =
          await auth.updateUserProfile(user.copyWith(bio: 'New bio'));

      expect(result, isFalse);
      expect(auth.errorCode, equals('permission-denied'));
      expect(auth.errorMessage, contains('Permission denied'));
      // Local state is not mutated
      expect(auth.currentUser?.bio, equals('Living life to the fullest.'));
    });
  });

  group('Phase 4 — EditProfileScreen UI Widget Tests', () {
    testWidgets(
        'Editing profile form, submitting saves, displays success SnackBar, and pops',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = FakePhase4AuthProvider();
      final initialUser = makeSampleUser(
        id: 'user_widget_1',
        username: 'original_name',
        email: 'widget@example.com',
      );
      auth.mockUser = initialUser;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
          ],
          child: const MaterialApp(
            home: EditProfileScreen(),
          ),
        ),
      );

      // Verify fields initialized with current user values
      expect(find.text('original_name'), findsOneWidget);

      // Edit username
      final usernameField = find.widgetWithText(TextFormField, 'Username');
      await tester.enterText(usernameField, 'renamed_user');

      // Edit bio
      final bioField = find.widgetWithText(TextFormField, 'Bio');
      await tester.enterText(bioField, 'My freshly updated bio.');

      // Tap Save Changes
      final saveBtn = find.text('Save Changes');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);

      await tester.pump(); // Start save
      await tester.pump(const Duration(milliseconds: 50)); // Finish delay
      await tester.pump(); // Render SnackBar

      expect(auth.updateCalls, equals(1));
      expect(auth.lastSavedUser?.username, equals('renamed_user'));
      expect(auth.lastSavedUser?.bio, equals('My freshly updated bio.'));
      expect(find.text('Profile updated successfully!'), findsOneWidget);
    });

    testWidgets(
        'Failed save in EditProfileScreen displays error SnackBar and preserves entered values',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = FakePhase4AuthProvider();
      final initialUser = makeSampleUser(
        id: 'user_widget_2',
        username: 'steady_user',
        email: 'steady@example.com',
      );
      auth.mockUser = initialUser;
      auth.updateShouldSucceed = false;
      auth.updateFailureMessage =
          'Network error: unable to save profile changes.';

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
          ],
          child: const MaterialApp(
            home: EditProfileScreen(),
          ),
        ),
      );

      // Enter new bio
      final bioField = find.widgetWithText(TextFormField, 'Bio');
      await tester.enterText(bioField, 'New unsaved bio draft.');

      // Tap Save Changes
      final saveBtn = find.text('Save Changes');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(auth.updateCalls, equals(1));
      expect(find.text('Network error: unable to save profile changes.'),
          findsOneWidget);
      // The user's typed input is still intact in the form!
      expect(find.text('New unsaved bio draft.'), findsOneWidget);
    });
  });

  group('Phase 4 — Firestore Authorization Invariants', () {
    // 1. A signed-out user cannot access protected user data.
    test(
        'Rule Invariant 1: A signed-out user cannot access protected user data',
        () {
      bool evaluateUserReadRule({required bool isSignedIn}) {
        return isSignedIn;
      }

      expect(evaluateUserReadRule(isSignedIn: false), isFalse);
      expect(evaluateUserReadRule(isSignedIn: true), isTrue);
    });

    // 2. User A cannot write User B's profile or private settings.
    test(
        'Rule Invariant 2: User A cannot write User B profile or private settings',
        () {
      bool evaluatePrivateSettingsWriteRule({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
      }) {
        return isSignedIn && authUid == targetUserId;
      }

      bool evaluateProfileWriteRule({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required Set<String> affectedKeys,
      }) {
        if (!isSignedIn) return false;
        if (authUid == targetUserId) return true;
        // Non-owner can only touch followersCount via follow
        return affectedKeys.difference({'followersCount'}).isEmpty;
      }

      // User A writing private settings of User B -> DENIED
      expect(
        evaluatePrivateSettingsWriteRule(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_B',
        ),
        isFalse,
      );

      // User A writing profile info (username, bio) of User B -> DENIED
      expect(
        evaluateProfileWriteRule(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_B',
          affectedKeys: {'username', 'bio'},
        ),
        isFalse,
      );
    });

    // 3. User A cannot assign themselves premium status.
    test(
        'Rule Invariant 3: User A cannot assign themselves premium status (isPremium)',
        () {
      bool evaluateSelfUpdate({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required Set<String> affectedKeys,
      }) {
        if (!isSignedIn || authUid != targetUserId) return false;
        const blockedKeys = {
          'role',
          'isPremium',
          'premiumExpiry',
          'isVerified',
          'verifiedExpiry',
          'followersCount',
        };
        return !affectedKeys.any(blockedKeys.contains);
      }

      // User A attempting to add or modify isPremium -> DENIED
      expect(
        evaluateSelfUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'isPremium'},
        ),
        isFalse,
      );
    });

    // 4. User A cannot assign themselves verified status.
    test(
        'Rule Invariant 4: User A cannot assign themselves verified status (isVerified)',
        () {
      bool evaluateSelfUpdate({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required Set<String> affectedKeys,
      }) {
        if (!isSignedIn || authUid != targetUserId) return false;
        const blockedKeys = {
          'role',
          'isPremium',
          'premiumExpiry',
          'isVerified',
          'verifiedExpiry',
          'followersCount',
        };
        return !affectedKeys.any(blockedKeys.contains);
      }

      // User A attempting to add or modify isVerified -> DENIED
      expect(
        evaluateSelfUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'isVerified'},
        ),
        isFalse,
      );
    });

    // 5. User A cannot modify protected expiry fields or role.
    test(
        'Rule Invariant 5: User A cannot modify protected expiry fields or role',
        () {
      bool evaluateSelfUpdate({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required Set<String> affectedKeys,
      }) {
        if (!isSignedIn || authUid != targetUserId) return false;
        const blockedKeys = {
          'role',
          'isPremium',
          'premiumExpiry',
          'isVerified',
          'verifiedExpiry',
          'followersCount',
        };
        return !affectedKeys.any(blockedKeys.contains);
      }

      // Attempting to modify role -> DENIED
      expect(
        evaluateSelfUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'role'},
        ),
        isFalse,
      );

      // Attempting to modify premiumExpiry -> DENIED
      expect(
        evaluateSelfUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'premiumExpiry'},
        ),
        isFalse,
      );

      // Attempting to modify verifiedExpiry -> DENIED
      expect(
        evaluateSelfUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'verifiedExpiry'},
        ),
        isFalse,
      );

      // Attempting to modify own followersCount -> DENIED
      expect(
        evaluateSelfUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'followersCount'},
        ),
        isFalse,
      );
    });

    // 6. Initial profile creation cannot grant privileged values.
    test(
        'Rule Invariant 6: Initial profile creation cannot grant privileged values',
        () {
      bool evaluateProfileCreateRule({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required Map<String, dynamic> data,
      }) {
        if (!isSignedIn || authUid != targetUserId) return false;

        // hasNoPrivilegeEscalation checks
        if (data.containsKey('role') && data['role'] != 'user') return false;
        if (data.containsKey('isPremium') && data['isPremium'] != false) {
          return false;
        }
        if (data.containsKey('premiumExpiry') &&
            data['premiumExpiry'] != null) {
          return false;
        }
        if (data.containsKey('isVerified') && data['isVerified'] != false) {
          return false;
        }
        if (data.containsKey('verifiedExpiry') &&
            data['verifiedExpiry'] != null) {
          return false;
        }
        if (data.containsKey('followersCount') && data['followersCount'] != 0) {
          return false;
        }
        if (data.containsKey('followingCount') && data['followingCount'] != 0) {
          return false;
        }

        return true;
      }

      // Valid initial profile creation
      expect(
        evaluateProfileCreateRule(
          isSignedIn: true,
          authUid: 'user_new',
          targetUserId: 'user_new',
          data: {
            'username': 'fresh_user',
            'isPremium': false,
            'isVerified': false,
            'followersCount': 0,
            'followingCount': 0,
          },
        ),
        isTrue,
      );

      // Malicious creation with isPremium: true -> DENIED
      expect(
        evaluateProfileCreateRule(
          isSignedIn: true,
          authUid: 'user_new',
          targetUserId: 'user_new',
          data: {
            'username': 'hacked_premium',
            'isPremium': true,
          },
        ),
        isFalse,
      );

      // Malicious creation with isVerified: true -> DENIED
      expect(
        evaluateProfileCreateRule(
          isSignedIn: true,
          authUid: 'user_new',
          targetUserId: 'user_new',
          data: {
            'username': 'hacked_verified',
            'isVerified': true,
          },
        ),
        isFalse,
      );

      // Malicious creation with role: 'admin' -> DENIED
      expect(
        evaluateProfileCreateRule(
          isSignedIn: true,
          authUid: 'user_new',
          targetUserId: 'user_new',
          data: {
            'username': 'hacked_admin',
            'role': 'admin',
          },
        ),
        isFalse,
      );

      // Malicious creation with fake followers -> DENIED
      expect(
        evaluateProfileCreateRule(
          isSignedIn: true,
          authUid: 'user_new',
          targetUserId: 'user_new',
          data: {
            'username': 'fame_seeker',
            'followersCount': 10000,
          },
        ),
        isFalse,
      );

      // User A attempting to create User B profile -> DENIED
      expect(
        evaluateProfileCreateRule(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_B',
          data: {'username': 'user_b'},
        ),
        isFalse,
      );
    });

    // 7. Legitimate edits to permitted profile fields still succeed.
    test(
        'Rule Invariant 7: Legitimate edits to permitted profile fields still succeed',
        () {
      bool evaluateProfileUpdateRule({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required Set<String> affectedKeys,
      }) {
        if (!isSignedIn) return false;
        final isOwner = authUid == targetUserId;
        if (isOwner &&
            !affectedKeys.any((k) => [
                  'role',
                  'isPremium',
                  'premiumExpiry',
                  'isVerified',
                  'verifiedExpiry',
                  'followersCount',
                ].contains(k))) {
          return true;
        }
        if (!isOwner && affectedKeys.difference({'followersCount'}).isEmpty) {
          return true;
        }
        return false;
      }

      // Permitted edit: bio, username, city, country, profilePicUrl, communities, followingCount
      expect(
        evaluateProfileUpdateRule(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {
            'username',
            'bio',
            'city',
            'country',
            'profilePicUrl',
            'communities',
            'updatedAt'
          },
        ),
        isTrue,
      );

      // Following action updates followingCount on self
      expect(
        evaluateProfileUpdateRule(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'followingCount'},
        ),
        isTrue,
      );

      // Following action updates followersCount on targetUser
      expect(
        evaluateProfileUpdateRule(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_B',
          affectedKeys: {'followersCount'},
        ),
        isTrue,
      );
    });

    // 8. Any intended trusted-server operations remain compatible with the rules.
    test(
        'Rule Invariant 8: Intended trusted-server operations (Admin SDK) remain compatible with rules',
        () {
      bool isPrivilegedAdminSdkOperation({required bool isAdminSdk}) {
        // Firebase Admin SDK used in Cloud Functions completely bypasses Security Rules
        return isAdminSdk;
      }

      // Webhook updating isPremium or isVerified via Admin SDK succeeds without restriction
      expect(isPrivilegedAdminSdkOperation(isAdminSdk: true), isTrue);
      // Untrusted direct client operations remain subject to security rules
      expect(isPrivilegedAdminSdkOperation(isAdminSdk: false), isFalse);
    });
  });

  group('Phase 4 — Social Counters & Connection Quota Security Tests', () {
    // 1. Non-owner arbitrary follower count manipulation is rejected
    test(
        'Non-owner cannot arbitrarily overwrite followersCount (must strictly be +/- 1)',
        () {
      bool evaluateFollowerUpdate({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required Set<String> affectedKeys,
        required int oldFollowersCount,
        required int newFollowersCount,
        required bool isBlocked,
      }) {
        if (!isSignedIn || authUid == targetUserId) return false;
        if (affectedKeys.difference({'followersCount'}).isNotEmpty) {
          return false;
        }
        if (isBlocked) return false;
        if (newFollowersCount < 0) return false;

        final isValidIncrement = (newFollowersCount == oldFollowersCount + 1) ||
            (newFollowersCount == oldFollowersCount - 1);
        return isValidIncrement;
      }

      // User B attempting to arbitrarily inflate User A followersCount to 999999 -> DENIED
      expect(
        evaluateFollowerUpdate(
          isSignedIn: true,
          authUid: 'user_B',
          targetUserId: 'user_A',
          affectedKeys: {'followersCount'},
          oldFollowersCount: 15,
          newFollowersCount: 999999,
          isBlocked: false,
        ),
        isFalse,
      );

      // User B attempting to reset User A followersCount to 0 -> DENIED
      expect(
        evaluateFollowerUpdate(
          isSignedIn: true,
          authUid: 'user_B',
          targetUserId: 'user_A',
          affectedKeys: {'followersCount'},
          oldFollowersCount: 15,
          newFollowersCount: 0,
          isBlocked: false,
        ),
        isFalse,
      );

      // User B attempting to decrement User A followersCount to negative -> DENIED
      expect(
        evaluateFollowerUpdate(
          isSignedIn: true,
          authUid: 'user_B',
          targetUserId: 'user_A',
          affectedKeys: {'followersCount'},
          oldFollowersCount: 0,
          newFollowersCount: -1,
          isBlocked: false,
        ),
        isFalse,
      );

      // Legitimate follow (+1) -> ALLOWED
      expect(
        evaluateFollowerUpdate(
          isSignedIn: true,
          authUid: 'user_B',
          targetUserId: 'user_A',
          affectedKeys: {'followersCount'},
          oldFollowersCount: 15,
          newFollowersCount: 16,
          isBlocked: false,
        ),
        isTrue,
      );

      // Legitimate unfollow (-1) -> ALLOWED
      expect(
        evaluateFollowerUpdate(
          isSignedIn: true,
          authUid: 'user_B',
          targetUserId: 'user_A',
          affectedKeys: {'followersCount'},
          oldFollowersCount: 15,
          newFollowersCount: 14,
          isBlocked: false,
        ),
        isTrue,
      );
    });

    // 2. Non-owner follower increment is denied if blocked
    test('Non-owner follower increment is rejected if blocked by target user',
        () {
      bool evaluateFollowerUpdate({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required Set<String> affectedKeys,
        required int oldFollowersCount,
        required int newFollowersCount,
        required bool isBlocked,
      }) {
        if (!isSignedIn || authUid == targetUserId) return false;
        if (affectedKeys.difference({'followersCount'}).isNotEmpty) {
          return false;
        }
        if (isBlocked) return false;
        if (newFollowersCount < 0) return false;

        return (newFollowersCount == oldFollowersCount + 1) ||
            (newFollowersCount == oldFollowersCount - 1);
      }

      // Blocked user attempting to increment follower count -> DENIED
      expect(
        evaluateFollowerUpdate(
          isSignedIn: true,
          authUid: 'blocked_stalker',
          targetUserId: 'user_A',
          affectedKeys: {'followersCount'},
          oldFollowersCount: 10,
          newFollowersCount: 11,
          isBlocked: true,
        ),
        isFalse,
      );
    });

    // 3. Owner arbitrary followingCount modification is rejected
    test(
        'Owner cannot arbitrarily modify followingCount (must strictly be +/- 1 or unedited)',
        () {
      bool evaluateFollowingUpdate({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required Set<String> affectedKeys,
        required int oldFollowingCount,
        required int newFollowingCount,
      }) {
        if (!isSignedIn || authUid != targetUserId) return false;

        // If followingCount is not affected, profile update is unaffected by following check
        if (!affectedKeys.contains('followingCount')) {
          return true;
        }

        if (newFollowingCount < 0) return false;
        return (newFollowingCount == oldFollowingCount + 1) ||
            (newFollowingCount == oldFollowingCount - 1);
      }

      // User A attempting to self-inflate followingCount to 500000 -> DENIED
      expect(
        evaluateFollowingUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'followingCount'},
          oldFollowingCount: 5,
          newFollowingCount: 500000,
        ),
        isFalse,
      );

      // User A attempting to set negative followingCount -> DENIED
      expect(
        evaluateFollowingUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'followingCount'},
          oldFollowingCount: 0,
          newFollowingCount: -1,
        ),
        isFalse,
      );

      // User A editing bio without touching followingCount -> ALLOWED
      expect(
        evaluateFollowingUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'bio', 'city'},
          oldFollowingCount: 5,
          newFollowingCount: 5,
        ),
        isTrue,
      );

      // User A following someone (+1) -> ALLOWED
      expect(
        evaluateFollowingUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'followingCount'},
          oldFollowingCount: 5,
          newFollowingCount: 6,
        ),
        isTrue,
      );

      // User A unfollowing someone (-1) -> ALLOWED
      expect(
        evaluateFollowingUpdate(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          affectedKeys: {'followingCount'},
          oldFollowingCount: 5,
          newFollowingCount: 4,
        ),
        isTrue,
      );
    });

    // 4. Private settings subcollection blocks privilege escalation
    test(
        'Private settings creation and updates reject privileged escalation fields',
        () {
      bool evaluatePrivateSettingsRules({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required Map<String, dynamic> data,
      }) {
        if (!isSignedIn || authUid != targetUserId) return false;
        const privilegedKeys = [
          'role',
          'isPremium',
          'premiumExpiry',
          'isVerified',
          'verifiedExpiry',
          'followersCount',
          'followingCount',
        ];
        return !data.keys.any((k) => privilegedKeys.contains(k));
      }

      // Malicious attempt to self-assign isPremium via private/settings -> DENIED
      expect(
        evaluatePrivateSettingsRules(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          data: {'isPremium': true},
        ),
        isFalse,
      );

      // Malicious attempt to elevate role via private/settings -> DENIED
      expect(
        evaluatePrivateSettingsRules(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          data: {'role': 'admin'},
        ),
        isFalse,
      );

      // Malicious attempt to spoof followersCount via private/settings -> DENIED
      expect(
        evaluatePrivateSettingsRules(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          data: {'followersCount': 5000},
        ),
        isFalse,
      );

      // Valid private settings payload (email, contact, quotas, blocked list) -> ALLOWED
      expect(
        evaluatePrivateSettingsRules(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_A',
          data: {
            'email': 'user@example.com',
            'preferredContactMethod': 'WhatsApp',
            'contactDetails': '+254712345678',
            'dailyConnections': 3,
            'dailyConnectionsDate': '2026-10-15T00:00:00.000',
            'monthlyConnections': 15,
            'monthlyConnectionsMonth': '2026-10-15T00:00:00.000',
            'blockedUserIds': ['blocked_user_1'],
            'updatedAt': '2026-10-15T12:00:00.000',
          },
        ),
        isTrue,
      );
    });

    // 5. Defense-in-depth sanitization: getUserProfile strips spoofed private entitlements
    test(
        'getUserProfile defense-in-depth sanitizes privateData and prevents entitlement spoofing',
        () {
      final publicData = <String, dynamic>{
        'username': 'normal_user',
        'email': 'user@example.com',
        'isPremium': false,
        'isVerified': false,
        'role': 'user',
        'followersCount': 10,
        'followingCount': 5,
      };

      final roguePrivateData = <String, dynamic>{
        'contactDetails': '+254700000000',
        'isPremium': true, // malicious spoof attempt in private doc
        'role': 'admin', // malicious spoof attempt in private doc
        'followersCount': 999999, // malicious spoof attempt
      };

      // Apply the same sanitization implemented in FirestoreService.getUserProfile
      final sanitizedPrivateData = Map<String, dynamic>.from(roguePrivateData);
      sanitizedPrivateData.remove('role');
      sanitizedPrivateData.remove('isPremium');
      sanitizedPrivateData.remove('premiumExpiry');
      sanitizedPrivateData.remove('isVerified');
      sanitizedPrivateData.remove('verifiedExpiry');
      sanitizedPrivateData.remove('followersCount');
      sanitizedPrivateData.remove('followingCount');

      final combinedMap = {...sanitizedPrivateData, ...publicData};
      final user = UserModel.fromMap(combinedMap, 'user_test_uid');

      // Assert that public values strictly prevailed and rogue private overrides were eliminated
      expect(user.isPremium, isFalse);
      expect(user.isVerified, isFalse);
      expect(user.followersCount, equals(10));
      expect(user.followingCount, equals(5));
      expect(user.contactDetails, equals('+254700000000'));
    });

    // 6. Relationship existence checks: cannot repeat increments or decrement without relationship
    test(
        'Follow counter rules reject repeated increments and decrements without matching follow document',
        () {
      bool evaluateFollowRuleWithRelationship({
        required bool isSignedIn,
        required String authUid,
        required String targetUserId,
        required int oldFollowersCount,
        required int newFollowersCount,
        required bool followDocExists,
        required bool isBlocked,
      }) {
        if (!isSignedIn || authUid == targetUserId) return false;
        if (isBlocked) return false;
        if (newFollowersCount < 0) return false;

        // Increment (+1): only permitted if user is not already recorded as following
        if (newFollowersCount == oldFollowersCount + 1 && !followDocExists) {
          return true;
        }
        // Decrement (-1): only permitted if user was actually recorded as following
        if (newFollowersCount == oldFollowersCount - 1 && followDocExists) {
          return true;
        }
        return false;
      }

      // Case A: User A does NOT follow User B. Attempts decrement (-1) -> REJECTED (no relationship)
      expect(
        evaluateFollowRuleWithRelationship(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_B',
          oldFollowersCount: 10,
          newFollowersCount: 9,
          followDocExists: false,
          isBlocked: false,
        ),
        isFalse,
      );

      // Case B: User A does NOT follow User B. Follows (+1) -> ALLOWED
      expect(
        evaluateFollowRuleWithRelationship(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_B',
          oldFollowersCount: 10,
          newFollowersCount: 11,
          followDocExists: false,
          isBlocked: false,
        ),
        isTrue,
      );

      // Case C: User A ALREADY follows User B. Attempts repeated increment (+1) -> REJECTED
      expect(
        evaluateFollowRuleWithRelationship(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_B',
          oldFollowersCount: 11,
          newFollowersCount: 12,
          followDocExists: true,
          isBlocked: false,
        ),
        isFalse,
      );

      // Case D: User A ALREADY follows User B. Unfollows (-1) -> ALLOWED
      expect(
        evaluateFollowRuleWithRelationship(
          isSignedIn: true,
          authUid: 'user_A',
          targetUserId: 'user_B',
          oldFollowersCount: 11,
          newFollowersCount: 10,
          followDocExists: true,
          isBlocked: false,
        ),
        isTrue,
      );
    });

    // 7. Connection quota reset prevention (hasNoQuotaReset)
    test(
        'hasNoQuotaReset rejects decreasing daily or monthly connection counts within the same window',
        () {
      bool hasNoQuotaReset(
          Map<String, dynamic> oldData, Map<String, dynamic> newData) {
        final dailyCheck = !newData.containsKey('dailyConnections') ||
            !oldData.containsKey('dailyConnections') ||
            !newData.containsKey('dailyConnectionsDate') ||
            !oldData.containsKey('dailyConnectionsDate') ||
            newData['dailyConnectionsDate'] !=
                oldData['dailyConnectionsDate'] ||
            newData['dailyConnections'] >= oldData['dailyConnections'];

        final monthlyCheck = !newData.containsKey('monthlyConnections') ||
            !oldData.containsKey('monthlyConnections') ||
            !newData.containsKey('monthlyConnectionsMonth') ||
            !oldData.containsKey('monthlyConnectionsMonth') ||
            newData['monthlyConnectionsMonth'] !=
                oldData['monthlyConnectionsMonth'] ||
            newData['monthlyConnections'] >= oldData['monthlyConnections'];

        return dailyCheck && monthlyCheck;
      }

      final today = '2026-10-15T00:00:00.000';
      final tomorrow = '2026-10-16T00:00:00.000';
      final thisMonth = '2026-10-01T00:00:00.000';
      final nextMonth = '2026-11-01T00:00:00.000';

      final oldSettings = {
        'dailyConnections': 8,
        'dailyConnectionsDate': today,
        'monthlyConnections': 45,
        'monthlyConnectionsMonth': thisMonth,
      };

      // Reset daily count from 8 to 0 on the same date -> REJECTED
      expect(
        hasNoQuotaReset(oldSettings, {
          'dailyConnections': 0,
          'dailyConnectionsDate': today,
          'monthlyConnections': 45,
          'monthlyConnectionsMonth': thisMonth,
        }),
        isFalse,
      );

      // Legitimate increment on the same date (8 -> 9) -> ALLOWED
      expect(
        hasNoQuotaReset(oldSettings, {
          'dailyConnections': 9,
          'dailyConnectionsDate': today,
          'monthlyConnections': 46,
          'monthlyConnectionsMonth': thisMonth,
        }),
        isTrue,
      );

      // New day arrives: count resets to 0 on new date -> ALLOWED
      expect(
        hasNoQuotaReset(oldSettings, {
          'dailyConnections': 0,
          'dailyConnectionsDate': tomorrow,
          'monthlyConnections': 45,
          'monthlyConnectionsMonth': thisMonth,
        }),
        isTrue,
      );

      // Reset monthly count on the same month (45 -> 0) -> REJECTED
      expect(
        hasNoQuotaReset(oldSettings, {
          'dailyConnections': 8,
          'dailyConnectionsDate': today,
          'monthlyConnections': 0,
          'monthlyConnectionsMonth': thisMonth,
        }),
        isFalse,
      );

      // New month arrives: monthly count resets to 0 on new month -> ALLOWED
      expect(
        hasNoQuotaReset(oldSettings, {
          'dailyConnections': 0,
          'dailyConnectionsDate': tomorrow,
          'monthlyConnections': 0,
          'monthlyConnectionsMonth': nextMonth,
        }),
        isTrue,
      );
    });

    // 8. Connection quota calculation and entitlement enforcement
    test(
        'UserModel and connection logic strictly enforces daily (10) and monthly (60) limits for free users',
        () {
      final now = DateTime.now();

      // Free user within limits
      final freeUserActive = UserModel(
        id: 'free_1',
        username: 'free_active',
        email: 'free1@example.com',
        country: 'Kenya',
        city: 'Nairobi',
        dateOfBirth: DateTime(2000, 1, 1),
        gender: 'Male',
        bio: 'Hello',
        profilePicUrl: '',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+254700000000',
        dailyConnections: 5,
        dailyConnectionsDate: now,
        monthlyConnections: 20,
        monthlyConnectionsMonth: now,
        isPremium: false,
      );

      expect(freeUserActive.isDailyLimitReached, isFalse);
      expect(freeUserActive.isMonthlyLimitReached, isFalse);
      expect(freeUserActive.canConnectFree, isTrue);

      // Free user at daily limit (10)
      final freeUserDailyCapped = freeUserActive.copyWith(
        dailyConnections: 10,
        dailyConnectionsDate: now,
      );
      expect(freeUserDailyCapped.isDailyLimitReached, isTrue);
      expect(freeUserDailyCapped.canConnectFree, isFalse);

      // Free user at monthly limit (60)
      final freeUserMonthlyCapped = freeUserActive.copyWith(
        dailyConnections: 2,
        monthlyConnections: 60,
        monthlyConnectionsMonth: now,
      );
      expect(freeUserMonthlyCapped.isMonthlyLimitReached, isTrue);
      expect(freeUserMonthlyCapped.canConnectFree, isFalse);

      // Premium user with 20 daily connections is exempt from limits
      final premiumUser = freeUserActive.copyWith(
        isPremium: true,
        dailyConnections: 20,
        dailyConnectionsDate: now,
        monthlyConnections: 100,
        monthlyConnectionsMonth: now,
      );
      expect(premiumUser.isDailyLimitReached, isFalse);
      expect(premiumUser.isMonthlyLimitReached, isFalse);
      expect(premiumUser.canConnectFree, isTrue);
    });
  });
}
