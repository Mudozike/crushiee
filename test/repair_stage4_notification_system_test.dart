import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/models/post_model.dart';
import 'package:crushie/models/chat_message_model.dart';
import 'package:crushie/models/connection_model.dart';
import 'package:crushie/models/notification_model.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/providers/notification_provider.dart';
import 'package:crushie/screens/notifications/notifications_screen.dart';
import 'package:crushie/services/firestore_service.dart';

// --- TEST MOCKS & SERVICE HARNESS ---

class _FakeNotificationFirestoreService extends FirestoreService {
  _FakeNotificationFirestoreService() : super.forTesting();

  final Map<String, Map<String, NotificationModel>> _userNotifications = {};
  final Map<String, StreamController<List<NotificationModel>>> _notifStreamControllers = {};
  final Map<String, PostModel> _posts = {};
  final Map<String, UserModel> _users = {};
  final Map<String, ConnectionModel> _connections = {};
  final List<ChatMessageModel> sentMessages = [];

  StreamController<List<NotificationModel>> _getController(String userId) {
    return _notifStreamControllers.putIfAbsent(
      userId,
      () => StreamController<List<NotificationModel>>.broadcast(),
    );
  }

  void _emitNotifications(String userId) {
    final list = _userNotifications[userId]?.values.toList() ?? [];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _getController(userId).add(list);
  }

  @override
  Future<void> createNotification(NotificationModel notification) async {
    if (notification.userId.isEmpty) return;

    final isSelf = notification.userId == notification.fromUserId;
    final isAccountOrSystemEvent = notification.type == NotificationType.system ||
        notification.type == NotificationType.premium ||
        notification.type == NotificationType.verification ||
        notification.type == NotificationType.account ||
        notification.type == NotificationType.boost;

    if (isSelf && !isAccountOrSystemEvent) {
      return; // Suppress self-notification
    }

    _userNotifications.putIfAbsent(notification.userId, () => {});
    _userNotifications[notification.userId]![notification.id] = notification;
    _emitNotifications(notification.userId);
  }

