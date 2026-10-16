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
  final String contactDetails; // Private details revealed after payment
  final bool isVerified;
  final DateTime? verifiedExpiry;
  final String?
      verificationPhoto; // Firebase Storage URL: verification/{userId}/photo.jpg
  final bool isPremium;
  final DateTime? premiumExpiry;
  final int dailyConnections;
  final DateTime? dailyConnectionsDate;
  final int monthlyConnections;
  final DateTime? monthlyConnectionsMonth;
  final int followersCount;
  final int followingCount;
  final List<String> communities;
  final List<String> blockedUserIds;
  final bool profileCompleted;
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
    this.profileCompleted = false,
    this.isVerified = false,
    this.verifiedExpiry,
    this.verificationPhoto,
    this.isPremium = false,
    this.premiumExpiry,
    this.dailyConnections = 0,
    this.dailyConnectionsDate,
    this.monthlyConnections = 0,
    this.monthlyConnectionsMonth,
    this.followersCount = 0,
    this.followingCount = 0,
    this.communities = const [],
    this.blockedUserIds = const [],
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

  int get activeDailyConnections {
    final now = DateTime.now();
    if (dailyConnectionsDate == null) return 0;
    if (dailyConnectionsDate!.year != now.year ||
        dailyConnectionsDate!.month != now.month ||
        dailyConnectionsDate!.day != now.day) {
      return 0;
    }
    return dailyConnections;
  }

  int get activeMonthlyConnections {
    final now = DateTime.now();
    if (monthlyConnectionsMonth == null) return 0;
    if (monthlyConnectionsMonth!.year != now.year ||
        monthlyConnectionsMonth!.month != now.month) {
      return 0;
    }
    return monthlyConnections;
  }

  bool get isDailyLimitReached => !isPremium && activeDailyConnections >= 10;
  bool get isMonthlyLimitReached =>
      !isPremium && activeMonthlyConnections >= 60;
  bool get canConnectFree =>
      isPremium || (!isDailyLimitReached && !isMonthlyLimitReached);

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
      'verifiedExpiry': verifiedExpiry?.toIso8601String(),
      'verificationPhoto': verificationPhoto,
      'isPremium': isPremium,
      'premiumExpiry': premiumExpiry?.toIso8601String(),
      'dailyConnections': activeDailyConnections,
      'dailyConnectionsDate': dailyConnectionsDate?.toIso8601String(),
      'monthlyConnections': activeMonthlyConnections,
      'monthlyConnectionsMonth': monthlyConnectionsMonth?.toIso8601String(),
      'followersCount': followersCount,
      'followingCount': followingCount,
      'communities': communities,
      'blockedUserIds': blockedUserIds,
      'profileCompleted': profileCompleted,
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
      country: map['country'] ?? '',
      city: map['city'] ?? '',
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.tryParse(map['dateOfBirth']) ?? DateTime(2000, 1, 1)
          : DateTime(2000, 1, 1),
      gender: map['gender'] ?? 'Other',
      bio: map['bio'] ?? '',
      profilePicUrl: map['profilePicUrl'] ?? '',
      preferredContactMethod: map['preferredContactMethod'] ?? 'WhatsApp',
      contactDetails: map['contactDetails'] ?? '',
      profileCompleted: map['profileCompleted'] is bool
          ? map['profileCompleted'] as bool
          : (map['bio'] != null && (map['bio'] as String).trim().isNotEmpty),
      isVerified: map['isVerified'] ?? false,
      verifiedExpiry: map['verifiedExpiry'] != null
          ? DateTime.tryParse(map['verifiedExpiry'])
          : null,
      verificationPhoto: map['verificationPhoto'],
      isPremium: map['isPremium'] ?? false,
      premiumExpiry: map['premiumExpiry'] != null
          ? DateTime.tryParse(map['premiumExpiry'])
          : null,
      dailyConnections: map['dailyConnections'] ?? 0,
      dailyConnectionsDate: map['dailyConnectionsDate'] != null
          ? DateTime.tryParse(map['dailyConnectionsDate'])
          : null,
      monthlyConnections: map['monthlyConnections'] ?? 0,
      monthlyConnectionsMonth: map['monthlyConnectionsMonth'] != null
          ? DateTime.tryParse(map['monthlyConnectionsMonth'])
          : null,
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      communities: List<String>.from(map['communities'] ?? []),
      blockedUserIds: List<String>.from(map['blockedUserIds'] ?? []),
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
    String? country,
    String? city,
    DateTime? dateOfBirth,
    String? gender,
    String? bio,
    String? profilePicUrl,
    String? preferredContactMethod,
    String? contactDetails,
    bool? profileCompleted,
    bool? isVerified,
    DateTime? verifiedExpiry,
    String? verificationPhoto,
    bool? isPremium,
    DateTime? premiumExpiry,
    int? dailyConnections,
    DateTime? dailyConnectionsDate,
    int? monthlyConnections,
    DateTime? monthlyConnectionsMonth,
    int? followersCount,
    int? followingCount,
    List<String>? communities,
    List<String>? blockedUserIds,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id,
      username: username ?? this.username,
      email: email,
      country: country ?? this.country,
      city: city ?? this.city,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      preferredContactMethod:
          preferredContactMethod ?? this.preferredContactMethod,
      contactDetails: contactDetails ?? this.contactDetails,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      isVerified: isVerified ?? this.isVerified,
      verifiedExpiry: verifiedExpiry ?? this.verifiedExpiry,
      verificationPhoto: verificationPhoto ?? this.verificationPhoto,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiry: premiumExpiry ?? this.premiumExpiry,
      dailyConnections: dailyConnections ?? this.dailyConnections,
      dailyConnectionsDate: dailyConnectionsDate ?? this.dailyConnectionsDate,
      monthlyConnections: monthlyConnections ?? this.monthlyConnections,
      monthlyConnectionsMonth:
          monthlyConnectionsMonth ?? this.monthlyConnectionsMonth,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      communities: communities ?? this.communities,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
    );
  }
}
