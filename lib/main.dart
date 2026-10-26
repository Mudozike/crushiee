import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/post_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/profile/profile_setup_screen.dart' as profile_setup;
import 'screens/main_navigation_screen.dart';
import 'services/database_service.dart';
import 'services/firestore_service.dart';
import 'services/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('[ENV] Error loading .env file: $e');
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await PushNotificationService().initialize();
  } catch (e) {
    debugPrint('[PUSH] PushNotificationService initialization warning: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const CrushieApp(),
    ),
  );
}

enum AppScreenState {
  splash,
  landing,
  login,
  signUp,
  forgotPassword,
  emailVerification,
  profileSetup,
  mainNav,
}

class CrushieApp extends StatefulWidget {
  const CrushieApp({Key? key}) : super(key: key);

  @override
  State<CrushieApp> createState() => _CrushieAppState();
}

class _CrushieAppState extends State<CrushieApp> {
  GlobalKey<NavigatorState> get _navigatorKey => PushNotificationService.navigatorKey;
  AppScreenState _currentScreen = AppScreenState.splash;
  String _unverifiedEmail = 'user@crushie.app';
  // Set to true once Firebase auth state + Firestore profile have been checked.
  bool _authLoadComplete = false;

  Future<void> _handleSecureLogout() async {
    // 1. Pop all pushed routes so Back button cannot return to any protected screens
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);

    // 2. Clear sensitive in-memory user caches across services & providers
    DatabaseService().clearUserData();
    if (mounted) {
      Provider.of<UserProvider>(context, listen: false).clear();
      Provider.of<ConnectionProvider>(context, listen: false).clear();
      Provider.of<NotificationProvider>(context, listen: false).clear();
      Provider.of<ChatProvider>(context, listen: false).clear();
    }

    // 3. Clear presence and typing in Firestore while still authenticated
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final user = authProv.currentUser;
    if (user != null && user.id.isNotEmpty) {
      try {
        await PushNotificationService().clearUserToken(user.id);
        await FirestoreService().setUserTyping(user.id, null);
        await FirestoreService().updateUserPresence(user.id, isOnline: false);
      } catch (e) {
        debugPrint('[LOGOUT] Error clearing presence/typing/push token: $e');
      }
    }

    // 4. Await Firebase sign-out operation if user is still authenticated
    if (authProv.isAuthenticated) {
      await authProv.signOut();
    }

