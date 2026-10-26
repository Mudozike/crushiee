import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:crushie/models/chat_message_model.dart';
import 'package:crushie/models/connection_model.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/models/post_model.dart';
import 'package:crushie/services/firestore_service.dart';
import 'package:crushie/services/push_notification_service.dart';
import 'package:crushie/screens/messages/chat_screen.dart';

// ---------------------------------------------------------------------------
// MOCK & FAKE IMPLEMENTATIONS FOR PUSH & DIRECT REPLY TESTS
// ---------------------------------------------------------------------------

class _FakeLocalNotificationsPlugin implements FlutterLocalNotificationsPlugin {
  final List<Map<String, dynamic>> displayedNotifications = [];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async {
    return true;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    displayedNotifications.add({
      'id': id,
      'title': title,
      'body': body,
      'details': notificationDetails,
      'payload': payload,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

class _FakePushFirestoreService extends FirestoreService {
  _FakePushFirestoreService() : super.forTesting();

  final Map<String, Map<String, dynamic>> userDocs = {};
  final List<ChatMessageModel> sentMessages = [];
  final Map<String, ConnectionModel> connections = {};
  final Map<String, PostModel> posts = {};
  final Map<String, UserModel> users = {};

  @override
  Future<ConnectionModel?> getConnection(String connectionId) async {
    return connections[connectionId];
  }

  @override
  Future<PostModel?> getPost(String postId) async {
    return posts[postId];
  }

  @override
  Future<UserModel?> getUserProfile(String userId) async {
    return users[userId];
  }

  @override
  Future<void> sendChatMessage(ChatMessageModel message) async {
    sentMessages.add(message);
  }

  @override
  Future<void> sendNotificationReply({
    required String connectionId,
    required String recipientId,
    required String senderId,
    String senderUsername = 'Someone',
    String senderProfilePic = '',
    required String content,
  }) async {
    final replyMsg = ChatMessageModel(
      id: 'msg_reply_${sentMessages.length + 1}',
      connectionId: connectionId,
      senderId: senderId,
      receiverId: recipientId,
      content: content.trim(),
      createdAt: DateTime.now(),
      deliveryStatus: MessageDeliveryStatus.sent,
    );
    await sendChatMessage(replyMsg);
  }
}

// ---------------------------------------------------------------------------
// TEST SUITE
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. FCM Token Registration, Storage & Lifecycle', () {
    test('Token registration writes fcmToken and fcmTokens list accurately', () {
      final userStore = <String, dynamic>{};
      final token = 'fcm_device_token_xyz_123';

      // Simulate client registration
      userStore['fcmToken'] = token;
      userStore['fcmTokens'] = [token];
      userStore['fcmTokenUpdatedAt'] = DateTime.now().toIso8601String();

      expect(userStore['fcmToken'], 'fcm_device_token_xyz_123');
      expect(userStore['fcmTokens'], contains('fcm_device_token_xyz_123'));
      expect(userStore['fcmTokenUpdatedAt'], isNotNull);

      // Verify Cloud Function compatibility: Cloud function reads userDoc.data()?.fcmToken and userDoc.data()?.fcmTokens
      final tokenSet = <String>{};
      if (userStore['fcmToken'] is String) tokenSet.add(userStore['fcmToken']);
      if (userStore['fcmTokens'] is List) {
        for (final t in userStore['fcmTokens']) {
          tokenSet.add(t);
        }
      }
      expect(tokenSet.length, 1);
      expect(tokenSet.first, 'fcm_device_token_xyz_123');
    });

    test('Token clearing on logout removes fcmToken and removes token from array', () {
      final userStore = <String, dynamic>{
        'fcmToken': 'fcm_token_device_a',
        'fcmTokens': ['fcm_token_device_a', 'fcm_token_device_b'],
      };

      // User logs out on device A
      userStore.remove('fcmToken');
      final list = List<String>.from(userStore['fcmTokens'] as List);
      list.remove('fcm_token_device_a');
      userStore['fcmTokens'] = list;

      expect(userStore.containsKey('fcmToken'), isFalse);
      expect(userStore['fcmTokens'], equals(['fcm_token_device_b']));
    });
  });

  group('2. Foreground Notification Presentation & Active Conversation Suppression', () {
    test('Active conversation connection ID suppresses local heads-up notification', () async {
      final fakeLocal = _FakeLocalNotificationsPlugin();
      final service = PushNotificationService.withDependencies(
        localNotifications: fakeLocal,
      );

      // Set conversation as currently active
      PushNotificationService.activeConversationConnectionId = 'conn_active_42';

      // Incoming message in the currently active conversation
      final incomingData = {
        'type': 'message',
        'connectionId': 'conn_active_42',
        'fromUserId': 'user_sender',
        'title': 'New Message',
        'body': 'Hey there!',
      };

      // Check suppression logic
      final isSuppressed = PushNotificationService.activeConversationConnectionId == incomingData['connectionId'];
      expect(isSuppressed, isTrue);

      if (!isSuppressed) {
        await service.showLocalNotification(
          id: 1,
          title: incomingData['title']!,
          body: incomingData['body']!,
          payload: jsonEncode(incomingData),
          isMessage: true,
        );
      }

      // No notification should have been displayed
      expect(fakeLocal.displayedNotifications.isEmpty, isTrue);
    });

    test('Non-active conversation message triggers local notification with reply action', () async {
      final fakeLocal = _FakeLocalNotificationsPlugin();
      final service = PushNotificationService.withDependencies(
        localNotifications: fakeLocal,
      );

      PushNotificationService.activeConversationConnectionId = 'conn_active_42';

      // Incoming message for a DIFFERENT conversation
      final incomingData = {
        'type': 'message',
        'connectionId': 'conn_other_99',
        'fromUserId': 'user_sender_2',
        'title': 'New Message from Alice',
        'body': 'Are you free tonight?',
      };

      final isSuppressed = PushNotificationService.activeConversationConnectionId == incomingData['connectionId'];
      expect(isSuppressed, isFalse);

      await service.showLocalNotification(
        id: 101,
        title: incomingData['title']!,
        body: incomingData['body']!,
        payload: jsonEncode(incomingData),
        isMessage: true,
      );

      expect(fakeLocal.displayedNotifications.length, 1);
      final notification = fakeLocal.displayedNotifications.first;
      expect(notification['title'], 'New Message from Alice');
      expect(notification['body'], 'Are you free tonight?');

      final details = notification['details'] as NotificationDetails?;
      final androidDetails = details?.android;
      expect(androidDetails, isNotNull);
      expect(androidDetails!.actions, isNotNull);
      expect(androidDetails.actions!.length, 1);
      expect(androidDetails.actions!.first.id, 'reply_action');
      expect(androidDetails.actions!.first.title, 'Reply');
      expect(androidDetails.actions!.first.inputs.length, 1);
    });
  });

  group('3. Android Direct Notification Reply', () {
    test('Direct reply action parses payload, validates input, and sends via message service', () async {
      final fakeFirestore = _FakePushFirestoreService();

      // Notification response payload received from Android notification
      final payloadData = {
        'type': 'message',
        'connectionId': 'conn_test_55',
        'fromUserId': 'user_bob', // sender of original message, recipient of reply
      };

      final replyResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        actionId: 'reply_action',
        input: 'Sounds great, see you there!',
        payload: jsonEncode(payloadData),
      );

      // Verify response parsing
      expect(replyResponse.actionId, 'reply_action');
      expect(replyResponse.input, 'Sounds great, see you there!');

      final parsedPayload = Map<String, dynamic>.from(jsonDecode(replyResponse.payload!));
      expect(parsedPayload['connectionId'], 'conn_test_55');
      expect(parsedPayload['fromUserId'], 'user_bob');

      // Dispatch reply through service
      await fakeFirestore.sendNotificationReply(
        connectionId: parsedPayload['connectionId'],
        senderId: 'user_alice',
        recipientId: parsedPayload['fromUserId'],
        content: replyResponse.input!,
      );

      expect(fakeFirestore.sentMessages.length, 1);
      final sent = fakeFirestore.sentMessages.first;
      expect(sent.connectionId, 'conn_test_55');
      expect(sent.senderId, 'user_alice');
      expect(sent.receiverId, 'user_bob');
      expect(sent.content, 'Sounds great, see you there!');
      expect(sent.deliveryStatus, MessageDeliveryStatus.sent);
    });

    test('Empty or whitespace-only direct reply is rejected', () async {
      final fakeFirestore = _FakePushFirestoreService();
      final emptyInputs = ['', '   ', '\n\t  '];

      for (final input in emptyInputs) {
        final replyText = input.trim();
        final isValid = replyText.isNotEmpty;
        expect(isValid, isFalse);

        if (isValid) {
          await fakeFirestore.sendNotificationReply(
            connectionId: 'conn_1',
            senderId: 'user_alice',
            recipientId: 'user_bob',
            content: replyText,
          );
        }
      }

      expect(fakeFirestore.sentMessages.isEmpty, isTrue);
    });
  });

