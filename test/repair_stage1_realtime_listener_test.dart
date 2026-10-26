import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crushie/models/connection_model.dart';
import 'package:crushie/models/chat_message_model.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/providers/chat_provider.dart';
import 'package:crushie/providers/connection_provider.dart';
import 'package:crushie/providers/user_provider.dart';
import 'package:crushie/screens/messages/chat_screen.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
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

class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConnectionProvider extends ChangeNotifier implements ConnectionProvider {
  @override
  void markConnectionAsReadLocally(String connectionId, String userId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestableChatProvider extends ChatProvider {
  final Map<String, StreamController<List<ChatMessageModel>>> _controllers = {};
  int streamRequestCount = 0;
  String? lastRequestedConnectionId;
  int cancelCount = 0;

  StreamController<List<ChatMessageModel>> getController(String connId) {
    return _controllers.putIfAbsent(connId, () {
      final sc = StreamController<List<ChatMessageModel>>.broadcast(
        onCancel: () {
          cancelCount++;
        },
      );
      return sc;
    });
  }

  @override
  Stream<List<ChatMessageModel>> getChatMessagesStream(String connectionId,
      {int limit = 50}) {
    streamRequestCount++;
    lastRequestedConnectionId = connectionId;
    return getController(connectionId).stream;
  }
}

UserModel _createUser(String id, String username) {
  return UserModel(
    id: id,
    username: username,
    email: '$username@test.com',
    gender: 'Other',
    country: 'Kenya',
    city: 'Nairobi',
    contactDetails: '+254700000000',
    preferredContactMethod: 'WhatsApp',
    bio: 'Test bio',
    profilePicUrl: '',
    dateOfBirth: DateTime(2000, 1, 1),
  );
}

ConnectionModel _createConn(String id, String userA, String userB) {
  return ConnectionModel(
    id: id,
    senderId: userA,
    senderUsername: userA,
    senderProfilePic: '',
    receiverId: userB,
    receiverUsername: userB,
    receiverProfilePic: '',
    participants: [userA, userB],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crushie Stage 1: Real-Time Messaging Listener & Auto-Scroll Suite', () {
    testWidgets(
        '1. Incoming message from stream appears immediately on recipient view',
        (tester) async {
      final authProv = _FakeAuthProvider();
      final userProv = _FakeUserProvider();
      final connProv = _FakeConnectionProvider();
      final chatProv = _TestableChatProvider();

      authProv.currentUser = _createUser('bob', 'bob');
      final conn = _createConn('conn_alice_bob', 'alice', 'bob');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: conn),
          ),
        ),
      );

      // Initially empty conversation
      chatProv.getController('conn_alice_bob').add([]);
      await tester.pump();
      expect(find.text('No messages yet. Say hi to @alice!'), findsOneWidget);

      // Alice sends a new message arriving via Firestore listener stream
      final incoming = ChatMessageModel(
        id: 'msg_stream_001',
        connectionId: 'conn_alice_bob',
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Hey Bob, live incoming message!',
        timestamp: DateTime.now(),
        deliveryStatus: MessageDeliveryStatus.delivered,
      );

      chatProv.getController('conn_alice_bob').add([incoming]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Must appear immediately on screen without manual refresh
      expect(find.text('Hey Bob, live incoming message!'), findsOneWidget);
    });

