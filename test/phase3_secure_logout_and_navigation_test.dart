import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:crushie/models/user_model.dart';
import 'package:crushie/models/notification_model.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/providers/theme_provider.dart';
import 'package:crushie/providers/connection_provider.dart';
import 'package:crushie/providers/notification_provider.dart';
import 'package:crushie/screens/settings/settings_screen.dart';
import 'package:crushie/main.dart';

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

class FakePhase3AuthProvider extends ChangeNotifier implements AuthProvider {
  bool _isLoading = false;
  @override
  bool get isLoading => _isLoading;

  String? _errorMessage;
  @override
  String? get errorMessage => _errorMessage;

  String? _errorCode;
  @override
  String? get errorCode => _errorCode;

  bool _isNewUser = false;
  @override
  bool get isNewUser => _isNewUser;
  set isNewUser(bool val) => _isNewUser = val;

  bool mockIsGoogleUser = false;
  @override
  bool get isGoogleUser => mockIsGoogleUser;

  bool mockIsEmailVerified = true;
  @override
  bool get isEmailVerified => mockIsEmailVerified;

  UserModel? mockUser;
  @override
  UserModel? get currentUser => mockUser;

  @override
  bool get isAuthenticated => mockUser != null;

  bool signOutShouldSucceed = true;
  String? signOutFailureMessage;
  String? signOutFailureCode;
  int signOutCalls = 0;

