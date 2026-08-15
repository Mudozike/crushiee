import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';

class UserProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final StorageService _storage = StorageService();

  UserProvider() {
    _db.addListener(_onDbChanged);
  }

  void _onDbChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChanged);
    super.dispose();
  }

  UserModel? getUser(String userId) => _db.getUser(userId);

  int getDailyConnections(String userId) {
    final user = _db.getUser(userId);
    return user?.activeDailyConnections ?? 0;
  }

  int getMonthlyConnections(String userId) {
    final user = _db.getUser(userId);
    return user?.activeMonthlyConnections ?? 0;
  }

  Future<String?> uploadVerificationPhoto({
    required String userId,
    required XFile file,
  }) async {
    try {
      final String? photoUrl = await _storage.uploadVerificationPhoto(
        userId: userId,
        file: file,
      );
      final user = _db.getUser(userId);
      if (user != null) {
        _db.updateUser(user.copyWith(verificationPhoto: photoUrl));
      }
      notifyListeners();
      return photoUrl;
    } catch (e) {
      debugPrint('Failed to upload verification photo: $e');
      return null;
    }
  }

  void verifyUserWithPhoto(String userId, String photoUrl, {int days = 30}) {
    final user = _db.getUser(userId);
    if (user != null) {
      final expiry = DateTime.now().add(Duration(days: days));
      _db.updateUser(user.copyWith(
        isVerified: true,
        verifiedExpiry: expiry,
        verificationPhoto: photoUrl,
      ));
      notifyListeners();
    }
  }
}
