import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final DatabaseService _db;
  final FirestoreService _firestoreService;

  AuthProvider({
    AuthService? authService,
    DatabaseService? db,
    FirestoreService? firestoreService,
  })  : _authService = authService ?? AuthService(),
        _db = db ?? DatabaseService(),
        _firestoreService = firestoreService ?? FirestoreService();

  UserModel? get currentUser => _authService.currentUser;
  bool get isAuthenticated => currentUser != null;

  fb_auth.User? get firebaseUser => _authService.firebaseUser;
  bool get isGoogleUser => _authService.isGoogleUser;
  bool get isEmailVerified => _authService.isEmailVerified;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _errorCode;
  String? get errorCode => _errorCode;

  bool _isNewUser = false;
  bool get isNewUser => _isNewUser;

  void refreshUser() {
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    final result =
        await _authService.signInWithEmail(email: email, password: password);
    _isLoading = false;

    if (result.success) {
      _isNewUser = false;
      _errorCode = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage ?? 'Sign in failed';
      _errorCode = result.errorCode;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmail(
      String email, String password, String username) async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
      username: username,
    );
    _isLoading = false;

    if (result.success) {
      _isNewUser = true;
      _errorCode = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage ?? 'Sign up failed';
      _errorCode = result.errorCode;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    final result = await _authService.signInWithGoogle();
    _isLoading = false;

    if (result.success) {
      _isNewUser = result.isNewUser;
      _errorCode = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage ?? 'Google Sign-In failed';
      _errorCode = result.errorCode;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.sendPasswordResetEmail(email);
    _isLoading = false;

    if (result.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage =
          result.errorMessage ?? 'Failed to send password reset email.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    _isLoading = false;

    if (result.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage ?? 'Failed to change password.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendVerificationEmail() async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    final result = await _authService.sendEmailVerification();
    _isLoading = false;

    if (result.success) {
      _errorCode = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage =
          result.errorMessage ?? 'Failed to send verification email.';
      _errorCode = result.errorCode;
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkEmailVerified() async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final verified = await _authService.checkEmailVerified();
      _isLoading = false;
      notifyListeners();
      return verified;
    } catch (e) {
      _isLoading = false;
      _errorMessage = AuthService.formatAuthException(e);
      if (e is fb_auth.FirebaseAuthException) {
        _errorCode = e.code;
      } else {
        _errorCode = 'network-error';
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserProfile(UserModel updatedUser) async {
    if (_isLoading) return false;

    final currentUid =
        _authService.firebaseUser?.uid ?? _authService.currentUser?.id;
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

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final userToSave = updatedUser.id == currentUid
          ? updatedUser
          : UserModel(
              id: currentUid,
              username: updatedUser.username,
              email: updatedUser.email,
              country: updatedUser.country,
              city: updatedUser.city,
              dateOfBirth: updatedUser.dateOfBirth,
              gender: updatedUser.gender,
              bio: updatedUser.bio,
              profilePicUrl: updatedUser.profilePicUrl,
              preferredContactMethod: updatedUser.preferredContactMethod,
              contactDetails: updatedUser.contactDetails,
              profileCompleted: updatedUser.profileCompleted,
              isVerified: updatedUser.isVerified,
              verifiedExpiry: updatedUser.verifiedExpiry,
              verificationPhoto: updatedUser.verificationPhoto,
              isPremium: updatedUser.isPremium,
              premiumExpiry: updatedUser.premiumExpiry,
              dailyConnections: updatedUser.dailyConnections,
              dailyConnectionsDate: updatedUser.dailyConnectionsDate,
              monthlyConnections: updatedUser.monthlyConnections,
              monthlyConnectionsMonth: updatedUser.monthlyConnectionsMonth,
              followersCount: updatedUser.followersCount,
              followingCount: updatedUser.followingCount,
              communities: updatedUser.communities,
              blockedUserIds: updatedUser.blockedUserIds,
              locationNotificationSubscriptions:
                  updatedUser.locationNotificationSubscriptions,
              isOnline: updatedUser.isOnline,
              lastSeen: updatedUser.lastSeen,
              createdAt: updatedUser.createdAt,
            );

      await _firestoreService.saveUserProfile(userToSave);
      _db.updateUser(userToSave);
      await reloadUserProfile(currentUid);
      _isLoading = false;
      _errorCode = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      if (e is fb_auth.FirebaseException) {
        _errorCode = e.code;
        if (e.code == 'permission-denied') {
          if (e.message != null && e.message!.contains('private settings')) {
            _errorMessage =
                'Permission denied: unable to update private settings.';
          } else {
            _errorMessage =
                'Permission denied: you do not have permission to modify this profile.';
          }
        } else if (e.code == 'unavailable' ||
            e.code == 'network-request-failed') {
          _errorMessage =
              'Network error: unable to save profile changes. Please check your connection.';
        } else {
          _errorMessage = e.message ?? 'Failed to save profile: ${e.code}';
        }
      } else {
        _errorCode = 'unknown-error';
        _errorMessage = 'Failed to save profile: $e';
      }
      notifyListeners();
      return false;
    }
  }

  Future<UserModel?> reloadUserProfile([String? explicitUid]) async {
    final uid = explicitUid ??
        _authService.firebaseUser?.uid ??
        _authService.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      final latest = await _authService.fetchUserProfile(uid);
      if (latest != null) {
        _db.updateUser(latest);
      }
      notifyListeners();
      return latest;
    }
    return null;
  }

  Future<void> verifyUser({int days = 30}) async {
    if (currentUser != null) {
      final updated = currentUser!.copyWith(
        isVerified: true,
        verifiedExpiry: DateTime.now().add(Duration(days: days)),
      );
      await updateUserProfile(updated);
      notifyListeners();
    }
  }

  Future<void> upgradeToPremium({int days = 30}) async {
    if (currentUser != null) {
      final updated = currentUser!.copyWith(
        isPremium: true,
        premiumExpiry: DateTime.now().add(Duration(days: days)),
      );
      await updateUserProfile(updated);
      notifyListeners();
    }
  }

  Future<bool> signOut() async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final result = await _authService.signOut();
      _isLoading = false;

      if (result.success) {
        _isNewUser = false;
        _errorCode = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'Sign out failed.';
        _errorCode = result.errorCode;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = AuthService.formatAuthException(e);
      _errorCode =
          (e is fb_auth.FirebaseAuthException) ? e.code : 'sign-out-error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount(String userId, {String? currentPassword}) async {
    if (_isLoading) {
      debugPrint(
          '[AUTH_PROVIDER] Account deletion already in progress. Ignoring duplicate request.');
      return false;
    }

    final current = currentUser;
    final authedUid = current?.id ?? _authService.firebaseUser?.uid;
    if (authedUid == null || authedUid != userId) {
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

    try {
      final result = await _authService.deleteAccount(
        userId: userId,
        currentPassword: currentPassword,
      );
      _isLoading = false;

      if (result.success) {
        _isNewUser = false;
        _errorMessage = null;
        _errorCode = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'Failed to delete account.';
        _errorCode = result.errorCode;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = AuthService.formatAuthException(e);
      _errorCode =
          (e is fb_auth.FirebaseAuthException) ? e.code : 'deletion-error';
      notifyListeners();
      return false;
    }
  }
}
