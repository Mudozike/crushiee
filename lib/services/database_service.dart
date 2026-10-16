import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/connection_model.dart';
import '../models/chat_message_model.dart';
import '../models/notification_model.dart';
import '../models/crush_comment_model.dart';
import '../models/transaction_model.dart';
import 'firestore_service.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirestoreService get _firestoreService => FirestoreService();

  // Local state caches
  final Map<String, UserModel> _users = {};
  final List<PostModel> _posts = [];
  final List<ConnectionModel> _connections = [];
  final List<ChatMessageModel> _chatMessages = [];
  final List<NotificationModel> _notifications = [];
  final Map<String, List<CrushCommentModel>> _postComments = {};
  final Set<String> _followingUserIds = {};
  final Map<String, Set<String>> _typingUsersByConnection = {};

  List<PostModel> get posts => List.unmodifiable(_posts);
  List<ConnectionModel> get connections => List.unmodifiable(_connections);
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  bool isFollowing(String targetUserId) =>
      _followingUserIds.contains(targetUserId);

  void setPosts(List<PostModel> newPosts) {
    _posts.clear();
    _posts.addAll(newPosts);
    notifyListeners();
  }

  // --- USER, FOLLOW, BLOCK & REPORT API ---
  Map<String, UserModel> get users => Map.unmodifiable(_users);
  UserModel? getUser(String userId) => _users[userId];

  void updateUser(UserModel user) {
    _users[user.id] = user;
    notifyListeners();
  }

  void deleteUser(String userId) {
    _users.remove(userId);
    _posts.removeWhere((p) => p.userId == userId);
    _connections
        .removeWhere((c) => c.senderId == userId || c.recipientId == userId);
    _chatMessages
        .removeWhere((m) => m.senderId == userId || m.recipientId == userId);
    _notifications.removeWhere((n) => n.userId == userId);
    _followingUserIds.remove(userId);
    notifyListeners();
  }

  bool isUserBlocked(String currentUserId, String targetUserId) {
    final user = getUser(currentUserId);
    return user?.blockedUserIds.contains(targetUserId) ?? false;
  }

  void blockUser(String currentUserId, String targetUserId) {
    final user = getUser(currentUserId);
    if (user != null) {
      final updatedBlocked = List<String>.from(user.blockedUserIds);
      if (!updatedBlocked.contains(targetUserId)) {
        updatedBlocked.add(targetUserId);
        updateUser(user.copyWith(blockedUserIds: updatedBlocked));
      }
    }
  }

  void unblockUser(String currentUserId, String targetUserId) {
    final user = getUser(currentUserId);
    if (user != null) {
      final updatedBlocked = List<String>.from(user.blockedUserIds);
      updatedBlocked.remove(targetUserId);
      updateUser(user.copyWith(blockedUserIds: updatedBlocked));
    }
  }

  void reportUser({
    required String reporterId,
    required String reportedId,
    required String reason,
    String? details,
  }) {
    addNotification(
      NotificationModel(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        userId: reporterId,
        fromUserId: reportedId,
        fromUsername: 'Crushie Support',
        fromUserProfilePic: '',
        type: NotificationType.system,
        title: 'Report Submitted',
        body:
            'Your report against user ID $reportedId ($reason) has been received and is under review.',
      ),
    );
    notifyListeners();
  }

  void setFollowingUserIds(Set<String> ids) {
    _followingUserIds.clear();
    _followingUserIds.addAll(ids);
    notifyListeners();
  }

  void clearFollowing() {
    _followingUserIds.clear();
    notifyListeners();
  }

  void toggleFollow(String currentUserId, String targetUserId) {
    if (currentUserId == targetUserId) return;

    final targetUser = getUser(targetUserId);
    final currentUser = getUser(currentUserId);
    final isCurrentlyFollowing = _followingUserIds.contains(targetUserId);

    if (isCurrentlyFollowing) {
      _followingUserIds.remove(targetUserId);
      if (targetUser != null) {
        _users[targetUserId] = targetUser.copyWith(
          followersCount: (targetUser.followersCount - 1).clamp(0, 999999),
        );
      }
      if (currentUser != null) {
        _users[currentUserId] = currentUser.copyWith(
          followingCount: (currentUser.followingCount - 1).clamp(0, 999999),
        );
      }
    } else {
      _followingUserIds.add(targetUserId);
      if (targetUser != null) {
        _users[targetUserId] = targetUser.copyWith(
          followersCount: targetUser.followersCount + 1,
        );
      }
      if (currentUser != null) {
        _users[currentUserId] = currentUser.copyWith(
          followingCount: currentUser.followingCount + 1,
        );
      }

      if (targetUser != null && currentUser != null) {
        final notif = NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          userId: targetUserId,
          fromUserId: currentUserId,
          fromUsername: currentUser.username,
          fromUserProfilePic: currentUser.profilePicUrl,
          type: NotificationType.follow,
          title: 'New Follower!',
          body: '${currentUser.username} started following you',
        );
        addNotification(notif);
      }
    }
    notifyListeners();
  }

  // --- TYPING STATUS API ---
  void setTypingStatus(String connectionId, String userId, bool isTyping) {
    if (!_typingUsersByConnection.containsKey(connectionId)) {
      _typingUsersByConnection[connectionId] = {};
    }

    if (isTyping) {
      _typingUsersByConnection[connectionId]!.add(userId);
    } else {
      _typingUsersByConnection[connectionId]!.remove(userId);
    }
    notifyListeners();
  }

  bool isUserTyping(String connectionId, String userId) {
    return _typingUsersByConnection[connectionId]?.contains(userId) ?? false;
  }

  // --- POST API ---
  // NOTE: These methods are CACHE-ONLY. Firestore writes must be performed by
  // the caller (PostProvider) — never by DatabaseService — to avoid duplicate writes.

  /// Add a post to the in-memory cache (optimistic UI update only, no Firestore write).
  void addPostToCache(PostModel post) {
    // Avoid duplicate if Firestore refresh already inserted it
    if (_posts.any((p) => p.id == post.id)) return;
    _posts.insert(0, post);
    notifyListeners();
  }

  /// Internal alias for backward compat — same as addPostToCache, NO Firestore write.
  void createPost(PostModel post) {
    addPostToCache(post);
  }

  void updatePost(PostModel updatedPost, String userId) {
    final index = _posts.indexWhere((p) => p.id == updatedPost.id);
    if (index != -1) {
      if (_posts[index].userId != userId) return; // Ownership restriction
      _posts[index] = updatedPost;
      // Caller is responsible for Firestore write — no write here.
      notifyListeners();
    }
  }

  void deletePost(String postId, String userId) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      if (_posts[index].userId != userId) return; // Ownership restriction
      _posts.removeAt(index);
      _postComments.remove(postId);
      notifyListeners();
    }
  }

  final List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  void recordTransaction(TransactionModel tx) {
    _transactions.insert(0, tx);
    notifyListeners();
  }

  void incrementUserConnectionUsage(String userId) {
    final user = getUser(userId);
    if (user != null) {
      final now = DateTime.now();
      int newDaily = user.activeDailyConnections + 1;
      int newMonthly = user.activeMonthlyConnections + 1;

      updateUser(user.copyWith(
        dailyConnections: newDaily,
        dailyConnectionsDate: now,
        monthlyConnections: newMonthly,
        monthlyConnectionsMonth: now,
      ));
    }
  }

  void verifyUser(String userId, {int days = 30}) {
    final user = getUser(userId);
    if (user != null) {
      final expiry = DateTime.now().add(Duration(days: days));
      updateUser(user.copyWith(
        isVerified: true,
        verifiedExpiry: expiry,
      ));
    }
  }

  void upgradeUserToPremium(String userId, {int days = 30}) {
    final user = getUser(userId);
    if (user != null) {
      final expiry = DateTime.now().add(Duration(days: days));
      updateUser(user.copyWith(
        isPremium: true,
        premiumExpiry: expiry,
      ));
    }
  }

  void upgradeUserToBundle(String userId, {int days = 30}) {
    final user = getUser(userId);
    if (user != null) {
      final expiry = DateTime.now().add(Duration(days: days));
      updateUser(user.copyWith(
        isPremium: true,
        premiumExpiry: expiry,
        isVerified: true,
        verifiedExpiry: expiry,
      ));
    }
  }

  void boostPost(String postId, int hours) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      _posts[index] = post.copyWith(
        isBoosted: true,
        boostExpiresAt: DateTime.now().add(Duration(hours: hours)),
      );
      _firestoreService.createPost(_posts[index]);
      notifyListeners();
    }
  }

  void toggleCrush(String postId, String userId) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      final isCrushed = post.crushedUserIds.contains(userId);
      final updatedUserIds = List<String>.from(post.crushedUserIds);

      if (isCrushed) {
        updatedUserIds.remove(userId);
        _posts[index] = post.copyWith(
          crushCount: (post.crushCount - 1).clamp(0, 999999),
          crushedUserIds: updatedUserIds,
        );
      } else {
        updatedUserIds.add(userId);
        _posts[index] = post.copyWith(
          crushCount: post.crushCount + 1,
          crushedUserIds: updatedUserIds,
        );
      }
      _firestoreService.togglePostCrush(postId: postId, userId: userId);
      notifyListeners();
    }
  }

  List<CrushCommentModel> getPostComments(String postId) {
    return _postComments[postId] ?? [];
  }

  void addCrushComment(CrushCommentModel comment) {
    if (!_postComments.containsKey(comment.postId)) {
      _postComments[comment.postId] = [];
    }
    _postComments[comment.postId]!.add(comment);

    final index = _posts.indexWhere((p) => p.id == comment.postId);
    if (index != -1) {
      final post = _posts[index];
      _posts[index] = post.copyWith(crushesCount: post.crushesCount + 1);
    }
    notifyListeners();
  }

  void editCrushComment({
    required String commentId,
    required String postId,
    required String userId,
    required String newText,
  }) {
    if (_postComments.containsKey(postId)) {
      final comments = _postComments[postId]!;
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        if (comments[index].userId != userId) return; // Ownership restriction
        comments[index] = comments[index].copyWith(text: newText);
        notifyListeners();
      }
    }
  }

  void deleteCrushComment({
    required String commentId,
    required String postId,
    required String userId,
  }) {
    if (_postComments.containsKey(postId)) {
      final comments = _postComments[postId]!;
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        if (comments[index].userId != userId) return; // Ownership restriction
        comments.removeAt(index);

        final postIndex = _posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          final post = _posts[postIndex];
          _posts[postIndex] = post.copyWith(
            crushesCount: (post.crushesCount - 1).clamp(0, 999999),
          );
        }
        notifyListeners();
      }
    }
  }

  // --- CONNECTION API ---
  ConnectionModel? sendConnectionRequest({
    required UserModel sender,
    required UserModel recipient,
    String? postId,
    required double priceKES,
    required bool isPremiumFree,
  }) {
    final canonicalId =
        ConnectionModel.getConversationId(sender.id, recipient.id);
    final existingIndex = _connections.indexWhere(
      (c) =>
          c.id == canonicalId ||
          (c.participants.contains(sender.id) &&
              c.participants.contains(recipient.id)),
    );
    if (existingIndex != -1) {
      return _connections[existingIndex];
    }

    final connection = ConnectionModel(
      id: canonicalId,
      senderId: sender.id,
      senderUsername: sender.username,
      senderProfilePic: sender.profilePicUrl,
      recipientId: recipient.id,
      recipientUsername: recipient.username,
      recipientProfilePic: recipient.profilePicUrl,
      postId: postId,
      status: ConnectionStatus.accepted,
      priceKES: priceKES,
      isPremiumFree: isPremiumFree,
      recipientContactMethod: recipient.preferredContactMethod,
      recipientContactDetails: recipient.contactDetails,
    );

    _connections.insert(0, connection);
    _firestoreService.saveConnection(connection).catchError((e) {
      debugPrint('[DB_SERVICE] Error saving connection to firestore: $e');
    });

    final notif = NotificationModel(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      userId: recipient.id,
      fromUserId: sender.id,
      fromUsername: sender.username,
      fromUserProfilePic: sender.profilePicUrl,
      type: NotificationType.connectionRequest,
      title: 'Connection Request!',
      body: '${sender.username} wants to connect with you',
      connectionId: connection.id,
    );
    _firestoreService.createNotification(notif).catchError((e) {
      debugPrint('[DB_SERVICE] Error creating notification in firestore: $e');
    });

    notifyListeners();
    return connection;
  }

  void addConnection(ConnectionModel connection) {
    _connections.removeWhere((c) => c.id == connection.id);
    _connections.insert(0, connection);
    notifyListeners();
  }

  void respondToConnection(String connectionId, ConnectionStatus newStatus) {
    final index = _connections.indexWhere((c) => c.id == connectionId);
    if (index != -1) {
      final conn = _connections[index];
      _connections[index] = conn.copyWith(
        status: newStatus,
        respondedAt: DateTime.now(),
      );

      if (newStatus == ConnectionStatus.accepted) {
        final notif = NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          userId: conn.senderId,
          fromUserId: conn.recipientId,
          fromUsername: conn.recipientUsername,
          fromUserProfilePic: conn.recipientProfilePic,
          type: NotificationType.connectionAccepted,
          title: 'Connection Accepted!',
          body: '${conn.recipientUsername} accepted your connection request',
          connectionId: connectionId,
        );
        _firestoreService.createNotification(notif).catchError((e) {
          debugPrint(
              '[DB_SERVICE] Error creating notification in firestore: $e');
        });
      }
      notifyListeners();
    }
  }

  // --- CHAT MESSAGES API & DELETION ---
  List<ChatMessageModel> getChatMessages(String connectionId,
      {String? userId}) {
    return _chatMessages.where((m) {
      if (m.connectionId != connectionId) return false;
      if (userId != null && m.deletedForUserIds.contains(userId)) return false;
      return true;
    }).toList();
  }

  Stream<List<ChatMessageModel>> getChatMessagesStream(String connectionId,
      {int limit = 50}) {
    try {
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
    } catch (e) {
      return Stream.value(getChatMessages(connectionId));
    }
  }

  void sendChatMessage(ChatMessageModel message) {
    _chatMessages.add(message);
    notifyListeners();
  }

  void markMessagesAsRead(String connectionId, String currentUserId) {
    bool changed = false;
    for (int i = 0; i < _chatMessages.length; i++) {
      final m = _chatMessages[i];
      if (m.connectionId == connectionId && !m.isRead) {
        _chatMessages[i] = m.copyWith(
          isRead: true,
          deliveryStatus: MessageDeliveryStatus.read,
        );
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void deleteMessageForMe(String messageId, String userId) {
    final index = _chatMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final msg = _chatMessages[index];
      final updatedDeletedFor = List<String>.from(msg.deletedForUserIds);
      if (!updatedDeletedFor.contains(userId)) {
        updatedDeletedFor.add(userId);
        _chatMessages[index] =
            msg.copyWith(deletedForUserIds: updatedDeletedFor);
        notifyListeners();
      }
    }
  }

  void deleteMessageForEveryone(String messageId) {
    final index = _chatMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final msg = _chatMessages[index];
      _chatMessages[index] = msg.copyWith(
        content: 'Message deleted',
        isDeletedForEveryone: true,
      );
      notifyListeners();
    }
  }

  void clearConversation(String connectionId, String userId) {
    bool changed = false;
    for (int i = 0; i < _chatMessages.length; i++) {
      final msg = _chatMessages[i];
      if (msg.connectionId == connectionId) {
        final updatedDeletedFor = List<String>.from(msg.deletedForUserIds);
        if (!updatedDeletedFor.contains(userId)) {
          updatedDeletedFor.add(userId);
          _chatMessages[i] = msg.copyWith(deletedForUserIds: updatedDeletedFor);
          changed = true;
        }
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void deleteConversation(String connectionId, String userId) {
    clearConversation(connectionId, userId);
    _connections.removeWhere((c) => c.id == connectionId);
    notifyListeners();
  }

  // --- NOTIFICATIONS API ---
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void markNotificationAsRead(String notifId) {
    final index = _notifications.indexWhere((n) => n.id == notifId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  /// Clears in-memory sensitive user data upon sign-out to prevent cross-account leakage.
  void clearUserData() {
    _users.clear();
    _connections.clear();
    _chatMessages.clear();
    _notifications.clear();
    _followingUserIds.clear();
    _typingUsersByConnection.clear();
    notifyListeners();
  }
}
