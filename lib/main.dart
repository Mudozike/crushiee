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
import 'screens/auth/profile_setup_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  AppScreenState _currentScreen = AppScreenState.splash;
  String _unverifiedEmail = 'user@crushie.app';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    Widget currentWidget;
    switch (_currentScreen) {
      case AppScreenState.splash:
        currentWidget = SplashScreen(
          onSplashComplete: () {
            setState(() => _currentScreen = AppScreenState.landing);
          },
        );
        break;

      case AppScreenState.landing:
        currentWidget = LandingScreen(
          onGetStarted: () => setState(() => _currentScreen = AppScreenState.signUp),
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
            final user = authProvider.currentUser;
            final isProfileComplete = user != null && user.bio.isNotEmpty;
            setState(() {
              _currentScreen = isProfileComplete ? AppScreenState.mainNav : AppScreenState.profileSetup;
            });
          },
          onSignInTap: () => setState(() => _currentScreen = AppScreenState.login), // Direct Sign In
          onBack: () => setState(() => _currentScreen = AppScreenState.landing),
        );
        break;

      case AppScreenState.login:
        currentWidget = LoginScreen(
          onLoginSuccess: () => setState(() => _currentScreen = AppScreenState.mainNav),
          onSignUpTap: () => setState(() => _currentScreen = AppScreenState.signUp), // Direct Sign Up
          onForgotPasswordTap: () => setState(() => _currentScreen = AppScreenState.forgotPassword),
          onBack: () => setState(() => _currentScreen = AppScreenState.landing),
        );
        break;

      case AppScreenState.forgotPassword:
        currentWidget = ForgotPasswordScreen(
          onPasswordResetSuccess: () => setState(() => _currentScreen = AppScreenState.login),
          onSignInTap: () => setState(() => _currentScreen = AppScreenState.login),
          onBack: () => setState(() => _currentScreen = AppScreenState.login),
        );
        break;

      case AppScreenState.emailVerification:
        currentWidget = EmailVerificationScreen(
          email: _unverifiedEmail,
          onVerificationSuccess: () => setState(() => _currentScreen = AppScreenState.profileSetup),
          onBack: () => setState(() => _currentScreen = AppScreenState.signUp),
        );
        break;

      case AppScreenState.profileSetup:
        currentWidget = ProfileSetupScreen(
          username: authProvider.currentUser?.username ?? 'new_user',
          email: authProvider.currentUser?.email ?? _unverifiedEmail,
          onSetupComplete: () => setState(() => _currentScreen = AppScreenState.mainNav),
        );
        break;

      case AppScreenState.mainNav:
        currentWidget = MainNavigationScreen(
          onLogout: () => setState(() => _currentScreen = AppScreenState.landing),
        );
        break;
    }

    return MaterialApp(
      title: 'Crushie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: currentWidget,
    );
  }
}