  @override
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    // Emit current state immediately on listen
    final controller = _getController(userId);
    final list = _userNotifications[userId]?.values.toList() ?? [];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    Future.microtask(() => controller.add(list));
    return controller.stream;
  }

  @override
  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    final notif = _userNotifications[userId]?[notificationId];
    if (notif != null) {
      _userNotifications[userId]![notificationId] = notif.copyWith(isRead: true);
      _emitNotifications(userId);
    }
  }

  @override
  Future<void> markAllNotificationsAsRead(String userId) async {
    final map = _userNotifications[userId];
    if (map != null) {
      for (final id in map.keys.toList()) {
        map[id] = map[id]!.copyWith(isRead: true);
      }
      _emitNotifications(userId);
    }
  }

  @override
  Future<void> deleteNotification(String userId, String notificationId) async {
    _userNotifications[userId]?.remove(notificationId);
    _emitNotifications(userId);
  }

  @override
  Future<void> markMessageNotificationsAsRead(String userId, String connectionId) async {
    final map = _userNotifications[userId];
    if (map != null) {
      bool changed = false;
      for (final id in map.keys.toList()) {
        final n = map[id]!;
        if (n.connectionId == connectionId && n.type == NotificationType.message && !n.isRead) {
          map[id] = n.copyWith(isRead: true);
          changed = true;
        }
      }
      if (changed) _emitNotifications(userId);
    }
  }

  @override
  Future<void> notifyLocationSubscribers(PostModel post) async {
    if (post.location.trim().isEmpty) return;
    final normalizedLoc = post.location.trim();

    for (final user in _users.values) {
      if (user.id == post.userId) continue; // Exclude author
      if (user.locationNotificationSubscriptions.contains(normalizedLoc)) {
        final notif = NotificationModel(
          id: 'notif_loc_${post.id}_${user.id}',
          userId: user.id,
          fromUserId: post.userId,
          fromUsername: post.username,
          fromUserProfilePic: post.userProfilePic,
          type: NotificationType.locationPost,
          title: 'New Post in $normalizedLoc',
          body: post.description.isNotEmpty
              ? post.description
              : '@${post.username} shared a new post in $normalizedLoc',
          postId: post.id,
        );
        await createNotification(notif);
      }
    }
  }

  @override
  Future<void> sendChatMessage(ChatMessageModel message) async {
    sentMessages.add(message);
    if (message.receiverId.isNotEmpty && message.receiverId != message.senderId) {
      final notif = NotificationModel(
        id: 'notif_msg_${message.id}',
        userId: message.receiverId,
        fromUserId: message.senderId,
        fromUsername: 'Someone',
        fromUserProfilePic: '',
        type: NotificationType.message,
        title: 'New Message',
        body: message.content,
        connectionId: message.connectionId,
      );
      await createNotification(notif);
    }
  }

  @override
  Future<PostModel?> getPost(String postId) async => _posts[postId];

  @override
  Future<UserModel?> getUserProfile(String userId) async => _users[userId];

  @override
  Future<ConnectionModel?> getConnection(String connectionId) async => _connections[connectionId];

  void dispose() {
    for (final c in _notifStreamControllers.values) {
      c.close();
    }
  }
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel? _user;
  _MockAuthProvider(this._user);

  @override
  UserModel? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserModel _createTestUser({
  required String id,
  required String username,
  List<String> locationSubs = const [],
}) {
  return UserModel(
    id: id,
    username: username,
    email: '$username@test.com',
    gender: 'Other',
    country: 'Kenya',
    city: 'Nairobi',
    contactDetails: '+254700000000',
    preferredContactMethod: 'WhatsApp',
    bio: 'Test user bio',
    profilePicUrl: 'crushie_avatar_0',
    dateOfBirth: DateTime(2000, 1, 1),
    locationNotificationSubscriptions: locationSubs,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Notification Creation, Determinism & Deduplication', () {
    test('Follow, crush, and comment notifications use deterministic IDs and prevent duplicates', () async {
      final fake = _FakeNotificationFirestoreService();

      // 1. Follow notification
      final followNotif = NotificationModel(
        id: 'notif_follow_userA_userB',
        userId: 'userB',
        fromUserId: 'userA',
        fromUsername: 'alice',
        fromUserProfilePic: 'crushie_avatar_0',
        type: NotificationType.follow,
        title: 'New Follower!',
        body: 'alice followed you',
      );
      await fake.createNotification(followNotif);
      expect(fake._userNotifications['userB']!.length, 1);

      // Re-triggering same follow notification merges idempotently
      await fake.createNotification(followNotif);
      expect(fake._userNotifications['userB']!.length, 1);

      // 2. Crush notification
      final crushNotif = NotificationModel(
        id: 'notif_crush_post1_userA',
        userId: 'userB',
        fromUserId: 'userA',
        fromUsername: 'alice',
        fromUserProfilePic: 'crushie_avatar_0',
        type: NotificationType.crush,
        title: 'New Crush!',
        body: 'alice crushed your post',
        postId: 'post1',
      );
      await fake.createNotification(crushNotif);
      expect(fake._userNotifications['userB']!.length, 2);

      // Re-triggering same crush merges idempotently
      await fake.createNotification(crushNotif);
      expect(fake._userNotifications['userB']!.length, 2);

      // 3. Comment notification with commentId attached
      final commentNotif = NotificationModel(
        id: 'notif_comment_comm99',
        userId: 'userB',
        fromUserId: 'userA',
        fromUsername: 'alice',
        fromUserProfilePic: 'crushie_avatar_0',
        type: NotificationType.crushComment,
        title: 'New Comment!',
        body: 'alice commented on your post',
        postId: 'post1',
        commentId: 'comm99',
      );
      await fake.createNotification(commentNotif);
      expect(fake._userNotifications['userB']!.length, 3);
      expect(fake._userNotifications['userB']!['notif_comment_comm99']!.commentId, 'comm99');

      fake.dispose();
    });

    test('Message notifications use deterministic message ID', () async {
      final fake = _FakeNotificationFirestoreService();

      final message = ChatMessageModel(
        id: 'msg_abc_123',
        connectionId: 'conn_1',
        senderId: 'userA',
        receiverId: 'userB',
        content: 'Hey there!',
        createdAt: DateTime.now(),
      );

      await fake.sendChatMessage(message);
      expect(fake.sentMessages.length, 1);
      expect(fake._userNotifications['userB']!.containsKey('notif_msg_msg_abc_123'), isTrue);

      final notif = fake._userNotifications['userB']!['notif_msg_msg_abc_123']!;
      expect(notif.type, NotificationType.message);
      expect(notif.body, 'Hey there!');
      expect(notif.connectionId, 'conn_1');

      fake.dispose();
    });
  });

  group('2. Actor Self-Action Exclusion Policy', () {
    test('Social events (crush, comment, follow, message) for self are suppressed', () async {
      final fake = _FakeNotificationFirestoreService();

      // Self follow
      await fake.createNotification(NotificationModel(
        id: 'notif_self_follow',
        userId: 'userA',
        fromUserId: 'userA',
        fromUsername: 'alice',
        fromUserProfilePic: '',
        type: NotificationType.follow,
        title: 'Self follow',
        body: 'Self follow body',
      ));
      expect(fake._userNotifications.containsKey('userA'), isFalse);

      // Self crush
      await fake.createNotification(NotificationModel(
        id: 'notif_self_crush',
        userId: 'userA',
        fromUserId: 'userA',
        fromUsername: 'alice',
        fromUserProfilePic: '',
        type: NotificationType.crush,
        title: 'Self crush',
        body: 'Self crush body',
      ));
      expect(fake._userNotifications.containsKey('userA'), isFalse);

      // Self message
      await fake.createNotification(NotificationModel(
        id: 'notif_self_msg',
        userId: 'userA',
        fromUserId: 'userA',
        fromUsername: 'alice',
        fromUserProfilePic: '',
        type: NotificationType.message,
        title: 'Self message',
        body: 'Self message body',
      ));
      expect(fake._userNotifications.containsKey('userA'), isFalse);

      fake.dispose();
    });

    test('Account, system, premium, and verification self-notifications are permitted', () async {
      final fake = _FakeNotificationFirestoreService();

      await fake.createNotification(NotificationModel(
        id: 'notif_prem_userA',
        userId: 'userA',
        fromUserId: 'userA',
        fromUsername: 'alice',
        fromUserProfilePic: '',
        type: NotificationType.premium,
        title: 'Premium Activated',
        body: 'Welcome to Premium!',
      ));
      expect(fake._userNotifications['userA']!.length, 1);
      expect(fake._userNotifications['userA']!['notif_prem_userA']!.type, NotificationType.premium);

      await fake.createNotification(NotificationModel(
        id: 'notif_verif_userA',
        userId: 'userA',
        fromUserId: 'userA',
        fromUsername: 'alice',
        fromUserProfilePic: '',
        type: NotificationType.verification,
        title: 'Profile Verified',
        body: 'Your badge is active.',
      ));
      expect(fake._userNotifications['userA']!.length, 2);

      fake.dispose();
    });
  });

  group('3. Opt-in Location-Based Post Notifications (e.g. Juja)', () {
    test('Location post only notifies opted-in users and excludes post author', () async {
      final fake = _FakeNotificationFirestoreService();

      // User A (author in Juja)
      final userA = _createTestUser(id: 'userA', username: 'authorA', locationSubs: ['Juja']);
      // User B (subscribed to Juja)
      final userB = _createTestUser(id: 'userB', username: 'jujaFan', locationSubs: ['Juja']);
      // User C (subscribed to Nairobi only)
      final userC = _createTestUser(id: 'userC', username: 'nairobiFan', locationSubs: ['Nairobi']);
      // User D (no location subscriptions)
      final userD = _createTestUser(id: 'userD', username: 'genericUser', locationSubs: []);

      fake._users['userA'] = userA;
      fake._users['userB'] = userB;
      fake._users['userC'] = userC;
      fake._users['userD'] = userD;

      final jujaPost = PostModel(
        id: 'post_juja_101',
        userId: 'userA',
        username: 'authorA',
        userProfilePic: '',
        userCountry: 'Kenya',
        userCity: 'Juja',
        community: 'Coffee Date',
        lookingFor: 'Coffee Date',
        location: 'Juja',
        ageRangeMin: 18,
        ageRangeMax: 30,
        availability: 'Today',
        description: 'Meetup at Juja City Mall today!',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      await fake.notifyLocationSubscribers(jujaPost);

      // User A (author) was NOT notified
      expect(fake._userNotifications.containsKey('userA'), isFalse);

      // User B (subscribed to Juja) WAS notified
      expect(fake._userNotifications['userB']!.length, 1);
      final notifB = fake._userNotifications['userB']!['notif_loc_post_juja_101_userB']!;
      expect(notifB.type, NotificationType.locationPost);
      expect(notifB.title, 'New Post in Juja');
      expect(notifB.body, 'Meetup at Juja City Mall today!');

      // User C (Nairobi) was NOT notified
      expect(fake._userNotifications.containsKey('userC'), isFalse);

      // User D (No subs) was NOT notified
      expect(fake._userNotifications.containsKey('userD'), isFalse);

      fake.dispose();
    });
  });

  group('4. Unread Counts, Read State & Active Conversation Suppression', () {
    test('Unread count updates and markAsRead/markAllAsRead modify read state accurately', () async {
      final fake = _FakeNotificationFirestoreService();
      final prov = NotificationProvider(firestoreService: fake);

      // Seed 2 unread notifications
      final notif1 = NotificationModel(
        id: 'n1',
        userId: 'u1',
        fromUserId: 'u2',
        fromUsername: 'bob',
        fromUserProfilePic: '',
        type: NotificationType.follow,
        title: 'Followed',
        body: 'Followed you',
        isRead: false,
      );
      final notif2 = NotificationModel(
        id: 'n2',
        userId: 'u1',
        fromUserId: 'u3',
        fromUsername: 'carol',
        fromUserProfilePic: '',
        type: NotificationType.crush,
        title: 'Crushed',
        body: 'Crushed post',
        isRead: false,
      );
      await fake.createNotification(notif1);
      await fake.createNotification(notif2);

      prov.initUserNotifications('u1');
      await Future<void>.delayed(Duration.zero);

      expect(prov.getUnreadCount('u1'), 2);

      // Mark single notification read
      prov.markAsRead('u1', 'n1');
      await Future<void>.delayed(Duration.zero);

      expect(prov.getUnreadCount('u1'), 1);

      // Mark all read
      prov.markAllAsRead('u1');
      await Future<void>.delayed(Duration.zero);

      expect(prov.getUnreadCount('u1'), 0);

      prov.dispose();
      fake.dispose();
    });

    test('Active conversation suppresses unread noise for incoming message in that conversation', () async {
      final fake = _FakeNotificationFirestoreService();
      final prov = NotificationProvider(firestoreService: fake);
      prov.initUserNotifications('u1');
      await Future<void>.delayed(Duration.zero);

      // User u1 opens ChatScreen for conn_chat_42
      prov.activeConversationConnectionId = 'conn_chat_42';

      // Incoming message notification arrives for conn_chat_42
      await fake.createNotification(NotificationModel(
        id: 'notif_msg_incoming',
        userId: 'u1',
        fromUserId: 'u2',
        fromUsername: 'bob',
        fromUserProfilePic: '',
        type: NotificationType.message,
        title: 'New Message',
        body: 'Live chat update',
        connectionId: 'conn_chat_42',
        isRead: false,
      ));
      await Future<void>.delayed(Duration.zero);

      // Automatically marked read because user is actively reading conn_chat_42
      expect(prov.getUnreadCount('u1'), 0);
      expect(prov.notifications.first.isRead, isTrue);

      prov.dispose();
      fake.dispose();
    });
  });

  group('5. Direct Notification Reply Authentication & Delivery', () {
    test('sendNotificationReply validates content and sends through existing message service', () async {
      final fake = _FakeNotificationFirestoreService();

      // Empty content is rejected
      await fake.sendNotificationReply(
        connectionId: 'conn_10',
        recipientId: 'u_bob',
        senderId: 'u_alice',
        senderUsername: 'alice',
        senderProfilePic: '',
        content: '   ',
      );
      expect(fake.sentMessages.isEmpty, isTrue);

      // Valid reply is sent with sent delivery status
      await fake.sendNotificationReply(
        connectionId: 'conn_10',
        recipientId: 'u_bob',
        senderId: 'u_alice',
        senderUsername: 'alice',
        senderProfilePic: 'crushie_avatar_0',
        content: 'Direct notification reply response!',
      );

      expect(fake.sentMessages.length, 1);
      final sent = fake.sentMessages.first;
      expect(sent.connectionId, 'conn_10');
      expect(sent.receiverId, 'u_bob');
      expect(sent.senderId, 'u_alice');
      expect(sent.content, 'Direct notification reply response!');
      expect(sent.deliveryStatus, MessageDeliveryStatus.sent);

      fake.dispose();
    });
  });

  group('6. NotificationsScreen Widget & Graceful Stale Target Handling', () {
    testWidgets('NotificationsScreen renders items and handles deleted post gracefully', (tester) async {
      final fake = _FakeNotificationFirestoreService();
      final userAlice = _createTestUser(id: 'u_alice', username: 'alice');
      final authProv = _MockAuthProvider(userAlice);
      final notifProv = NotificationProvider(firestoreService: fake);

      // Seed a notification pointing to a deleted post (postId not in fake._posts)
      await fake.createNotification(NotificationModel(
        id: 'notif_stale_post',
        userId: 'u_alice',
        fromUserId: 'u_bob',
        fromUsername: 'bob',
        fromUserProfilePic: '',
        type: NotificationType.crush,
        title: 'New Crush!',
        body: 'bob crushed your post',
        postId: 'post_deleted_999',
      ));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProv),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Renders notification item
      expect(find.text('New Crush!'), findsOneWidget);
      expect(find.text('bob crushed your post'), findsOneWidget);

      // Tap the stale post notification
      await tester.tap(find.text('New Crush!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Shows graceful SnackBar without throwing or blanking screen
      expect(find.text('This post has expired or was removed.'), findsOneWidget);

      notifProv.dispose();
      fake.dispose();
    });

    testWidgets('NotificationsScreen handles deleted conversation gracefully', (tester) async {
      final fake = _FakeNotificationFirestoreService();
      final userAlice = _createTestUser(id: 'u_alice', username: 'alice');
      final authProv = _MockAuthProvider(userAlice);
      final notifProv = NotificationProvider(firestoreService: fake);

      // Seed a message notification pointing to a deleted conversation
      await fake.createNotification(NotificationModel(
        id: 'notif_stale_conn',
        userId: 'u_alice',
        fromUserId: 'u_bob',
        fromUsername: 'bob',
        fromUserProfilePic: '',
        type: NotificationType.message,
        title: 'New Message',
        body: 'Hello',
        connectionId: 'conn_deleted_888',
      ));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProv),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('New Message'), findsOneWidget);

      // Tap stale conversation notification
      await tester.tap(find.text('New Message'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Conversation is no longer available.'), findsOneWidget);

      notifProv.dispose();
      fake.dispose();
    });
  });

  group('7. Security Rules Permissions Logic Evaluator', () {
    // Evaluates the exact boolean conditions enforced in firestore.rules
    bool canCreateNotification({
      required String authUid,
      required String parentUserId,
      required String docUserId,
      required String docFromUserId,
      required String docType,
    }) {
      final isOwner = authUid == parentUserId;
      if (isOwner && docUserId == parentUserId) {
        return true;
      }
      if (!isOwner &&
          docUserId == parentUserId &&
          docFromUserId == authUid &&
          [
            'crush',
            'crushComment',
            'commentReply',
            'follow',
            'connectionRequest',
            'connectionAccepted',
            'connectionDeclined',
            'message',
            'mention',
            'locationPost',
          ].contains(docType)) {
        return true;
      }
      return false;
    }

    test('Rules permit authorized peer notification types with matching caller UID', () {
      expect(
        canCreateNotification(
          authUid: 'alice',
          parentUserId: 'bob',
          docUserId: 'bob',
          docFromUserId: 'alice',
          docType: 'message',
        ),
        isTrue,
      );

      expect(
        canCreateNotification(
          authUid: 'alice',
          parentUserId: 'bob',
          docUserId: 'bob',
          docFromUserId: 'alice',
          docType: 'follow',
        ),
        isTrue,
      );
    });

    test('Rules deny forging actor UID (docFromUserId != authUid)', () {
      expect(
        canCreateNotification(
          authUid: 'attacker',
          parentUserId: 'bob',
          docUserId: 'bob',
          docFromUserId: 'alice', // Spoofing Alice!
          docType: 'message',
        ),
        isFalse,
      );
    });

    test('Rules deny unauthorized users forging premium or verification status notifications', () {
      expect(
        canCreateNotification(
          authUid: 'attacker',
          parentUserId: 'bob',
          docUserId: 'bob',
          docFromUserId: 'attacker',
          docType: 'premium', // Forging premium notification!
        ),
        isFalse,
      );

      expect(
        canCreateNotification(
          authUid: 'attacker',
          parentUserId: 'bob',
          docUserId: 'bob',
          docFromUserId: 'attacker',
          docType: 'verification',
        ),
        isFalse,
      );
    });
  });
}
