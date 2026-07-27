import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
  landing,
  login,
  signUp,
  profileSetup,
  mainNav,
}

class CrushieApp extends StatefulWidget {
  const CrushieApp({Key? key}) : super(key: key);

  @override
  State<CrushieApp> createState() => _CrushieAppState();
}

class _CrushieAppState extends State<CrushieApp> {
  AppScreenState _currentScreen = AppScreenState.landing;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Auto navigate to mainNav if user is authenticated
    Widget currentWidget;
    switch (_currentScreen) {
      case AppScreenState.landing:
        currentWidget = LandingScreen(
          onGetStarted: () {
            if (authProvider.isAuthenticated) {
              setState(() => _currentScreen = AppScreenState.mainNav);
            } else {
              setState(() => _currentScreen = AppScreenState.signUp);
            }
          },
          onLogin: () => setState(() => _currentScreen = AppScreenState.login),
          onSignUp: () => setState(() => _currentScreen = AppScreenState.signUp),
        );
        break;
      case AppScreenState.login:
        currentWidget = LoginScreen(
          onLoginSuccess: () => setState(() => _currentScreen = AppScreenState.mainNav),
          onNavigateToSignUp: () => setState(() => _currentScreen = AppScreenState.signUp),
        );
        break;
      case AppScreenState.signUp:
        currentWidget = SignUpScreen(
          onSignUpSuccess: () => setState(() => _currentScreen = AppScreenState.profileSetup),
          onNavigateToLogin: () => setState(() => _currentScreen = AppScreenState.login),
        );
        break;
      case AppScreenState.profileSetup:
        currentWidget = ProfileSetupScreen(
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
