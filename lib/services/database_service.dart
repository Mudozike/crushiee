import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/connection_model.dart';
import '../models/chat_message_model.dart';
import '../models/notification_model.dart';
import '../models/crush_comment_model.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal() {
    _initSeedData();
  }

  // Local state caches
  final Map<String, UserModel> _users = {};
  final List<PostModel> _posts = [];
  final List<ConnectionModel> _connections = [];
  final List<ChatMessageModel> _chatMessages = [];
  final List<NotificationModel> _notifications = [];
  final Map<String, List<CrushCommentModel>> _postComments = {};
  final Set<String> _followingUserIds = {'user_2'}; // Default following user_2 for demo

  List<PostModel> get posts => List.unmodifiable(_posts);
  List<ConnectionModel> get connections => List.unmodifiable(_connections);
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);

  bool isFollowing(String targetUserId) => _followingUserIds.contains(targetUserId);

  void _initSeedData() {
    // Current User
    final currentUser = UserModel(
      id: 'current_user_1',
      username: 'alex_ke',
      email: 'alex@crushie.app',
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(1998, 5, 14),
      gender: 'Male',
      bio: 'Lover of good conversations, outdoor adventures, and great coffee',
      profilePicUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254712345678',
      isVerified: true,
      isPremium: false,
      followersCount: 142,
      followingCount: 89,
      communities: ['Coffee Date', 'Travel Partner', 'Casual Meet'],
      isOnline: true,
      lastSeen: DateTime.now(),
    );
    _users[currentUser.id] = currentUser;

    // Seed Users
    final user2 = UserModel(
      id: 'user_2',
      username: 'sarah_k',
      email: 'sarah@example.com',
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(2000, 3, 20),
      gender: 'Female',
      bio: 'Interior designer. Looking for genuine conversations and relaxed meetups',
      profilePicUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254722987654',
      isVerified: true,
      isPremium: false,
      followersCount: 320,
      followingCount: 150,
      communities: ['Coffee Date', 'Casual Meet'],
      isOnline: true,
      lastSeen: DateTime.now(),
    );
    _users[user2.id] = user2;

    final user3 = UserModel(
      id: 'user_3',
      username: 'david_m',
      email: 'david@example.com',
      country: 'Kenya',
      city: 'Mombasa',
      dateOfBirth: DateTime(1995, 8, 10),
      gender: 'Male',
      bio: 'Photographer and road trip enthusiast based in Mombasa',
      profilePicUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      preferredContactMethod: 'Telegram',
      contactDetails: '@david_mombasa',
      isVerified: true,
      isPremium: true,
      followersCount: 540,
      followingCount: 210,
      communities: ['Travel Partner', 'Weekend Meet'],
      isOnline: false,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 23)),
    );
    _users[user3.id] = user3;

    final user4 = UserModel(
      id: 'user_4',
      username: 'anita_x',
      email: 'anita@example.com',
      country: 'Kenya',
      city: 'Nakuru',
      dateOfBirth: DateTime(2001, 11, 5),
      gender: 'Female',
      bio: 'Spontaneous weekend plans and good energy',
      profilePicUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
      preferredContactMethod: 'Phone Call',
      contactDetails: '+254733112233',
      isVerified: false,
      isPremium: true,
      followersCount: 890,
      followingCount: 120,
      communities: ['Hook Up', 'Tonight Meet', 'Quick Meet'],
      isOnline: true,
      lastSeen: DateTime.now(),
    );
    _users[user4.id] = user4;

    final user5 = UserModel(
      id: 'user_5',
      username: 'chloe_w',
      email: 'chloe@example.com',
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(1999, 1, 28),
      gender: 'Female',
      bio: 'Fine dining, luxury lifestyle and high standards',
      profilePicUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254700554433',
      isVerified: true,
      isPremium: true,
      followersCount: 1250,
      followingCount: 300,
      communities: ['Sugar Daddy / Sugar Mummy', 'Weekend Meet'],
      isOnline: true,
      lastSeen: DateTime.now(),
    );
    _users[user5.id] = user5;

    // Seed Posts (With Pictures & No Emojis)
    _posts.addAll([
      PostModel(
        id: 'post_1',
        userId: user2.id,
        username: user2.username,
        userProfilePic: user2.profilePicUrl,
        userIsVerified: user2.isVerified,
        userIsOnline: user2.isOnline,
        userLastSeen: user2.lastSeen,
        userCountry: user2.country,
        userCity: user2.city,
        community: 'Coffee Date',
        lookingFor: 'Coffee Date',
        location: 'Westlands, Nairobi',
        ageRangeMin: 22,
        ageRangeMax: 32,
        availability: 'Tonight',
        description: 'Looking for someone open-minded for a coffee date and great conversations at Westlands tonight.',
        postImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800',
        crushCount: 24,
        crushesCount: 5,
        crushedUserIds: ['user_3', 'user_4'],
        isBoosted: true,
        boostExpiresAt: DateTime.now().add(const Duration(hours: 18)),
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      PostModel(
        id: 'post_2',
        userId: user4.id,
        username: user4.username,
        userProfilePic: user4.profilePicUrl,
        userIsVerified: user4.isVerified,
        userIsOnline: user4.isOnline,
        userLastSeen: user4.lastSeen,
        userCountry: user4.country,
        userCity: user4.city,
        community: 'Hook Up',
        lookingFor: 'Hook Up',
        location: 'Nakuru Town, Kenya',
        ageRangeMin: 21,
        ageRangeMax: 30,
        availability: 'Today',
        description: 'Spontaneous plans for today. Let us hang out and enjoy good company.',
        crushCount: 42,
        crushesCount: 8,
        crushedUserIds: ['user_2'],
        isBoosted: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      PostModel(
        id: 'post_3',
        userId: user3.id,
        username: user3.username,
        userProfilePic: user3.profilePicUrl,
        userIsVerified: user3.isVerified,
        userIsOnline: user3.isOnline,
        userLastSeen: user3.lastSeen,
        userCountry: user3.country,
        userCity: user3.city,
        community: 'Travel Partner',
        lookingFor: 'Travel Partner',
        location: 'Mombasa, Kenya',
        ageRangeMin: 22,
        ageRangeMax: 35,
        availability: 'Weekend',
        description: 'Planning a road trip down to Diani Beach this weekend. Looking for a fun travel partner to join the ride.',
        postImageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
        crushCount: 18,
        crushesCount: 3,
        crushedUserIds: [],
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      PostModel(
        id: 'post_4',
        userId: user5.id,
        username: user5.username,
        userProfilePic: user5.profilePicUrl,
        userIsVerified: user5.isVerified,
        userIsOnline: user5.isOnline,
        userLastSeen: user5.lastSeen,
        userCountry: user5.country,
        userCity: user5.city,
        community: 'Sugar Daddy / Sugar Mummy',
        lookingFor: 'Sugar Daddy',
        location: 'Kilimani, Nairobi',
        ageRangeMin: 30,
        ageRangeMax: 55,
        availability: 'Anytime',
        description: 'Looking for a generous gentleman who appreciates class, good company, and fine dining.',
        crushCount: 56,
        crushesCount: 12,
        crushedUserIds: [],
        isBoosted: true,
        boostExpiresAt: DateTime.now().add(const Duration(hours: 48)),
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
    ]);

    // Seed Comments ("Crushes")
    _postComments['post_1'] = [
      CrushCommentModel(
        id: 'c1',
        postId: 'post_1',
        userId: user3.id,
        username: user3.username,
        userProfilePic: user3.profilePicUrl,
        userIsVerified: user3.isVerified,
        text: 'Java House or Artcaffe?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
      ),
    ];

    // Seed Connection (Accepted for Chat Demo)
    final demoConnection = ConnectionModel(
      id: 'conn_demo_1',
      senderId: 'current_user_1',
      senderUsername: 'alex_ke',
      senderProfilePic: currentUser.profilePicUrl,
      recipientId: user2.id,
      recipientUsername: user2.username,
      recipientProfilePic: user2.profilePicUrl,
      postId: 'post_1',
      status: ConnectionStatus.accepted,
      priceKES: 50.0,
      recipientContactMethod: user2.preferredContactMethod,
      recipientContactDetails: user2.contactDetails,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      respondedAt: DateTime.now().subtract(const Duration(hours: 20)),
    );
    _connections.add(demoConnection);

    // Seed Chat Messages
    _chatMessages.addAll([
      ChatMessageModel(
        id: 'm1',
        connectionId: 'conn_demo_1',
        senderId: 'current_user_1',
        recipientId: user2.id,
        message: 'Hey Sarah! Glad we connected here on Crushie',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      ChatMessageModel(
        id: 'm2',
        connectionId: 'conn_demo_1',
        senderId: user2.id,
        recipientId: 'current_user_1',
        message: 'Hey Alex! Glad to connect with you. You can reach me on my WhatsApp: ${user2.contactDetails}',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ]);

    // Seed Notifications
    _notifications.addAll([
      NotificationModel(
        id: 'n1',
        userId: 'current_user_1',
        fromUserId: user2.id,
        fromUsername: user2.username,
        fromUserProfilePic: user2.profilePicUrl,
        type: NotificationType.connectionAccepted,
        title: 'Connection Accepted',
        body: 'sarah_k accepted your connection request. Tap to start chatting.',
        connectionId: 'conn_demo_1',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      NotificationModel(
        id: 'n2',
        userId: 'current_user_1',
        fromUserId: user3.id,
        fromUsername: user3.username,
        fromUserProfilePic: user3.profilePicUrl,
        type: NotificationType.crush,
        title: 'New Crush',
        body: 'david_m Crushed your post.',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
    ]);
  }

  // --- USER & FOLLOW API ---
  UserModel? getUser(String userId) => _users[userId];

  void updateUser(UserModel user) {
    _users[user.id] = user;
    notifyListeners();
  }

  void toggleFollow(String currentUserId, String targetUserId) {
    if (currentUserId == targetUserId) return;

    final targetUser = getUser(targetUserId);
    final currentUser = getUser(currentUserId);

    if (targetUser != null && currentUser != null) {
      final isCurrentlyFollowing = _followingUserIds.contains(targetUserId);

      if (isCurrentlyFollowing) {
        _followingUserIds.remove(targetUserId);
        _users[targetUserId] = targetUser.copyWith(
          followersCount: (targetUser.followersCount - 1).clamp(0, 999999),
        );
        _users[currentUserId] = currentUser.copyWith(
          followingCount: (currentUser.followingCount - 1).clamp(0, 999999),
        );
      } else {
        _followingUserIds.add(targetUserId);
        _users[targetUserId] = targetUser.copyWith(
          followersCount: targetUser.followersCount + 1,
        );
        _users[currentUserId] = currentUser.copyWith(
          followingCount: currentUser.followingCount + 1,
        );

        // Notify target user
        addNotification(
          NotificationModel(
            id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
            userId: targetUserId,
            fromUserId: currentUserId,
            fromUsername: currentUser.username,
            fromUserProfilePic: currentUser.profilePicUrl,
            type: NotificationType.follow,
            title: 'New Follower',
            body: '${currentUser.username} started following you.',
          ),
        );
      }
      notifyListeners();
    }
  }

  // --- POST API ---
  void createPost(PostModel post) {
    _posts.insert(0, post);
    notifyListeners();
  }

  void toggleCrush(String postId, String userId) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      final isCrushed = post.crushedUserIds.contains(userId);
      final updatedUserIds = List<String>.from(post.crushedUserIds);

      if (isCrushed) {
        updatedUserIds.remove(userId);
      } else {
        updatedUserIds.add(userId);
        
        if (post.userId != userId) {
          final currentUser = getUser(userId);
          addNotification(
            NotificationModel(
              id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
              userId: post.userId,
              fromUserId: userId,
              fromUsername: currentUser?.username ?? 'Someone',
              fromUserProfilePic: currentUser?.profilePicUrl ?? '',
              type: NotificationType.crush,
              title: 'New Crush',
              body: '${currentUser?.username ?? 'Someone'} Crushed your post.',
              postId: postId,
            ),
          );
        }
      }

      _posts[index] = post.copyWith(
        crushCount: isCrushed ? post.crushCount - 1 : post.crushCount + 1,
        crushedUserIds: updatedUserIds,
      );
      notifyListeners();
    }
  }

  // --- CRUSHES (COMMENTS) API ---
  List<CrushCommentModel> getPostComments(String postId) {
    return _postComments[postId] ?? [];
  }

  void addCrushComment(CrushCommentModel comment) {
    if (!_postComments.containsKey(comment.postId)) {
      _postComments[comment.postId] = [];
    }
    _postComments[comment.postId]!.insert(0, comment);

    final index = _posts.indexWhere((p) => p.id == comment.postId);
    if (index != -1) {
      final post = _posts[index];
      _posts[index] = post.copyWith(crushesCount: post.crushesCount + 1);

      if (post.userId != comment.userId) {
        addNotification(
          NotificationModel(
            id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
            userId: post.userId,
            fromUserId: comment.userId,
            fromUsername: comment.username,
            fromUserProfilePic: comment.userProfilePic,
            type: NotificationType.crushComment,
            title: 'New Comment',
            body: '${comment.username}: ${comment.text}',
            postId: comment.postId,
          ),
        );
      }
    }
    notifyListeners();
  }

  // --- CONNECTION API (KES 50) ---
  ConnectionModel? sendConnectionRequest({
    required UserModel sender,
    required UserModel recipient,
    String? postId,
    required double priceKES,
    required bool isPremiumFree,
  }) {
    final existingIndex = _connections.indexWhere(
      (c) => c.senderId == sender.id && c.recipientId == recipient.id,
    );
    if (existingIndex != -1) {
      return _connections[existingIndex];
    }

    final connection = ConnectionModel(
      id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
      senderId: sender.id,
      senderUsername: sender.username,
      senderProfilePic: sender.profilePicUrl,
      recipientId: recipient.id,
      recipientUsername: recipient.username,
      recipientProfilePic: recipient.profilePicUrl,
      postId: postId,
      status: ConnectionStatus.pending,
      priceKES: priceKES,
      isPremiumFree: isPremiumFree,
      recipientContactMethod: recipient.preferredContactMethod,
      recipientContactDetails: recipient.contactDetails,
    );

    _connections.insert(0, connection);

    addNotification(
      NotificationModel(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        userId: recipient.id,
        fromUserId: sender.id,
        fromUsername: sender.username,
        fromUserProfilePic: sender.profilePicUrl,
        type: NotificationType.connectionRequest,
        title: 'Connection Request',
        body: '${sender.username} wants to connect with you.',
        connectionId: connection.id,
      ),
    );

    notifyListeners();
    return connection;
  }

  void respondToConnection(String connectionId, ConnectionStatus newStatus) {
    final index = _connections.indexWhere((c) => c.id == connectionId);
    if (index != -1) {
      final conn = _connections[index];
      _connections[index] = conn.copyWith(
        status: newStatus,
        respondedAt: DateTime.now(),
      );

      final isAccepted = newStatus == ConnectionStatus.accepted;
      
      addNotification(
        NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          userId: conn.senderId,
          fromUserId: conn.recipientId,
          fromUsername: conn.recipientUsername,
          fromUserProfilePic: conn.recipientProfilePic,
          type: isAccepted
              ? NotificationType.connectionAccepted
              : NotificationType.connectionDeclined,
          title: isAccepted ? 'Connection Accepted' : 'Connection Declined',
          body: isAccepted
              ? '${conn.recipientUsername} accepted your connection request.'
              : '${conn.recipientUsername} declined your connection request.',
          connectionId: connectionId,
        ),
      );

      notifyListeners();
    }
  }

  // --- CHAT MESSAGES API ---
  List<ChatMessageModel> getChatMessages(String connectionId) {
    return _chatMessages.where((m) => m.connectionId == connectionId).toList();
  }

  void sendChatMessage(ChatMessageModel message) {
    _chatMessages.add(message);
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
      final notif = _notifications[index];
      _notifications[index] = NotificationModel(
        id: notif.id,
        userId: notif.userId,
        fromUserId: notif.fromUserId,
        fromUsername: notif.fromUsername,
        fromUserProfilePic: notif.fromUserProfilePic,
        type: notif.type,
        title: notif.title,
        body: notif.body,
        postId: notif.postId,
        connectionId: notif.connectionId,
        isRead: true,
        createdAt: notif.createdAt,
      );
      notifyListeners();
    }
  }

  // --- BOOST & VERIFICATION API ---
  void boostPost(String postId, int hours) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      _posts[index] = post.copyWith(
        isBoosted: true,
        boostExpiresAt: DateTime.now().add(Duration(hours: hours)),
      );
      notifyListeners();
    }
  }

  void verifyUser(String userId) {
    final user = getUser(userId);
    if (user != null) {
      updateUser(user.copyWith(isVerified: true));
    }
  }

  void upgradeUserToPremium(String userId) {
    final user = getUser(userId);
    if (user != null) {
      updateUser(user.copyWith(isPremium: true));
    }
  }
}
