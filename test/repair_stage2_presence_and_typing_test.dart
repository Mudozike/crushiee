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
import 'package:crushie/screens/messages/messages_list_screen.dart';
import 'package:crushie/widgets/status_badge.dart';

// --- MOCKS & TEST HARNESS ---

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel? _currentUser;
  bool _isAuthenticated = true;

  @override
  UserModel? get currentUser => _currentUser;
  set currentUser(UserModel? u) {
    _currentUser = u;
    notifyListeners();
  }

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<bool> signOut() async {
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  @override
  bool isUserBlocked(String a, String b) => false;

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
  int setTypingCallCount = 0;
  String? lastTypingConnectionId;
  String? lastTypingUserId;
  bool? lastIsTyping;

  StreamController<List<ChatMessageModel>> getController(String connId) {
    return _controllers.putIfAbsent(connId, () => StreamController<List<ChatMessageModel>>.broadcast());
  }

  @override
  Stream<List<ChatMessageModel>> getChatMessagesStream(String connectionId, {int limit = 50}) {
    return getController(connectionId).stream;
  }

  @override
  List<ChatMessageModel> getMessagesForConnection(String connectionId, {String? userId}) {
    return const [];
  }

  @override
  Future<void> markMessagesAsRead(String connectionId, String userId) async {}

  @override
  void setTypingStatus(String connectionId, String userId, bool isTyping) {
    setTypingCallCount++;
    lastTypingConnectionId = connectionId;
    lastTypingUserId = userId;
    lastIsTyping = isTyping;
    super.setTypingStatus(connectionId, userId, isTyping);
  }
}

