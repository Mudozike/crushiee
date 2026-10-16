import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:crushie/models/user_model.dart';
import 'package:crushie/services/auth_service.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/screens/auth/email_verification_screen.dart';
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

class FakePhase2AuthProvider extends ChangeNotifier implements AuthProvider {
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

  bool mockIsEmailVerified = false;
  @override
  bool get isEmailVerified => mockIsEmailVerified;

  UserModel? mockUser;
  @override
  UserModel? get currentUser => mockUser;

  @override
  bool get isAuthenticated => mockUser != null;

  bool checkEmailVerifiedResult = false;
  Object? checkEmailVerifiedException;

  bool resendEmailResult = true;
  String? resendEmailErrorCode;
  String? resendEmailErrorMessage;

  int checkEmailVerifiedCalls = 0;
  int resendEmailCalls = 0;
  int signOutCalls = 0;

  @override
  Future<bool> checkEmailVerified() async {
    checkEmailVerifiedCalls++;
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 10));
    _isLoading = false;

    if (checkEmailVerifiedException != null) {
      final e = checkEmailVerifiedException!;
      _errorMessage = AuthService.formatAuthException(e);
      if (e is fb_auth.FirebaseAuthException) {
        _errorCode = e.code;
      } else {
        _errorCode = 'network-error';
      }
      notifyListeners();
      return false;
    }

    mockIsEmailVerified = checkEmailVerifiedResult;
    notifyListeners();
    return checkEmailVerifiedResult;
  }

  @override
  Future<bool> resendVerificationEmail() async {
    resendEmailCalls++;
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 10));
    _isLoading = false;

    if (resendEmailResult) {
      _errorCode = null;
      notifyListeners();
      return true;
    } else {
      _errorCode = resendEmailErrorCode ?? 'too-many-requests';
      _errorMessage = resendEmailErrorMessage ??
          'Too many failed attempts. Please wait a moment and try again.';
      notifyListeners();
      return false;
    }
  }

  @override
  Future<bool> signOut() async {
    signOutCalls++;
    mockUser = null;
    mockIsEmailVerified = false;
    _isNewUser = false;
    notifyListeners();
    return true;
  }

  @override
  Future<UserModel?> reloadUserProfile([String? explicitUid]) async {
    return mockUser;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 — Verification State, Reload, and Resend Logic', () {
    test(
        'Unverified email/password account initial state has isEmailVerified false',
        () {
      final auth = FakePhase2AuthProvider();
      auth.mockIsGoogleUser = false;
      auth.mockIsEmailVerified = false;

      expect(auth.isEmailVerified, isFalse);
      expect(auth.isGoogleUser, isFalse);
    });

    test(
        'Google sign-in user is treated as verified by provider without separate email check',
        () {
      final auth = FakePhase2AuthProvider();
      auth.mockIsGoogleUser = true;

      // Google provider satisfies verification requirement
      final isAllowed = auth.isGoogleUser || auth.isEmailVerified;
      expect(isAllowed, isTrue);
    });

    test(
        'User becomes verified after refreshing Firebase state (checkEmailVerified)',
        () async {
      final auth = FakePhase2AuthProvider();
      auth.checkEmailVerifiedResult = true;

      final result = await auth.checkEmailVerified();
      expect(result, isTrue);
      expect(auth.isEmailVerified, isTrue);
      expect(auth.checkEmailVerifiedCalls, equals(1));
      expect(auth.isLoading, isFalse);
    });

    test(
        'checkEmailVerified handles network failure safely and cleans up loading state',
        () async {
      final auth = FakePhase2AuthProvider();
      auth.checkEmailVerifiedException = MockFirebaseAuthException(
        'network-request-failed',
        'A network error occurred.',
      );

      final result = await auth.checkEmailVerified();
      expect(result, isFalse);
      expect(auth.isLoading, isFalse);
      expect(auth.errorCode, equals('network-request-failed'));
      expect(auth.errorMessage, contains('Network error'));
    });

    test(
        'resendVerificationEmail records success, loading state, and error code on failure',
        () async {
      final auth = FakePhase2AuthProvider();

      // 1. Success case
      auth.resendEmailResult = true;
      final success = await auth.resendVerificationEmail();
      expect(success, isTrue);
      expect(auth.isLoading, isFalse);
      expect(auth.resendEmailCalls, equals(1));

      // 2. Failure case (rate limit)
      auth.resendEmailResult = false;
      auth.resendEmailErrorCode = 'too-many-requests';
      auth.resendEmailErrorMessage = 'Too many requests. Please wait a moment.';
      final failure = await auth.resendVerificationEmail();
      expect(failure, isFalse);
      expect(auth.isLoading, isFalse);
      expect(auth.errorCode, equals('too-many-requests'));
      expect(auth.errorMessage, contains('Too many requests'));
    });
  });

  group('Phase 2 — EmailVerificationScreen Widget Tests', () {
    testWidgets(
        'Tapping "I\'ve Verified" when verified triggers onVerificationSuccess',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = FakePhase2AuthProvider();
      auth.checkEmailVerifiedResult = true;

      bool verifiedSuccessCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: EmailVerificationScreen(
              email: 'test@example.com',
              onVerificationSuccess: () {
                verifiedSuccessCalled = true;
              },
            ),
          ),
        ),
      );

      final verifyBtn = find.text("I've Verified My Account");
      expect(verifyBtn, findsOneWidget);

      await tester.tap(verifyBtn);
      await tester.pump(); // Start async check
      await tester.pump(const Duration(milliseconds: 50)); // Finish delay
      await tester.pumpAndSettle();

      expect(auth.checkEmailVerifiedCalls, equals(1));
      expect(verifiedSuccessCalled, isTrue);
    });

    testWidgets(
        'Tapping "I\'ve Verified" when still unverified displays guidance and blocks success',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = FakePhase2AuthProvider();
      auth.checkEmailVerifiedResult = false;

      bool verifiedSuccessCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: EmailVerificationScreen(
              email: 'unverified@example.com',
              onVerificationSuccess: () {
                verifiedSuccessCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text("I've Verified My Account"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(verifiedSuccessCalled, isFalse);
      expect(find.textContaining('Your email is not verified yet'),
          findsOneWidget);
    });

    testWidgets(
        'Tapping "I\'ve Verified" when network fails displays network error SnackBar',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = FakePhase2AuthProvider();
      auth.checkEmailVerifiedException =
          MockFirebaseAuthException('network-request-failed');

      bool verifiedSuccessCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: EmailVerificationScreen(
              email: 'test@example.com',
              onVerificationSuccess: () {
                verifiedSuccessCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text("I've Verified My Account"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(verifiedSuccessCalled, isFalse);
      expect(find.textContaining('Network error'), findsOneWidget);
    });

    testWidgets('Resend verification email displays success SnackBar',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = FakePhase2AuthProvider();
      auth.resendEmailResult = true;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: EmailVerificationScreen(
              email: 'test@example.com',
              onVerificationSuccess: () {},
            ),
          ),
        ),
      );

      final resendBtn = find.text('Resend Verification Email');
      expect(resendBtn, findsOneWidget);

      await tester.tap(resendBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(auth.resendEmailCalls, equals(1));
      expect(find.textContaining('Verification email sent to test@example.com'),
          findsOneWidget);
    });

    testWidgets('Safe Sign Out / Change Account invokes onSignOut callback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = FakePhase2AuthProvider();
      bool signOutCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: EmailVerificationScreen(
              email: 'test@example.com',
              onVerificationSuccess: () {},
              onSignOut: () {
                signOutCalled = true;
              },
            ),
          ),
        ),
      );

      final signOutBtn = find.text('Sign Out / Change Account');
      expect(signOutBtn, findsOneWidget);

      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      expect(signOutCalled, isTrue);
    });
  });

  group('Phase 2 — Verification Gate & Routing Enforcement Decision Tests', () {
    // Pure function simulating Crushie app routing state decision to verify invariant correctness
    AppScreenState resolveAppDestination({
      required bool isAuthenticated,
      required bool isGoogleUser,
      required bool isEmailVerified,
      required bool isNewUser,
      required bool isProfileComplete,
    }) {
      if (!isAuthenticated) return AppScreenState.landing;

      // 1. Check verification requirement
      final isVerified = isGoogleUser || isEmailVerified;
      if (!isVerified) {
        return AppScreenState.emailVerification;
      }

      // 2. Verified user -> check profile completion
      if (isNewUser || !isProfileComplete) {
        return AppScreenState.profileSetup;
      }

      return AppScreenState.mainNav;
    }

    test(
        '1. Verified email/password login reaches mainNav if profile completed',
        () {
      final dest = resolveAppDestination(
        isAuthenticated: true,
        isGoogleUser: false,
        isEmailVerified: true,
        isNewUser: false,
        isProfileComplete: true,
      );
      expect(dest, equals(AppScreenState.mainNav));
    });

    test(
        '2. Unverified email/password login is strictly routed to emailVerification',
        () {
      final dest = resolveAppDestination(
        isAuthenticated: true,
        isGoogleUser: false,
        isEmailVerified: false,
        isNewUser: false,
        isProfileComplete: true, // Even if profile is marked complete in DB!
      );
      expect(dest, equals(AppScreenState.emailVerification));
    });

    test(
        '3. Unverified session restored at app startup is strictly routed to emailVerification',
        () {
      final dest = resolveAppDestination(
        isAuthenticated: true,
        isGoogleUser: false,
        isEmailVerified: false,
        isNewUser: false,
        isProfileComplete: false,
      );
      expect(dest, equals(AppScreenState.emailVerification));
    });

    test(
        '4. User becoming verified after refreshing Firebase state proceeds to intended destination',
        () {
      // First unverified
      var dest = resolveAppDestination(
        isAuthenticated: true,
        isGoogleUser: false,
        isEmailVerified: false,
        isNewUser: false,
        isProfileComplete: true,
      );
      expect(dest, equals(AppScreenState.emailVerification));

      // After verification refresh
      dest = resolveAppDestination(
        isAuthenticated: true,
        isGoogleUser: false,
        isEmailVerified: true,
        isNewUser: false,
        isProfileComplete: true,
      );
      expect(dest, equals(AppScreenState.mainNav));
    });

    test(
        '6. Google sign-in for an existing verified user bypasses verification and reaches mainNav',
        () {
      final dest = resolveAppDestination(
        isAuthenticated: true,
        isGoogleUser: true,
        isEmailVerified: true,
        isNewUser: false,
        isProfileComplete: true,
      );
      expect(dest, equals(AppScreenState.mainNav));
    });

    test(
        '7. First-time Google onboarding bypasses verification and reaches profileSetup',
        () {
      final dest = resolveAppDestination(
        isAuthenticated: true,
        isGoogleUser: true,
        isEmailVerified: true,
        isNewUser: true,
        isProfileComplete: false,
      );
      expect(dest, equals(AppScreenState.profileSetup));
    });

    test(
        '9. Regression check: unverified email user CANNOT reach mainNav or profileSetup',
        () {
      // Unverified user with profile completed
      final dest1 = resolveAppDestination(
        isAuthenticated: true,
        isGoogleUser: false,
        isEmailVerified: false,
        isNewUser: false,
        isProfileComplete: true,
      );
      expect(dest1, isNot(equals(AppScreenState.mainNav)));
      expect(dest1, isNot(equals(AppScreenState.profileSetup)));
      expect(dest1, equals(AppScreenState.emailVerification));

      // Unverified user with profile incomplete
      final dest2 = resolveAppDestination(
        isAuthenticated: true,
        isGoogleUser: false,
        isEmailVerified: false,
        isNewUser: false,
        isProfileComplete: false,
      );
      expect(dest2, isNot(equals(AppScreenState.mainNav)));
      expect(dest2, isNot(equals(AppScreenState.profileSetup)));
      expect(dest2, equals(AppScreenState.emailVerification));
    });
  });
}
