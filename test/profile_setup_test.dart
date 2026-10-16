import 'package:flutter_test/flutter_test.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/widgets/crushie_avatar.dart';

void main() {
  group('Profile Setup & Kenya Phone Normalization Tests', () {
    String normalizePhoneNumber(String raw) {
      String cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (cleaned.startsWith('+254')) {
        return cleaned;
      } else if (cleaned.startsWith('07') || cleaned.startsWith('01')) {
        return '+254${cleaned.substring(1)}';
      } else if (cleaned.startsWith('7') || cleaned.startsWith('1')) {
        return '+254$cleaned';
      } else if (cleaned.startsWith('254')) {
        return '+$cleaned';
      }
      return cleaned;
    }

    bool isValidKenyaPhone(String raw) {
      final norm = normalizePhoneNumber(raw);
      final reg = RegExp(r'^\+254(7\d{8}|1\d{8})$');
      return reg.hasMatch(norm);
    }

    test('Normalizes various Kenya mobile phone inputs to standard +254 E.164 format', () {
      expect(normalizePhoneNumber('0712345678'), equals('+254712345678'));
      expect(normalizePhoneNumber('0722 123 456'), equals('+254722123456'));
      expect(normalizePhoneNumber('0112345678'), equals('+254112345678'));
      expect(normalizePhoneNumber('712345678'), equals('+254712345678'));
      expect(normalizePhoneNumber('254712345678'), equals('+254712345678'));
      expect(normalizePhoneNumber('+254 712 345 678'), equals('+254712345678'));
      expect(normalizePhoneNumber('+254712345678'), equals('+254712345678'));
    });

    test('Validates Kenyan mobile numbers accurately', () {
      expect(isValidKenyaPhone('0712345678'), isTrue);
      expect(isValidKenyaPhone('+254712345678'), isTrue);
      expect(isValidKenyaPhone('0112345678'), isTrue);
      expect(isValidKenyaPhone('+254112345678'), isTrue);
      expect(isValidKenyaPhone('712345678'), isTrue);

      // Invalid formats
      expect(isValidKenyaPhone('0201234567'), isFalse); // Landline
      expect(isValidKenyaPhone('0712345'), isFalse);     // Too short
      expect(isValidKenyaPhone('07123456789'), isFalse);  // Too long
      expect(isValidKenyaPhone('12345'), isFalse);
      expect(isValidKenyaPhone('+1234567890'), isFalse);
    });
  });

  group('Avatar Presets and Indexing Tests', () {
    test('Contains exactly 8 distinctive signature mascot avatars', () {
      expect(CrushieAvatar.avatarPresets.length, equals(8));
      final names = CrushieAvatar.avatarPresets.map((p) => p['name']).toList();
      expect(names, contains('Sweet Heart'));
      expect(names, contains('Electric Crush'));
      expect(names, contains('Ocean Vibe'));
      expect(names, contains('Sunset Star'));
      expect(names, contains('Neon Glow'));
      expect(names, contains('Cupid Love'));
      expect(names, contains('Vibe King'));
      expect(names, contains('Emerald Charm'));
    });

    test('Avatar index parses accurately from string identifiers', () {
      int getAvatarIndex(String url) {
        if (url.startsWith('crushie_avatar_')) {
          final parsed = int.tryParse(url.replaceFirst('crushie_avatar_', ''));
          if (parsed != null && parsed >= 0 && parsed < CrushieAvatar.avatarPresets.length) {
            return parsed;
          }
        }
        return 0;
      }

      expect(getAvatarIndex('crushie_avatar_0'), equals(0));
      expect(getAvatarIndex('crushie_avatar_3'), equals(3));
      expect(getAvatarIndex('crushie_avatar_7'), equals(7));
      expect(getAvatarIndex('https://firebasestorage.app/custom.jpg'), equals(0));
      expect(getAvatarIndex('invalid_avatar_99'), equals(0));
    });
  });

  group('Profile Completion & Age Validation Tests', () {
    int calculateAge(DateTime dob) {
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    }

    test('Validates 18+ age requirement accurately', () {
      final now = DateTime.now();
      final adultDob = DateTime(now.year - 20, now.month, now.day);
      final minorDob = DateTime(now.year - 16, now.month, now.day);

      expect(calculateAge(adultDob), greaterThanOrEqualTo(18));
      expect(calculateAge(minorDob), lessThan(18));
    });

    test('Profile completion requires non-empty bio', () {
      final incompleteUser = UserModel(
        id: 'user_123',
        username: 'testuser',
        email: 'test@crushie.app',
        country: 'Kenya',
        city: 'Nairobi',
        dateOfBirth: DateTime(2000, 1, 1),
        gender: 'Female',
        bio: '',
        profilePicUrl: 'crushie_avatar_0',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+254712345678',
      );

      final completedUser = incompleteUser.copyWith(
        bio: 'Adventurous soul looking for good vibes and coffee dates.',
      );

      expect(incompleteUser.bio.trim().isNotEmpty, isFalse);
      expect(completedUser.bio.trim().isNotEmpty, isTrue);
    });

    test('UserModel serializes and deserializes accurately with Firebase UID', () {
      final user = UserModel(
        id: 'fb_auth_uid_xyz',
        username: 'kenyan_crush',
        email: 'kenya@crushie.app',
        country: 'Kenya',
        city: 'Mombasa',
        dateOfBirth: DateTime(1999, 5, 20),
        gender: 'Male',
        bio: 'Coastal living and creative minds.',
        profilePicUrl: 'https://firebasestorage.googleapis.com/profiles/fb_auth_uid_xyz/profile_123.jpg',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+254712345678',
      );

      final map = user.toMap();
      expect(map['id'], equals('fb_auth_uid_xyz'));
      expect(map['country'], equals('Kenya'));
      expect(map['city'], equals('Mombasa'));
      expect(map['preferredContactMethod'], equals('WhatsApp'));
      expect(map['contactDetails'], equals('+254712345678'));
      expect(map['profilePicUrl'], startsWith('https://firebasestorage.googleapis.com/'));

      final restored = UserModel.fromMap(map, 'fb_auth_uid_xyz');
      expect(restored.id, equals(user.id));
      expect(restored.username, equals(user.username));
      expect(restored.city, equals('Mombasa'));
      expect(restored.contactDetails, equals('+254712345678'));
    });
  });
}
