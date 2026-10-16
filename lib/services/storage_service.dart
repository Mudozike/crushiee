import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService([FirebaseStorage? storage]) {
    if (storage != null) {
      return StorageService._withStorage(storage);
    }
    return _instance;
  }
  StorageService._internal() : _customStorage = null;
  StorageService._withStorage(this._customStorage);

  final FirebaseStorage? _customStorage;
  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  // Validate photo file size (default <= 10MB)
  Future<bool> isPhotoUnderLimit(XFile file,
      {int maxBytes = 10 * 1024 * 1024}) async {
    try {
      final length = await file.length();
      return length <= maxBytes;
    } catch (e) {
      return true;
    }
  }

  // Validate photo file size for verification (<= 2MB)
  Future<bool> isPhotoUnder2MB(XFile file) async {
    return isPhotoUnderLimit(file, maxBytes: 2 * 1024 * 1024);
  }

  // Validate video file size (default <= 50MB)
  Future<bool> isVideoUnderLimit(XFile file,
      {int maxBytes = 50 * 1024 * 1024}) async {
    try {
      final length = await file.length();
      return length <= maxBytes;
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
      final isUnderLimit =
          await isPhotoUnderLimit(file, maxBytes: 2 * 1024 * 1024);
      if (!isUnderLimit) {
        debugPrint('[STORAGE] File size exceeds 2MB limit for verification');
        return null;
      }

      final String storagePath = 'verification/$userId/photo.jpg';
      final ref = _storage.ref().child(storagePath);

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        return await uploadTask.ref.getDownloadURL();
      } else {
        final uploadTask = await ref.putFile(
          File(file.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        return await uploadTask.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint(
          '[STORAGE] Verification photo upload failed for userId $userId: $e');
      return null;
    }
  }

  // Upload profile photo to Firebase Storage path: profiles/{userId}/{timestamp}.jpg (Max 5MB)
  Future<String> uploadProfilePicture({
    required String userId,
    required XFile file,
  }) async {
    try {
      final isUnderLimit =
          await isPhotoUnderLimit(file, maxBytes: 5 * 1024 * 1024);
      if (!isUnderLimit) {
        throw Exception('Profile photo file size exceeds the 5MB limit.');
      }

      final String extension =
          file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final String contentType =
          extension == 'png' ? 'image/png' : 'image/jpeg';
      final String filename =
          'profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String storagePath = 'profiles/$userId/$filename';
      final ref = _storage.ref().child(storagePath);

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        return await uploadTask.ref.getDownloadURL();
      } else {
        final uploadTask = await ref.putFile(
          File(file.path),
          SettableMetadata(contentType: contentType),
        );
        return await uploadTask.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint(
          '[STORAGE] Profile photo upload failed for userId $userId: $e');
      rethrow;
    }
  }

  // Upload post photo to Firebase Storage path: posts/{userId}/{timestamp}.jpg
  Future<String> uploadPostPhoto({
    required String userId,
    required XFile file,
  }) async {
    try {
      final isUnderLimit =
          await isPhotoUnderLimit(file, maxBytes: 10 * 1024 * 1024);
      if (!isUnderLimit) {
        throw Exception('Photo file size exceeds the 10MB limit.');
      }

      final String extension =
          file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final String contentType =
          extension == 'png' ? 'image/png' : 'image/jpeg';
      final String filename =
          'photo_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String storagePath = 'posts/$userId/$filename';
      final ref = _storage.ref().child(storagePath);

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        return await uploadTask.ref.getDownloadURL();
      } else {
        final uploadTask = await ref.putFile(
          File(file.path),
          SettableMetadata(contentType: contentType),
        );
        return await uploadTask.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('[STORAGE] Post photo upload failed for userId $userId: $e');
      rethrow;
    }
  }

  // Upload post video to Firebase Storage path: posts/{userId}/{timestamp}.mp4
  Future<String> uploadPostVideo({
    required String userId,
    required XFile file,
  }) async {
    try {
      final isUnderLimit =
          await isVideoUnderLimit(file, maxBytes: 50 * 1024 * 1024);
      if (!isUnderLimit) {
        throw Exception('Video file size exceeds the 50MB limit.');
      }

      String extension = 'mp4';
      String contentType = 'video/mp4';
      final lowerPath = file.path.toLowerCase();
      if (lowerPath.endsWith('.mov')) {
        extension = 'mov';
        contentType = 'video/quicktime';
      } else if (lowerPath.endsWith('.webm')) {
        extension = 'webm';
        contentType = 'video/webm';
      }

      final String filename =
          'video_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String storagePath = 'posts/$userId/$filename';
      final ref = _storage.ref().child(storagePath);

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        return await uploadTask.ref.getDownloadURL();
      } else {
        final uploadTask = await ref.putFile(
          File(file.path),
          SettableMetadata(contentType: contentType),
        );
        return await uploadTask.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('[STORAGE] Post video upload failed for userId $userId: $e');
      rethrow;
    }
  }

  // Upload chat photo to Firebase Storage path: chats/{connectionId}/{userId}/{timestamp}.jpg
  Future<String> uploadChatPhoto({
    required String connectionId,
    required String userId,
    required XFile file,
  }) async {
    try {
      final isUnderLimit =
          await isPhotoUnderLimit(file, maxBytes: 10 * 1024 * 1024);
      if (!isUnderLimit) {
        throw Exception('Photo file size exceeds the 10MB limit.');
      }

      final String extension =
          file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final String contentType =
          extension == 'png' ? 'image/png' : 'image/jpeg';
      final String filename =
          'chat_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String storagePath = 'chats/$connectionId/$userId/$filename';
      final ref = _storage.ref().child(storagePath);

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        return await uploadTask.ref.getDownloadURL();
      } else {
        final uploadTask = await ref.putFile(
          File(file.path),
          SettableMetadata(contentType: contentType),
        );
        return await uploadTask.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint(
          '[STORAGE] Chat photo upload failed for connectionId $connectionId: $e');
      rethrow;
    }
  }

  // --- STORAGE DELETION & CLEANUP ---

  /// Delete a file by its permanent Storage download URL or gs:// URL.
  /// Returns true if successfully deleted or already absent ('object-not-found').
  /// Throws non-ignorable errors (e.g. network or permission errors).
  Future<bool> deleteFileByUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return false;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://') &&
        !trimmed.startsWith('gs://')) {
      return false;
    }

    try {
      final ref = _storage.refFromURL(trimmed);
      await ref.delete();
      debugPrint('[STORAGE] Successfully deleted file: $trimmed');
      return true;
    } catch (e) {
      if (e is FirebaseException && e.code == 'object-not-found') {
        debugPrint(
            '[STORAGE] File already absent (object-not-found): $trimmed');
        return true;
      }
      debugPrint('[STORAGE] Note: error deleting file by URL ($trimmed): $e');
      rethrow;
    }
  }

  /// Delete verification photo at verification/{userId}/photo.jpg.
  /// Returns true if deleted or already absent ('object-not-found').
  Future<bool> deleteVerificationPhoto(String userId) async {
    if (userId.trim().isEmpty) return false;
    try {
      final ref = _storage.ref().child('verification/$userId/photo.jpg');
      await ref.delete();
      debugPrint('[STORAGE] Verification photo deleted for UID: $userId');
      return true;
    } catch (e) {
      if (e is FirebaseException && e.code == 'object-not-found') {
        debugPrint(
            '[STORAGE] Verification photo already absent for UID: $userId');
        return true;
      }
      debugPrint('[STORAGE] Error deleting verification photo: $e');
      rethrow;
    }
  }

  /// Delete all storage files associated with a user.
  /// Distinguishes already-missing objects (success) from transient network failures
  /// and authorization barriers, reporting an actionable StorageCleanupResult.
  Future<StorageCleanupResult> deleteUserStorageData(
    String userId, {
    List<String>? mediaUrls,
  }) async {
    if (userId.trim().isEmpty) {
      return const StorageCleanupResult(success: true);
    }
    debugPrint('[STORAGE] Starting storage cleanup for UID: $userId');

    int deletedCount = 0;
    String? fatalError;
    String? errorCode;
    bool isRetryable = false;

    // 1. Delete verification photo
    try {
      final ok = await deleteVerificationPhoto(userId);
      if (ok) deletedCount++;
    } catch (e) {
      if (e is FirebaseException) {
        errorCode = e.code;
        if (e.code == 'network-request-failed' ||
            e.code == 'retry-limit-exceeded' ||
            e.code == 'canceled') {
          isRetryable = true;
          fatalError =
              'Network error deleting verification photo: ${e.message}';
        } else {
          fatalError =
              'Storage error deleting verification photo: ${e.message}';
        }
      } else {
        fatalError = e.toString();
      }
    }

    // 2. Delete explicitly passed media URLs
    if (mediaUrls != null) {
      for (final url in mediaUrls) {
        try {
          final ok = await deleteFileByUrl(url);
          if (ok) deletedCount++;
        } catch (e) {
          if (e is FirebaseException) {
            errorCode = e.code;
            if (e.code == 'network-request-failed' ||
                e.code == 'retry-limit-exceeded' ||
                e.code == 'canceled') {
              isRetryable = true;
              fatalError ??= 'Network error deleting media file: ${e.message}';
            } else if (e.code == 'permission-denied' ||
                e.code == 'unauthorized') {
              fatalError ??=
                  'Permission denied deleting media file: ${e.message}';
            }
          } else {
            fatalError ??= e.toString();
          }
        }
      }
    }

    // 3. Folder enumeration and item cleanup
    for (final folder in ['profiles', 'posts']) {
      try {
        final listResult =
            await _storage.ref().child('$folder/$userId').listAll();
        for (final item in listResult.items) {
          try {
            await item.delete();
            deletedCount++;
            debugPrint('[STORAGE] Deleted $folder file: ${item.name}');
          } catch (e) {
            if (e is FirebaseException && e.code == 'object-not-found') {
              continue; // benign
            }
            if (e is FirebaseException &&
                (e.code == 'network-request-failed' ||
                    e.code == 'retry-limit-exceeded')) {
              isRetryable = true;
              errorCode = e.code;
              fatalError ??=
                  'Network error deleting $folder file: ${e.message}';
            }
            debugPrint('[STORAGE] Error deleting item ${item.name}: $e');
          }
        }
      } catch (e) {
        if (e is FirebaseException &&
            (e.code == 'network-request-failed' ||
                e.code == 'retry-limit-exceeded')) {
          isRetryable = true;
          errorCode = e.code;
          fatalError ??= 'Network error listing folder $folder: ${e.message}';
        }
        debugPrint(
            '[STORAGE] Folder listing not supported or empty for $folder/$userId: $e');
      }
    }

    final bool overallSuccess = fatalError == null;
    return StorageCleanupResult(
      success: overallSuccess,
      deletedCount: deletedCount,
      errorMessage: fatalError,
      errorCode: errorCode,
      isRetryable: isRetryable,
    );
  }
}

class StorageCleanupResult {
  final bool success;
  final int deletedCount;
  final String? errorMessage;
  final String? errorCode;
  final bool isRetryable;

  const StorageCleanupResult({
    required this.success,
    this.deletedCount = 0,
    this.errorMessage,
    this.errorCode,
    this.isRetryable = false,
  });
}
