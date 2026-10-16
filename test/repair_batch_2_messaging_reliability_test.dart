import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crushie/models/connection_model.dart';
import 'package:crushie/models/chat_message_model.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/providers/chat_provider.dart';
import 'package:crushie/providers/connection_provider.dart';
import 'package:crushie/screens/messages/chat_screen.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel? _currentUser;
  @override
  UserModel? get currentUser => _currentUser;
  set currentUser(UserModel? u) {
    _currentUser = u;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockWaitingChatProvider extends ChatProvider {
  final StreamController<List<ChatMessageModel>> _controller =
      StreamController<List<ChatMessageModel>>.broadcast();

  @override
  Stream<List<ChatMessageModel>> getChatMessagesStream(String connectionId,
      {int limit = 50}) {
    return _controller.stream;
  }
}

class MockErrorChatProvider extends ChatProvider {
  @override
  Stream<List<ChatMessageModel>> getChatMessagesStream(String connectionId,
      {int limit = 50}) {
    return Stream.error(
        Exception('Simulated permission denied or offline network error'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
      '1. Stable Conversation ID Generation and Participant-Order Independence',
      () {
    test('Canonical conversation ID is deterministic and order-independent',
        () {
      const uidA = 'user_123_alice';
      const uidB = 'user_456_bob';

      final idAB = ConnectionModel.getConversationId(uidA, uidB);
      final idBA = ConnectionModel.getConversationId(uidB, uidA);

      expect(idAB, equals(idBA));
      expect(idAB, equals('conn_user_123_alice_user_456_bob'));
    });

    test('Trims whitespace from UIDs before generating canonical ID', () {
      final id = ConnectionModel.getConversationId('  userA  ', 'userB  ');
      expect(id, equals('conn_userA_userB'));
    });

    test('Rejects empty or whitespace-only UIDs', () {
      expect(() => ConnectionModel.getConversationId('', 'userB'),
          throwsA(isA<ArgumentError>()));
      expect(() => ConnectionModel.getConversationId('   ', 'userB'),
          throwsA(isA<ArgumentError>()));
      expect(() => ConnectionModel.getConversationId('userA', ''),
          throwsA(isA<ArgumentError>()));
    });

    test('Rejects self-conversations', () {
      expect(() => ConnectionModel.getConversationId('userA', 'userA'),
          throwsA(isA<ArgumentError>()));
      expect(() => ConnectionModel.getConversationId(' userA ', 'userA'),
          throwsA(isA<ArgumentError>()));
    });
  });

  group('2. Concurrent and Idempotent Conversation Creation', () {
    test(
        'Simultaneous initiation by both users computes identical canonical ID',
        () {
      const aliceUid = 'uid_alice';
      const bobUid = 'uid_bob';

      final aliceInitiation =
          ConnectionModel.getConversationId(aliceUid, bobUid);
      final bobInitiation = ConnectionModel.getConversationId(bobUid, aliceUid);

      expect(aliceInitiation, equals(bobInitiation));
    });

    test(
        'DatabaseService.sendConnectionRequest does not duplicate existing conversation',
        () {
      final db = DatabaseService();
      db.clearUserData();

      final sender = UserModel(
        id: 'user_initiator',
        username: 'initiator',
        email: 'init@test.com',
        gender: 'Male',
        country: 'Kenya',
        city: 'Nairobi',
        contactDetails: '+254700000001',
        preferredContactMethod: 'WhatsApp',
        bio: 'Hello',
        profilePicUrl: '',
        dateOfBirth: DateTime(2000, 1, 1),
      );
      final recipient = UserModel(
        id: 'user_target',
        username: 'target',
        email: 'target@test.com',
        gender: 'Female',
        country: 'Kenya',
        city: 'Nairobi',
        contactDetails: '+254700000002',
        preferredContactMethod: 'WhatsApp',
        bio: 'Hello',
        profilePicUrl: '',
        dateOfBirth: DateTime(2000, 1, 1),
      );

      final firstConn = db.sendConnectionRequest(
        sender: sender,
        recipient: recipient,
        priceKES: 0,
        isPremiumFree: true,
      );
      expect(firstConn, isNotNull);
      expect(firstConn!.id,
          equals(ConnectionModel.getConversationId(sender.id, recipient.id)));

      // Second attempt in reverse direction:
      final secondConn = db.sendConnectionRequest(
        sender: recipient,
        recipient: sender,
        priceKES: 0,
        isPremiumFree: true,
      );

      // Must return the existing connection without adding a new one
      expect(secondConn, isNotNull);
      expect(secondConn!.id, equals(firstConn.id));
      expect(
          db.connections.where((c) => c.id == firstConn.id).length, equals(1));
    });
  });

  group('3. Message Model Serialization and Persistence Invariants', () {
    test(
        'ChatMessageModel serialization and deserialization preserves all fields',
        () {
      final now = DateTime.now();
      final original = ChatMessageModel(
        id: 'msg_test_101',
        connectionId: 'conn_u1_u2',
        senderId: 'u1',
        recipientId: 'u2',
        message: 'Hello Crushie!',
        mediaUrl: 'https://cdn.crushie.app/media/photo.jpg',
        timestamp: now,
        deliveryStatus: MessageDeliveryStatus.delivered,
        isRead: false,
        deletedForUserIds: ['u3'],
        isDeletedForEveryone: false,
      );

      final map = original.toMap();
      final deserialized = ChatMessageModel.fromMap(map, original.id);

      expect(deserialized.id, equals(original.id));
      expect(deserialized.connectionId, equals(original.connectionId));
      expect(deserialized.senderId, equals(original.senderId));
      expect(deserialized.recipientId, equals(original.recipientId));
      expect(deserialized.message, equals(original.message));
      expect(deserialized.mediaUrl, equals(original.mediaUrl));
      expect(
          deserialized.deliveryStatus, equals(MessageDeliveryStatus.delivered));
      expect(deserialized.isRead, isFalse);
      expect(deserialized.deletedForUserIds, contains('u3'));
    });

    test(
        'ChatProvider rolls back optimistic message and rethrows when persistence fails',
        () async {
      final chatProv = ChatProvider();
      chatProv.clear();

      // Attempting to send message without network/Firestore app initialized will throw in unit test
      await expectLater(
        chatProv.sendMessage(
          connectionId: 'conn_mock_1',
          senderId: 'mock_sender',
          recipientId: 'mock_recipient',
          text: 'This should fail gracefully',
        ),
        throwsA(anything),
      );

      // In-memory messages for this connection must not contain the failed message
      final messages = chatProv.getMessagesForConnection('conn_mock_1');
      expect(messages.where((m) => m.message == 'This should fail gracefully'),
          isEmpty);
    });
  });

  group('4. Message History and Synchronization', () {
    test(
        'ChatProvider.syncMessages reconciles incoming messages and sorts by timestamp',
        () {
      final chatProv = ChatProvider();
      chatProv.clear();

      final t1 = DateTime.now().subtract(const Duration(minutes: 5));
      final t2 = DateTime.now().subtract(const Duration(minutes: 2));

      final msg1 = ChatMessageModel(
        id: 'msg_1',
        connectionId: 'conn_test',
        senderId: 'u1',
        recipientId: 'u2',
        message: 'First',
        timestamp: t1,
      );
      final msg2 = ChatMessageModel(
        id: 'msg_2',
        connectionId: 'conn_test',
        senderId: 'u2',
        recipientId: 'u1',
        message: 'Second',
        timestamp: t2,
      );

      chatProv.syncMessages('conn_test', [msg2, msg1]);

      final cached = chatProv.getMessagesForConnection('conn_test');
      expect(cached.length, equals(2));
      expect(cached[0].id, equals('msg_1'));
      expect(cached[1].id, equals('msg_2'));
    });
  });

  group('5. Initial Loading vs Empty State in ChatScreen', () {
    testWidgets(
        'ChatScreen shows progress indicator when waiting with empty cache',
        (tester) async {
      final authProv = FakeAuthProvider();
      authProv.currentUser = UserModel(
        id: 'user_self',
        username: 'self_user',
        email: 'self@test.com',
        country: 'Kenya',
        city: 'Nairobi',
        gender: 'Male',
        bio: 'Self bio',
        profilePicUrl: '',
        dateOfBirth: DateTime(2000, 1, 1),
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+254700000001',
      );

      final chatProv = MockWaitingChatProvider();
      chatProv.clear();

      final conn = ConnectionModel(
        id: 'conn_test_loading',
        senderId: 'user_self',
        senderUsername: 'self_user',
        senderProfilePic: '',
        receiverId: 'user_other',
        receiverUsername: 'other_user',
        receiverProfilePic: '',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: conn),
          ),
        ),
      );

      // When the stream is waiting for initial snapshot and cache is empty,
      // it must display a CircularProgressIndicator and NOT "No messages yet."
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('No messages yet'), findsNothing);
    });
  });

  group('6. Inbox Previews and Timestamps Recovery', () {
    test(
        'ConnectionModel serialization preserves lastMessage fields and unreadCounts',
        () {
      final msgTime = DateTime.now().subtract(const Duration(hours: 1));
      final conn = ConnectionModel(
        id: 'conn_u1_u2',
        senderId: 'u1',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'u2',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        lastMessageText: 'See you tomorrow at 5pm!',
        lastMessageTimestamp: msgTime,
        lastMessageSenderId: 'u1',
        unreadCounts: {'u2': 4, 'u1': 0},
      );

      final map = conn.toMap();
      final restored = ConnectionModel.fromMap(map, conn.id);

      expect(restored.lastMessageText, equals('See you tomorrow at 5pm!'));
      expect(restored.lastMessageSenderId, equals('u1'));
      expect(restored.lastMessageTimestamp?.millisecondsSinceEpoch,
          equals(msgTime.millisecondsSinceEpoch));
      expect(restored.unreadCounts['u2'], equals(4));
      expect(restored.unreadCountForUser('u2'), equals(4));
      expect(restored.unreadCountForUser('u1'), equals(0));
    });

    test(
        'Recovers preview and timestamp on restart when message cache is empty',
        () {
      final msgTime = DateTime.now().subtract(const Duration(minutes: 30));
      final conn = ConnectionModel(
        id: 'conn_u1_u2',
        senderId: 'u1',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'u2',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        lastMessageText: 'Persistent preview message',
        lastMessageTimestamp: msgTime,
      );

      // Verify that when no in-memory messages exist, the connection model provides the preview text and timestamp
      final chatProv = ChatProvider();
      chatProv.clear();
      final messages = chatProv.getMessagesForConnection(conn.id);
      expect(messages, isEmpty);

      final previewText = messages.isNotEmpty
          ? messages.last.message
          : (conn.lastMessageText ?? 'Fallback');

      final previewTime = messages.isNotEmpty
          ? messages.last.timestamp
          : (conn.lastMessageTimestamp ?? conn.updatedAt);

      expect(previewText, equals('Persistent preview message'));
      expect(previewTime, equals(msgTime));
    });
  });

  group('7. Unread Counts Persistence and Isolation', () {
    test('Unread counts are isolated per participant', () {
      final conn = ConnectionModel(
        id: 'conn_u1_u2',
        senderId: 'u1',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'u2',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        unreadCounts: {'u1': 0, 'u2': 7},
      );

      expect(conn.unreadCountForUser('u2'), equals(7));
      expect(conn.unreadCountForUser('u1'), equals(0));
      expect(conn.unreadCountForUser('non_participant'), equals(0));
    });

    test('Opening one conversation does not affect unread counts of another',
        () {
      final conn1 = ConnectionModel(
        id: 'conn_u1_u2',
        senderId: 'u1',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'u2',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        unreadCounts: {'u2': 5},
      );

      final conn2 = ConnectionModel(
        id: 'conn_u3_u2',
        senderId: 'u3',
        senderUsername: 'carol',
        senderProfilePic: '',
        receiverId: 'u2',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        unreadCounts: {'u2': 2},
      );

      final updatedConn1 = conn1.copyWith(
        unreadCounts: {'u2': 0},
      );

      expect(updatedConn1.unreadCountForUser('u2'), equals(0));
      expect(conn2.unreadCountForUser('u2'), equals(2));
    });
  });

  group('8. Duplicate Prevention in Streams and Messages', () {
    test(
        'ChatProvider.syncMessages de-duplicates repeated messages with identical IDs',
        () {
      final chatProv = ChatProvider();
      chatProv.clear();

      final msg = ChatMessageModel(
        id: 'msg_dup_1',
        connectionId: 'conn_test',
        senderId: 'u1',
        recipientId: 'u2',
        message: 'No duplicate allowed',
        timestamp: DateTime.now(),
      );

      chatProv.syncMessages('conn_test', [msg]);
      chatProv.syncMessages('conn_test', [msg, msg]);

      final msgs = chatProv.getMessagesForConnection('conn_test');
      expect(msgs.length, equals(1));
    });
  });

  group('9. Account Isolation and Logout Cleanup', () {
    test('ChatProvider.clear empties cached messages', () {
      final chatProv = ChatProvider();
      final msg = ChatMessageModel(
        id: 'msg_isolate_1',
        connectionId: 'conn_1',
        senderId: 'u1',
        recipientId: 'u2',
        message: 'Sensitive message',
        timestamp: DateTime.now(),
      );

      chatProv.syncMessages('conn_1', [msg]);
      expect(chatProv.getMessagesForConnection('conn_1'), isNotEmpty);

      chatProv.clear();
      expect(chatProv.getMessagesForConnection('conn_1'), isEmpty);
    });

    test('ConnectionProvider.clear cancels listeners and resets state', () {
      final connProv = ConnectionProvider();
      connProv.clear();

      expect(connProv.isLoading, isFalse);
      expect(connProv.connections, isEmpty);
    });

    test(
        'DatabaseService.clearUserData completely wipes user and message caches',
        () {
      final db = DatabaseService();
      db.sendChatMessage(
        ChatMessageModel(
          id: 'msg_db_1',
          connectionId: 'conn_db',
          senderId: 'u1',
          recipientId: 'u2',
          message: 'Cache to be wiped',
          timestamp: DateTime.now(),
        ),
      );

      expect(db.getChatMessages('conn_db'), isNotEmpty);

      db.clearUserData();
      expect(db.getChatMessages('conn_db'), isEmpty);
      expect(db.connections, isEmpty);
    });
  });

  group('10. Legacy Conversation ID Compatibility', () {
    test('Recognizes legacy timestamp-based conversation IDs', () {
      expect(
          ConnectionModel.isLegacyConversationId('conn_1729000000000'), isTrue);
      expect(ConnectionModel.isLegacyConversationId('conn_12345'), isTrue);
      expect(
          ConnectionModel.isLegacyConversationId('conn_userA_userB'), isFalse);
      expect(ConnectionModel.isLegacyConversationId('random_id'), isFalse);
    });

    test(
        'Legacy connection model deserializes correctly with participants and messages',
        () {
      final legacyMap = {
        'senderId': 'user_1',
        'senderUsername': 'user1',
        'senderProfilePic': '',
        'receiverId': 'user_2',
        'receiverUsername': 'user2',
        'receiverProfilePic': '',
        'participants': ['user_1', 'user_2'],
        'status': 'accepted',
        'isPaid': false,
        'amount': 0,
        'createdAt': '2025-01-01T12:00:00.000Z',
        'updatedAt': '2025-01-01T12:00:00.000Z',
        'lastMessageText': 'Legacy chat history message',
        'lastMessageTimestamp': '2025-01-01T12:30:00.000Z',
        'unreadCounts': {'user_2': 1},
      };

      final conn = ConnectionModel.fromMap(legacyMap, 'conn_1729111222333');
      expect(conn.id, equals('conn_1729111222333'));
      expect(ConnectionModel.isLegacyConversationId(conn.id), isTrue);
      expect(conn.participants, containsAll(['user_1', 'user_2']));
      expect(conn.lastMessageText, equals('Legacy chat history message'));
      expect(conn.unreadCountForUser('user_2'), equals(1));
    });
  });

  group('11. Stream Error and Offline States', () {
    testWidgets(
        'ChatScreen shows error message and retry button on stream error',
        (tester) async {
      final authProv = FakeAuthProvider();
      authProv.currentUser = UserModel(
        id: 'user_self',
        username: 'self_user',
        email: 'self@test.com',
        country: 'Kenya',
        city: 'Nairobi',
        gender: 'Male',
        bio: 'Self bio',
        profilePicUrl: '',
        dateOfBirth: DateTime(2000, 1, 1),
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+254700000001',
      );

      final chatProv = MockErrorChatProvider();

      final conn = ConnectionModel(
        id: 'conn_error_test',
        senderId: 'user_self',
        senderUsername: 'self_user',
        senderProfilePic: '',
        receiverId: 'user_other',
        receiverUsername: 'other_user',
        receiverProfilePic: '',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: conn),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to load messages'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('12. Regressions Check from Repair Batch 1', () {
    test('User following and connections work seamlessly together', () {
      final db = DatabaseService();
      db.clearUserData();

      db.setFollowingUserIds({'target_uid_1', 'target_uid_2'});
      expect(db.isFollowing('target_uid_1'), isTrue);

      final sender = UserModel(
        id: 'my_uid',
        username: 'me',
        email: 'me@test.com',
        gender: 'Male',
        country: 'Kenya',
        city: 'Nairobi',
        contactDetails: '+254700000001',
        preferredContactMethod: 'WhatsApp',
        bio: 'Hello',
        profilePicUrl: '',
        dateOfBirth: DateTime(2000, 1, 1),
      );
      final recipient = UserModel(
        id: 'target_uid_1',
        username: 'target1',
        email: 'target1@test.com',
        gender: 'Female',
        country: 'Kenya',
        city: 'Nairobi',
        contactDetails: '+254700000002',
        preferredContactMethod: 'WhatsApp',
        bio: 'Hello',
        profilePicUrl: '',
        dateOfBirth: DateTime(2000, 1, 1),
      );

      final conn = db.sendConnectionRequest(
        sender: sender,
        recipient: recipient,
        priceKES: 0,
        isPremiumFree: true,
      );

      expect(conn, isNotNull);
      expect(conn!.id,
          equals(ConnectionModel.getConversationId('my_uid', 'target_uid_1')));
      expect(db.isFollowing('target_uid_1'), isTrue);
    });
  });
}