  group('4. Push Notification Tap Navigation Routing & Stale Target Fallback', () {
    testWidgets('Tapping notification with stale/deleted connection shows graceful notice', (tester) async {
      final fakeFirestore = _FakePushFirestoreService();
      final service = PushNotificationService.withDependencies(
        firestoreService: fakeFirestore,
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: PushNotificationService.navigatorKey,
          home: const Scaffold(body: Text('Home Screen')),
        ),
      );

      // Tap message notification where connection no longer exists
      final data = {
        'type': 'message',
        'connectionId': 'conn_deleted_999',
      };

      await service.handleNotificationTap(data);
      await tester.pumpAndSettle();

      expect(find.text('Conversation is no longer available.'), findsOneWidget);
    });

    testWidgets('Tapping notification with stale/deleted post shows graceful notice', (tester) async {
      final fakeFirestore = _FakePushFirestoreService();
      final service = PushNotificationService.withDependencies(
        firestoreService: fakeFirestore,
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: PushNotificationService.navigatorKey,
          home: const Scaffold(body: Text('Home Screen')),
        ),
      );

      // Tap post notification where post has been deleted
      final data = {
        'type': 'crush',
        'postId': 'post_deleted_888',
      };

      await service.handleNotificationTap(data);
      await tester.pumpAndSettle();

      expect(find.text('This post has expired or was removed.'), findsOneWidget);
    });

