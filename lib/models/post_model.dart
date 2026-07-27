class PostModel {
  final String id;
  final String userId;
  final String username;
  final String userProfilePic;
  final bool userIsVerified;
  final bool userIsOnline;
  final DateTime userLastSeen;
  final String userCountry;
  final String userCity;
  
  final String community;       // e.g. Coffee Date, Hook Up
  final String lookingFor;      // e.g. Coffee Date, Travel Partner
  final String location;        // e.g. Nairobi, Kenya
  final int ageRangeMin;        // e.g. 21
  final int ageRangeMax;        // e.g. 35
  final String availability;   // Today, Tonight, Weekend, Anytime
  final String description;    // Unlimited characters
  final String? postImageUrl;   // Optional attached picture

  final int crushCount;         // Replaces likes
  final int crushesCount;       // Replaces comments count
  final List<String> crushedUserIds; // User IDs who crushed this post
  final bool isBoosted;
  final DateTime? boostExpiresAt;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.userProfilePic,
    this.userIsVerified = false,
    this.userIsOnline = true,
    DateTime? userLastSeen,
    required this.userCountry,
    required this.userCity,
    required this.community,
    required this.lookingFor,
    required this.location,
    required this.ageRangeMin,
    required this.ageRangeMax,
    required this.availability,
    required this.description,
    this.postImageUrl,
    this.crushCount = 0,
    this.crushesCount = 0,
    this.crushedUserIds = const [],
    this.isBoosted = false,
    this.boostExpiresAt,
    DateTime? createdAt,
  })  : userLastSeen = userLastSeen ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  bool get currentlyBoosted {
    if (!isBoosted || boostExpiresAt == null) return false;
    return boostExpiresAt!.isAfter(DateTime.now());
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userProfilePic': userProfilePic,
      'userIsVerified': userIsVerified,
      'userIsOnline': userIsOnline,
      'userLastSeen': userLastSeen.toIso8601String(),
      'userCountry': userCountry,
      'userCity': userCity,
      'community': community,
      'lookingFor': lookingFor,
      'location': location,
      'ageRangeMin': ageRangeMin,
      'ageRangeMax': ageRangeMax,
      'availability': availability,
      'description': description,
      'postImageUrl': postImageUrl,
      'crushCount': crushCount,
      'crushesCount': crushesCount,
      'crushedUserIds': crushedUserIds,
      'isBoosted': isBoosted,
      'boostExpiresAt': boostExpiresAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    return PostModel(
      id: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      userProfilePic: map['userProfilePic'] ?? '',
      userIsVerified: map['userIsVerified'] ?? false,
      userIsOnline: map['userIsOnline'] ?? false,
      userLastSeen: map['userLastSeen'] != null
          ? DateTime.tryParse(map['userLastSeen']) ?? DateTime.now()
          : DateTime.now(),
      userCountry: map['userCountry'] ?? '',
      userCity: map['userCity'] ?? '',
      community: map['community'] ?? 'Casual Meet',
      lookingFor: map['lookingFor'] ?? 'Friendship',
      location: map['location'] ?? 'Nairobi, Kenya',
      ageRangeMin: map['ageRangeMin'] ?? 18,
      ageRangeMax: map['ageRangeMax'] ?? 99,
      availability: map['availability'] ?? 'Anytime',
      description: map['description'] ?? '',
      postImageUrl: map['postImageUrl'],
      crushCount: map['crushCount'] ?? 0,
      crushesCount: map['crushesCount'] ?? 0,
      crushedUserIds: List<String>.from(map['crushedUserIds'] ?? []),
      isBoosted: map['isBoosted'] ?? false,
      boostExpiresAt: map['boostExpiresAt'] != null
          ? DateTime.tryParse(map['boostExpiresAt'])
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  PostModel copyWith({
    int? crushCount,
    int? crushesCount,
    List<String>? crushedUserIds,
    bool? isBoosted,
    DateTime? boostExpiresAt,
    String? postImageUrl,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      username: username,
      userProfilePic: userProfilePic,
      userIsVerified: userIsVerified,
      userIsOnline: userIsOnline,
      userLastSeen: userLastSeen,
      userCountry: userCountry,
      userCity: userCity,
      community: community,
      lookingFor: lookingFor,
      location: location,
      ageRangeMin: ageRangeMin,
      ageRangeMax: ageRangeMax,
      availability: availability,
      description: description,
      postImageUrl: postImageUrl ?? this.postImageUrl,
      crushCount: crushCount ?? this.crushCount,
      crushesCount: crushesCount ?? this.crushesCount,
      crushedUserIds: crushedUserIds ?? this.crushedUserIds,
      isBoosted: isBoosted ?? this.isBoosted,
      boostExpiresAt: boostExpiresAt ?? this.boostExpiresAt,
      createdAt: createdAt,
    );
  }
}
