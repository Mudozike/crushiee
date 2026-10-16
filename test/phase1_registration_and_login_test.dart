import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:crushie/models/user_model.dart';
import 'package:crushie/services/auth_service.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/screens/auth/signup_screen.dart';
import 'package:crushie/screens/auth/login_screen.dart';

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

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
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

  bool signUpShouldSucceed = false;
  bool signInShouldSucceed = false;

  String? failureCode;
  String? failureMessage;

  @override
  UserModel? get currentUser => null;

  @override
  bool get isAuthenticated => false;

  @override
  bool get isGoogleUser => false;

  @override
  bool get isEmailVerified => false;

  @override
  Future<bool> signUpWithEmail(
      String email, String password, String username) async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 10));
    _isLoading = false;

    if (signUpShouldSucceed) {
      _isNewUser = true;
      notifyListeners();
      return true;
    } else {
      _errorCode = failureCode ?? 'email-already-in-use';
      _errorMessage = failureMessage ??
          'This email is already registered. Please log in or use Forgot Password if you forgot your password.';
      notifyListeners();
      return false;
    }
  }

  @override
  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 10));
    _isLoading = false;

    if (signInShouldSucceed) {
      _isNewUser = false;
      notifyListeners();
      return true;
    } else {
      _errorCode = failureCode ?? 'invalid-credential';
      _errorMessage = failureMessage ??
          'Incorrect email or password. Please check your credentials, continue with Google, or reset your password.';
      notifyListeners();
      return false;
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 10));
    _isLoading = false;
    if (signInShouldSucceed) {
      return true;
    } else {
      _errorCode = failureCode;
      _errorMessage = failureMessage;
      notifyListeners();
      return false;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase 1 - AuthService Exception Formatting & Error Mapping Tests', () {
    test('Formats email-already-in-use with actionable guidance', () {
      final ex = MockFirebaseAuthException('email-already-in-use');
      final msg = AuthService.formatAuthException(ex);
      expect(msg, contains('already registered'));
      expect(msg, contains('Forgot Password'));
    });

    test('Formats user-not-found with clear registration suggestion', () {
      final ex = MockFirebaseAuthException('user-not-found');
      final msg = AuthService.formatAuthException(ex);
      expect(msg, contains('No account found with this email'));
      expect(msg, contains('create an account'));
    });

    test('Formats invalid-credential with enumeration-protecting message', () {
      final ex = MockFirebaseAuthException('invalid-credential');
      final msg = AuthService.formatAuthException(ex);
      expect(msg, contains('Incorrect email or password'));
      expect(msg, contains('Google'));
    });

    test('Formats account-exists-with-different-credential safely', () {
      final ex =
          MockFirebaseAuthException('account-exists-with-different-credential');
      final msg = AuthService.formatAuthException(ex);
      expect(
          msg,
          contains(
              'An account already exists with this email using another sign-in method'));
    });

    test('Formats weak-password and invalid-email clearly', () {
      final weakEx = MockFirebaseAuthException('weak-password');
      expect(AuthService.formatAuthException(weakEx),
          contains('at least 6 characters'));

      final invalidEx = MockFirebaseAuthException('invalid-email');
      expect(AuthService.formatAuthException(invalidEx),
          contains('valid email address'));
    });

    test('Formats network errors without exposing stack traces', () {
      final netEx = MockFirebaseAuthException('network-request-failed');
      expect(AuthService.formatAuthException(netEx), contains('Network error'));

      final genericNet =
          Exception('SocketException: OS Error: connection refused');
      expect(AuthService.formatAuthException(genericNet),
          contains('Network error'));
    });

    test('Formats unknown exceptions with generic safe message', () {
      final unknown = Exception('Some internal server failure 0x8849');
      final msg = AuthService.formatAuthException(unknown);
      expect(msg, equals('Authentication failed. Please try again.'));
      expect(msg.contains('0x8849'), isFalse);
    });
  });

  group('Phase 1 - SignUpScreen Error Handling & Flow Tests', () {
    testWidgets(
        'Failed registration never navigates to email verification and displays SnackBar',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAuthProvider();
      fakeAuth.signUpShouldSucceed = false;
      fakeAuth.failureCode = 'email-already-in-use';
      fakeAuth.failureMessage =
          'This email is already registered. Please log in or use Forgot Password if you forgot your password.';

      bool navigatedToVerification = false;
      bool navigatedToSignIn = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: fakeAuth,
            child: SignUpScreen(
              onSignUpSuccess: (email) {
                navigatedToVerification = true;
              },
              onSignInTap: () {
                navigatedToSignIn = true;
              },
            ),
          ),
        ),
      );

      // Enter form data
      final emailFinder = find.byType(TextFormField).at(0);
      final passFinder = find.byType(TextFormField).at(1);
      final confirmFinder = find.byType(TextFormField).at(2);

      await tester.enterText(emailFinder, 'existing@example.com');
      await tester.enterText(passFinder, 'password123');
      await tester.enterText(confirmFinder, 'password123');
      await tester.pumpAndSettle();

      // Tap Create Account
      final createAccountBtn = find.text('Create Account');
      expect(createAccountBtn, findsOneWidget);
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pump(); // Start submission
      await tester
          .pump(const Duration(milliseconds: 50)); // Complete async delay
      await tester.pumpAndSettle();

      // Verify that navigation did NOT occur
      expect(navigatedToVerification, isFalse);

      // Verify SnackBar displayed
      expect(find.textContaining('already registered'), findsOneWidget);

      // Verify form data remains preserved
      expect(find.text('existing@example.com'), findsOneWidget);

      // Verify SnackBar has functional "Sign In" action
      final signInAction = find.text('Sign In');
      expect(signInAction, findsWidgets); // SnackBarAction + footer link
      await tester.tap(signInAction.first);
      expect(navigatedToSignIn, isTrue);
    });

    testWidgets('Successful registration navigates to email verification',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAuthProvider();
      fakeAuth.signUpShouldSucceed = true;

      String? verifiedEmail;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: fakeAuth,
            child: SignUpScreen(
              onSignUpSuccess: (email) {
                verifiedEmail = email;
              },
              onSignInTap: () {},
            ),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      final passFinder = find.byType(TextFormField).at(1);
      final confirmFinder = find.byType(TextFormField).at(2);

      await tester.enterText(emailFinder, 'newuser@example.com');
      await tester.enterText(passFinder, 'password123');
      await tester.enterText(confirmFinder, 'password123');
      await tester.pumpAndSettle();

      final createAccountBtn = find.text('Create Account');
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(verifiedEmail, equals('newuser@example.com'));
    });
  });

  group('Phase 1 - LoginScreen Error Handling & Flow Tests', () {
    testWidgets('Failed login with user-not-found offers route to Sign Up',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAuthProvider();
      fakeAuth.signInShouldSucceed = false;
      fakeAuth.failureCode = 'user-not-found';
      fakeAuth.failureMessage =
          'No account found with this email. Please create an account.';

      bool navigatedToSignUp = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: fakeAuth,
            child: LoginScreen(
              onLoginSuccess: () {},
              onSignUpTap: () {
                navigatedToSignUp = true;
              },
              onForgotPasswordTap: () {},
            ),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      final passFinder = find.byType(TextFormField).at(1);

      await tester.enterText(emailFinder, 'nonexistent@example.com');
      await tester.enterText(passFinder, 'password123');
      await tester.pumpAndSettle();

      final signInBtn = find.text('Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.textContaining('No account found with this email'),
          findsOneWidget);

      final signUpAction = find.text('Sign Up');
      expect(signUpAction, findsOneWidget);
      await tester.tap(signUpAction);
      expect(navigatedToSignUp, isTrue);
    });

    testWidgets(
        'Failed login with invalid-credential offers route to Reset Password',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAuthProvider();
      fakeAuth.signInShouldSucceed = false;
      fakeAuth.failureCode = 'invalid-credential';
      fakeAuth.failureMessage =
          'Incorrect email or password. Please check your credentials, continue with Google, or reset your password.';

      bool navigatedToReset = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: fakeAuth,
            child: LoginScreen(
              onLoginSuccess: () {},
              onSignUpTap: () {},
              onForgotPasswordTap: () {
                navigatedToReset = true;
              },
            ),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      final passFinder = find.byType(TextFormField).at(1);

      await tester.enterText(emailFinder, 'user@example.com');
      await tester.enterText(passFinder, 'wrongpass');
      await tester.pumpAndSettle();

      final signInBtn = find.text('Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('Incorrect email or password'), findsOneWidget);

      final resetAction = find.text('Reset');
      expect(resetAction, findsOneWidget);
      await tester.tap(resetAction);
      expect(navigatedToReset, isTrue);
    });

    testWidgets('Successful login triggers onLoginSuccess', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAuthProvider();
      fakeAuth.signInShouldSucceed = true;

      bool loginSuccessCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: fakeAuth,
            child: LoginScreen(
              onLoginSuccess: () {
                loginSuccessCalled = true;
              },
              onSignUpTap: () {},
              onForgotPasswordTap: () {},
            ),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      final passFinder = find.byType(TextFormField).at(1);

      await tester.enterText(emailFinder, 'user@example.com');
      await tester.enterText(passFinder, 'correctpass');
      await tester.pumpAndSettle();

      final signInBtn = find.text('Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(loginSuccessCalled, isTrue);
    });
  });
}