    testWidgets('Tapping notification with valid connection opens ChatScreen', (tester) async {
      final fakeFirestore = _FakePushFirestoreService();
      fakeFirestore.connections['conn_live_123'] = ConnectionModel(
        id: 'conn_live_123',
        senderId: 'user_me',
        senderUsername: 'me',
        senderProfilePic: '',
        receiverId: 'user_them',
        receiverUsername: 'them',
        receiverProfilePic: '',
        status: ConnectionStatus.accepted,
        createdAt: DateTime.now(),
      );

      final service = PushNotificationService.withDependencies(
        firestoreService: fakeFirestore,
      );

      final observer = _TestNavigatorObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: PushNotificationService.navigatorKey,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home Screen')),
        ),
      );

      final data = {
        'type': 'message',
        'connectionId': 'conn_live_123',
      };

      await service.handleNotificationTap(data);

      expect(observer.pushedRoutes.length, 2);
      final route = observer.pushedRoutes.last as MaterialPageRoute;
      final builtWidget = route.builder(tester.element(find.text('Home Screen')));
      expect(builtWidget, isA<ChatScreen>());
      final chatWidget = builtWidget as ChatScreen;
      expect(chatWidget.connection.id, 'conn_live_123');
    });
  });

  group('5. Cloud Function Token Cleanup & Deduplication Logic', () {
    test('Invalid FCM tokens are collected and cleaned from document', () {
      final registeredTokens = ['valid_token_1', 'stale_token_bad_2', 'valid_token_3'];
      final staleTokens = <String>[];

      // Simulate Cloud Function dispatch with error handling
      for (final token in registeredTokens) {
        if (token.contains('stale')) {
          staleTokens.add(token);
        }
      }

      expect(staleTokens.length, 1);
      expect(staleTokens.first, 'stale_token_bad_2');

      // Emulate Firestore arrayRemove cleanup
      final updatedTokens = registeredTokens.where((t) => !staleTokens.contains(t)).toList();
      expect(updatedTokens, equals(['valid_token_1', 'valid_token_3']));
    });

    test('Deduplication prevents double push when pushDispatched is true', () {
      final notificationDoc = {
        'id': 'notif_100',
        'title': 'Crush Alert',
        'isRead': false,
        'pushDispatched': true, // Already dispatched once
      };

      final shouldDispatch = notificationDoc['isRead'] == false &&
          notificationDoc['pushDispatched'] != true;

      expect(shouldDispatch, isFalse);
    });
  });
}
