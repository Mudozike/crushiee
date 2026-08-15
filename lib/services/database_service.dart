import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/connection_model.dart';
import '../models/chat_message_model.dart';
import '../models/notification_model.dart';
import '../models/crush_comment_model.dart';
import '../models/transaction_model.dart';

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
  final Set<String> _followingUserIds = {'user_2', 'user_4'};
  final Map<String, Set<String>> _typingUsersByConnection = {};

  List<PostModel> get posts => List.unmodifiable(_posts);
  List<ConnectionModel> get connections => List.unmodifiable(_connections);
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);

  bool isFollowing(String targetUserId) => _followingUserIds.contains(targetUserId);

  void _initSeedData() {
    final now = DateTime.now();

    // Default Current User
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
      isPremium: false, // Set to false by default for Free User connection limit testing
      dailyConnections: 0,
      dailyConnectionsDate: now,
      followersCount: 142,
      followingCount: 89,
      communities: ['Coffee Date', 'Travel Partner', 'Casual Meet'],
      isOnline: true,
      lastSeen: now,
    );
    _users[currentUser.id] = currentUser;

    // 1. @sarah_k — Online — 2 unread
    final user2 = UserModel(
      id: 'user_2',
      username: 'sarah_k',
      email: 'sarah@example.com',
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(2000, 3, 20),
      gender: 'Female',
      bio: 'Interior designer. Looking for genuine conversations and relaxed meetups',
      profilePicUrl: 'crushie_avatar_0',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254722987654',
      isVerified: true,
      isPremium: false,
      followersCount: 320,
      followingCount: 150,
      communities: ['Coffee Date', 'Casual Meet'],
      isOnline: true, // Online
      lastSeen: now,
    );
    _users[user2.id] = user2;

    // 2. @chloe_w — Active 5m ago
    final user5 = UserModel(
      id: 'user_5',
      username: 'chloe_w',
      email: 'chloe@example.com',
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(1999, 1, 28),
      gender: 'Female',
      bio: 'Fine dining, luxury lifestyle and high standards',
      profilePicUrl: 'crushie_avatar_1',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254700554433',
      isVerified: true,
      isPremium: true,
      followersCount: 1250,
      followingCount: 300,
      communities: ['Coffee Date', 'Weekend Meet'],
      isOnline: false, // Offline
      lastSeen: now.subtract(const Duration(minutes: 5)), // Active 5m ago
    );
    _users[user5.id] = user5;

    // 3. @anita_x — Online — 1 unread
    final user4 = UserModel(
      id: 'user_4',
      username: 'anita_x',
      email: 'anita@example.com',
      country: 'Kenya',
      city: 'Nakuru',
      dateOfBirth: DateTime(2001, 11, 5),
      gender: 'Female',
      bio: 'Spontaneous weekend plans and good energy',
      profilePicUrl: 'crushie_avatar_2',
      preferredContactMethod: 'Phone Call',
      contactDetails: '+254733112233',
      isVerified: false,
      isPremium: true,
      followersCount: 890,
      followingCount: 120,
      communities: ['Hook Up', 'Tonight Meet', 'Quick Meet'],
      isOnline: true, // Online
      lastSeen: now,
    );
    _users[user4.id] = user4;

    // 4. @kevin_m — Active 1h ago
    final userKevin = UserModel(
      id: 'user_kevin',
      username: 'kevin_m',
      email: 'kevin@example.com',
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(1996, 7, 19),
      gender: 'Male',
      bio: 'Tech enthusiast & weekend mountain biker',
      profilePicUrl: 'crushie_avatar_3',
      preferredContactMethod: 'Telegram',
      contactDetails: '@kevin_m_ke',
      isVerified: true,
      isPremium: false,
      followersCount: 410,
      followingCount: 190,
      communities: ['Travel Partner', 'Weekend Meet'],
      isOnline: false, // Offline
      lastSeen: now.subtract(const Duration(hours: 1)), // Active 1h ago
    );
    _users[userKevin.id] = userKevin;

    // 5. @mercy_n — Active 3h ago
    final userMercy = UserModel(
      id: 'user_mercy',
      username: 'mercy_n',
      email: 'mercy@example.com',
      country: 'Kenya',
      city: 'Mombasa',
      dateOfBirth: DateTime(2002, 9, 30),
      gender: 'Female',
      bio: 'Beach sunsets, music festivals, and travel',
      profilePicUrl: 'crushie_avatar_5',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254744556677',
      isVerified: true,
      isPremium: true,
      followersCount: 1540,
      followingCount: 420,
      communities: ['Travel Partner', 'Relationship'],
      isOnline: false, // Offline
      lastSeen: now.subtract(const Duration(hours: 3)), // Active 3h ago
    );
    _users[userMercy.id] = userMercy;

    // 6. @brian_t — Active yesterday
    final userBrian = UserModel(
      id: 'user_brian',
      username: 'brian_t',
      email: 'brian@example.com',
      country: 'Kenya',
      city: 'Eldoret',
      dateOfBirth: DateTime(1997, 4, 12),
      gender: 'Male',
      bio: 'Fitness, running, and positive vibes only',
      profilePicUrl: 'crushie_avatar_4',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254711889900',
      isVerified: false,
      isPremium: false,
      followersCount: 230,
      followingCount: 110,
      communities: ['Casual Meet', 'Friendship'],
      isOnline: false, // Offline
      lastSeen: now.subtract(const Duration(days: 1)), // Active yesterday
    );
    _users[userBrian.id] = userBrian;

    // 7. @PremiumQueen (Premium User)
    final userPQ = UserModel(
      id: 'user_premium_queen',
      username: 'PremiumQueen',
      email: 'queen@crushie.app',
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(1999, 6, 15),
      gender: 'Female',
      bio: 'Fashion designer & lifestyle blogger. Ambitious and high energy!',
      profilePicUrl: 'crushie_avatar_1',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254711223344',
      isVerified: false,
      isPremium: true,
      followersCount: 2400,
      followingCount: 150,
      communities: ['Long-Term Relationship', 'Coffee Date'],
      isOnline: true,
      lastSeen: now,
    );
    _users[userPQ.id] = userPQ;

    // 8. @VerifiedKing (Verified User)
    final userVK = UserModel(
      id: 'user_verified_king',
      username: 'VerifiedKing',
      email: 'king@crushie.app',
      country: 'Kenya',
      city: 'Mombasa',
      dateOfBirth: DateTime(1995, 8, 22),
      gender: 'Male',
      bio: 'Marine engineer & beach lover. Verified for authentic conversations.',
      profilePicUrl: 'crushie_avatar_4',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254722334455',
      isVerified: true,
      isPremium: false,
      followersCount: 1800,
      followingCount: 210,
      communities: ['Travel Partner', 'Weekend Meet'],
      isOnline: true,
      lastSeen: now,
    );
    _users[userVK.id] = userVK;

    // 9. @PremiumVerified (Both Premium + Verified)
    final userPV = UserModel(
      id: 'user_premium_verified',
      username: 'PremiumVerified',
      email: 'pv@crushie.app',
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(1997, 12, 10),
      gender: 'Female',
      bio: 'CEO & Founder. Looking for executive networking and genuine dates.',
      profilePicUrl: 'crushie_avatar_5',
      preferredContactMethod: 'Telegram',
      contactDetails: '@premium_verified_vip',
      isVerified: true,
      isPremium: true,
      followersCount: 5200,
      followingCount: 88,
      communities: ['Coffee Date', 'Relationship'],
      isOnline: true,
      lastSeen: now,
    );
    _users[userPV.id] = userPV;

    // 10. @FreeUser123 (Free User)
    final userFU = UserModel(
      id: 'user_free_123',
      username: 'FreeUser123',
      email: 'free123@crushie.app',
      country: 'Kenya',
      city: 'Kisumu',
      dateOfBirth: DateTime(2001, 2, 14),
      gender: 'Male',
      bio: 'Student at UoN. Loves chill vibes, fish dinners & lakeside sunsets.',
      profilePicUrl: 'crushie_avatar_2',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254733445566',
      isVerified: false,
      isPremium: false,
      followersCount: 120,
      followingCount: 95,
      communities: ['Casual Meet', 'Friendship'],
      isOnline: false,
      lastSeen: now.subtract(const Duration(minutes: 45)),
    );
    _users[userFU.id] = userFU;

    // 11. @HotNakuru (Free User)
    final userHN = UserModel(
      id: 'user_hot_nakuru',
      username: 'HotNakuru',
      email: 'nakuru@crushie.app',
      country: 'Kenya',
      city: 'Nakuru',
      dateOfBirth: DateTime(2002, 5, 4),
      gender: 'Female',
      bio: 'Spontaneous party lover in Nakuru! Let us connect for fun weekends.',
      profilePicUrl: 'crushie_avatar_0',
      preferredContactMethod: 'Phone Call',
      contactDetails: '+254744556688',
      isVerified: false,
      isPremium: false,
      followersCount: 980,
      followingCount: 340,
      communities: ['Hook Up', 'Tonight Meet'],
      isOnline: true,
      lastSeen: now,
    );
    _users[userHN.id] = userHN;

    // Seed 10+ Mock Posts across multiple locations & communities
    _posts.addAll([
      PostModel(
        id: 'post_pv_1',
        userId: userPV.id,
        username: userPV.username,
        userProfilePic: userPV.profilePicUrl,
        userIsVerified: userPV.isVerified,
        userIsOnline: userPV.isOnline,
        userLastSeen: userPV.lastSeen,
        userCountry: userPV.country,
        userCity: userPV.city,
        community: 'Coffee Date',
        lookingFor: 'Coffee Date',
        location: 'Westlands, Nairobi',
        ageRangeMin: 24,
        ageRangeMax: 38,
        availability: 'Tonight',
        description: 'Looking for an open-minded professional for a coffee & art gallery date at Westlands tonight.',
        postImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800',
        crushCount: 56,
        crushesCount: 12,
        crushedUserIds: ['user_kevin', 'user_verified_king'],
        isBoosted: true,
        boostExpiresAt: now.add(const Duration(hours: 24)),
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),
      PostModel(
        id: 'post_vk_1',
        userId: userVK.id,
        username: userVK.username,
        userProfilePic: userVK.profilePicUrl,
        userIsVerified: userVK.isVerified,
        userIsOnline: userVK.isOnline,
        userLastSeen: userVK.lastSeen,
        userCountry: userVK.country,
        userCity: userVK.city,
        community: 'Travel Partner',
        lookingFor: 'Travel Partner',
        location: 'Nyali, Mombasa',
        ageRangeMin: 21,
        ageRangeMax: 35,
        availability: 'Weekend',
        description: 'Planning a weekend roadtrip to Diani beach! Looking for a fun, spontaneous travel partner.',
        postImageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
        crushCount: 48,
        crushesCount: 9,
        crushedUserIds: ['user_premium_queen'],
        isBoosted: true,
        boostExpiresAt: now.add(const Duration(hours: 12)),
        createdAt: now.subtract(const Duration(minutes: 40)),
      ),
      PostModel(
        id: 'post_hn_1',
        userId: userHN.id,
        username: userHN.username,
        userProfilePic: userHN.profilePicUrl,
        userIsVerified: userHN.isVerified,
        userIsOnline: userHN.isOnline,
        userLastSeen: userHN.lastSeen,
        userCountry: userHN.country,
        userCity: userHN.city,
        community: 'Hook Up',
        lookingFor: 'Hook Up',
        location: 'Nakuru Town, Kenya',
        ageRangeMin: 20,
        ageRangeMax: 30,
        availability: 'Today',
        description: 'Spontaneous plans for today in Nakuru town. Let us grab drinks and see where the night takes us!',
        crushCount: 35,
        crushesCount: 6,
        crushedUserIds: ['user_free_123'],
        isBoosted: true,
        boostExpiresAt: now.add(const Duration(hours: 20)),
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      PostModel(
        id: 'post_pq_1',
        userId: userPQ.id,
        username: userPQ.username,
        userProfilePic: userPQ.profilePicUrl,
        userIsVerified: userPQ.isVerified,
        userIsOnline: userPQ.isOnline,
        userLastSeen: userPQ.lastSeen,
        userCountry: userPQ.country,
        userCity: userPQ.city,
        community: 'Long-Term Relationship',
        lookingFor: 'Long-Term Relationship',
        location: 'Kilimani, Nairobi',
        ageRangeMin: 25,
        ageRangeMax: 40,
        availability: 'Anytime',
        description: 'Successful fashion entrepreneur looking for an ambitious, genuine, and romantic connection.',
        crushCount: 62,
        crushesCount: 14,
        crushedUserIds: ['user_verified_king'],
        isBoosted: false,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      PostModel(
        id: 'post_fu_1',
        userId: userFU.id,
        username: userFU.username,
        userProfilePic: userFU.profilePicUrl,
        userIsVerified: userFU.isVerified,
        userIsOnline: userFU.isOnline,
        userLastSeen: userFU.lastSeen,
        userCountry: userFU.country,
        userCity: userFU.city,
        community: 'Casual Meet',
        lookingFor: 'Friendship',
        location: 'Milimani, Kisumu',
        ageRangeMin: 19,
        ageRangeMax: 28,
        availability: 'Weekend',
        description: 'Lover of lakeside sunsets and fish dinners. Who is free for a relaxed chat and coffee this weekend?',
        crushCount: 18,
        crushesCount: 3,
        crushedUserIds: [],
        isBoosted: false,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
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
        crushedUserIds: ['user_kevin', 'user_4'],
        isBoosted: false,
        createdAt: now.subtract(const Duration(hours: 4)),
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
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      PostModel(
        id: 'post_3',
        userId: user5.id,
        username: user5.username,
        userProfilePic: user5.profilePicUrl,
        userIsVerified: user5.isVerified,
        userIsOnline: user5.isOnline,
        userLastSeen: user5.lastSeen,
        userCountry: user5.country,
        userCity: user5.city,
        community: 'Weekend Meet',
        lookingFor: 'Coffee Date',
        location: 'Lavington, Nairobi',
        ageRangeMin: 25,
        ageRangeMax: 45,
        availability: 'Weekend',
        description: 'Fine dining, luxury lifestyle and weekend lounge plans. Serious people only.',
        crushCount: 88,
        crushesCount: 19,
        crushedUserIds: ['user_premium_verified'],
        isBoosted: false,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
    ]);

    // Seed EXACT 6 Mock Active Connections
    final conn1 = ConnectionModel(
      id: 'conn_1',
      senderId: 'current_user_1',
      senderUsername: 'alex_ke',
      senderProfilePic: currentUser.profilePicUrl,
      recipientId: user2.id,
      recipientUsername: user2.username,
      recipientProfilePic: user2.profilePicUrl,
      status: ConnectionStatus.accepted,
      priceKES: 50.0,
      recipientContactMethod: user2.preferredContactMethod,
      recipientContactDetails: user2.contactDetails,
      createdAt: now.subtract(const Duration(hours: 2)),
      respondedAt: now.subtract(const Duration(hours: 1)),
    );

    final conn2 = ConnectionModel(
      id: 'conn_2',
      senderId: user5.id,
      senderUsername: user5.username,
      senderProfilePic: user5.profilePicUrl,
      recipientId: 'current_user_1',
      recipientUsername: 'alex_ke',
      recipientProfilePic: currentUser.profilePicUrl,
      status: ConnectionStatus.accepted,
      priceKES: 50.0,
      recipientContactMethod: currentUser.preferredContactMethod,
      recipientContactDetails: currentUser.contactDetails,
      createdAt: now.subtract(const Duration(hours: 4)),
      respondedAt: now.subtract(const Duration(hours: 3)),
    );

    final conn3 = ConnectionModel(
      id: 'conn_3',
      senderId: 'current_user_1',
      senderUsername: 'alex_ke',
      senderProfilePic: currentUser.profilePicUrl,
      recipientId: user4.id,
      recipientUsername: user4.username,
      recipientProfilePic: user4.profilePicUrl,
      status: ConnectionStatus.accepted,
      priceKES: 50.0,
      recipientContactMethod: user4.preferredContactMethod,
      recipientContactDetails: user4.contactDetails,
      createdAt: now.subtract(const Duration(hours: 6)),
      respondedAt: now.subtract(const Duration(hours: 5)),
    );

    final conn4 = ConnectionModel(
      id: 'conn_4',
      senderId: userKevin.id,
      senderUsername: userKevin.username,
      senderProfilePic: userKevin.profilePicUrl,
      recipientId: 'current_user_1',
      recipientUsername: 'alex_ke',
      recipientProfilePic: currentUser.profilePicUrl,
      status: ConnectionStatus.accepted,
      priceKES: 50.0,
      recipientContactMethod: currentUser.preferredContactMethod,
      recipientContactDetails: currentUser.contactDetails,
      createdAt: now.subtract(const Duration(hours: 12)),
      respondedAt: now.subtract(const Duration(hours: 10)),
    );

    final conn5 = ConnectionModel(
      id: 'conn_5',
      senderId: userMercy.id,
      senderUsername: userMercy.username,
      senderProfilePic: userMercy.profilePicUrl,
      recipientId: 'current_user_1',
      recipientUsername: 'alex_ke',
      recipientProfilePic: currentUser.profilePicUrl,
      status: ConnectionStatus.accepted,
      priceKES: 50.0,
      recipientContactMethod: currentUser.preferredContactMethod,
      recipientContactDetails: currentUser.contactDetails,
      createdAt: now.subtract(const Duration(hours: 18)),
      respondedAt: now.subtract(const Duration(hours: 15)),
    );

    final conn6 = ConnectionModel(
      id: 'conn_6',
      senderId: 'current_user_1',
      senderUsername: 'alex_ke',
      senderProfilePic: currentUser.profilePicUrl,
      recipientId: userBrian.id,
      recipientUsername: userBrian.username,
      recipientProfilePic: userBrian.profilePicUrl,
      status: ConnectionStatus.accepted,
      priceKES: 50.0,
      recipientContactMethod: userBrian.preferredContactMethod,
      recipientContactDetails: userBrian.contactDetails,
      createdAt: now.subtract(const Duration(days: 1)),
      respondedAt: now.subtract(const Duration(hours: 20)),
    );

    _connections.addAll([conn1, conn2, conn3, conn4, conn5, conn6]);

    // Seed Chat Messages for the 6 Connections
    _chatMessages.addAll([
      // 1. @sarah_k — 2 unread
      ChatMessageModel(
        id: 'msg_1_1',
        connectionId: 'conn_1',
        senderId: 'current_user_1',
        recipientId: user2.id,
        message: 'Hey Sarah, hope your day is going well!',
        timestamp: now.subtract(const Duration(minutes: 15)),
        isRead: true,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
      ChatMessageModel(
        id: 'msg_1_2',
        connectionId: 'conn_1',
        senderId: user2.id,
        recipientId: 'current_user_1',
        message: 'Hey 😊, are we still meeting tonight?',
        timestamp: now.subtract(const Duration(minutes: 2)),
        isRead: false,
        deliveryStatus: MessageDeliveryStatus.delivered,
      ),

      // 2. @chloe_w — Active 5m ago
      ChatMessageModel(
        id: 'msg_2_1',
        connectionId: 'conn_2',
        senderId: 'current_user_1',
        recipientId: user5.id,
        message: 'I told them the story about yesterday haha',
        timestamp: now.subtract(const Duration(minutes: 20)),
        isRead: true,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
      ChatMessageModel(
        id: 'msg_2_2',
        connectionId: 'conn_2',
        senderId: user5.id,
        recipientId: 'current_user_1',
        message: 'Haha, you really made me laugh.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        isRead: true,
        deliveryStatus: MessageDeliveryStatus.read,
      ),

      // 3. @anita_x — 1 unread
      ChatMessageModel(
        id: 'msg_3_1',
        connectionId: 'conn_3',
        senderId: user4.id,
        recipientId: 'current_user_1',
        message: 'I enjoyed our conversation.',
        timestamp: now.subtract(const Duration(minutes: 12)),
        isRead: false,
        deliveryStatus: MessageDeliveryStatus.delivered,
      ),

      // 4. @kevin_m — Active 1h ago
      ChatMessageModel(
        id: 'msg_4_1',
        connectionId: 'conn_4',
        senderId: 'current_user_1',
        recipientId: userKevin.id,
        message: 'Are you free for mountain biking this Saturday?',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 15)),
        isRead: true,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
      ChatMessageModel(
        id: 'msg_4_2',
        connectionId: 'conn_4',
        senderId: userKevin.id,
        recipientId: 'current_user_1',
        message: 'Let\'s plan something for Saturday.',
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: true,
        deliveryStatus: MessageDeliveryStatus.read,
      ),

      // 5. @mercy_n — Active 3h ago
      ChatMessageModel(
        id: 'msg_5_1',
        connectionId: 'conn_5',
        senderId: userMercy.id,
        recipientId: 'current_user_1',
        message: 'Good night ❤️',
        timestamp: now.subtract(const Duration(hours: 3)),
        isRead: true,
        deliveryStatus: MessageDeliveryStatus.read,
      ),

      // 6. @brian_t — Active yesterday
      ChatMessageModel(
        id: 'msg_6_1',
        connectionId: 'conn_6',
        senderId: userBrian.id,
        recipientId: 'current_user_1',
        message: 'Nice meeting you here.',
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: true,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
    ]);
  }

  // --- USER, FOLLOW, BLOCK & REPORT API ---
  UserModel? getUser(String userId) => _users[userId];

  void updateUser(UserModel user) {
    _users[user.id] = user;
    notifyListeners();
  }

  void deleteUser(String userId) {
    _users.remove(userId);
    _posts.removeWhere((p) => p.userId == userId);
    _connections.removeWhere((c) => c.senderId == userId || c.recipientId == userId);
    _chatMessages.removeWhere((m) => m.senderId == userId || m.recipientId == userId);
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
        body: 'Your report against user ID $reportedId ($reason) has been received and is under review.',
      ),
    );
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
      }
      notifyListeners();
    }
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
  void createPost(PostModel post) {
    _posts.insert(0, post);
    notifyListeners();
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

  // --- CONNECTION API ---
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
      status: ConnectionStatus.accepted,
      priceKES: priceKES,
      isPremiumFree: isPremiumFree,
      recipientContactMethod: recipient.preferredContactMethod,
      recipientContactDetails: recipient.contactDetails,
    );

    _connections.insert(0, connection);
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
      notifyListeners();
    }
  }

  // --- CHAT MESSAGES API & DELETION ---
  List<ChatMessageModel> getChatMessages(String connectionId, {String? userId}) {
    return _chatMessages.where((m) {
      if (m.connectionId != connectionId) return false;
      if (userId != null && m.deletedForUserIds.contains(userId)) return false;
      return true;
    }).toList();
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
        _chatMessages[index] = msg.copyWith(deletedForUserIds: updatedDeletedFor);
        notifyListeners();
      }
    }
  }

  void deleteMessageForEveryone(String messageId) {
    final index = _chatMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final msg = _chatMessages[index];
      _chatMessages[index] = msg.copyWith(
        message: 'Message deleted',
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
}
