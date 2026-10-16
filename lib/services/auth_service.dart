import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

class AuthResult {
  final bool success;
  final UserModel? user;
  final String? errorMessage;
  final String? errorCode;
  final bool isNewUser;

  AuthResult({
    required this.success,
    this.user,
    this.errorMessage,
    this.errorCode,
    this.isNewUser = false,
  });
}

class AuthService {
  final fb_auth.FirebaseAuth _fbAuth;
  final GoogleSignIn _googleSignIn;
  final DatabaseService _db;
  final FirestoreService _firestoreService;
  final StorageService _storageService;

  AuthService({
    fb_auth.FirebaseAuth? fbAuth,
    GoogleSignIn? googleSignIn,
    DatabaseService? db,
    FirestoreService? firestoreService,
    StorageService? storageService,
  })  : _fbAuth = fbAuth ?? fb_auth.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
              serverClientId:
                  '172519315239-2viqqkoa9k0mkqir92u1lvb5p4s6masi.apps.googleusercontent.com',
            ),
        _db = db ?? DatabaseService(),
        _firestoreService = firestoreService ?? FirestoreService(),
        _storageService = storageService ?? StorageService();

  UserModel? _currentUser;

  UserModel? get currentUser {
    final fbUser = _fbAuth.currentUser;
    if (fbUser != null) {
      final userInDb = _db.getUser(fbUser.uid);
      if (userInDb != null) return userInDb;
    }
    return _currentUser;
  }

  Future<UserModel?> fetchUserProfile(String uid) async {
    try {
      final user = await _firestoreService.getUserProfile(uid);
      if (user != null) {
        _currentUser = user;
        _db.updateUser(user);
      }
      return user;
    } catch (e) {
      debugPrint('[AUTH] Error fetching user profile from Firestore: $e');
      return null;
    }
  }

  fb_auth.User? get firebaseUser => _fbAuth.currentUser;

  bool get isGoogleUser {
    final fbUser = _fbAuth.currentUser;
    if (fbUser != null) {
      return fbUser.providerData.any((p) => p.providerId == 'google.com');
    }
    return false;
  }

  bool get isEmailVerified {
    final fbUser = _fbAuth.currentUser;
    if (fbUser == null) return false;
    if (isGoogleUser) return true;
    return fbUser.emailVerified;
  }

  static String formatAuthException(Object e) {
    if (e is fb_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered. Please log in or use Forgot Password if you forgot your password.';
        case 'user-not-found':
          return 'No account found with this email. Please create an account.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password. Please check your credentials, continue with Google, or reset your password.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password must be at least 6 characters long.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email using another sign-in method. Please sign in with your original method (e.g. Email or Google).';
        case 'credential-already-in-use':
          return 'This credential is already associated with a different user account.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'requires-recent-login':
          return 'This sensitive operation requires recent authentication. Please log out and sign back in.';
        default:
          return e.message ?? 'Authentication failed. Please try again.';
      }
    }
    final str = e.toString().toLowerCase();
    if (str.contains('network') ||
        str.contains('socket') ||
        str.contains('connection') ||
        str.contains('host')) {
      return 'Network error. Please check your internet connection.';
    }
    return 'Authentication failed. Please try again.';
  }

  String _handleAuthException(Object e) => formatAuthException(e);

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    try {
      debugPrint('[AUTH] Login request started for email: "$trimmedEmail"');
      final credential = await _fbAuth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final fbUser = credential.user;
      debugPrint('[AUTH] Login succeeded. UID: ${fbUser?.uid}');
      if (fbUser != null) {
        UserModel? user = await fetchUserProfile(fbUser.uid);
        if (user == null) {
          // Draft user model requiring Profile Setup
          user = UserModel(
            id: fbUser.uid,
            username: trimmedEmail.split('@').first,
            email: trimmedEmail,
            country: 'Kenya',
            city: 'Nairobi',
            dateOfBirth: DateTime(2000, 1, 1),
            gender: 'Other',
            bio: '',
            profilePicUrl: 'crushie_avatar_0',
            preferredContactMethod: 'WhatsApp',
            contactDetails: '+254700000000',
          );
          _currentUser = user;
        }
        return AuthResult(success: true, user: user);
      } else {
        return AuthResult(
            success: false, errorMessage: 'User authentication failed.');
      }
    } catch (e) {
      String? code;
      if (e is fb_auth.FirebaseAuthException) {
        code = e.code;
        debugPrint('[AUTH] Login FAILED');
        debugPrint('[AUTH] Firebase error code: "${e.code}"');
        debugPrint('[AUTH] Firebase error message: "${e.message}"');
      } else {
        debugPrint('[AUTH] Login FAILED with exception: $e');
      }
      final msg = _handleAuthException(e);
      return AuthResult(success: false, errorMessage: msg, errorCode: code);
    }
  }

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final trimmedEmail = email.trim();
    try {
      debugPrint('[AUTH] SignUp request started for email: "$trimmedEmail"');
      final credential = await _fbAuth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser != null) {
        // Check if user document already exists in Firestore
        final existingProfile = await fetchUserProfile(fbUser.uid);
        if (existingProfile != null && existingProfile.bio.isNotEmpty) {
          debugPrint(
              '[AUTH] Account already exists in Firestore for UID: ${fbUser.uid}');
          return AuthResult(
            success: false,
            errorMessage:
                'This email is already registered. Please log in or use Forgot Password if you forgot your password.',
            errorCode: 'email-already-in-use',
          );
        }

        // Send email verification immediately via Firebase Auth
        try {
          debugPrint('[AUTH] Calling sendEmailVerification()');
          await fbUser.sendEmailVerification();
          debugPrint('[AUTH] Verification email request SUCCESS');
        } catch (verr) {
          debugPrint('[AUTH] Verification email request note: $verr');
        }

        // Draft user model requiring Profile Setup
        final newUser = UserModel(
          id: fbUser.uid,
          username: username.isEmpty ? trimmedEmail.split('@').first : username,
          email: trimmedEmail,
          country: 'Kenya',
          city: 'Nairobi',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'Other',
          bio: '',
          profilePicUrl: 'crushie_avatar_0',
          preferredContactMethod: 'WhatsApp',
          contactDetails: '+254700000000',
        );

        _currentUser = newUser;
        return AuthResult(success: true, user: newUser, isNewUser: true);
      } else {
        return AuthResult(
            success: false, errorMessage: 'User account creation failed.');
      }
    } catch (e) {
      String? code;
      if (e is fb_auth.FirebaseAuthException) {
        code = e.code;
        debugPrint('[AUTH] SignUp FAILED');
        debugPrint('[AUTH] Firebase error code: "${e.code}"');
        debugPrint('[AUTH] Firebase error message: "${e.message}"');
      } else {
        debugPrint('[AUTH] SignUp FAILED with exception: $e');
      }
      final msg = _handleAuthException(e);
      return AuthResult(success: false, errorMessage: msg, errorCode: code);
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    try {
      debugPrint('[AUTH] Initiating Google Sign-In with Account Picker...');
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[AUTH] User canceled Google Sign-In.');
        return AuthResult(
            success: false, errorMessage: 'Google sign-in was canceled.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fb_auth.UserCredential userCredential =
          await _fbAuth.signInWithCredential(credential);
      final fbUser = userCredential.user;

      if (fbUser != null) {
        debugPrint('[AUTH] Google Sign-In succeeded. UID: ${fbUser.uid}');
        UserModel? user = await fetchUserProfile(fbUser.uid);

        bool isNew = userCredential.additionalUserInfo?.isNewUser ?? false;

        if (user == null) {
          isNew = true;
          // Draft user model requiring Profile Setup
          user = UserModel(
            id: fbUser.uid,
            username:
                googleUser.displayName?.replaceAll(' ', '_').toLowerCase() ??
                    'google_user',
            email: googleUser.email,
            country: 'Kenya',
            city: 'Nairobi',
            dateOfBirth: DateTime(1998, 1, 1),
            gender: 'Other',
            bio: '',
            profilePicUrl: googleUser.photoUrl ?? 'crushie_avatar_0',
            preferredContactMethod: 'Email',
            contactDetails: googleUser.email,
          );
          _currentUser = user;
        } else {
          _currentUser = user;
          _db.updateUser(user);
        }

        final bool profileIncomplete =
            !user.profileCompleted || user.bio.isEmpty;
        return AuthResult(
            success: true, user: user, isNewUser: isNew || profileIncomplete);
      } else {
        return AuthResult(
            success: false, errorMessage: 'Google sign-in credential failed.');
      }
    } catch (e) {
      String? code;
      if (e is fb_auth.FirebaseAuthException) {
        code = e.code;
        debugPrint('[AUTH] Google Sign-In FAILED');
        debugPrint('[AUTH] Firebase error code: "${e.code}"');
        debugPrint('[AUTH] Firebase error message: "${e.message}"');
      } else {
        debugPrint('[AUTH] Google Sign-In FAILED with exception: $e');
      }
      final msg = _handleAuthException(e);
      return AuthResult(success: false, errorMessage: msg, errorCode: code);
    }
  }

  Future<AuthResult> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    try {
      debugPrint(
          '[AUTH] Password reset request started for email: "$trimmedEmail"');
      debugPrint(
          '[AUTH] Calling sendPasswordResetEmail(email: "$trimmedEmail")');
      await _fbAuth.sendPasswordResetEmail(email: trimmedEmail);
      debugPrint(
          '[AUTH] Password reset email request SUCCESS (Firebase accepted the request)');
      return AuthResult(success: true);
    } catch (e) {
      if (e is fb_auth.FirebaseAuthException) {
        debugPrint('[AUTH] Password reset email request FAILED');
        debugPrint('[AUTH] Firebase error code: "${e.code}"');
        debugPrint('[AUTH] Firebase error message: "${e.message}"');
      } else {
        debugPrint('[AUTH] Password reset request FAILED with exception: $e');
      }
      final msg = _handleAuthException(e);
      return AuthResult(success: false, errorMessage: msg);
    }
  }

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final fbUser = _fbAuth.currentUser;
      if (fbUser == null || fbUser.email == null) {
        return AuthResult(
            success: false,
            errorMessage: 'No authenticated user session found.');
      }

      // Re-authenticate email/password user before changing password
      final cred = fb_auth.EmailAuthProvider.credential(
        email: fbUser.email!,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(cred);
      await fbUser.updatePassword(newPassword);

      return AuthResult(success: true);
    } catch (e) {
      if (e is fb_auth.FirebaseAuthException) {
        debugPrint('[AUTH] ChangePassword FAILED');
        debugPrint('[AUTH] Firebase error code: "${e.code}"');
        debugPrint('[AUTH] Firebase error message: "${e.message}"');
      } else {
        debugPrint('[AUTH] ChangePassword FAILED with exception: $e');
      }
      final msg = _handleAuthException(e);
      return AuthResult(success: false, errorMessage: msg);
    }
  }

  Future<AuthResult> sendEmailVerification() async {
    try {
      final fbUser = _fbAuth.currentUser;
      final userExists = fbUser != null;
      debugPrint('[AUTH] Manual resend verification email started');
      debugPrint('[AUTH] Current user exists: $userExists');
      debugPrint('[AUTH] UID exists: ${fbUser?.uid != null}');
      if (fbUser != null) {
        debugPrint('[AUTH] Calling sendEmailVerification()');
        await fbUser.sendEmailVerification();
        debugPrint(
            '[AUTH] Verification email request SUCCESS (Firebase accepted the request)');
        return AuthResult(success: true);
      }
      return AuthResult(
          success: false, errorMessage: 'No authenticated user found.');
    } catch (e) {
      String? code;
      if (e is fb_auth.FirebaseAuthException) {
        code = e.code;
        debugPrint('[AUTH] Verification email request FAILED');
        debugPrint('[AUTH] Firebase error code: "${e.code}"');
        debugPrint('[AUTH] Firebase error message: "${e.message}"');
      } else {
        debugPrint(
            '[AUTH] Verification email request FAILED with exception: $e');
      }
      final msg = _handleAuthException(e);
      return AuthResult(success: false, errorMessage: msg, errorCode: code);
    }
  }

  Future<bool> checkEmailVerified() async {
    final fbUser = _fbAuth.currentUser;
    debugPrint(
        '[AUTH] Checking verification status for currentUser: ${fbUser?.uid}...');
    if (fbUser == null) return false;
    if (isGoogleUser) return true;

    // Reload Firebase user to fetch fresh emailVerified from server
    await fbUser.reload();
    final verified = _fbAuth.currentUser?.emailVerified ?? false;
    debugPrint(
        '[AUTH] emailVerified refreshed result: $verified for UID: ${fbUser.uid}');
    return verified;
  }

  Future<AuthResult> signOut() async {
    try {
      debugPrint('[AUTH] Signing out user...');
      try {
        await _googleSignIn.signOut();
      } catch (gErr) {
        debugPrint('[AUTH] Google sign out note: $gErr');
      }
      await _fbAuth.signOut();
      _currentUser = null;
      debugPrint('[AUTH] Sign out SUCCESS');
      return AuthResult(success: true);
    } catch (e) {
      debugPrint('[AUTH] Exception during sign out: $e');
      String? code;
      if (e is fb_auth.FirebaseAuthException) {
        code = e.code;
      }
      final msg = _handleAuthException(e);
      return AuthResult(success: false, errorMessage: msg, errorCode: code);
    }
  }

  Future<AuthResult> deleteAccount({
    String? userId,
    String? currentPassword,
  }) async {
    try {
      final fbUser = _fbAuth.currentUser;
      if (fbUser == null) {
        return AuthResult(
          success: false,
          errorMessage: 'No active user session found.',
          errorCode: 'no-current-user',
        );
      }

      final uid = fbUser.uid;
      // 1. Authorization check: if userId specified, it must match authenticated UID
      if (userId != null && userId.isNotEmpty && userId != uid) {
        debugPrint(
            '[AUTH] Unauthorized delete attempt: caller $uid != target $userId');
        return AuthResult(
          success: false,
          errorMessage:
              'Unauthorized: You cannot delete another user\'s account.',
          errorCode: 'unauthorized',
        );
      }

      debugPrint('[AUTH] Initiating secure account deletion for UID: $uid');

      // 2. Re-authenticate user before performing irreversible deletion
      if (isGoogleUser) {
        try {
          final googleUser = await _googleSignIn.signInSilently() ??
              await _googleSignIn.signIn();
          if (googleUser == null) {
            return AuthResult(
              success: false,
              errorMessage: 'Google re-authentication cancelled or failed.',
              errorCode: 'reauth-cancelled',
            );
          }
          final googleAuth = await googleUser.authentication;
          final cred = fb_auth.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await fbUser.reauthenticateWithCredential(cred);
        } catch (gerr) {
          debugPrint('[AUTH] Google re-authentication failed: $gerr');
          final code = (gerr is fb_auth.FirebaseAuthException)
              ? gerr.code
              : 'reauth-failed';
          return AuthResult(
            success: false,
            errorMessage:
                'Google re-authentication failed. Please sign in again to verify identity.',
            errorCode: code,
          );
        }
      } else {
        if (currentPassword == null || currentPassword.isEmpty) {
          return AuthResult(
            success: false,
            errorMessage: 'Password is required to delete your account.',
            errorCode: 'wrong-password',
          );
        }
        if (fbUser.email == null || fbUser.email!.isEmpty) {
          return AuthResult(
            success: false,
            errorMessage: 'User email not found for re-authentication.',
            errorCode: 'invalid-email',
          );
        }
        final cred = fb_auth.EmailAuthProvider.credential(
          email: fbUser.email!,
          password: currentPassword,
        );
        await fbUser.reauthenticateWithCredential(cred);
      }

      // 3. Clean up Cloud Firestore user data (posts, subcollections, profile)
      // Discovers media URLs and cleans up Firestore data while rules evaluate isOwner(uid) == true.
      final discoveredMediaUrls =
          await _firestoreService.deleteUserAccountData(uid);

      // 4. Clean up Firebase Storage files while still authenticated
      final storageResult = await _storageService.deleteUserStorageData(
        uid,
        mediaUrls: discoveredMediaUrls,
      );
      if (!storageResult.success) {
        if (storageResult.isRetryable) {
          debugPrint(
              '[AUTH] Storage cleanup failed with retryable error: ${storageResult.errorMessage}');
          return AuthResult(
            success: false,
            errorMessage:
                'Network error cleaning up user media. Please check your connection and retry.',
            errorCode: storageResult.errorCode ?? 'storage-cleanup-error',
          );
        } else if (storageResult.errorCode == 'permission-denied') {
          debugPrint(
              '[AUTH] Storage deletion restricted by security rules; flagged for trusted backend cleanup.');
        }
      }

      // 5. Delete in-memory user cache
      _db.deleteUser(uid);

      // 6. Delete Firebase Auth user
      await fbUser.delete();

      // 7. Sign out and clear local session state
      await signOut();

      debugPrint('[AUTH] Account permanently deleted for UID: $uid');
      return AuthResult(success: true);
    } catch (e) {
      if (e is fb_auth.FirebaseAuthException) {
        debugPrint('[AUTH] Account deletion FAILED');
        debugPrint('[AUTH] Firebase error code: "${e.code}"');
        debugPrint('[AUTH] Firebase error message: "${e.message}"');
        if (e.code == 'requires-recent-login') {
          return AuthResult(
            success: false,
            errorMessage:
                'For security, this operation requires a recent login. Please log out, sign in again, and retry.',
            errorCode: e.code,
          );
        }
      } else {
        debugPrint('[AUTH] Account deletion FAILED with exception: $e');
      }
      final msg = _handleAuthException(e);
      final code =
          (e is fb_auth.FirebaseAuthException) ? e.code : 'deletion-error';
      return AuthResult(success: false, errorMessage: msg, errorCode: code);
    }
  }
}
