import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class UserModel {
  final String id;
  final String username;
  final String email;
  final String country;
  final String city;
  final DateTime dateOfBirth;
  final String gender;
  final String bio;
  final String profilePicUrl;
  final String preferredContactMethod; // WhatsApp, Telegram, Phone Call, Email
  final String contactDetails;         // Private contact info
  final bool isVerified;
  final bool isPremium;
  final int followersCount;
  final int followingCount;
  final List<String> communities;
  final bool isOnline;
  final DateTime lastSeen;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.country,
    required this.city,
    required this.dateOfBirth,
    required this.gender,
    required this.bio,
    required this.profilePicUrl,
    required this.preferredContactMethod,
    required this.contactDetails,
    this.isVerified = false,
    this.isPremium = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.communities = const [],
    this.isOnline = true,
    DateTime? lastSeen,
    DateTime? createdAt,
  })  : lastSeen = lastSeen ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  String get statusText {
    if (isOnline) {
      return 'Online';
    }
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 60) {
      return 'Active ${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return 'Active ${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Last seen yesterday';
    } else {
      return 'Last seen ${diff.inDays}d ago';
    }
  }

  Color get statusColor {
    if (isOnline) {
      return AppColors.online;
    }
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inHours < 24) {
      return AppColors.activeToday;
    }
    return AppColors.offline;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'country': country,
      'city': city,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'bio': bio,
      'profilePicUrl': profilePicUrl,
      'preferredContactMethod': preferredContactMethod,
      'contactDetails': contactDetails,
      'isVerified': isVerified,
      'isPremium': isPremium,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'communities': communities,
      'isOnline': isOnline,
      'lastSeen': lastSeen.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      country: map['country'] ?? 'Kenya',
      city: map['city'] ?? 'Nairobi',
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.tryParse(map['dateOfBirth']) ?? DateTime(2000, 1, 1)
          : DateTime(2000, 1, 1),
      gender: map['gender'] ?? 'Female',
      bio: map['bio'] ?? '',
      profilePicUrl: map['profilePicUrl'] ?? '',
      preferredContactMethod: map['preferredContactMethod'] ?? 'WhatsApp',
      contactDetails: map['contactDetails'] ?? '',
      isVerified: map['isVerified'] ?? false,
      isPremium: map['isPremium'] ?? false,
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      communities: List<String>.from(map['communities'] ?? []),
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? DateTime.tryParse(map['lastSeen']) ?? DateTime.now()
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? username,
    String? email,
    String? country,
    String? city,
    DateTime? dateOfBirth,
    String? gender,
    String? bio,
    String? profilePicUrl,
    String? preferredContactMethod,
    String? contactDetails,
    bool? isVerified,
    bool? isPremium,
    int? followersCount,
    int? followingCount,
    List<String>? communities,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      country: country ?? this.country,
      city: city ?? this.city,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      preferredContactMethod: preferredContactMethod ?? this.preferredContactMethod,
      contactDetails: contactDetails ?? this.contactDetails,
      isVerified: isVerified ?? this.isVerified,
      isPremium: isPremium ?? this.isPremium,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      communities: communities ?? this.communities,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
    );
  }
}
