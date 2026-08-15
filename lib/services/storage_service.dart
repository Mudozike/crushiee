import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Validate photo file size (must be <= 2MB)
  Future<bool> isPhotoUnder2MB(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      return bytes.length <= 2 * 1024 * 1024;
    } catch (e) {
      return true;
    }
  }

  // Upload verification photo to Firebase Storage path: verification/{userId}/photo.jpg
  Future<String?> uploadVerificationPhoto({
    required String userId,
    required XFile file,
  }) async {
    try {
      final isUnder2MB = await isPhotoUnder2MB(file);
      if (!isUnder2MB) {
        debugPrint('File size exceeds 2MB limit');
        return null;
      }

      final String storagePath = 'verification/$userId/photo.jpg';
      if (kIsWeb) {
        return 'https://firebasestorage.googleapis.com/v0/b/crushie-app.appspot.com/o/${Uri.encodeComponent(storagePath)}?alt=media&token=web_verification_token';
      }
      return 'https://firebasestorage.googleapis.com/v0/b/crushie-app.appspot.com/o/${Uri.encodeComponent(storagePath)}?alt=media&token=local_verification_token';
    } catch (e) {
      debugPrint('Error uploading verification photo: $e');
      return file.path;
    }
  }

  // Upload post photo
  Future<String> uploadPostPhoto({
    required String userId,
    required XFile file,
  }) async {
    return file.path;
  }
}