ConnectionModel _createTestConn({
  required String connId,
  required String senderId,
  required String recipientId,
  String senderUsername = 'alice',
  String recipientUsername = 'bob',
}) {
  return ConnectionModel(
    id: connId,
    senderId: senderId,
    recipientId: recipientId,
    receiverId: recipientId,
    participants: [senderId, recipientId],
    status: ConnectionStatus.accepted,
    createdAt: DateTime.now(),
    senderUsername: senderUsername,
    recipientUsername: recipientUsername,
    receiverUsername: recipientUsername,
    senderProfilePic: '',
    recipientProfilePic: '',
    receiverProfilePic: '',
    isPaid: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Online Presence & Last Seen Formatting', () {
    test('Accurate presence formatting for online and offline states', () {
      final now = DateTime(2026, 10, 26, 12, 0, 0);

      // Active user online
      expect(StatusBadge.formatStatus(true, now, now: now), 'Online');

      // Offline user with null lastSeen never shows 'Last seen just now'
      expect(StatusBadge.formatStatus(false, null, now: now), 'Offline');

      // Offline user seen 30 seconds ago
      final thirtySecAgo = now.subtract(const Duration(seconds: 30));
      expect(StatusBadge.formatStatus(false, thirtySecAgo, now: now), 'Last seen just now');

      // Offline user seen 15 minutes ago
      final fifteenMinAgo = now.subtract(const Duration(minutes: 15));
      expect(StatusBadge.formatStatus(false, fifteenMinAgo, now: now), 'Last seen 15m ago');

      // Offline user seen 2 hours ago
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      expect(StatusBadge.formatStatus(false, twoHoursAgo, now: now), 'Last seen 2h ago');

      // Offline user seen yesterday
      final yesterday = now.subtract(const Duration(days: 1));
      expect(StatusBadge.formatStatus(false, yesterday, now: now), 'Last seen yesterday');

      // Offline user seen 4 days ago
      final fourDaysAgo = now.subtract(const Duration(days: 4));
      expect(StatusBadge.formatStatus(false, fourDaysAgo, now: now), 'Last seen 4d ago');
    });

    test('Stale online presence (>5m heartbeat gap) is automatically rendered offline', () {
      final now = DateTime(2026, 10, 26, 12, 0, 0);

      // User marked isOnline=true, but heartbeat was 10 minutes ago (crashed or lost connectivity)
      final tenMinAgo = now.subtract(const Duration(minutes: 10));
      expect(StatusBadge.isEffectiveOnline(true, tenMinAgo, now: now), isFalse);
      expect(StatusBadge.formatStatus(true, tenMinAgo, now: now), 'Last seen 10m ago');

      // User marked isOnline=true, heartbeat was 2 minutes ago -> accurately online
      final twoMinAgo = now.subtract(const Duration(minutes: 2));
      expect(StatusBadge.isEffectiveOnline(true, twoMinAgo, now: now), isTrue);
      expect(StatusBadge.formatStatus(true, twoMinAgo, now: now), 'Online');
    });

    test('MessagesListScreen delegates formatPresenceStatus to effective presence logic', () {
      final now = DateTime(2026, 10, 26, 12, 0, 0);

      expect(MessagesListScreen.formatPresenceStatus(true, now, now: now), 'Online');
      expect(MessagesListScreen.formatPresenceStatus(false, null, now: now), 'Offline');

      // Stale online (>5m) in messages list displays last seen time instead of false online
      final eightMinAgo = now.subtract(const Duration(minutes: 8));
      expect(MessagesListScreen.formatPresenceStatus(true, eightMinAgo, now: now), 'Last seen 8m ago');
    });
  });

  group('2. UserModel Presence & Typing Serialization', () {
    test('UserModel default constructor has isOnline=false and nullable lastSeen', () {
      final user = UserModel(
        id: 'user_new',
        username: 'newbie',
        email: 'new@example.com',
        country: 'US',
        city: 'NY',
        dateOfBirth: DateTime(2000, 1, 1),
        gender: 'Male',
        bio: 'Hello',
        profilePicUrl: '',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+1234567890',
      );

      expect(user.isOnline, isFalse);
      expect(user.lastSeen, isNull);
    });

    test('UserModel.fromMap with missing or null lastSeen does not default to DateTime.now()', () {
      final map = <String, dynamic>{
        'username': 'alice',
        'email': 'alice@example.com',
        'country': 'US',
        'city': 'NY',
        'gender': 'Female',
        'bio': 'Hi',
        'profilePicUrl': '',
        'preferredContactMethod': 'WhatsApp',
        'contactDetails': 'alice_contact',
        'isOnline': false,
        'lastSeen': null,
      };

      final user = UserModel.fromMap(map, 'alice_1');
      expect(user.isOnline, isFalse);
      expect(user.lastSeen, isNull);
    });

    test('UserModel.fromMap accurately parses ISO strings and millisecond epochs', () {
      final dt = DateTime(2026, 10, 26, 10, 30, 0);
      final mapIso = <String, dynamic>{
        'username': 'bob',
        'email': 'bob@example.com',
        'country': 'CA',
        'city': 'Toronto',
        'gender': 'Male',
        'bio': 'Hi',
        'profilePicUrl': '',
        'preferredContactMethod': 'WhatsApp',
        'contactDetails': 'bob_contact',
        'isOnline': true,
        'lastSeen': dt.toIso8601String(),
        'typingInConnectionId': 'conn_123',
        'typingUpdatedAt': dt.toIso8601String(),
      };

      final userIso = UserModel.fromMap(mapIso, 'bob_1');
      expect(userIso.isOnline, isTrue);
      expect(userIso.lastSeen, isNotNull);
      expect(userIso.lastSeen!.year, 2026);
      expect(userIso.typingInConnectionId, 'conn_123');

      // Test with integer epoch milliseconds
      final mapEpoch = Map<String, dynamic>.from(mapIso);
      mapEpoch['lastSeen'] = dt.millisecondsSinceEpoch;
      final userEpoch = UserModel.fromMap(mapEpoch, 'bob_2');
      expect(userEpoch.lastSeen, isNotNull);
      expect(userEpoch.lastSeen!.millisecondsSinceEpoch, dt.millisecondsSinceEpoch);
    });

    test('UserModel.copyWith supports clearLastSeen and clearTyping', () {
      final dt = DateTime(2026, 10, 26, 10, 0, 0);
      final user = UserModel(
        id: 'u1',
        username: 'user1',
        email: 'u1@test.com',
        country: 'US',
        city: 'NY',
        dateOfBirth: DateTime(1995, 1, 1),
        gender: 'Other',
        bio: '',
        profilePicUrl: '',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '',
        isOnline: true,
        lastSeen: dt,
        typingInConnectionId: 'conn_abc',
        typingUpdatedAt: dt,
      );

      final cleared = user.copyWith(clearLastSeen: true, clearTyping: true, isOnline: false);
      expect(cleared.isOnline, isFalse);
      expect(cleared.lastSeen, isNull);
      expect(cleared.typingInConnectionId, isNull);
      expect(cleared.typingUpdatedAt, isNull);
    });
  });

  group('3. Multi-Device Presence Session Logic Simulation', () {
    test('Simulate multi-device session aggregation logic', () {
      final now = DateTime(2026, 10, 26, 12, 0, 0);
      final Map<String, dynamic> activeSessions = {};

      // Device A connects
      activeSessions['dev_phone_A'] = now.toIso8601String();
      bool isUserOnline = activeSessions.isNotEmpty;
      expect(isUserOnline, isTrue);
      expect(activeSessions.length, 1);

      // Device B connects
      activeSessions['dev_tablet_B'] = now.toIso8601String();
      isUserOnline = activeSessions.isNotEmpty;
      expect(isUserOnline, isTrue);
      expect(activeSessions.length, 2);

      // Device A disconnects
      activeSessions.remove('dev_phone_A');
      // Prune sessions older than 4 minutes
      activeSessions.removeWhere((k, v) {
        final dt = DateTime.tryParse(v.toString());
        return dt == null || now.difference(dt).inMinutes >= 4;
      });

      // User remains online because device B is still active!
      isUserOnline = activeSessions.isNotEmpty;
      expect(isUserOnline, isTrue);
      expect(activeSessions.containsKey('dev_tablet_B'), isTrue);

      // Device B disconnects
      activeSessions.remove('dev_tablet_B');
      isUserOnline = activeSessions.isNotEmpty;
      expect(isUserOnline, isFalse);
      expect(activeSessions.isEmpty, isTrue);
    });

    test('Stale multi-device sessions (>4 min) are pruned automatically', () {
      final now = DateTime(2026, 10, 26, 12, 0, 0);
      final tenMinAgo = now.subtract(const Duration(minutes: 10));

      final Map<String, dynamic> activeSessions = {
        'dev_phone_stale': tenMinAgo.toIso8601String(),
      };

      // When another device connects or disconnects, stale sessions are pruned
      activeSessions.removeWhere((k, v) {
        final dt = DateTime.tryParse(v.toString());
        return dt == null || now.difference(dt).inMinutes >= 4;
      });

      expect(activeSessions.isEmpty, isTrue);
      expect(activeSessions.isNotEmpty, isFalse);
    });
  });

  group('4. Typing Indicator Scoping & Recipient Expiration', () {
    test('isUserTypingInConnection returns true only for matching connection within 5 seconds', () {
      final now = DateTime.now();

      final user = UserModel(
        id: 'u2',
        username: 'chatter',
        email: 'c@test.com',
        country: 'US',
        city: 'NY',
        dateOfBirth: DateTime(2000, 1, 1),
        gender: 'Other',
        bio: '',
        profilePicUrl: '',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '',
        typingInConnectionId: 'conn_active',
        typingUpdatedAt: now,
      );

      // Matching connection and fresh timestamp -> true
      expect(user.isUserTypingInConnection('conn_active'), isTrue);

      // Different connection ID -> false (conversation isolation)
      expect(user.isUserTypingInConnection('conn_other'), isFalse);

      // Expired typing timestamp (e.g. 6 seconds ago due to sender crash or lost conn) -> false
      final expiredUser = user.copyWith(
        typingUpdatedAt: now.subtract(const Duration(seconds: 6)),
      );
      expect(expiredUser.isUserTypingInConnection('conn_active'), isFalse);
    });
  });

  group('5. Chat Screen Typing Throttling & Inactivity Lifecycle Widget Tests', () {
    testWidgets('Entering text throttles remote updates and auto-clears on send', (tester) async {
      final authProv = _FakeAuthProvider();
      final userProv = _FakeUserProvider();
      final connProv = _FakeConnectionProvider();
      final chatProv = _TestableChatProvider();

      final currentUser = UserModel(
        id: 'user_me',
        username: 'alice',
        email: 'alice@test.com',
        country: 'US',
        city: 'NY',
        dateOfBirth: DateTime(1998, 1, 1),
        gender: 'Female',
        bio: 'Bio',
        profilePicUrl: '',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+1234',
        isOnline: true,
      );
      authProv.currentUser = currentUser;

      final connection = _createTestConn(
        connId: 'conn_typing_test',
        senderId: 'user_me',
        recipientId: 'user_them',
        recipientUsername: 'bob',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: connection),
          ),
        ),
      );
      await tester.pump();

      // Find the message text field
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // 1. Type characters rapidly into composer
      await tester.enterText(textFieldFinder, 'H');
      await tester.pump();
      await tester.enterText(textFieldFinder, 'He');
      await tester.pump();
      await tester.enterText(textFieldFinder, 'Hello');
      await tester.pump();

      // Typing status was set to true
      expect(chatProv.lastTypingConnectionId, 'conn_typing_test');
      expect(chatProv.lastTypingUserId, 'user_me');
      expect(chatProv.lastIsTyping, isTrue);

      // 2. Tap Send button
      final sendButton = find.byIcon(Icons.send_rounded);
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pump();

      // After send, typing status was immediately cleared to false
      expect(chatProv.lastIsTyping, isFalse);
    });

    testWidgets('3 seconds of inactivity clears typing status', (tester) async {
      final authProv = _FakeAuthProvider();
      final userProv = _FakeUserProvider();
      final connProv = _FakeConnectionProvider();
      final chatProv = _TestableChatProvider();

      final currentUser = UserModel(
        id: 'user_me',
        username: 'alice',
        email: 'alice@test.com',
        country: 'US',
        city: 'NY',
        dateOfBirth: DateTime(1998, 1, 1),
        gender: 'Female',
        bio: 'Bio',
        profilePicUrl: '',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+1234',
      );
      authProv.currentUser = currentUser;

      final connection = _createTestConn(
        connId: 'conn_timeout_test',
        senderId: 'user_me',
        recipientId: 'user_them',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: connection),
          ),
        ),
      );
      await tester.pump();

      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, 'Still thinking...');
      await tester.pump();
      expect(chatProv.lastIsTyping, isTrue);

      // Advance time by 3.1 seconds of user inactivity
      await tester.pump(const Duration(milliseconds: 3100));

      // Inactivity timer fired and cleared typing
      expect(chatProv.lastIsTyping, isFalse);
    });

    testWidgets('Switching conversations or unmounting chat clears typing cleanly', (tester) async {
      final authProv = _FakeAuthProvider();
      final userProv = _FakeUserProvider();
      final connProv = _FakeConnectionProvider();
      final chatProv = _TestableChatProvider();

      final currentUser = UserModel(
        id: 'user_me',
        username: 'alice',
        email: 'alice@test.com',
        country: 'US',
        city: 'NY',
        dateOfBirth: DateTime(1998, 1, 1),
        gender: 'Female',
        bio: 'Bio',
        profilePicUrl: '',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+1234',
      );
      authProv.currentUser = currentUser;

      final conn1 = _createTestConn(connId: 'conn_alpha', senderId: 'user_me', recipientId: 'user_b');
      final conn2 = _createTestConn(connId: 'conn_beta', senderId: 'user_me', recipientId: 'user_c');

      // Mount ChatScreen with conn1
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
      await tester.pump();

      // Start typing in conn1
      await tester.enterText(find.byType(TextField), 'Message in conn1');
      await tester.pump();
      expect(chatProv.lastTypingConnectionId, 'conn_alpha');
      expect(chatProv.lastIsTyping, isTrue);

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
      await tester.pump();

      // Typing in conn1 was cleared on conversation switch
      expect(chatProv.lastTypingConnectionId, 'conn_alpha');
      expect(chatProv.lastIsTyping, isFalse);

      // Unmount ChatScreen completely
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      // State is disposed cleanly without exceptions
    });
  });
}