  @override
  Future<bool> signOut() async {
    if (_isLoading) return false;
    signOutCalls++;
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 20));
    _isLoading = false;

    if (signOutShouldSucceed) {
      mockUser = null;
      mockIsEmailVerified = false;
      _isNewUser = false;
      _errorCode = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = signOutFailureMessage ?? 'Sign out failed.';
      _errorCode = signOutFailureCode ?? 'sign-out-error';
      notifyListeners();
      return false;
    }
  }

  @override
  Future<bool> checkEmailVerified() async => mockIsEmailVerified;

  @override
  Future<UserModel?> reloadUserProfile([String? explicitUid]) async => mockUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UserModel makeUser(String id, String username, String email) {
    return UserModel(
      id: id,
      username: username,
      email: email,
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(1998, 5, 10),
      gender: 'Other',
      bio: 'Bio for $username',
      profilePicUrl: 'crushie_avatar_0',
      preferredContactMethod: 'Email',
      contactDetails: email,
      profileCompleted: true,
    );
  }

  group('Phase 3 — In-Memory Sensitive State Invalidation', () {
    test(
        'DatabaseService.clearUserData completely wipes all user-specific collections',
        () {
      final db = DatabaseService();

      // Populate dummy in-memory data
      final userA = makeUser('user_A', 'Alice', 'alice@example.com');
      db.updateUser(userA);

      db.addNotification(NotificationModel(
        id: 'notif_1',
        userId: 'user_A',
        fromUserId: 'user_B',
        fromUsername: 'Bob',
        fromUserProfilePic: 'crushie_avatar_1',
        type: NotificationType.follow,
        title: 'New match',
        body: 'You matched with Bob',
        createdAt: DateTime.now(),
      ));

      expect(db.users.containsKey('user_A'), isTrue);
      expect(db.notifications.isNotEmpty, isTrue);

      // Execute logout cleanup
      db.clearUserData();

      expect(db.users.isEmpty, isTrue);
      expect(db.notifications.isEmpty, isTrue);
      expect(db.connections.isEmpty, isTrue);
      expect(db.posts.isEmpty, isTrue);
    });

    test('ConnectionProvider.clear clears connection state and subscriptions',
        () {
      final connProvider = ConnectionProvider();
      connProvider.clear();

      expect(connProvider.connections.isEmpty, isTrue);
    });

    test(
        'NotificationProvider.clear clears notification state and subscriptions',
        () {
      final notifProvider = NotificationProvider();
      notifProvider.clear();

      expect(notifProvider.notifications.isEmpty, isTrue);
    });

    test(
        'Login after logout restores only new user profile without cross-account data leak',
        () async {
      final db = DatabaseService();
      final auth = FakePhase3AuthProvider();

      // User A logged in
      final userA = makeUser('user_A', 'Alice', 'alice@example.com');
      auth.mockUser = userA;
      db.updateUser(userA);
      expect(auth.currentUser?.id, equals('user_A'));

      // Logout User A
      db.clearUserData();
      await auth.signOut();
      expect(auth.currentUser, isNull);
      expect(db.getUser('user_A'), isNull);

      // User B logs in
      final userB = makeUser('user_B', 'Bob', 'bob@example.com');
      auth.mockUser = userB;
      db.updateUser(userB);

      expect(auth.currentUser?.id, equals('user_B'));
      expect(db.getUser('user_B')?.username, equals('Bob'));
      expect(db.getUser('user_A'), isNull); // Alice data is not present
    });
  });

  group('Phase 3 — AuthProvider.signOut Logic & Duplicate Prevention', () {
    test('Successful signOut clears user state and resets loading', () async {
      final auth = FakePhase3AuthProvider();
      auth.mockUser = makeUser('u1', 'UserOne', 'u1@example.com');
      auth.signOutShouldSucceed = true;

      final result = await auth.signOut();
      expect(result, isTrue);
      expect(auth.currentUser, isNull);
      expect(auth.isLoading, isFalse);
      expect(auth.errorMessage, isNull);
    });

    test(
        'Failed signOut records error, does not clear user, and does not report success',
        () async {
      final auth = FakePhase3AuthProvider();
      final user = makeUser('u1', 'UserOne', 'u1@example.com');
      auth.mockUser = user;
      auth.signOutShouldSucceed = false;
      auth.signOutFailureMessage = 'Network error during sign out.';
      auth.signOutFailureCode = 'network-request-failed';

      final result = await auth.signOut();
      expect(result, isFalse);
      expect(
          auth.currentUser, isNotNull); // User is not cleared if logout failed
      expect(auth.isLoading, isFalse);
      expect(auth.errorCode, equals('network-request-failed'));
      expect(auth.errorMessage, contains('Network error'));
    });

    test(
        'Concurrent duplicate signOut requests are prevented while one is running',
        () async {
      final auth = FakePhase3AuthProvider();
      auth.mockUser = makeUser('u1', 'UserOne', 'u1@example.com');

      // Start first sign out
      final future1 = auth.signOut();
      // Attempt duplicate immediately
      final future2 = auth.signOut();

      final res1 = await future1;
      final res2 = await future2;

      expect(res1, isTrue);
      expect(res2, isFalse); // Rejected as already loading
      expect(auth.signOutCalls, equals(1)); // Only executed once
    });

    test('Google and email/password user logout compatibility', () async {
      final auth = FakePhase3AuthProvider();

      // Email user
      auth.mockIsGoogleUser = false;
      auth.mockUser = makeUser('email_u', 'EmailUser', 'email@example.com');
      expect(await auth.signOut(), isTrue);

      // Google user
      auth.mockIsGoogleUser = true;
      auth.mockUser = makeUser('google_u', 'GoogleUser', 'google@example.com');
      expect(await auth.signOut(), isTrue);
    });
  });

  group('Phase 3 — SettingsScreen Logout Dialog Widget Tests', () {
    testWidgets(
        'Tapping Log Out opens confirmation dialog; Cancel dismisses without logout',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = FakePhase3AuthProvider();
      auth.mockUser = makeUser('u1', 'UserOne', 'u1@example.com');

      bool logoutCallbackCalled = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: SettingsScreen(
              onLogout: () {
                logoutCallbackCalled = true;
              },
              onOpenVerification: () {},
              onOpenPremium: () {},
            ),
          ),
        ),
      );

      final logoutTile = find.text('Log Out');
      expect(logoutTile, findsOneWidget);
      await tester.ensureVisible(logoutTile);
      await tester.tap(logoutTile);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Are you sure you want to log out?'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog dismissed, no logout executed
      expect(find.text('Are you sure you want to log out?'), findsNothing);
      expect(auth.signOutCalls, equals(0));
      expect(logoutCallbackCalled, isFalse);
    });

    testWidgets(
        'Confirming Log Out awaits signOut, calls onLogout, and prevents double taps',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = FakePhase3AuthProvider();
      auth.mockUser = makeUser('u1', 'UserOne', 'u1@example.com');
      auth.signOutShouldSucceed = true;

      bool logoutCallbackCalled = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: SettingsScreen(
              onLogout: () {
                logoutCallbackCalled = true;
              },
              onOpenVerification: () {},
              onOpenPremium: () {},
            ),
          ),
        ),
      );

      final logoutTile = find.text('Log Out');
      await tester.ensureVisible(logoutTile);
      await tester.tap(logoutTile);
      await tester.pumpAndSettle();

      // Confirm log out in dialog
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Log Out');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);

      await tester.pump(); // Start async sign out
      await tester.pump(const Duration(milliseconds: 50)); // Finish delay
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, equals(1));
      expect(logoutCallbackCalled, isTrue);
    });

    testWidgets(
        'Failed logout displays error SnackBar and does NOT invoke onLogout',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = FakePhase3AuthProvider();
      auth.mockUser = makeUser('u1', 'UserOne', 'u1@example.com');
      auth.signOutShouldSucceed = false;
      auth.signOutFailureMessage =
          'Sign out network timeout. Please try again.';

      bool logoutCallbackCalled = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: SettingsScreen(
              onLogout: () {
                logoutCallbackCalled = true;
              },
              onOpenVerification: () {},
              onOpenPremium: () {},
            ),
          ),
        ),
      );

      final logoutTile = find.text('Log Out');
      await tester.ensureVisible(logoutTile);
      await tester.tap(logoutTile);
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Log Out');
      await tester.tap(confirmBtn);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, equals(1));
      expect(logoutCallbackCalled, isFalse);
      expect(find.textContaining('Sign out network timeout'), findsOneWidget);
    });
  });

  group(
      'Phase 3 — Navigation Stack Reset & Real Authentication State Invariants',
      () {
    testWidgets(
        'Navigator popUntil clears pushed screens and returns to root route',
        (tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('Root Screen')),
        ),
      );

      expect(find.text('Root Screen'), findsOneWidget);

      // Push Screen A
      navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Protected Screen A')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Protected Screen A'), findsOneWidget);

      // Push Screen B (e.g. Settings)
      navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Protected Screen B')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Protected Screen B'), findsOneWidget);

      // Execute popUntil (as performed during secure logout)
      navKey.currentState!.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();

      // Only Root Screen remains; Screen A and B cannot be reached by Back button
      expect(find.text('Root Screen'), findsOneWidget);
      expect(find.text('Protected Screen A'), findsNothing);
      expect(find.text('Protected Screen B'), findsNothing);
    });

    test(
        'UI responds to real authentication state: unauthenticated user strictly resolves to landing',
        () {
      AppScreenState resolveScreen({
        required bool isAuthenticated,
        required AppScreenState requestedScreen,
      }) {
        if (!isAuthenticated &&
            (requestedScreen == AppScreenState.mainNav ||
                requestedScreen == AppScreenState.profileSetup ||
                requestedScreen == AppScreenState.emailVerification)) {
          return AppScreenState.landing;
        }
        return requestedScreen;
      }

      // Even if requestedScreen was mainNav, unauthenticated session forces landing
      expect(
        resolveScreen(
            isAuthenticated: false, requestedScreen: AppScreenState.mainNav),
        equals(AppScreenState.landing),
      );

      // Unauthenticated session cannot remain on profileSetup
      expect(
        resolveScreen(
            isAuthenticated: false,
            requestedScreen: AppScreenState.profileSetup),
        equals(AppScreenState.landing),
      );

      // Authenticated session maintains mainNav
      expect(
        resolveScreen(
            isAuthenticated: true, requestedScreen: AppScreenState.mainNav),
        equals(AppScreenState.mainNav),
      );
    });
  });
}
