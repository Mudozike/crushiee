
import '../models/user_model.dart';
import 'database_service.dart';

class AuthResult {
  final bool success;
  final UserModel? user;
  final String? errorMessage;

  AuthResult({
    required this.success,
    this.user,
    this.errorMessage,
  });
}

class AuthService {
  final DatabaseService _db = DatabaseService();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  AuthService() {
    // Default logged in demo user
    _currentUser = _db.getUser('current_user_1');
  }

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Demo login success
    final user = _db.getUser('current_user_1') ??
        UserModel(
          id: 'user_email_${DateTime.now().millisecondsSinceEpoch}',
          username: email.split('@').first,
          email: email,
          country: 'Kenya',
          city: 'Nairobi',
          dateOfBirth: DateTime(1999, 1, 1),
          gender: 'Female',
          bio: 'Hey there! I am using Crushie.',
          profilePicUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
          preferredContactMethod: 'WhatsApp',
          contactDetails: '+254712345678',
        );

    _currentUser = user;
    _db.updateUser(user);

    return AuthResult(success: true, user: user);
  }

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final newUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      username: username.isEmpty ? email.split('@').first : username,
      email: email,
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(2000, 1, 1),
      gender: 'Other',
      bio: 'New on Crushie! Excited to connect.',
      profilePicUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254700000000',
    );

    _currentUser = newUser;
    _db.updateUser(newUser);

    return AuthResult(success: true, user: newUser);
  }

  Future<AuthResult> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final googleUser = UserModel(
      id: 'google_user_${DateTime.now().millisecondsSinceEpoch}',
      username: 'google_user',
      email: 'user.google@gmail.com',
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(1997, 6, 15),
      gender: 'Male',
      bio: 'Google authenticated Crushie user 🚀',
      profilePicUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=400',
      preferredContactMethod: 'Email',
      contactDetails: 'user.google@gmail.com',
    );

    _currentUser = googleUser;
    _db.updateUser(googleUser);

    return AuthResult(success: true, user: googleUser);
  }

  void signOut() {
    _currentUser = null;
  }
}
