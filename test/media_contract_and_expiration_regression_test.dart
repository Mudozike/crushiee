import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crushie/models/post_model.dart';

void main() {
  group('Task 1 & 2 — Media Contract & Local Path Prevention Tests', () {
    test('isValidRemoteMediaUrl strictly rejects local filesystem and cache paths', () {
      // Android cache paths observed in live Firestore evidence
      expect(
        PostModel.isValidRemoteMediaUrl('/data/user/0/com.mudozi.crushie/cache/scaled_3202.jpg'),
        isFalse,
      );
      expect(
        PostModel.isValidRemoteMediaUrl('/data/user/0/com.mudozi.crushie/cache/scaled_15617.jpg'),
        isFalse,
      );
      expect(PostModel.isValidRemoteMediaUrl('file:///sdcard/Download/photo.jpg'), isFalse);
      expect(PostModel.isValidRemoteMediaUrl('/storage/emulated/0/DCIM/Camera/IMG_001.jpg'), isFalse);
      expect(PostModel.isValidRemoteMediaUrl(''), isFalse);
      expect(PostModel.isValidRemoteMediaUrl('   '), isFalse);
      expect(PostModel.isValidRemoteMediaUrl(null), isFalse);
    });

    test('isValidRemoteMediaUrl accepts valid remote HTTP and HTTPS URLs', () {
      expect(
        PostModel.isValidRemoteMediaUrl(
          'https://firebasestorage.googleapis.com/v0/b/chrushie-e5774.firebasestorage.app/o/posts%2Fuser123%2Fphoto_123.jpg?alt=media&token=abc',
        ),
        isTrue,
      );
      expect(
        PostModel.isValidRemoteMediaUrl('https://example.com/images/sample.png'),
        isTrue,
      );
      expect(
        PostModel.isValidRemoteMediaUrl('http://example.com/video.mp4'),
        isTrue,
      );
    });

    test('PostModel constructor sanitizes local path to null and mediaType to "none"', () {
      final postWithLocalPath = PostModel(
        id: 'post_101',
        userId: 'user_123',
        username: 'alice',
        userProfilePic: 'https://example.com/avatar.jpg',
        userCountry: 'Kenya',
        userCity: 'Nairobi',
        community: 'Casual Meet',
        lookingFor: 'Coffee Date',
        location: 'Westlands, Nairobi',
        ageRangeMin: 22,
        ageRangeMax: 30,
        availability: 'Today',
        description: 'Grabbing coffee in Westlands!',
        mediaUrl: '/data/user/0/com.mudozi.crushie/cache/scaled_3202.jpg',
        mediaType: 'image',
      );

      expect(postWithLocalPath.mediaUrl, isNull);
      expect(postWithLocalPath.postImageUrl, isNull);
      expect(postWithLocalPath.mediaType, equals('none'));
      expect(postWithLocalPath.hasMedia, isFalse);
    });

    test('toMap() never persists local paths or invalid media URLs', () {
      final post = PostModel(
        id: 'post_102',
        userId: 'user_123',
        username: 'alice',
        userProfilePic: 'https://example.com/avatar.jpg',
        userCountry: 'Kenya',
        userCity: 'Nairobi',
        community: 'Casual Meet',
        lookingFor: 'Coffee Date',
        location: 'Westlands',
        ageRangeMin: 20,
        ageRangeMax: 30,
        availability: 'Tonight',
        description: 'Meeting up',
        postImageUrl: '/data/user/0/com.mudozi.crushie/cache/scaled_15617.jpg',
      );

      final map = post.toMap();
      expect(map['mediaUrl'], isNull);
      expect(map['postImageUrl'], isNull);
      expect(map['mediaType'], equals('none'));
    });

    test('toMap() correctly serializes valid persistent remote media URLs', () {
      const validStorageUrl =
          'https://firebasestorage.googleapis.com/v0/b/chrushie-e5774.firebasestorage.app/o/posts%2Fuser_123%2Fphoto_123.jpg?alt=media';
      final post = PostModel(
        id: 'post_103',
        userId: 'user_123',
        username: 'alice',
        userProfilePic: 'https://example.com/avatar.jpg',
        userCountry: 'Kenya',
        userCity: 'Nairobi',
        community: 'Casual Meet',
        lookingFor: 'Coffee Date',
        location: 'Westlands',
        ageRangeMin: 20,
        ageRangeMax: 30,
        availability: 'Tonight',
        description: 'Meeting up',
        mediaUrl: validStorageUrl,
        mediaType: 'image',
      );

      final map = post.toMap();
      expect(map['mediaUrl'], equals(validStorageUrl));
      expect(map['postImageUrl'], equals(validStorageUrl));
      expect(map['mediaType'], equals('image'));
      expect(post.hasMedia, isTrue);
      expect(post.isImage, isTrue);
      expect(post.isVideo, isFalse);
    });

    test('Video posts preserve video mediaType and remote thumbnailUrl', () {
      const videoUrl = 'https://firebasestorage.googleapis.com/v0/b/chrushie-e5774.firebasestorage.app/o/posts%2Fuser_123%2Fvideo_123.mp4?alt=media';
      const thumbUrl = 'https://firebasestorage.googleapis.com/v0/b/chrushie-e5774.firebasestorage.app/o/posts%2Fuser_123%2Fthumb_123.jpg?alt=media';

      final post = PostModel(
        id: 'post_104',
        userId: 'user_123',
        username: 'bob',
        userProfilePic: 'https://example.com/avatar.jpg',
        userCountry: 'Kenya',
        userCity: 'Nairobi',
        community: 'Casual Meet',
        lookingFor: 'Activity Partner',
        location: 'CBD',
        ageRangeMin: 25,
        ageRangeMax: 35,
        availability: 'Weekend',
        description: 'Hiking this weekend',
        mediaUrl: videoUrl,
        mediaType: 'video',
        thumbnailUrl: thumbUrl,
      );

      expect(post.isVideo, isTrue);
      expect(post.isImage, isFalse);
      expect(post.hasMedia, isTrue);
      expect(post.thumbnailUrl, equals(thumbUrl));

      final map = post.toMap();
      expect(map['mediaType'], equals('video'));
      expect(map['mediaUrl'], equals(videoUrl));
      expect(map['thumbnailUrl'], equals(thumbUrl));

      final restored = PostModel.fromMap(map, 'post_104');
      expect(restored.isVideo, isTrue);
      expect(restored.mediaUrl, equals(videoUrl));
      expect(restored.thumbnailUrl, equals(thumbUrl));
    });

    test('fromMap() sanitizes existing Firestore documents containing local cache paths', () {
      final legacyDocMap = {
        'userId': 'user_live_01',
        'username': 'legacy_user',
        'userProfilePic': 'crushie_avatar_1',
        'userCountry': 'Kenya',
        'userCity': 'Nairobi',
        'community': 'Casual Meet',
        'lookingFor': 'Coffee Date',
        'location': 'Nairobi',
        'ageRangeMin': 21,
        'ageRangeMax': 35,
        'availability': 'Anytime',
        'description': 'Old post with local path',
        'postImageUrl': '/data/user/0/com.mudozi.crushie/cache/scaled_3202.jpg',
        'mediaUrl': '/data/user/0/com.mudozi.crushie/cache/scaled_3202.jpg',
        'mediaType': 'image',
        'createdAt': '2026-08-21T10:00:00.000',
        'expiresAt': '2026-09-20T10:00:00.000',
        'isActive': true,
      };

      final post = PostModel.fromMap(legacyDocMap, 'legacy_post_id');
      expect(post.mediaUrl, isNull);
      expect(post.postImageUrl, isNull);
      expect(post.mediaType, equals('none'));
      expect(post.hasMedia, isFalse);
    });
  });

  group('Task 3 — Serialization, Expiration & Disappearing Posts Diagnosis Tests', () {
    test('fromMap() handles both Firestore Timestamp and ISO-8601 String cleanly', () {
      final mapWithTimestamp = {
        'userId': 'user_timestamp',
        'username': 'time_user',
        'userProfilePic': 'crushie_avatar_2',
        'userCountry': 'Kenya',
        'userCity': 'Mombasa',
        'community': 'Casual Meet',
        'lookingFor': 'Travel Partner',
        'location': 'Mombasa',
        'ageRangeMin': 20,
        'ageRangeMax': 30,
        'availability': 'Weekend',
        'description': 'Timestamp test',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 12, 12, 0)),
        'expiresAt': Timestamp.fromDate(DateTime(2026, 11, 11, 12, 0)),
        'userLastSeen': Timestamp.fromDate(DateTime(2026, 10, 12, 12, 30)),
        'boostExpiresAt': Timestamp.fromDate(DateTime(2026, 10, 13, 12, 0)),
        'isActive': true,
      };

      final post = PostModel.fromMap(mapWithTimestamp, 'ts_doc_id');
      expect(post.createdAt.year, equals(2026));
      expect(post.createdAt.month, equals(10));
      expect(post.createdAt.day, equals(12));
      expect(post.expiresAt.month, equals(11));
      expect(post.boostExpiresAt?.day, equals(13));
    });

    test('August 21, 2026 posts with September 20 expiration are expired on October 12, 2026', () {
      final augPost = PostModel(
        id: 'aug_post_01',
        userId: 'user_aug',
        username: 'aug_user',
        userProfilePic: 'crushie_avatar_0',
        userCountry: 'Kenya',
        userCity: 'Nairobi',
        community: 'Casual Meet',
        lookingFor: 'Coffee Date',
        location: 'Nairobi',
        ageRangeMin: 21,
        ageRangeMax: 35,
        availability: 'Anytime',
        description: 'Post from August',
        createdAt: DateTime(2026, 8, 21, 10, 0),
        expiresAt: DateTime(2026, 9, 20, 10, 0),
        isActive: true,
      );

      // On current system date October 12, 2026:
      final currentDate = DateTime(2026, 10, 12, 21, 0);

      // The post is expired
      final isExpiredOnCurrentDate = currentDate.isAfter(augPost.expiresAt);
      expect(isExpiredOnCurrentDate, isTrue);

      // Feed query filter: expiresAt > currentDate
      final passesFeedQuery = augPost.expiresAt.isAfter(currentDate);
      expect(passesFeedQuery, isFalse);

      // String lexicographical comparison used in Firestore:
      final augExpiresAtIso = augPost.expiresAt.toIso8601String();
      final currentDateIso = currentDate.toIso8601String();
      expect(augExpiresAtIso.compareTo(currentDateIso) < 0, isTrue);
    });

    test('Newly created unexpired post remains eligible for feed query for 30 days', () {
      final now = DateTime(2026, 10, 12, 21, 0);
      final newPost = PostModel(
        id: 'new_post_today',
        userId: 'user_today',
        username: 'new_user',
        userProfilePic: 'crushie_avatar_3',
        userCountry: 'Kenya',
        userCity: 'Nairobi',
        community: 'Coffee Date',
        lookingFor: 'Coffee Date',
        location: 'Kilimani, Nairobi',
        ageRangeMin: 24,
        ageRangeMax: 32,
        availability: 'Tonight',
        description: 'Looking for coffee partner tonight!',
        createdAt: now,
      );

      // Preserves 30-day expiration policy
      expect(newPost.expiresAt.difference(newPost.createdAt).inDays, equals(30));
      expect(newPost.expiresAt, equals(now.add(const Duration(days: 30))));

      // Post is active and unexpired
      expect(newPost.isActive, isTrue);
      expect(newPost.isExpired, isFalse);

      // Passes feed query inequality filter (expiresAt > now)
      final passesFeedQuery = newPost.expiresAt.isAfter(now);
      expect(passesFeedQuery, isTrue);

      final newExpiresIso = newPost.expiresAt.toIso8601String();
      final nowIso = now.toIso8601String();
      expect(newExpiresIso.compareTo(nowIso) > 0, isTrue);
    });
  });
}
