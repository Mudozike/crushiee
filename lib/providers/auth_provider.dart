import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();

  UserModel? get currentUser => _authService.currentUser;
  bool get isAuthenticated => currentUser != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void refreshUser() {
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.signInWithEmail(email: email, password: password);
    _isLoading = false;

    if (result.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage ?? 'Sign in failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmail(String email, String password, String username) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
      username: username,
    );
    _isLoading = false;

    if (result.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage ?? 'Sign up failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.signInWithGoogle();
    _isLoading = false;

    if (result.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage ?? 'Google Sign-In failed';
      notifyListeners();
      return false;
    }
  }

  void updateUserProfile(UserModel updatedUser) {
    _db.updateUser(updatedUser);
    notifyListeners();
  }

  void verifyUser() {
    if (currentUser != null) {
      _db.verifyUser(currentUser!.id);
      notifyListeners();
    }
  }

  void upgradeToPremium() {
    if (currentUser != null) {
      _db.upgradeUserToPremium(currentUser!.id);
      notifyListeners();
    }
  }

  void signOut() {
    _authService.signOut();
    notifyListeners();
  }
}