    testWidgets(
        '2. Listener updates delivery status and read receipts dynamically',
        (tester) async {
      final authProv = _FakeAuthProvider();
      final userProv = _FakeUserProvider();
      final connProv = _FakeConnectionProvider();
      final chatProv = _TestableChatProvider();

      authProv.currentUser = _createUser('alice', 'alice');
      final conn = _createConn('conn_alice_bob', 'alice', 'bob');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: conn),
          ),
        ),
      );

      final msgTime = DateTime(2026, 10, 26, 12, 0);
      final sentMsg = ChatMessageModel(
        id: 'msg_receipt_1',
        connectionId: 'conn_alice_bob',
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Status check',
        timestamp: msgTime,
        deliveryStatus: MessageDeliveryStatus.sent,
        isRead: false,
      );

      chatProv.getController('conn_alice_bob').add([sentMsg]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Status check'), findsOneWidget);
      expect(find.text('✓'), findsOneWidget);

      // Recipient reads it: stream emits read update
      final readMsg = sentMsg.copyWith(
        deliveryStatus: MessageDeliveryStatus.read,
        isRead: true,
      );
      chatProv.getController('conn_alice_bob').add([readMsg]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Ticks update to double accent tick
      expect(find.text('✓✓'), findsOneWidget);
      expect(find.text('✓'), findsNothing);
    });

    testWidgets(
        '3. Out-of-order stream messages are sorted chronologically ascending',
        (tester) async {
      final authProv = _FakeAuthProvider();
      final userProv = _FakeUserProvider();
      final connProv = _FakeConnectionProvider();
      final chatProv = _TestableChatProvider();

      authProv.currentUser = _createUser('alice', 'alice');
      final conn = _createConn('conn_alice_bob', 'alice', 'bob');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: conn),
          ),
        ),
      );

      final t1 = DateTime(2026, 10, 26, 10, 0);
      final t2 = DateTime(2026, 10, 26, 10, 5);
      final t3 = DateTime(2026, 10, 26, 10, 10);

      // Arrives out-of-order in snapshot
      final msg3 = ChatMessageModel(
        id: 'msg_3',
        connectionId: 'conn_alice_bob',
        senderId: 'bob',
        recipientId: 'alice',
        message: 'Third (latest)',
        timestamp: t3,
      );
      final msg1 = ChatMessageModel(
        id: 'msg_1',
        connectionId: 'conn_alice_bob',
        senderId: 'alice',
        recipientId: 'bob',
        message: 'First (oldest)',
        timestamp: t1,
      );
      final msg2 = ChatMessageModel(
        id: 'msg_2',
        connectionId: 'conn_alice_bob',
        senderId: 'bob',
        recipientId: 'alice',
        message: 'Second (middle)',
        timestamp: t2,
      );

      chatProv.getController('conn_alice_bob').add([msg3, msg1, msg2]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final merged = chatProv.getMergedMessages('conn_alice_bob');
      expect(merged.length, equals(3));
      expect(merged[0].id, equals('msg_1'));
      expect(merged[1].id, equals('msg_2'));
      expect(merged[2].id, equals('msg_3'));
    });

    testWidgets(
        '4. Switching conversation isolates messages and re-initializes stream cleanly',
        (tester) async {
      final authProv = _FakeAuthProvider();
      final userProv = _FakeUserProvider();
      final connProv = _FakeConnectionProvider();
      final chatProv = _TestableChatProvider();

      authProv.currentUser = _createUser('alice', 'alice');
      final conn1 = _createConn('conn_1', 'alice', 'bob');
      final conn2 = _createConn('conn_2', 'alice', 'charlie');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: conn1),
          ),
        ),
      );

      expect(chatProv.streamRequestCount, equals(1));
      expect(chatProv.lastRequestedConnectionId, equals('conn_1'));

      final msgConn1 = ChatMessageModel(
        id: 'msg_conn1_secret',
        connectionId: 'conn_1',
        senderId: 'bob',
        recipientId: 'alice',
        message: 'Private for conn1',
        timestamp: DateTime.now(),
      );
      chatProv.getController('conn_1').add([msgConn1]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Private for conn1'), findsOneWidget);

      // Switch to conn2
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: conn2),
          ),
        ),
      );

      expect(chatProv.streamRequestCount, equals(2));
      expect(chatProv.lastRequestedConnectionId, equals('conn_2'));
      // Old conversation messages MUST NOT leak into new conversation
      expect(find.text('Private for conn1'), findsNothing);

      chatProv.getController('conn_2').add([]);
      await tester.pump();
      expect(find.text('No messages yet. Say hi to @bob!'), findsNothing);
    });

    testWidgets('5. Unmounting ChatScreen disposes stream listener properly',
        (tester) async {
      final authProv = _FakeAuthProvider();
      final userProv = _FakeUserProvider();
      final connProv = _FakeConnectionProvider();
      final chatProv = _TestableChatProvider();

      authProv.currentUser = _createUser('alice', 'alice');
      final conn = _createConn('conn_pop_test', 'alice', 'bob');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: conn),
          ),
        ),
      );

      chatProv.getController('conn_pop_test').add([]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(chatProv.streamRequestCount, equals(1));
      expect(chatProv.cancelCount, equals(0));

      // Unmount ChatScreen completely by replacing root widget
      await tester.pumpWidget(const SizedBox());

      expect(find.byType(ChatScreen), findsNothing);
      // Stream subscription was cancelled on dispose
      expect(chatProv.cancelCount, greaterThanOrEqualTo(1));
    });
  });
}