    // 5. Reset top-level screen state to public landing screen
    if (mounted) {
      setState(() {
        _currentScreen = AppScreenState.landing;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkPersistedAuth();
  }

  Future<void> _checkPersistedAuth() async {
    try {
      User? fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null) {
        try {
          fbUser = await FirebaseAuth.instance
              .authStateChanges()
              .first
              .timeout(const Duration(milliseconds: 600));
        } catch (_) {}
      }

      if (fbUser != null) {
        final uid = fbUser.uid;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) {
            _authLoadComplete = true;
            return;
          }
          try {
            final authProv = Provider.of<AuthProvider>(context, listen: false);
            await authProv.reloadUserProfile(uid);
            PushNotificationService().registerUserToken(uid);
            if (mounted) {
              Provider.of<UserProvider>(context, listen: false)
                  .initUserFollowing(uid);
            }
            debugPrint('[MAIN] Firebase profile reload complete for UID: $uid');
          } catch (e) {
            debugPrint('[MAIN] Firebase profile reload error: $e');
          } finally {
            if (mounted) {
              setState(() => _authLoadComplete = true);
            } else {
              _authLoadComplete = true;
            }
          }
        });
        return;
      }
    } catch (e) {
      debugPrint('[MAIN] Error checking persisted auth: $e');
    }

    if (mounted) {
      setState(() => _authLoadComplete = true);
    } else {
      _authLoadComplete = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Enforce real authentication state: If user is not authenticated,
    // protected screens (mainNav, profileSetup, emailVerification) cannot be displayed.
    if (!authProvider.isAuthenticated &&
        (_currentScreen == AppScreenState.mainNav ||
            _currentScreen == AppScreenState.profileSetup ||
            _currentScreen == AppScreenState.emailVerification)) {
      _currentScreen = AppScreenState.landing;
    }

    Widget currentWidget;
    switch (_currentScreen) {
      case AppScreenState.splash:
        currentWidget = SplashScreen(
          onSplashComplete: () async {
            final authProv = Provider.of<AuthProvider>(context, listen: false);
            // If auth check is still running, wait for it
            if (!_authLoadComplete) {
              for (int i = 0; i < 40 && !_authLoadComplete; i++) {
                await Future.delayed(const Duration(milliseconds: 100));
              }
            }
            if (!mounted) return;
            final fbUser = FirebaseAuth.instance.currentUser;
            if (fbUser != null) {
              // 1. Verify user's email state before permitting access to protected app content
              final isGoogle = authProv.isGoogleUser;
              final isVerified =
                  isGoogle || await authProv.checkEmailVerified();

              if (!isVerified) {
                debugPrint(
                    '[MAIN] User email is unverified. Routing to EmailVerificationScreen.');
                setState(() {
                  _unverifiedEmail = fbUser.email ?? _unverifiedEmail;
                  _currentScreen = AppScreenState.emailVerification;
                });
                return;
              }

              var user = authProv.currentUser;
              if (user == null || !user.profileCompleted) {
                user = await authProv.reloadUserProfile(fbUser.uid);
              }
              final isProfileComplete = user != null && user.profileCompleted;
              setState(() {
                _currentScreen = isProfileComplete
                    ? AppScreenState.mainNav
                    : AppScreenState.profileSetup;
              });
            } else {
              setState(() => _currentScreen = AppScreenState.landing);
            }
          },
        );
        break;

      case AppScreenState.landing:
        currentWidget = LandingScreen(
          onGetStarted: () =>
              setState(() => _currentScreen = AppScreenState.signUp),
          onSignIn: () => setState(() => _currentScreen = AppScreenState.login),
        );
        break;

      case AppScreenState.signUp:
        currentWidget = SignUpScreen(
          onSignUpSuccess: (email) {
            setState(() {
              _unverifiedEmail = email;
              _currentScreen = AppScreenState.emailVerification;
            });
          },
          onGoogleSignInSuccess: () {
            final isNew = authProvider.isNewUser;
            final user = authProvider.currentUser;
            final isProfileComplete = user != null && user.profileCompleted;
            setState(() {
              _currentScreen = (isNew || !isProfileComplete)
                  ? AppScreenState.profileSetup
                  : AppScreenState.mainNav;
            });
          },
          onSignInTap: () => setState(
              () => _currentScreen = AppScreenState.login), // Direct Sign In
          onBack: () => setState(() => _currentScreen = AppScreenState.landing),
        );
        break;

      case AppScreenState.login:
        currentWidget = LoginScreen(
          onLoginSuccess: () async {
            final fbUser = FirebaseAuth.instance.currentUser;
            final isGoogle = authProvider.isGoogleUser;
            final isVerified =
                isGoogle || await authProvider.checkEmailVerified();

            if (!isVerified) {
              debugPrint(
                  '[MAIN] Login succeeded but email is unverified. Routing to verification.');
              setState(() {
                _unverifiedEmail = fbUser?.email ?? _unverifiedEmail;
                _currentScreen = AppScreenState.emailVerification;
              });
              return;
            }

            final isNew = authProvider.isNewUser;
            final user = authProvider.currentUser;
            final isProfileComplete = user != null && user.profileCompleted;
            setState(() {
              _currentScreen = (isNew || !isProfileComplete)
                  ? AppScreenState.profileSetup
                  : AppScreenState.mainNav;
            });
          },
          onSignUpTap: () => setState(
              () => _currentScreen = AppScreenState.signUp), // Direct Sign Up
          onForgotPasswordTap: () =>
              setState(() => _currentScreen = AppScreenState.forgotPassword),
          onBack: () => setState(() => _currentScreen = AppScreenState.landing),
        );
        break;

      case AppScreenState.forgotPassword:
        currentWidget = ForgotPasswordScreen(
          onPasswordResetSuccess: () =>
              setState(() => _currentScreen = AppScreenState.login),
          onSignInTap: () =>
              setState(() => _currentScreen = AppScreenState.login),
          onBack: () => setState(() => _currentScreen = AppScreenState.login),
        );
        break;

      case AppScreenState.emailVerification:
        currentWidget = EmailVerificationScreen(
          email: _unverifiedEmail,
          onVerificationSuccess: () async {
            final authProv = Provider.of<AuthProvider>(context, listen: false);
            final fbUser = FirebaseAuth.instance.currentUser;
            var user = authProv.currentUser;
            if (fbUser != null && (user == null || !user.profileCompleted)) {
              user = await authProv.reloadUserProfile(fbUser.uid);
            }
            final isProfileComplete = user != null && user.profileCompleted;
            setState(() {
              _currentScreen = isProfileComplete
                  ? AppScreenState.mainNav
                  : AppScreenState.profileSetup;
            });
          },
          onSignOut: _handleSecureLogout,
          onBack: _handleSecureLogout,
        );
        break;

      case AppScreenState.profileSetup:
        currentWidget = profile_setup.ProfileSetupScreen(
          onSetupComplete: () =>
              setState(() => _currentScreen = AppScreenState.mainNav),
          onLogout: _handleSecureLogout,
        );
        break;

      case AppScreenState.mainNav:
        currentWidget = MainNavigationScreen(
          onLogout: _handleSecureLogout,
        );
        break;
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Crushie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: currentWidget,
    );
  }
}
