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
          'lastSeen': user.lastSeen.toIso8601String(),
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
          'lastSeen': user.lastSeen.toIso8601String(),
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
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    });
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

  /// Create new post in posts/{postId}
  Future<bool> createPost(PostModel post) async {
    try {
      await _firestore.collection('posts').doc(post.id).set(post.toMap());
      debugPrint('[FIRESTORE] Post created with ID: ${post.id}');
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
            id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
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
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          userId: postAuthorId,
          fromUserId: comment.userId,
          fromUsername: comment.username,
          fromUserProfilePic: comment.userProfilePic,
          type: NotificationType.crushComment,
          title: 'New Comment!',
          body: '${comment.username} commented on your post',
          postId: comment.postId,
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
    if (currentUserId == targetUserId) return false;

    try {
      final followRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('follows')
          .doc(targetUserId);

      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);

      final doc = await followRef.get();
      final targetDoc = await targetUserRef.get();
      final currentUserDoc = await currentUserRef.get();

      final hasFollowersCounter = targetDoc.exists &&
          targetDoc.data() != null &&
          targetDoc.data()!.containsKey('followersCount');
      final hasFollowingCounter = currentUserDoc.exists &&
          currentUserDoc.data() != null &&
          currentUserDoc.data()!.containsKey('followingCount');

      if (doc.exists) {
        // Unfollow
        final batch = _firestore.batch();
        batch.delete(followRef);
        if (hasFollowingCounter &&
            ((currentUserDoc.data()!['followingCount'] as num?) ?? 0) > 0) {
          batch.update(
              currentUserRef, {'followingCount': FieldValue.increment(-1)});
        }
        if (hasFollowersCounter &&
            ((targetDoc.data()!['followersCount'] as num?) ?? 0) > 0) {
          batch.update(
              targetUserRef, {'followersCount': FieldValue.increment(-1)});
        }
        await batch.commit();
        debugPrint('[FIRESTORE] Unfollowed: $targetUserId by $currentUserId');
        return false;
      } else {
        // Follow
        final batch = _firestore.batch();
        batch.set(followRef, {
          'targetId': targetUserId,
          'targetUsername': targetUsername ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (hasFollowingCounter) {
          batch.update(
              currentUserRef, {'followingCount': FieldValue.increment(1)});
        } else if (currentUserDoc.exists) {
          batch.update(currentUserRef, {'followingCount': 1});
        }
        if (hasFollowersCounter) {
          batch.update(
              targetUserRef, {'followersCount': FieldValue.increment(1)});
        }
        await batch.commit();
        debugPrint('[FIRESTORE] Followed: $targetUserId by $currentUserId');

        // Notification for target user
        final notif = NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          userId: targetUserId,
          fromUserId: currentUserId,
          fromUsername: currentUsername ?? 'Someone',
          fromUserProfilePic: currentUserProfilePic ?? 'crushie_avatar_0',
          type: NotificationType.follow,
          title: 'New Follower!',
          body: '${currentUsername ?? "Someone"} followed you',
        );
        createNotification(notif);
        return true;
      }
    } catch (e) {
      debugPrint('[FIRESTORE] Error toggling follow: $e');
      rethrow;
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
  Future<void> createNotification(NotificationModel notification) async {
    try {
      await _firestore
          .collection('users')
          .doc(notification.userId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
      debugPrint(
          '[FIRESTORE] Notification created for UID: ${notification.userId}');
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

  /// Finds existing connection between two users (checks canonical ID first, then legacy IDs)
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
      // 2. Check for legacy connection where participants contain both uids
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
      return null;
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
        return timeB.compareTo(timeA);
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
        .orderBy('timestamp', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Send chat message to connections/{connectionId}/messages/{messageId}
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

      final batch = _firestore.batch();
      batch.set(msgRef, message.toMap());
      batch.set(
        connRef,
        {
          'lastMessageText': previewContent,
          'lastMessageTimestamp': message.createdAt.toIso8601String(),
          'lastMessageSenderId': message.senderId,
          'updatedAt': message.createdAt.toIso8601String(),
          if (recipientId.isNotEmpty)
            'unreadCounts': {
              recipientId: FieldValue.increment(1),
            },
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      debugPrint(
          '[FIRESTORE] Chat message sent for connection: ${message.connectionId}');
    } catch (e) {
      debugPrint('[FIRESTORE] Error sending chat message: $e');
      rethrow;
    }
  }

  /// Mark incoming messages as read in connections/{connectionId}/messages
  Future<void> markMessagesAsRead(
      String connectionId, String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('connections')
          .doc(connectionId)
          .collection('messages')
          .where('recipientId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'deliveryStatus': 'read',
        });
      }
      final connRef = _firestore.collection('connections').doc(connectionId);
      batch.set(
        connRef,
        {
          'unreadCounts': {
            currentUserId: 0,
          },
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      debugPrint(
          '[FIRESTORE] Marked ${snapshot.docs.length} messages as read in connection: $connectionId');
    } catch (e) {
      debugPrint('[FIRESTORE] Error marking messages as read: $e');
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

      // 2. Delete subcollections of users/{userId}
      // 2a. Private settings
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

      // 2b. Follows subcollection
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

      // 2c. Blocks subcollection
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

      // 2d. User notifications subcollection
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

      // 3. Delete direct notifications where userId == userId
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

      // 4. Handle shared connections: soft-delete sent messages & anonymize user data
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

      // 5. Discover profile media URLs before document deletion
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

      // 6. Delete the public user profile document: users/{userId}
      await _firestore.collection('users').doc(userId).delete();
      debugPrint('[FIRESTORE] Public profile deleted for UID: $userId');

      return discoveredMediaUrls;
    } catch (e) {
      debugPrint(
          '[FIRESTORE] Critical error during account data cleanup for UID $userId: $e');
      rethrow;
    }
  }
}
