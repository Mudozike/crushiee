import 'package:cloud_firestore/cloud_firestore.dart';

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
  
  // Media fields
  final String mediaType;       // 'none', 'image', 'video'
  final String? mediaUrl;       // Firebase Storage permanent URL
  final String? thumbnailUrl;   // Optional video thumbnail URL

  // Backward compatibility alias for postImageUrl
  String? get postImageUrl => mediaUrl;

  final int crushCount;         // Replaces likes
  final int crushesCount;       // Replaces comments count
  final List<String> crushedUserIds; // User IDs who crushed this post
  final bool isBoosted;
  final DateTime? boostExpiresAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Helper to strictly validate that a media URL is a remote HTTP/HTTPS URL,
  /// preventing local cache file paths (e.g. /data/user/0/...) from being treated as media URLs.
  static bool isValidRemoteMediaUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// Robust helper to parse DateTime from Timestamp, ISO-8601 String, DateTime, or epoch milliseconds.
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

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
    String? mediaType,
    String? mediaUrl,
    String? postImageUrl,
    this.thumbnailUrl,
    this.crushCount = 0,
    this.crushesCount = 0,
    this.crushedUserIds = const [],
    this.isBoosted = false,
    this.boostExpiresAt,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? expiresAt,
  })  : userLastSeen = userLastSeen ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ?? (createdAt ?? DateTime.now()).add(const Duration(days: 30)),
        mediaUrl = isValidRemoteMediaUrl(mediaUrl ?? postImageUrl) ? (mediaUrl ?? postImageUrl) : null,
        mediaType = isValidRemoteMediaUrl(mediaUrl ?? postImageUrl)
            ? (mediaType != null && mediaType.isNotEmpty && mediaType != 'none' ? mediaType : 'image')
            : 'none';

  bool get currentlyBoosted {
    if (!isBoosted || boostExpiresAt == null) return false;
    return boostExpiresAt!.isAfter(DateTime.now());
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image';
  bool get hasMedia => isValidRemoteMediaUrl(mediaUrl) && mediaType != 'none';

  Map<String, dynamic> toMap() {
    final validMedia = isValidRemoteMediaUrl(mediaUrl) ? mediaUrl : null;
    final validMediaType = validMedia != null ? mediaType : 'none';
    final validThumbnail = isValidRemoteMediaUrl(thumbnailUrl) ? thumbnailUrl : null;

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
      'mediaType': validMediaType,
      'mediaUrl': validMedia,
      'postImageUrl': validMedia, // Keep for backward compatibility with existing Firestore queries
      'thumbnailUrl': validThumbnail,
      'crushCount': crushCount,
      'crushesCount': crushesCount,
      'crushedUserIds': crushedUserIds,
      'isBoosted': isBoosted,
      'boostExpiresAt': boostExpiresAt?.toIso8601String(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    final created = _parseDateTime(map['createdAt']) ?? DateTime.now();

    final rawMedia = map['mediaUrl'] ?? map['postImageUrl'];
    final resolvedMediaUrl = isValidRemoteMediaUrl(rawMedia is String ? rawMedia : null)
        ? (rawMedia as String)
        : null;
    final rawMediaType = map['mediaType'];
    final resolvedMediaType = resolvedMediaUrl != null
        ? (rawMediaType is String && rawMediaType.isNotEmpty && rawMediaType != 'none' ? rawMediaType : 'image')
        : 'none';

    final rawThumbnail = map['thumbnailUrl'];
    final resolvedThumbnail = isValidRemoteMediaUrl(rawThumbnail is String ? rawThumbnail : null)
        ? (rawThumbnail as String)
        : null;

    return PostModel(
      id: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      userProfilePic: map['userProfilePic'] ?? '',
      userIsVerified: map['userIsVerified'] ?? false,
      userIsOnline: map['userIsOnline'] ?? false,
      userLastSeen: _parseDateTime(map['userLastSeen']) ?? DateTime.now(),
      userCountry: map['userCountry'] ?? '',
      userCity: map['userCity'] ?? '',
      community: map['community'] ?? 'Casual Meet',
      lookingFor: map['lookingFor'] ?? 'Friendship',
      location: map['location'] ?? 'Nairobi, Kenya',
      ageRangeMin: (map['ageRangeMin'] as num?)?.toInt() ?? 18,
      ageRangeMax: (map['ageRangeMax'] as num?)?.toInt() ?? 99,
      availability: map['availability'] ?? 'Anytime',
      description: map['description'] ?? '',
      mediaType: resolvedMediaType,
      mediaUrl: resolvedMediaUrl,
      thumbnailUrl: resolvedThumbnail,
      crushCount: (map['crushCount'] as num?)?.toInt() ?? 0,
      crushesCount: (map['crushesCount'] as num?)?.toInt() ?? (map['commentCount'] as num?)?.toInt() ?? 0,
      crushedUserIds: List<String>.from(map['crushedUserIds'] ?? []),
      isBoosted: map['isBoosted'] ?? false,
      boostExpiresAt: _parseDateTime(map['boostExpiresAt']),
      isActive: map['isActive'] ?? true,
      createdAt: created,
      expiresAt: _parseDateTime(map['expiresAt']) ?? created.add(const Duration(days: 30)),
    );
  }

  PostModel copyWith({
    String? community,
    String? lookingFor,
    String? location,
    int? ageRangeMin,
    int? ageRangeMax,
    String? availability,
    String? description,
    String? mediaType,
    String? mediaUrl,
    String? postImageUrl,
    String? thumbnailUrl,
    int? crushCount,
    int? crushesCount,
    List<String>? crushedUserIds,
    bool? isBoosted,
    DateTime? boostExpiresAt,
    bool? isActive,
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
      community: community ?? this.community,
      lookingFor: lookingFor ?? this.lookingFor,
      location: location ?? this.location,
      ageRangeMin: ageRangeMin ?? this.ageRangeMin,
      ageRangeMax: ageRangeMax ?? this.ageRangeMax,
      availability: availability ?? this.availability,
      description: description ?? this.description,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? postImageUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      crushCount: crushCount ?? this.crushCount,
      crushesCount: crushesCount ?? this.crushesCount,
      crushedUserIds: crushedUserIds ?? this.crushedUserIds,
      isBoosted: isBoosted ?? this.isBoosted,
      boostExpiresAt: boostExpiresAt ?? this.boostExpiresAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}
