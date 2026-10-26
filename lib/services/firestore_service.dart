import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/connection_model.dart';
import '../models/chat_message_model.dart';
import '../models/notification_model.dart';
import '../models/crush_comment_model.dart';
import '../models/transaction_model.dart';
import '../models/report_model.dart';

class PaginatedPostsResult {
  final List<PostModel> posts;
  final DocumentSnapshot? lastDocument;

  PaginatedPostsResult({
    required this.posts,
    this.lastDocument,
  });
}

class FeedSnapshotResult {
  final List<PostModel> posts;
  final DocumentSnapshot? lastDocument;

  FeedSnapshotResult({
    required this.posts,
    this.lastDocument,
  });
}

class _InFlightFollowOp {
  final bool isFollow;
  final Future<bool> future;
  _InFlightFollowOp(this.isFollow, this.future);
}

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService([FirebaseFirestore? firestore]) {
    if (firestore != null) {
      return FirestoreService._withFirestore(firestore);
    }
    return _instance;
  }
  FirestoreService._internal() : _customFirestore = null;
  FirestoreService._withFirestore(this._customFirestore);
  FirestoreService.forTesting([this._customFirestore]);

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  // --- USER PROFILE & PRIVATE SETTINGS ---

  /// Save public user profile to users/{userId} and private settings to users/{userId}/private/settings.
  /// Strictly distinguishes initial creation from profile updates to satisfy Firestore security rules.
  /// Ordinary profile updates send ONLY mutable fields and never overwrite or send protected entitlements or counters.
  Future<void> saveUserProfile(UserModel user) async {
    if (user.id.trim().isEmpty) {
      throw ArgumentError('User ID must not be empty when saving profile.');
    }
    try {
      final userRef = _firestore.collection('users').doc(user.id);
      final privateRef = userRef.collection('private').doc('settings');

      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        // Initial creation: baseline unprivileged schema satisfying hasNoPrivilegeEscalation
        final publicData = {
          'uid': user.id,
          'username': user.username,
          'displayName': user.username,
          'country': user.country,
          'city': user.city,
          'dateOfBirth': user.dateOfBirth.toIso8601String(),
          'gender': user.gender,
          'bio': user.bio,
          'profilePicUrl': user.profilePicUrl,
          'profileCompleted': true,
          'isVerified': false,
          'verifiedExpiry': null,
          'isPremium': false,
          'premiumExpiry': null,
          'followersCount': 0,
          'followingCount': 0,
          'communities': user.communities,
          'isOnline': user.isOnline,
          'lastSeen': user.lastSeen?.toIso8601String(),
          'createdAt': user.createdAt.toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final privateData = {
          'email': user.email,
          'preferredContactMethod': user.preferredContactMethod,
          'contactDetails': user.contactDetails,
          'dailyConnections': 0,
          'dailyConnectionsDate': null,
          'monthlyConnections': 0,
          'monthlyConnectionsMonth': null,
          'blockedUserIds': user.blockedUserIds,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final batch = _firestore.batch();
        batch.set(userRef, publicData);
        batch.set(privateRef, privateData);
        await batch.commit();
        debugPrint(
            '[FIRESTORE] Initial user profile & settings created for UID: ${user.id}');
      } else {
        // Profile update: write ONLY permitted mutable fields.
        // Protected fields (role, isVerified, verifiedExpiry, isPremium, premiumExpiry,
        // followersCount, followingCount, dailyConnections, monthlyConnections) are NEVER
        // included in ordinary profile update payloads.
        final publicUpdateData = {
          'username': user.username,
          'displayName': user.username,
          'country': user.country,
          'city': user.city,
          'dateOfBirth': user.dateOfBirth.toIso8601String(),
          'gender': user.gender,
          'bio': user.bio,
          'profilePicUrl': user.profilePicUrl,
          'profileCompleted': true,
          'communities': user.communities,
          'isOnline': user.isOnline,
          'lastSeen': user.lastSeen?.toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final privateUpdateData = {
          'email': user.email,
          'preferredContactMethod': user.preferredContactMethod,
          'contactDetails': user.contactDetails,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        // Update public profile first
        await userRef.set(publicUpdateData, SetOptions(merge: true));

        // Update private settings separately so errors can be precisely reported
        try {
          await privateRef.set(privateUpdateData, SetOptions(merge: true));
        } catch (pe) {
          debugPrint(
              '[FIRESTORE] Warning: private settings update failed: $pe');
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: pe is FirebaseException ? pe.code : 'permission-denied',
            message:
                'Failed to update private settings: ${pe is FirebaseException ? pe.message : pe}',
          );
        }
        debugPrint(
            '[FIRESTORE] User profile & private settings updated for UID: ${user.id}');
      }
    } catch (e) {
      debugPrint('[FIRESTORE] Error saving user profile: $e');
      rethrow;
    }
  }

  /// Get public user profile from users/{userId}
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      // Attempt to load private settings if current user is owner
      Map<String, dynamic> privateData = {};
      try {
        final privateDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('private')
            .doc('settings')
            .get();
        if (privateDoc.exists && privateDoc.data() != null) {
          privateData = Map<String, dynamic>.from(privateDoc.data()!);
          // Defense-in-depth: Never allow private settings to overwrite server-managed entitlements
          privateData.remove('role');
          privateData.remove('isPremium');
          privateData.remove('premiumExpiry');
          privateData.remove('isVerified');
          privateData.remove('verifiedExpiry');
          privateData.remove('followersCount');
          privateData.remove('followingCount');
        }
      } catch (_) {
        // Private document read restricted for non-owners
      }

      final combinedMap = {...data, ...privateData};
      return UserModel.fromMap(combinedMap, userId);
    } catch (e) {
      debugPrint('[FIRESTORE] Error fetching user profile for UID $userId: $e');
      return null;
    }
  }

  /// Stream of a user's profile document
  Stream<UserModel?> getUserProfileStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value(null);
    try {
      return _firestore.collection('users').doc(userId).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        try {
          return UserModel.fromMap(doc.data()!, doc.id);
        } catch (e) {
          debugPrint('[FIRESTORE] Error parsing user profile $userId in stream: $e');
          return null;
        }
      }).handleError((e) {
        debugPrint('[FIRESTORE] Error in getUserProfileStream for $userId: $e');
        return null;
      });
    } catch (e) {
      debugPrint('[FIRESTORE] Error initializing getUserProfileStream for $userId: $e');
      return Stream.value(null);
    }
  }

  /// Convenience alias for getUserProfileStream
  Stream<UserModel?> getUserStream(String userId) => getUserProfileStream(userId);

  static String? _clientDeviceId;

  /// Unique client session identifier for this device
  static String get clientDeviceId {
    _clientDeviceId ??=
        'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
    return _clientDeviceId!;
  }

  /// Override client device ID (useful for multi-device simulation in tests)
  @visibleForTesting
  static void setClientDeviceIdForTesting(String? id) {
    _clientDeviceId = id;
  }

  /// Update online presence and lastSeen for user with multi-device session support.
  /// If one device disconnects, the user remains online if another active device session exists.
  Future<void> updateUserPresence(
    String userId, {
    required bool isOnline,
    String? deviceId,
  }) async {
    if (userId.trim().isEmpty) return;
    final devId = deviceId ?? clientDeviceId;
    final now = DateTime.now();
    final userRef = _firestore.collection('users').doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) {
          final initialSessions =
              isOnline ? <String, dynamic>{devId: now.toIso8601String()} : <String, dynamic>{};
          transaction.set(
            userRef,
            {
              'isOnline': isOnline,
              'lastSeen': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
              'activeSessions': initialSessions,
            },
            SetOptions(merge: true),
          );
          return;
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        final rawSessions = data['activeSessions'];
        final Map<String, dynamic> activeSessions =
            rawSessions is Map ? Map<String, dynamic>.from(rawSessions) : {};

        // Prune stale sessions (> 4 minutes without heartbeat)
        activeSessions.removeWhere((key, val) {
          if (key == devId) return false;
          if (val == null) return true;
          final dt = DateTime.tryParse(val.toString());
          if (dt == null) return true;
          return now.difference(dt).inMinutes >= 4;
        });

        bool effectiveOnline;
        if (isOnline) {
          activeSessions[devId] = now.toIso8601String();
          effectiveOnline = true;
        } else {
          activeSessions.remove(devId);
          effectiveOnline = activeSessions.isNotEmpty;
        }

        final updateData = <String, dynamic>{
          'isOnline': effectiveOnline,
          'lastSeen': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'activeSessions': activeSessions,
        };

        if (!effectiveOnline) {
          updateData['typingInConnectionId'] = null;
          updateData['typingUpdatedAt'] = null;
        }

        transaction.update(userRef, updateData);
      });
      debugPrint(
          '[FIRESTORE] Presence updated for $userId (device: $devId): isOnline=$isOnline');
    } catch (e) {
      debugPrint('[FIRESTORE] Error updating presence transaction for $userId: $e');
      try {
        await userRef.set({
          'isOnline': isOnline,
          'lastSeen': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        }, SetOptions(merge: true));
      } catch (fallbackErr) {
        debugPrint('[FIRESTORE] Fallback presence update failed: $fallbackErr');
      }
    }
  }

  /// Update typing indicator for user in a connection
  Future<void> setUserTyping(String userId, String? connectionId) async {
    if (userId.trim().isEmpty) return;
    try {
      final now = DateTime.now();
      await _firestore.collection('users').doc(userId).set({
        'typingInConnectionId': connectionId,
        'typingUpdatedAt': connectionId != null ? now.toIso8601String() : null,
      }, SetOptions(merge: true));
      debugPrint('[FIRESTORE] Typing updated for $userId in $connectionId');
    } catch (e) {
      debugPrint('[FIRESTORE] Error updating typing for $userId: $e');
    }
  }

  // --- POSTS & CURSOR-BASED PAGINATION ---

  Future<PaginatedPostsResult> getPostsPaginated({
    String? community,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    Query query = _firestore.collection('posts');

    // Filter active and non-expired posts
    query = query
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: DateTime.now().toIso8601String());

    if (community != null && community.isNotEmpty && community != 'All') {
      query = query.where('community', isEqualTo: community);
    }

    query = query.orderBy('expiresAt').orderBy('createdAt', descending: true);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    query = query.limit(limit);

    final snapshot = await query.get();

    final posts = snapshot.docs
        .map((doc) =>
            PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((p) => !p.isExpired)
        .toList();

    posts.sort((a, b) {
      if (a.currentlyBoosted && !b.currentlyBoosted) return -1;
      if (!a.currentlyBoosted && b.currentlyBoosted) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    final newLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    debugPrint(
        '[FIRESTORE] Fetched ${posts.length} paginated posts (community: ${community ?? 'All'})');
    return PaginatedPostsResult(posts: posts, lastDocument: newLastDoc);
  }

  /// Stream real-time feed updates with cursor tracking
  Stream<FeedSnapshotResult> getFeedSnapshotStream({
    String? community,
    int limit = 20,
  }) {
    try {
      Query query = _firestore.collection('posts');

      // Filter active and non-expired posts
      query = query
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: DateTime.now().toIso8601String());

      if (community != null && community.isNotEmpty && community != 'All') {
        query = query.where('community', isEqualTo: community);
      }

      query = query
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      return query.snapshots().map((snapshot) {
        final posts = snapshot.docs
            .map((doc) =>
                PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((p) => !p.isExpired)
            .toList();

        posts.sort((a, b) {
          if (a.currentlyBoosted && !b.currentlyBoosted) return -1;
          if (!a.currentlyBoosted && b.currentlyBoosted) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        return FeedSnapshotResult(posts: posts, lastDocument: lastDoc);
      });
    } catch (e) {
      debugPrint('[FIRESTORE] Error getting feed snapshot stream: $e');
      return Stream.error(e);
    }
  }

  /// Convenience stream for real-time posts list
  Stream<List<PostModel>> getFeedPostsStream({
    String? community,
    int limit = 20,
  }) {
    return getFeedSnapshotStream(community: community, limit: limit)
        .map((r) => r.posts);
  }

  /// Real-time stream for an individual post document
  Stream<PostModel?> getPostStream(String postId) {
    try {
      return _firestore
          .collection('posts')
          .doc(postId)
          .snapshots()
          .map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      });
    } catch (e) {
      debugPrint('[FIRESTORE] Error getting post stream for $postId: $e');
      return Stream.error(e);
    }
  }

  /// Fetch a single post document one-time
  Future<PostModel?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (!doc.exists || doc.data() == null) return null;
      return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      debugPrint('[FIRESTORE] Error getting post $postId: $e');
      return null;
    }
  }

  /// Create new post in posts/{postId}
  Future<bool> createPost(PostModel post) async {
    try {
      await _firestore.collection('posts').doc(post.id).set(post.toMap());
      debugPrint('[FIRESTORE] Post created with ID: ${post.id}');

      // Opt-in location notification trigger (e.g. Juja)
      if (post.location.trim().isNotEmpty) {
        notifyLocationSubscribers(post).catchError((e) {
          debugPrint('[FIRESTORE] Location notification error: $e');
        });
      }

      return true;
    } catch (e) {
      debugPrint('[FIRESTORE] Error creating post: $e');
      rethrow;
    }
  }

  /// Update existing post document in posts/{postId}
  Future<void> updatePost(PostModel post) async {
    try {
      await _firestore.collection('posts').doc(post.id).update(post.toMap());
      debugPrint('[FIRESTORE] Post updated with ID: ${post.id}');
    } catch (e) {
      debugPrint('[FIRESTORE] Error updating post: $e');
      rethrow;
    }
  }

  /// Delete post document from posts/{postId}
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      debugPrint('[FIRESTORE] Post deleted with ID: $postId');
    } catch (e) {
      debugPrint('[FIRESTORE] Error deleting post: $e');
      rethrow;
    }
  }

  // --- LIKES / CRUSHES ON POSTS ---

  /// Toggle post crush/like using scalable likes/{userId} sub-collection
  Future<bool> togglePostCrush({
    required String postId,
    required String userId,
    String? username,
    String? userProfilePic,
    String? postAuthorId,
  }) async {
    try {
      final likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId);

      final doc = await likeRef.get();
      final postRef = _firestore.collection('posts').doc(postId);

      if (doc.exists) {
        // Unlike
        final batch = _firestore.batch();
        batch.delete(likeRef);
        batch.update(postRef, {
          'crushCount': FieldValue.increment(-1),
          'crushedUserIds': FieldValue.arrayRemove([userId]),
        });
        await batch.commit();
        debugPrint('[FIRESTORE] Unliked post: $postId by $userId');
        return false;
      } else {
        // Like
        final batch = _firestore.batch();
        batch.set(likeRef, {
          'userId': userId,
          'username': username ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(postRef, {
          'crushCount': FieldValue.increment(1),
          'crushedUserIds': FieldValue.arrayUnion([userId]),
        });
        await batch.commit();
        debugPrint('[FIRESTORE] Liked post: $postId by $userId');

        // Notify post author (if not self and postAuthorId is provided)
        if (postAuthorId != null && postAuthorId != userId) {
          final notif = NotificationModel(
            id: 'notif_crush_${postId}_$userId',
            userId: postAuthorId,
            fromUserId: userId,
            fromUsername: username ?? 'Someone',
            fromUserProfilePic: userProfilePic ?? 'crushie_avatar_0',
            type: NotificationType.crush,
            title: 'New Crush!',
            body: '${username ?? "Someone"} crushed your post',
            postId: postId,
          );
          createNotification(notif);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[FIRESTORE] Error toggling post crush: $e');
      rethrow;
    }
  }

  // --- COMMENTS ON POSTS ---

  /// Add comment to posts/{postId}/comments/{commentId} and increment comment count
  Future<void> addCrushComment(CrushCommentModel comment,
      {String? postAuthorId}) async {
    try {
      final commentRef = _firestore
          .collection('posts')
          .doc(comment.postId)
          .collection('comments')
          .doc(comment.id);

      final postRef = _firestore.collection('posts').doc(comment.postId);

      final batch = _firestore.batch();
      batch.set(commentRef, comment.toMap());
      batch.update(postRef, {'crushesCount': FieldValue.increment(1)});

      await batch.commit();
      debugPrint('[FIRESTORE] Comment added to post: ${comment.postId}');

      // Notify post author (if not self)
      if (postAuthorId != null && postAuthorId != comment.userId) {
        final notif = NotificationModel(
          id: 'notif_comment_${comment.id}',
          userId: postAuthorId,
          fromUserId: comment.userId,
          fromUsername: comment.username,
          fromUserProfilePic: comment.userProfilePic,
          type: NotificationType.crushComment,
          title: 'New Comment!',
          body: '${comment.username} commented on your post',
          postId: comment.postId,
          commentId: comment.id,
        );
        createNotification(notif);
      }
    } catch (e) {
      debugPrint('[FIRESTORE] Error adding comment: $e');
      rethrow;
    }
  }

  /// Update comment text in posts/{postId}/comments/{commentId}
  Future<void> updateCrushComment({
    required String postId,
    required String commentId,
    required String newText,
  }) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .update({
        'text': newText,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('[FIRESTORE] Comment updated: $commentId');
    } catch (e) {
      debugPrint('[FIRESTORE] Error updating comment: $e');
      rethrow;
    }
  }

  /// Delete comment from posts/{postId}/comments/{commentId} and decrement count
  Future<void> deleteCrushComment({
    required String postId,
    required String commentId,
  }) async {
    try {
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      final postRef = _firestore.collection('posts').doc(postId);

      final batch = _firestore.batch();
      batch.delete(commentRef);
      batch.update(postRef, {'crushesCount': FieldValue.increment(-1)});

      await batch.commit();
      debugPrint('[FIRESTORE] Comment deleted: $commentId');
    } catch (e) {
      debugPrint('[FIRESTORE] Error deleting comment: $e');
      rethrow;
    }
  }

  /// Stream comments for post from posts/{postId}/comments
  Stream<List<CrushCommentModel>> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CrushCommentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // --- FOLLOWING / FOLLOWERS ---

  /// Toggle follow state between currentUser and targetUser
  Future<bool> toggleFollow({
    required String currentUserId,
    required String targetUserId,
    String? currentUsername,
    String? currentUserProfilePic,
    String? targetUsername,
  }) async {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return false;
    }

    final followRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('follows')
        .doc(targetUserId);

    final doc = await followRef.get();
    if (doc.exists) {
      return unfollowUser(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      );
    } else {
      return followUser(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        currentUsername: currentUsername,
        currentUserProfilePic: currentUserProfilePic,
        targetUsername: targetUsername,
      );
    }
  }

  final Map<String, _InFlightFollowOp> _inFlightFollowOps = {};

  /// Idempotently follow a target user. If already followed, does nothing.
  /// Concurrency-guarded to prevent concurrent duplicate writes from triggering permission errors.
  Future<bool> followUser({
    required String currentUserId,
    required String targetUserId,
    String? currentUsername,
    String? currentUserProfilePic,
    String? targetUsername,
  }) async {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return false;
    }

    final opKey = '$currentUserId:$targetUserId';
    final existing = _inFlightFollowOps[opKey];
    if (existing != null) {
      if (existing.isFollow) {
        return existing.future;
      }
      try {
        await existing.future;
      } catch (_) {}
    }

    late final Future<bool> opFuture;
    opFuture = _executeFollowUser(
      currentUserId: currentUserId,
      targetUserId: targetUserId,
      currentUsername: currentUsername,
      currentUserProfilePic: currentUserProfilePic,
      targetUsername: targetUsername,
    );

    _inFlightFollowOps[opKey] = _InFlightFollowOp(true, opFuture);
    try {
      return await opFuture;
    } finally {
      if (identical(_inFlightFollowOps[opKey]?.future, opFuture)) {
        _inFlightFollowOps.remove(opKey);
      }
    }
  }

  Future<bool> _executeFollowUser({
    required String currentUserId,
    required String targetUserId,
    String? currentUsername,
    String? currentUserProfilePic,
    String? targetUsername,
  }) async {
    try {
      final followRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('follows')
          .doc(targetUserId);

      final doc = await followRef.get();
      if (doc.exists) {
        return true; // Already following, idempotent no-op
      }

      await followRef.set({
        'targetId': targetUserId,
        'targetUsername': targetUsername ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FIRESTORE] Followed: $targetUserId by $currentUserId');

      // Notification for target user
      final notif = NotificationModel(
        id: 'notif_follow_${currentUserId}_$targetUserId',
        userId: targetUserId,
        fromUserId: currentUserId,
        fromUsername: currentUsername ?? 'Someone',
        fromUserProfilePic: currentUserProfilePic ?? 'crushie_avatar_0',
        type: NotificationType.follow,
        title: 'New Follower!',
        body: '${currentUsername ?? "Someone"} followed you',
      );
      createNotification(notif).catchError((_) {});
      return true;
    } catch (e) {
      debugPrint('[FIRESTORE] Error in followUser: $e');
      rethrow;
    }
  }

  /// Idempotently unfollow a target user. If relationship is absent, does nothing.
  /// Concurrency-guarded to prevent race conditions during rapid toggles.
  Future<bool> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return false;
    }

    final opKey = '$currentUserId:$targetUserId';
    final existing = _inFlightFollowOps[opKey];
    if (existing != null) {
      if (!existing.isFollow) {
        return existing.future;
      }
      try {
        await existing.future;
      } catch (_) {}
    }

    late final Future<bool> opFuture;
    opFuture = _executeUnfollowUser(
      currentUserId: currentUserId,
      targetUserId: targetUserId,
    );

    _inFlightFollowOps[opKey] = _InFlightFollowOp(false, opFuture);
    try {
      return await opFuture;
    } finally {
      if (identical(_inFlightFollowOps[opKey]?.future, opFuture)) {
        _inFlightFollowOps.remove(opKey);
      }
    }
  }

  Future<bool> _executeUnfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      final followRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('follows')
          .doc(targetUserId);

      final doc = await followRef.get();
      if (!doc.exists) {
        return false; // Absent relationship, idempotent no-op
      }

      await followRef.delete();
      debugPrint('[FIRESTORE] Unfollowed: $targetUserId by $currentUserId');
      return false;
    } catch (e) {
      debugPrint('[FIRESTORE] Error in unfollowUser: $e');
      rethrow;
    }
  }

  /// Returns the derived number of followers for a user using a Firestore count aggregation.
  /// Returns null if the aggregation query fails (e.g. network/offline error).
  Future<int?> getFollowersCount(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final aggregateQuery = _firestore
          .collectionGroup('follows')
          .where('targetId', isEqualTo: userId)
          .count();
      final snapshot = await aggregateQuery.get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('[FIRESTORE] Error fetching followers count for $userId: $e');
      return null;
    }
  }

  /// Returns the derived number of users followed by userId using a Firestore count aggregation.
  /// Returns null if the aggregation query fails (e.g. network/offline error).
  Future<int?> getFollowingCount(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final aggregateQuery = _firestore
          .collection('users')
          .doc(userId)
          .collection('follows')
          .count();
      final snapshot = await aggregateQuery.get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('[FIRESTORE] Error fetching following count for $userId: $e');
      return null;
    }
  }

  /// Stream of all target user IDs followed by userId
  Stream<Set<String>> getFollowingUserIdsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('follows')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  // --- NOTIFICATIONS API ---

  /// Create notification document in users/{userId}/notifications/{notificationId}
  /// Validates recipient, prevents self-notifications for social interactions,
  /// and merges deterministically to prevent duplicate entries.
  Future<void> createNotification(NotificationModel notification) async {
    try {
      if (notification.userId.isEmpty) return;

      // Prevent self-notifications for social interactions
      final isSelf = notification.userId == notification.fromUserId;
      final isAccountOrSystemEvent = notification.type == NotificationType.system ||
          notification.type == NotificationType.premium ||
          notification.type == NotificationType.verification ||
          notification.type == NotificationType.account ||
          notification.type == NotificationType.boost;

      if (isSelf && !isAccountOrSystemEvent) {
        debugPrint(
            '[FIRESTORE] Suppressed self-notification for actor: ${notification.fromUserId}');
        return;
      }

      await _firestore
          .collection('users')
          .doc(notification.userId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap(), SetOptions(merge: true));
      debugPrint(
          '[FIRESTORE] Notification created for UID: ${notification.userId} (type: ${notification.type.name}, id: ${notification.id})');
    } catch (e) {
      debugPrint('[FIRESTORE] Error creating notification: $e');
    }
  }

  /// Real-time notifications stream for users/{userId}/notifications
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Mark single notification as read
  Future<void> markNotificationAsRead(
      String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('[FIRESTORE] Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for user
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FIRESTORE] Error marking all notifications as read: $e');
    }
  }

  /// Delete a single notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('[FIRESTORE] Error deleting notification $notificationId: $e');
    }
  }

  /// Automatically mark message notifications as read when connection conversation is opened
  Future<void> markMessageNotificationsAsRead(
      String userId, String connectionId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('connectionId', isEqualTo: connectionId)
          .where('type', isEqualTo: NotificationType.message.name)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[FIRESTORE] Error marking message notifications as read: $e');
    }
  }

  /// Notify users who have explicitly opted into notifications for the post's location.
  Future<void> notifyLocationSubscribers(PostModel post) async {
    if (post.location.trim().isEmpty) return;
    final normalizedLoc = post.location.trim();

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('locationNotificationSubscriptions', arrayContains: normalizedLoc)
          .get();

      for (final doc in snapshot.docs) {
        final subscriberId = doc.id;
        // Suppress notifying author
        if (subscriberId == post.userId) continue;

        final notif = NotificationModel(
          id: 'notif_loc_${post.id}_$subscriberId',
          userId: subscriberId,
          fromUserId: post.userId,
          fromUsername: post.username,
          fromUserProfilePic: post.userProfilePic,
          type: NotificationType.locationPost,
          title: 'New Post in $normalizedLoc',
          body: post.description.isNotEmpty
              ? (post.description.length > 80
                  ? '${post.description.substring(0, 80)}...'
                  : post.description)
              : '@${post.username} shared a new post in $normalizedLoc',
          postId: post.id,
        );
        await createNotification(notif);
      }
    } catch (e) {
      debugPrint(
          '[FIRESTORE] Error notifying location subscribers for $normalizedLoc: $e');
    }
  }

  /// Authenticated direct message reply handler
  /// Reuses existing sendChatMessage transaction and messaging security
  Future<void> sendNotificationReply({
    required String connectionId,
    required String recipientId,
    required String senderId,
    required String senderUsername,
    required String senderProfilePic,
    required String content,
  }) async {
    if (content.trim().isEmpty) return;
    final replyMsg = ChatMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      connectionId: connectionId,
      senderId: senderId,
      receiverId: recipientId,
      content: content.trim(),
      createdAt: DateTime.now(),
      deliveryStatus: MessageDeliveryStatus.sent,
    );
    await sendChatMessage(replyMsg);
  }

  // --- CONNECTIONS & MESSAGES ---

  /// Get connection by ID from connections/{connectionId}
  Future<ConnectionModel?> getConnection(String connectionId) async {
    try {
      final doc =
          await _firestore.collection('connections').doc(connectionId).get();
      if (doc.exists && doc.data() != null) {
        return ConnectionModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('[FIRESTORE] Error getting connection $connectionId: $e');
      return null;
    }
  }

  /// Finds existing connection between two users.
  ///
  /// Resolution order:
  ///   1. Canonical document ID  `conn_{sorted[0]}_{sorted[1]}`
  ///   2. Query by `participants` array containing uid1 (may miss legacy docs)
  ///   3. Legacy fallback: query by senderId/receiverId fields in both
  ///      orientations so documents that pre-date the `participants` field are
  ///      found.
  ///
  /// When step 3 returns multiple candidate documents the most recently
  /// updated one is returned and the ambiguity is logged as a diagnosable
  /// warning — documents are NOT merged or rewritten.
  Future<ConnectionModel?> findExistingConnection(
      String uid1, String uid2) async {
    try {
      if (uid1.trim().isEmpty ||
          uid2.trim().isEmpty ||
          uid1.trim() == uid2.trim()) {
        return null;
      }
      // 1. Check canonical ID first
      final canonicalId = ConnectionModel.getConversationId(uid1, uid2);
      final canonicalDoc =
          await _firestore.collection('connections').doc(canonicalId).get();
      if (canonicalDoc.exists && canonicalDoc.data() != null) {
        return ConnectionModel.fromMap(canonicalDoc.data()!, canonicalDoc.id);
      }
      // 2. Check for connections where participants array contains uid1
      final snapshot = await _firestore
          .collection('connections')
          .where('participants', arrayContains: uid1)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        if (participants.contains(uid2)) {
          return ConnectionModel.fromMap(data, doc.id);
        }
      }
      // 3. Legacy fallback: documents that lack the `participants` field but
      //    carry senderId + receiverId/recipientId in direct and reverse order.
      //    Bounded by sender match so we do not download the full collection.
      final List<ConnectionModel> candidates = [];
      for (final pair in [
        [uid1, uid2],
        [uid2, uid1],
      ]) {
        final sender = pair[0];
        final receiver = pair[1];
        // 3a. senderId + receiverId
        try {
          final byReceiverId = await _firestore
              .collection('connections')
              .where('senderId', isEqualTo: sender)
              .where('receiverId', isEqualTo: receiver)
              .get();
          for (final doc in byReceiverId.docs) {
            candidates.add(ConnectionModel.fromMap(doc.data(), doc.id));
          }
        } catch (e) {
          debugPrint('[FIRESTORE] Legacy lookup (receiverId) error: $e');
        }
        // 3b. senderId + recipientId (alternate field name)
        try {
          final byRecipientId = await _firestore
              .collection('connections')
              .where('senderId', isEqualTo: sender)
              .where('recipientId', isEqualTo: receiver)
              .get();
          for (final doc in byRecipientId.docs) {
            if (!candidates.any((c) => c.id == doc.id)) {
              candidates.add(ConnectionModel.fromMap(doc.data(), doc.id));
            }
          }
        } catch (e) {
          debugPrint('[FIRESTORE] Legacy lookup (recipientId) error: $e');
        }
      }

      if (candidates.isEmpty) return null;

      if (candidates.length > 1) {
        // Multiple legacy documents for the same participant pair.
        // Return the most recently updated one; do NOT merge or rewrite.
        debugPrint(
            '[FIRESTORE] WARNING: ${candidates.length} candidate connections found '
            'for participants $uid1 / $uid2. IDs: '
            '${candidates.map((c) => c.id).join(', ')}. '
            'Using most recently updated. Manual investigation recommended.');
        candidates.sort((a, b) {
          final tA = a.lastMessageTimestamp ?? a.updatedAt;
          final tB = b.lastMessageTimestamp ?? b.updatedAt;
          return tB.compareTo(tA);
        });
      }
      return candidates.first;
    } catch (e) {
      debugPrint('[FIRESTORE] Error finding existing connection: $e');
      return null;
    }
  }


  /// Save or update a connection document in connections/{connectionId}
  Future<void> saveConnection(ConnectionModel connection) async {
    try {
      final data = connection.toMap();
      data['participants'] = [connection.senderId, connection.receiverId];
      await _firestore.collection('connections').doc(connection.id).set(
            data,
            SetOptions(merge: true),
          );
      debugPrint('[FIRESTORE] Connection saved with ID: ${connection.id}');
    } catch (e) {
      debugPrint('[FIRESTORE] Error saving connection: $e');
      rethrow;
    }
  }

  /// Update connection status in connections/{connectionId}
  Future<void> updateConnectionStatus(
      String connectionId, ConnectionStatus status) async {
    try {
      await _firestore.collection('connections').doc(connectionId).update({
        'status': status.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      debugPrint(
          '[FIRESTORE] Connection $connectionId status updated to: ${status.name}');
    } catch (e) {
      debugPrint('[FIRESTORE] Error updating connection status: $e');
      rethrow;
    }
  }

  /// Real-time connections stream for connections where user is a participant
  Stream<List<ConnectionModel>> getUserConnectionsStream(String userId) {
    return _firestore
        .collection('connections')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ConnectionModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) {
        final timeA = a.lastMessageTimestamp ?? a.updatedAt;
        final timeB = b.lastMessageTimestamp ?? b.updatedAt;
        final cmp = timeB.compareTo(timeA);
        if (cmp != 0) return cmp;
        return b.id.compareTo(a.id);
      });
      return list;
    });
  }

  /// Real-time chat messages stream for connection
  Stream<List<ChatMessageModel>> getMessagesStream(String connectionId,
      {int limit = 100}) {
    return _firestore
        .collection('connections')
        .doc(connectionId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .transform(StreamTransformer<QuerySnapshot<Map<String, dynamic>>,
            QuerySnapshot<Map<String, dynamic>>>.fromHandlers(
          handleData: (snapshot, sink) {
            sink.add(snapshot);
          },
          handleError: (error, stackTrace, sink) {
            debugPrint(
                '[FIRESTORE] getMessagesStream error for connection $connectionId: $error\n$stackTrace');
            sink.addError(error, stackTrace);
          },
        ))
        .map((snapshot) {
          final List<ChatMessageModel> messages = [];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              messages.add(ChatMessageModel.fromMap(data, doc.id,
                  connectionIdFallback: connectionId));
            } catch (e) {
              debugPrint('[FIRESTORE] Error parsing message doc ${doc.id}: $e');
            }
          }
          // Sort chronologically ascending for display with stable tie-breaker
          messages.sort((a, b) {
            final cmp = a.timestamp.compareTo(b.timestamp);
            if (cmp != 0) return cmp;
            return a.id.compareTo(b.id);
          });
          return messages;
        });
  }

  /// Fetches a bounded page of older messages before [oldestMessage] using deterministic cursor pagination.
  /// Strictly requires a valid Firestore DocumentSnapshot cursor with the ordered 'timestamp' field.
  /// Does not attempt unsafe single-value fallbacks that skip or duplicate records on equal timestamps.
  Future<List<ChatMessageModel>> fetchOlderMessages({
    required String connectionId,
    required ChatMessageModel oldestMessage,
    int limit = 50,
  }) async {
    try {
      final docRef = _firestore
          .collection('connections')
          .doc(connectionId)
          .collection('messages')
          .doc(oldestMessage.id);

      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw StateError(
          '[FIRESTORE] Pagination cursor document not found for message ${oldestMessage.id}. '
          'Cannot construct a safe cursor without skipping or duplicating records.',
        );
      }

      final data = docSnap.data();
      if (data == null || data['timestamp'] == null) {
        throw StateError(
          '[FIRESTORE] Pagination cursor document ${oldestMessage.id} lacks ordered field "timestamp". '
          'Aborting pagination to prevent silent query failure or omitted records.',
        );
      }

      final Query<Map<String, dynamic>> query = _firestore
          .collection('connections')
          .doc(connectionId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(docSnap)
          .limit(limit);

      final snapshot = await query.get();
      final List<ChatMessageModel> messages = [];
      for (final doc in snapshot.docs) {
        try {
          messages.add(ChatMessageModel.fromMap(doc.data(), doc.id,
              connectionIdFallback: connectionId));
        } catch (e) {
          debugPrint('[FIRESTORE] Error parsing older message doc ${doc.id}: $e');
        }
      }

      // Sort chronologically ascending with stable deterministic tie-breaker
      messages.sort((a, b) {
        final cmp = a.timestamp.compareTo(b.timestamp);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });
      return messages;
    } catch (e) {
      debugPrint('[FIRESTORE] Error fetching older messages: $e');
      rethrow;
    }
  }

  /// Bounded fallback fetch for conversations where the primary ordered query
  /// (`orderBy('timestamp')`) returned empty results because legacy message
  /// documents lack the `'timestamp'` field.
  ///
  /// **Limitations / caller contract:**
  ///   - Returns at most [limit] documents (default 100) ordered by document ID,
  ///     NOT by true chronological send time.  Global ordering is NOT guaranteed.
  ///   - The caller is responsible for determining that the ordered query
  ///     returned 0 results for a connection known to have messages (e.g. the
  ///     connection document's `lastMessageText` is non-empty).
  ///   - This method does NOT suppress or override a real PERMISSION_DENIED
  ///     or network error; those propagate to the caller so they can be surfaced
  ///     to the user rather than mistaken for an empty conversation.
  ///   - Do NOT use this as the primary stream; use only as a one-time
  ///     diagnostic/recovery fetch.
  Future<List<ChatMessageModel>> fetchLatestMessagesUnordered({
    required String connectionId,
    int limit = 100,
  }) async {
    final snapshot = await _firestore
        .collection('connections')
        .doc(connectionId)
        .collection('messages')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .get();
    final List<ChatMessageModel> messages = [];
    for (final doc in snapshot.docs) {
      try {
        messages.add(ChatMessageModel.fromMap(doc.data(), doc.id,
            connectionIdFallback: connectionId));
      } catch (e) {
        debugPrint(
            '[FIRESTORE] fetchLatestMessagesUnordered parse error ${doc.id}: $e');
      }
    }
    // Sort client-side by whatever timestamp fields are available.
    messages.sort((a, b) {
      final cmp = a.timestamp.compareTo(b.timestamp);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
    return messages;
  }



  /// Send chat message to connections/{connectionId}/messages/{messageId}
  ///
  /// Phase 2A (F-01): Uses a Firestore transaction so that the unreadCounts
  /// increment is computed against the freshest server state, eliminating the
  /// client-side read-then-write race that could overwrite a concurrent
  /// markMessagesAsRead operation.
  Future<void> sendChatMessage(ChatMessageModel message) async {
    try {
      final msgRef = _firestore
          .collection('connections')
          .doc(message.connectionId)
          .collection('messages')
          .doc(message.id);

      final connRef =
          _firestore.collection('connections').doc(message.connectionId);

      final previewContent = message.content.isNotEmpty
          ? message.content
          : (message.mediaUrl != null && message.mediaUrl!.isNotEmpty
              ? '📷 Photo'
              : '');

      final recipientId = message.receiverId.isNotEmpty
          ? message.receiverId
          : message.recipientId;

      final messageData = message.toMap();
      messageData['serverTimestamp'] = FieldValue.serverTimestamp();

      // Phase 2A: run a transaction so the unreadCounts increment is applied
      // against the freshest server-side value, not a potentially stale
      // client-read snapshot.
      await _firestore.runTransaction((txn) async {
        // 1. Read current connection state inside the transaction.
        final connSnap = await txn.get(connRef);
        Map<String, dynamic> unreadCountsMap = {};
        List<dynamic> participants = [];
        if (connSnap.exists) {
          final connData = connSnap.data() ?? {};
          if (connData['unreadCounts'] is Map) {
            unreadCountsMap =
                Map<String, dynamic>.from(connData['unreadCounts']);
          }
          if (connData['participants'] is List) {
            participants = connData['participants'] as List<dynamic>;
          }
        }

        // 2. Compute new unreadCounts: increment recipient by 1, preserve sender.
        if (recipientId.isNotEmpty) {
          final currentRecipientCount = (unreadCountsMap[recipientId] is num)
              ? (unreadCountsMap[recipientId] as num).toInt()
              : 0;
          unreadCountsMap[recipientId] = currentRecipientCount + 1;
        }
        if (!unreadCountsMap.containsKey(message.senderId)) {
          unreadCountsMap[message.senderId] = 0;
        }
        // Restrict keys to known participants to satisfy security rules.
        if (participants.isNotEmpty) {
          unreadCountsMap.removeWhere((k, v) => !participants.contains(k));
        }

        // 3. Write message document.
        txn.set(msgRef, messageData);

        // 4. Merge connection metadata (last-message preview + unread counts).
        txn.set(
          connRef,
          {
            'lastMessageText': previewContent,
            'lastMessageTimestamp': message.createdAt.toUtc().toIso8601String(),
            'lastMessageSenderId': message.senderId,
            'updatedAt': message.createdAt.toUtc().toIso8601String(),
            if (recipientId.isNotEmpty) 'unreadCounts': unreadCountsMap,
          },
          SetOptions(merge: true),
        );
      });
      debugPrint(
          '[FIRESTORE] Chat message sent for connection: ${message.connectionId}');

      // Trigger deterministic in-app notification for message recipient
      if (recipientId.isNotEmpty && recipientId != message.senderId) {
        final notif = NotificationModel(
          id: 'notif_msg_${message.id}',
          userId: recipientId,
          fromUserId: message.senderId,
          fromUsername: 'Someone',
          fromUserProfilePic: '',
          type: NotificationType.message,
          title: 'New Message',
          body: previewContent.isNotEmpty
              ? previewContent
              : 'Sent an attachment',
          connectionId: message.connectionId,
        );
        createNotification(notif).catchError((e) {
          debugPrint('[FIRESTORE] Message notification error: $e');
        });
      }
    } catch (e) {
      debugPrint('[FIRESTORE] Error sending chat message: $e');
      rethrow;
    }
  }


  /// Mark incoming messages as read in connections/{connectionId}/messages
  Future<void> markMessagesAsRead(
      String connectionId, String currentUserId) async {
    try {
      // Query unread messages in this connection without requiring composite multi-field indexes
      final snapshot = await _firestore
          .collection('connections')
          .doc(connectionId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      int updatedMessagesCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final recipient = data['recipientId'] ?? data['receiverId'];
        // Update only messages strictly intended for current user as recipient
        // to strictly satisfy firestore.rules (line 303: receiverId == auth.uid || recipientId == auth.uid)
        if (recipient == currentUserId) {
          batch.update(doc.reference, {
            'isRead': true,
            'deliveryStatus': 'read',
          });
          updatedMessagesCount++;
        }
      }

      final connRef = _firestore.collection('connections').doc(connectionId);
      bool shouldUpdateConn = false;
      try {
        final connSnap = await connRef.get();
        if (connSnap.exists) {
          final connData = connSnap.data() ?? {};
          final dynamic existingUnreads = connData['unreadCounts'];
          final List participants = (connData['participants'] is List)
              ? connData['participants'] as List
              : [];
          if (existingUnreads is Map) {
            final currentCount = existingUnreads[currentUserId];
            if (currentCount != 0 || updatedMessagesCount > 0) {
              final Map<String, dynamic> updatedMap =
                  Map<String, dynamic>.from(existingUnreads);
              updatedMap[currentUserId] = 0;
              // Clean keys to ensure they only contain participants according to rules
              if (participants.isNotEmpty) {
                updatedMap.removeWhere((k, v) => !participants.contains(k));
              }
              batch.update(connRef, {
                'unreadCounts': updatedMap,
              });
              shouldUpdateConn = true;
            }
          } else {
            final Map<String, dynamic> initialMap = {currentUserId: 0};
            for (final p in participants) {
              if (p is String && p != currentUserId) {
                initialMap[p] = 0;
              }
            }
            batch.set(
              connRef,
              {
                'unreadCounts': initialMap,
              },
              SetOptions(merge: true),
            );
            shouldUpdateConn = true;
          }
        }
      } catch (e) {
        debugPrint(
            '[FIRESTORE] Warning reading connection during markAsRead: $e');
      }

      if (updatedMessagesCount > 0 || shouldUpdateConn) {
        await batch.commit();
        debugPrint(
            '[FIRESTORE] Marked $updatedMessagesCount messages as read in connection: $connectionId');
      }
    } catch (e, stack) {
      debugPrint('[FIRESTORE] Error marking messages as read in $connectionId: $e\n$stack');
      rethrow;
    }
  }

  /// Delete message for me
  Future<void> deleteMessageForMe(
      String connectionId, String messageId, String userId) async {
    try {
      await _firestore
          .collection('connections')
          .doc(connectionId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedForUserIds': FieldValue.arrayUnion([userId]),
      });
      debugPrint('[FIRESTORE] Message deleted for user: $userId');
    } catch (e) {
      debugPrint('[FIRESTORE] Error deleting message for me: $e');
      rethrow;
    }
  }

  /// Delete message for everyone
  Future<void> deleteMessageForEveryone(
      String connectionId, String messageId) async {
    try {
      await _firestore
          .collection('connections')
          .doc(connectionId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeletedForEveryone': true,
        'content': 'This message was deleted',
        'message': 'This message was deleted',
        'mediaUrl': null,
      });
      debugPrint('[FIRESTORE] Message deleted for everyone: $messageId');
    } catch (e) {
      debugPrint('[FIRESTORE] Error deleting message for everyone: $e');
      rethrow;
    }
  }

  // --- BLOCKING & SAFETY ---

  /// Block a user in users/{currentUserId}/blocks/{targetUserId}
  Future<void> blockUser({
    required String currentUserId,
    required String targetUserId,
    String? targetUsername,
  }) async {
    if (currentUserId == targetUserId) return;

    try {
      final blockRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocks')
          .doc(targetUserId);

      final settingsRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('private')
          .doc('settings');

      final batch = _firestore.batch();
      batch.set(blockRef, {
        'blockerId': currentUserId,
        'targetId': targetUserId,
        'targetUsername': targetUsername ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(
          settingsRef,
          {
            'blockedUserIds': FieldValue.arrayUnion([targetUserId]),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true));

      await batch.commit();
      debugPrint('[FIRESTORE] Blocked user: $targetUserId by $currentUserId');
    } catch (e) {
      debugPrint('[FIRESTORE] Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblock a user in users/{currentUserId}/blocks/{targetUserId}
  Future<void> unblockUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      final blockRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocks')
          .doc(targetUserId);

      final settingsRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('private')
          .doc('settings');

      final batch = _firestore.batch();
      batch.delete(blockRef);
      batch.set(
          settingsRef,
          {
            'blockedUserIds': FieldValue.arrayRemove([targetUserId]),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true));

      await batch.commit();
      debugPrint('[FIRESTORE] Unblocked user: $targetUserId by $currentUserId');
    } catch (e) {
      debugPrint('[FIRESTORE] Error unblocking user: $e');
      rethrow;
    }
  }

  /// Real-time stream of blocked user IDs for current user
  Stream<Set<String>> getBlockedUserIdsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('blocks')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  // --- REPORTING ---

  /// Submit a user or content report to reports/{reportId}
  Future<void> submitReport(ReportModel report) async {
    if (report.reporterId.isEmpty ||
        report.targetId.isEmpty ||
        report.reason.isEmpty) {
      throw Exception(
          'Report validation failed: reporterId, targetId, and reason are required.');
    }

    try {
      await _firestore.collection('reports').doc(report.id).set(report.toMap());
      debugPrint('[FIRESTORE] Report submitted with ID: ${report.id}');
    } catch (e) {
      debugPrint('[FIRESTORE] Error submitting report: $e');
      rethrow;
    }
  }

  // --- TRANSACTIONS & REVENUE MONETIZATION ---

  /// Save transaction record in transactions/{transactionId}
  Future<void> saveTransaction(TransactionModel tx) async {
    try {
      await _firestore.collection('transactions').doc(tx.id).set(tx.toMap());
      debugPrint('[FIRESTORE] Transaction recorded with ID: ${tx.id}');
    } catch (e) {
      debugPrint('[FIRESTORE] Error recording transaction: $e');
    }
  }

  /// Real-time transactions stream for Admin Revenue Dashboard
  Stream<List<TransactionModel>> getAdminTransactionsStream() {
    return _firestore
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // --- ACCOUNT DELETION & CLEANUP ---

  /// Cleans up all Firestore data owned by the user prior to Firebase Auth deletion.
  /// Throws an exception if any critical deletion step fails so caller does NOT delete
  /// the Firebase Auth account, preventing orphaned data and allowing safe retries.
  /// Returns a list of discovered media URLs (posts and profile) for targeted storage cleanup.
  Future<List<String>> deleteUserAccountData(String userId) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('User ID must not be empty for account deletion.');
    }

    debugPrint('[FIRESTORE] Starting account data cleanup for UID: $userId');
    final discoveredMediaUrls = <String>[];

    try {
      // 1. Delete user-created posts and their subcollections
      final userPostsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();

      for (final postDoc in userPostsSnapshot.docs) {
        final pData = postDoc.data();
        if (pData['mediaUrl'] != null &&
            (pData['mediaUrl'] as String).isNotEmpty) {
          discoveredMediaUrls.add(pData['mediaUrl'] as String);
        }
        if (pData['thumbnailUrl'] != null &&
            (pData['thumbnailUrl'] as String).isNotEmpty) {
          discoveredMediaUrls.add(pData['thumbnailUrl'] as String);
        }

        // Delete likes on post
        try {
          final likesSnapshot =
              await postDoc.reference.collection('likes').get();
          for (final likeDoc in likesSnapshot.docs) {
            await likeDoc.reference.delete();
          }
        } catch (e) {
          debugPrint('[FIRESTORE] Error deleting post likes: $e');
        }

        // Delete comments on post
        try {
          final commentsSnapshot =
              await postDoc.reference.collection('comments').get();
          for (final commentDoc in commentsSnapshot.docs) {
            await commentDoc.reference.delete();
          }
        } catch (e) {
          debugPrint('[FIRESTORE] Error deleting post comments: $e');
        }

        // Delete the post document itself
        await postDoc.reference.delete();
        debugPrint('[FIRESTORE] Deleted post: ${postDoc.id}');
      }

      // 2. Discover profile media URLs and delete the public user profile document: users/{userId}
      // Establishing an unambiguous, non-reversible deletion state BEFORE subcollection cleanup
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final uData = userDoc.data()!;
          if (uData['profilePicUrl'] != null &&
              (uData['profilePicUrl'] as String).isNotEmpty) {
            discoveredMediaUrls.add(uData['profilePicUrl'] as String);
          }
          if (uData['verificationPhoto'] != null &&
              (uData['verificationPhoto'] as String).isNotEmpty) {
            discoveredMediaUrls.add(uData['verificationPhoto'] as String);
          }
        }
      } catch (e) {
        debugPrint('[FIRESTORE] Error reading profile media URLs: $e');
      }

      await _firestore.collection('users').doc(userId).delete();
      debugPrint('[FIRESTORE] Public profile deleted for UID: $userId');

      // 3. Delete subcollections of users/{userId} (authorized by !exists(/users/{userId}))
      // 3a. Private settings
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('private')
            .doc('settings')
            .delete();
      } catch (e) {
        debugPrint('[FIRESTORE] Error deleting private settings: $e');
      }

      // 3b. Follows subcollection
      try {
        final followsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('follows')
            .get();
        for (final doc in followsSnapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[FIRESTORE] Error deleting follows subcollection: $e');
      }

      // 3c. Blocks subcollection
      try {
        final blocksSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('blocks')
            .get();
        for (final doc in blocksSnapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[FIRESTORE] Error deleting blocks subcollection: $e');
      }

      // 3d. User notifications subcollection
      try {
        final notifsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .get();
        for (final doc in notifsSnapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint(
            '[FIRESTORE] Error deleting notifications subcollection: $e');
      }

      // 4. Delete direct notifications where userId == userId
      try {
        final directNotifsSnapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .get();
        for (final doc in directNotifsSnapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[FIRESTORE] Error deleting direct notifications: $e');
      }

      // 5. Handle shared connections: soft-delete sent messages & anonymize user data
      // Preserves shared conversation history for the other participant
      try {
        final connectionsSnapshot = await _firestore
            .collection('connections')
            .where('participants', arrayContains: userId)
            .get();

        for (final connDoc in connectionsSnapshot.docs) {
          // Soft-delete messages sent by this user
          try {
            final messagesSnapshot = await connDoc.reference
                .collection('messages')
                .where('senderId', isEqualTo: userId)
                .get();

            for (final msgDoc in messagesSnapshot.docs) {
              await msgDoc.reference.update({
                'isDeletedForEveryone': true,
                'content': 'This message was deleted',
                'message': 'This message was deleted',
                'mediaUrl': null,
              });
            }
          } catch (e) {
            debugPrint('[FIRESTORE] Error soft-deleting message: $e');
          }

          // Anonymize user in shared connection document
          try {
            final data = connDoc.data();
            final isSender = data['senderId'] == userId;
            final Map<String, dynamic> updatePayload = {
              'updatedAt': DateTime.now().toIso8601String(),
              'lastMessageText': 'Conversation closed (user deleted account)',
            };
            if (isSender) {
              updatePayload['senderUsername'] = 'Deleted User';
              updatePayload['senderProfilePic'] = '';
            } else {
              updatePayload['receiverUsername'] = 'Deleted User';
              updatePayload['receiverProfilePic'] = '';
              updatePayload['recipientUsername'] = 'Deleted User';
              updatePayload['recipientProfilePic'] = '';
            }
            await connDoc.reference.update(updatePayload);
          } catch (e) {
            debugPrint('[FIRESTORE] Error anonymizing shared connection: $e');
          }
        }
      } catch (e) {
        debugPrint('[FIRESTORE] Error handling user connections: $e');
      }

      return discoveredMediaUrls;
    } catch (e) {
      debugPrint(
          '[FIRESTORE] Critical error during account data cleanup for UID $userId: $e');
      rethrow;
    }
  }
}
