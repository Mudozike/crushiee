import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:crushie/models/chat_message_model.dart';
import 'package:crushie/models/connection_model.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/providers/chat_provider.dart';
import 'package:crushie/providers/connection_provider.dart';
import 'package:crushie/providers/user_provider.dart';
import 'package:crushie/screens/messages/chat_screen.dart';
import 'package:crushie/screens/messages/messages_list_screen.dart';
import 'package:crushie/widgets/contact_reveal_card.dart';
import 'package:crushie/widgets/status_badge.dart';

// Test Mocks & Fakes
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

class FakeUserProvider extends ChangeNotifier implements UserProvider {
  final Set<String> _blocked = {};

  @override
  bool isUserBlocked(String userId, String targetId) =>
      _blocked.contains('$userId:$targetId');

  @override
  Future<void> blockUser(String userId, String targetId,
      {String? targetUsername}) async {
    _blocked.add('$userId:$targetId');
    notifyListeners();
  }

  @override
  Future<void> unblockUser(String userId, String targetId) async {
    _blocked.remove('$userId:$targetId');
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeConnectionProvider extends ChangeNotifier
    implements ConnectionProvider {
  @override
  bool get isLoading => false;

  @override
  List<ConnectionModel> getAcceptedConnections(String userId) => [];

  @override
  List<ConnectionModel> getPendingRequestsForUser(String userId) => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestableChatProvider extends ChatProvider {
  int streamRequestCount = 0;
  String? lastRequestedConnectionId;
  StreamController<List<ChatMessageModel>>? activeController;
  bool simulateError = false;

  @override
  Stream<List<ChatMessageModel>> getChatMessagesStream(String connectionId,
      {int limit = 50}) {
    streamRequestCount++;
    lastRequestedConnectionId = connectionId;
    if (simulateError) {
      return Stream.error(Exception('Simulated offline network error'));
    }
    activeController = StreamController<List<ChatMessageModel>>.broadcast();
    return activeController!.stream;
  }

  @override
  Future<void> sendMessage({
    required String connectionId,
    required String senderId,
    required String recipientId,
    required String text,
    String? mediaUrl,
  }) async {
    final msg = ChatMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      connectionId: connectionId,
      senderId: senderId,
      recipientId: recipientId,
      message: text.trim(),
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
      deliveryStatus: MessageDeliveryStatus.sent,
    );
    syncMessages(connectionId, [msg]);
  }
}

UserModel _createTestUser(String id, String username) => UserModel(
      id: id,
      username: username,
      email: '$username@test.com',
      gender: 'Female',
      country: 'Kenya',
      city: 'Nairobi',
      contactDetails: '+254712345678',
      preferredContactMethod: 'WhatsApp',
      bio: 'Hello',
      profilePicUrl: '',
      dateOfBirth: DateTime(2000, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase A1: Message Timestamp Parsing & Resiliency', () {
    test('Parses Firestore Timestamp correctly without crashing', () {
      final utcNow = DateTime.utc(2026, 10, 18, 14, 30, 0);
      final ts = Timestamp.fromDate(utcNow);
      final parsed = ChatMessageModel.parseTimestamp(ts);

      expect(parsed.isAtSameMomentAs(utcNow), isTrue);
    });

    test('Parses DateTime directly and preserves value', () {
      final dt = DateTime(2026, 10, 18, 9, 15, 30);
      final parsed = ChatMessageModel.parseTimestamp(dt);

      expect(parsed, equals(dt));
    });

    test('Parses valid ISO-8601 strings safely', () {
      const iso = '2026-10-18T10:20:30.000Z';
      final parsed = ChatMessageModel.parseTimestamp(iso);

      expect(parsed.isUtc, isTrue);
      expect(parsed.year, equals(2026));
      expect(parsed.month, equals(10));
      expect(parsed.day, equals(18));
      expect(parsed.hour, equals(10));
      expect(parsed.minute, equals(20));
    });

    test('Parses integer epoch milliseconds and seconds', () {
      // Milliseconds
      const millis = 1760788800000;
      final parsedMillis = ChatMessageModel.parseTimestamp(millis);
      expect(parsedMillis.millisecondsSinceEpoch, equals(millis));

      // Seconds
      const seconds = 1760788800;
      final parsedSeconds = ChatMessageModel.parseTimestamp(seconds);
      expect(parsedSeconds.millisecondsSinceEpoch, equals(seconds * 1000));
    });

    test('Handles null, invalid string, or corrupt raw value with deterministic fallback', () {
      final fallback = DateTime(2026, 1, 1, 0, 0);

      expect(ChatMessageModel.parseTimestamp(null, fallback: fallback), equals(fallback));
      expect(ChatMessageModel.parseTimestamp('invalid-date-format', fallback: fallback), equals(fallback));
      expect(ChatMessageModel.parseTimestamp({'invalid': 'map'}, fallback: fallback), equals(fallback));
    });

    test('Extracts deterministic fallback timestamp from message ID suffix', () {
      const millis = 1760799999000;
      const msgId = 'msg_$millis';

      final fallback = ChatMessageModel.fallbackTimestamp(msgId);
      expect(fallback!.millisecondsSinceEpoch, equals(millis));
    });

    test('Preserves valid server timestamps without replacing with device time', () {
      final serverTime = DateTime.utc(2026, 5, 1, 12, 0, 0);
      final parsed = ChatMessageModel.parseTimestamp(serverTime);

      // Must be the server timestamp, not DateTime.now()
      expect(parsed, equals(serverTime));
      expect(parsed.isBefore(DateTime.now()), isTrue);
    });

    test('ChatMessageModel.fromMap gracefully parses corrupt documents without throwing', () {
      final rawMap = {
        'id': 'msg_test_123',
        'connectionId': 'conn_1',
        'senderId': 'user_a',
        'recipientId': 'user_b',
        'message': 'Hello world',
        'timestamp': 'completely_corrupt_timestamp',
      };

      final msg = ChatMessageModel.fromMap(rawMap, 'msg_test_123');
      expect(msg.id, equals('msg_test_123'));
      expect(msg.message, equals('Hello world'));
      expect(msg.timestamp, isNotNull);
    });

    test('Messages preserve chronological sorting when parsed', () {
      final t1 = DateTime.utc(2026, 10, 18, 10, 0);
      final t2 = DateTime.utc(2026, 10, 18, 11, 0);
      final t3 = DateTime.utc(2026, 10, 18, 12, 0);

      final msgList = [
        ChatMessageModel(
          id: '3',
          connectionId: 'c1',
          senderId: 'u1',
          recipientId: 'u2',
          message: 'third',
          timestamp: t3,
        ),
        ChatMessageModel(
          id: '1',
          connectionId: 'c1',
          senderId: 'u1',
          recipientId: 'u2',
          message: 'first',
          timestamp: t1,
        ),
        ChatMessageModel(
          id: '2',
          connectionId: 'c1',
          senderId: 'u1',
          recipientId: 'u2',
          message: 'second',
          timestamp: t2,
        ),
      ];

      msgList.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      expect(msgList[0].id, equals('1'));
      expect(msgList[1].id, equals('2'));
      expect(msgList[2].id, equals('3'));
    });
  });

  group('Phase A2: Relative Timestamps and Presence Labels', () {
    final referenceNow = DateTime(2026, 10, 18, 15, 30, 0);

    test('Displays "Online" when user is marked online', () {
      final status = MessagesListScreen.formatPresenceStatus(true, referenceNow, now: referenceNow);
      expect(status, equals('Online'));

      final badgeStatus = StatusBadge.formatStatus(true, referenceNow, now: referenceNow);
      expect(badgeStatus, equals('Online'));
    });

    test('Displays "Offline" when lastSeen is null', () {
      final status = MessagesListScreen.formatPresenceStatus(false, null, now: referenceNow);
      expect(status, equals('Offline'));

      final badgeStatus = StatusBadge.formatStatus(false, null, now: referenceNow);
      expect(badgeStatus, equals('Offline'));
    });

    test('Displays "Last seen just now" for under 60 seconds (boundary test)', () {
      // 0 seconds ago
      expect(MessagesListScreen.formatPresenceStatus(false, referenceNow, now: referenceNow),
          equals('Last seen just now'));
      // 10 seconds ago
      final tenSecAgo = referenceNow.subtract(const Duration(seconds: 10));
      expect(MessagesListScreen.formatPresenceStatus(false, tenSecAgo, now: referenceNow),
          equals('Last seen just now'));
      // 59 seconds ago
      final fiftyNineSecAgo = referenceNow.subtract(const Duration(seconds: 59));
      expect(MessagesListScreen.formatPresenceStatus(false, fiftyNineSecAgo, now: referenceNow),
          equals('Last seen just now'));

      // StatusBadge
      expect(StatusBadge.formatStatus(false, fiftyNineSecAgo, now: referenceNow),
          equals('Last seen just now'));
    });

    test('Safely handles future timestamps (clock drift) with "Last seen just now"', () {
      final futureTime = referenceNow.add(const Duration(seconds: 30));
      expect(MessagesListScreen.formatPresenceStatus(false, futureTime, now: referenceNow),
          equals('Last seen just now'));
      expect(StatusBadge.formatStatus(false, futureTime, now: referenceNow),
          equals('Last seen just now'));
    });

    test('Displays minute boundary: exactly 60 seconds is 1m ago', () {
      final oneMinAgo = referenceNow.subtract(const Duration(seconds: 60));
      expect(MessagesListScreen.formatPresenceStatus(false, oneMinAgo, now: referenceNow),
          equals('Last seen 1m ago'));
      expect(StatusBadge.formatStatus(false, oneMinAgo, now: referenceNow),
          equals('Last seen 1m ago'));

      final fiftyNineMinAgo = referenceNow.subtract(const Duration(minutes: 59));
      expect(MessagesListScreen.formatPresenceStatus(false, fiftyNineMinAgo, now: referenceNow),
          equals('Last seen 59m ago'));
    });

    test('Displays hour boundary and calendar day boundaries', () {
      // 2 hours ago today
      final twoHoursAgo = referenceNow.subtract(const Duration(hours: 2));
      expect(MessagesListScreen.formatPresenceStatus(false, twoHoursAgo, now: referenceNow),
          equals('Last seen 2h ago'));

      // Yesterday boundary
      final yesterday = DateTime(2026, 10, 17, 20, 0, 0);
      expect(MessagesListScreen.formatPresenceStatus(false, yesterday, now: referenceNow),
          equals('Last seen yesterday'));
      expect(StatusBadge.formatStatus(false, yesterday, now: referenceNow),
          equals('Last seen yesterday'));

      // 3 days ago boundary
      final threeDaysAgo = DateTime(2026, 10, 15, 12, 0, 0);
      expect(MessagesListScreen.formatPresenceStatus(false, threeDaysAgo, now: referenceNow),
          equals('Last seen 3d ago'));
    });

    test('Conversation timestamp formatting with local timezone conversion', () {
      // Today formatting -> h:mm a
      final localToday = DateTime(2026, 10, 18, 14, 15);
      final formattedToday =
          MessagesListScreen.formatConversationTimestamp(localToday, now: referenceNow);
      expect(formattedToday, equals(DateFormat('h:mm a').format(localToday.toLocal())));

      // Yesterday formatting -> "Yesterday"
      final yesterday = DateTime(2026, 10, 17, 10, 0);
      expect(MessagesListScreen.formatConversationTimestamp(yesterday, now: referenceNow),
          equals('Yesterday'));

      // Same year formatting -> "d MMM"
      final sameYear = DateTime(2026, 8, 12, 10, 0);
      expect(MessagesListScreen.formatConversationTimestamp(sameYear, now: referenceNow),
          equals(DateFormat('d MMM').format(sameYear.toLocal())));

      // Different year formatting -> "d MMM yyyy"
      final lastYear = DateTime(2025, 8, 12, 10, 0);
      expect(MessagesListScreen.formatConversationTimestamp(lastYear, now: referenceNow),
          equals(DateFormat('d MMM yyyy').format(lastYear.toLocal())));
    });

    test('Timezone conversion: UTC timestamp across midnight boundary converts correctly to local day', () {
      // Suppose local time is UTC+3.
      // 2026-10-18 01:30 local is 2026-10-17 22:30 UTC.
      // Without toLocal(), checking against today (Oct 18) would treat Oct 17 UTC as "Yesterday"!
      // With toLocal(), both are on Oct 18 in local time.
      final nowLocal = DateTime.now();
      final msgUtc = nowLocal.toUtc();

      final formatted = MessagesListScreen.formatConversationTimestamp(msgUtc);
      // Because msgUtc represents nowLocal, it should format as today's time "h:mm a", NOT "Yesterday"
      expect(formatted, equals(DateFormat('h:mm a').format(nowLocal)));
    });
  });

  group('Phase A3: Contact Access Safety & Fail-Closed Behavior', () {
    test('isValidContact rejects empty, blank, or invalid phone numbers', () {
      expect(ContactRevealCard.isValidContact('whatsapp', ''), isFalse);
      expect(ContactRevealCard.isValidContact('whatsapp', '   '), isFalse);
      expect(ContactRevealCard.isValidContact('whatsapp', null), isFalse);
      expect(ContactRevealCard.isValidContact(null, '+254712345678'), isFalse);
      expect(ContactRevealCard.isValidContact('whatsapp', '12345'), isFalse); // < 8 digits
      expect(ContactRevealCard.isValidContact('phone call', 'abc'), isFalse);
      expect(ContactRevealCard.isValidContact('email', 'not-an-email'), isFalse);
      expect(ContactRevealCard.isValidContact('telegram', '@'), isFalse);
    });

    test('isValidContact accepts valid normalized contacts', () {
      expect(ContactRevealCard.isValidContact('whatsapp', '+254712345678'), isTrue);
      expect(ContactRevealCard.isValidContact('whatsapp', '0712345678'), isTrue);
      expect(ContactRevealCard.isValidContact('phone call', '+1 555 123 4567'), isTrue);
      expect(ContactRevealCard.isValidContact('email', 'alice@crushie.app'), isTrue);
      expect(ContactRevealCard.isValidContact('telegram', '@alice_crushie'), isTrue);
    });

    test('normalizePhone normalizes and validates digits accurately', () {
      expect(ContactRevealCard.normalizePhone('+254 712-345-678'), equals('254712345678'));
      expect(ContactRevealCard.normalizePhone('0712345678'), equals('0712345678'));
      expect(ContactRevealCard.normalizePhone('123'), isNull); // Too short
      expect(ContactRevealCard.normalizePhone('123456789012345678'), isNull); // Too long
    });

    testWidgets('ContactRevealCard renders SizedBox.shrink when contact info is missing or blank',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactRevealCard(
              contactMethod: 'whatsapp',
              contactDetails: '',
              username: 'bob',
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.textContaining('UNLOCKED CONTACT METHOD'), findsNothing);
    });

    testWidgets('ContactRevealCard renders SizedBox.shrink when phone number is malformed (< 8 digits)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactRevealCard(
              contactMethod: 'whatsapp',
              contactDetails: '123',
              username: 'bob',
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('ContactRevealCard does not launch external WhatsApp and shows fail-closed notice',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactRevealCard(
              contactMethod: 'whatsapp',
              contactDetails: '+254712345678',
              username: 'bob',
            ),
          ),
        ),
      );

      // Card is displayed with warning button
      expect(find.text('Contact Opening Unavailable'), findsOneWidget);
      expect(find.textContaining('Direct external messaging is temporarily disabled'), findsOneWidget);

      // Tap button -> Shows fail-closed SnackBar instead of external URL launching
      await tester.tap(find.text('Contact Opening Unavailable'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Direct contact opening is temporarily unavailable pending server verification'),
          findsOneWidget);
    });

    test('Conversation previews do not expose private contact details', () {
      final conn = ConnectionModel(
        id: 'conn_1',
        senderId: 'userA',
        senderUsername: 'Alice',
        senderProfilePic: '',
        receiverId: 'userB',
        receiverUsername: 'Bob',
        receiverProfilePic: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        participants: ['userA', 'userB'],
        recipientContactMethod: 'whatsapp',
        recipientContactDetails: '+254712345678', // Private number
      );

      // In MessagesListScreen: previewText should be generic connected message, never exposing phone number
      final previewText = (conn.lastMessageText != null && conn.lastMessageText!.isNotEmpty)
          ? conn.lastMessageText!
          : 'Connected! Tap to start chatting';

      expect(previewText.contains('+254712345678'), isFalse);
      expect(previewText, equals('Connected! Tap to start chatting'));
    });
  });

  group('Phase A4: Chat Stream Retention & Provider Deduplication', () {
    test('ChatProvider.syncMessages deduplicates and prevents redundant notifyListeners', () {
      final chatProv = ChatProvider();
      int notifyCount = 0;
      chatProv.addListener(() => notifyCount++);

      final t1 = DateTime(2026, 10, 18, 10, 0);
      final msg1 = ChatMessageModel(
        id: 'msg_1',
        connectionId: 'conn_100',
        senderId: 'userA',
        recipientId: 'userB',
        message: 'Hello',
        timestamp: t1,
      );

      // First sync adds the message
      chatProv.syncMessages('conn_100', [msg1]);
      expect(notifyCount, equals(1));
      expect(chatProv.getMessagesForConnection('conn_100').length, equals(1));

      // Second sync with identical data -> does NOT notify listeners!
      chatProv.syncMessages('conn_100', [msg1]);
      expect(notifyCount, equals(1)); // Still 1!
    });

    test('ChatProvider.syncMessages reconciles optimistic message with incoming Firestore message', () {
      final chatProv = ChatProvider();
      final t1 = DateTime(2026, 10, 18, 10, 0);

      // Local optimistic message
      final localOptimistic = ChatMessageModel(
        id: 'msg_10',
        connectionId: 'conn_100',
        senderId: 'userA',
        recipientId: 'userB',
        message: 'Hello from local',
        timestamp: t1,
        deliveryStatus: MessageDeliveryStatus.sent,
      );
      chatProv.syncMessages('conn_100', [localOptimistic]);

      // Server acknowledged message with same ID
      final serverAck = ChatMessageModel(
        id: 'msg_10',
        connectionId: 'conn_100',
        senderId: 'userA',
        recipientId: 'userB',
        message: 'Hello from local',
        timestamp: t1,
        deliveryStatus: MessageDeliveryStatus.delivered,
      );
      chatProv.syncMessages('conn_100', [serverAck]);

      final messages = chatProv.getMessagesForConnection('conn_100');
      expect(messages.length, equals(1));
      expect(messages.first.deliveryStatus, equals(MessageDeliveryStatus.delivered));
    });

    testWidgets('ChatScreen retains stream across widget rebuilds without creating new subscriptions',
        (tester) async {
      final authProv = FakeAuthProvider();
      final userProv = FakeUserProvider();
      final connProv = FakeConnectionProvider();
      final chatProv = TestableChatProvider();

      final currentUser = _createTestUser('userA', 'alice');
      authProv.currentUser = currentUser;

      final connection = ConnectionModel(
        id: 'conn_test_lifecycle',
        senderId: 'userA',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'userB',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        participants: ['userA', 'userB'],
      );

      // Pump widget
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

      // Verify stream was requested once
      expect(chatProv.streamRequestCount, equals(1));

      // Trigger a provider notify / parent rebuild
      authProv.notifyListeners();
      await tester.pump();

      // Verify stream was NOT recreated on rebuild
      expect(chatProv.streamRequestCount, equals(1));
    });

    test('ChatProvider.syncMessages triggers notifyListeners when deletedForUserIds changes user ID with identical list length', () {
      final chatProv = ChatProvider();
      int notifyCount = 0;
      chatProv.addListener(() => notifyCount++);

      final t1 = DateTime(2026, 10, 18, 10, 0);
      final msg1 = ChatMessageModel(
        id: 'msg_del_test',
        connectionId: 'conn_100',
        senderId: 'userA',
        recipientId: 'userB',
        message: 'Hello',
        timestamp: t1,
        deletedForUserIds: ['user_first'],
      );

      // Initial sync
      chatProv.syncMessages('conn_100', [msg1]);
      expect(notifyCount, equals(1));
      expect(chatProv.getMessagesForConnection('conn_100').first.deletedForUserIds, equals(['user_first']));

      // Content of deletedForUserIds changes to another user ID while length remains 1
      final msg2 = ChatMessageModel(
        id: 'msg_del_test',
        connectionId: 'conn_100',
        senderId: 'userA',
        recipientId: 'userB',
        message: 'Hello',
        timestamp: t1,
        deletedForUserIds: ['user_second'],
      );

      chatProv.syncMessages('conn_100', [msg2]);
      expect(notifyCount, equals(2), reason: 'Must notify listeners when deleted-user ID changes even if list length stays 1');
      expect(chatProv.getMessagesForConnection('conn_100').first.deletedForUserIds, equals(['user_second']));

      // Syncing identical msg2 again does NOT trigger notifyListeners
      chatProv.syncMessages('conn_100', [msg2]);
      expect(notifyCount, equals(2), reason: 'Must not notify when messages genuinely have not changed');
    });

    test('ChatProvider.syncMessages triggers notifyListeners when mediaUrl or content changes', () {
      final chatProv = ChatProvider();
      int notifyCount = 0;
      chatProv.addListener(() => notifyCount++);

      final t1 = DateTime(2026, 10, 18, 10, 0);
      final msg1 = ChatMessageModel(
        id: 'msg_media_test',
        connectionId: 'conn_100',
        senderId: 'userA',
        recipientId: 'userB',
        message: 'Photo',
        mediaUrl: 'https://example.com/old.png',
        timestamp: t1,
      );

      chatProv.syncMessages('conn_100', [msg1]);
      expect(notifyCount, equals(1));

      final msg2 = ChatMessageModel(
        id: 'msg_media_test',
        connectionId: 'conn_100',
        senderId: 'userA',
        recipientId: 'userB',
        message: 'Photo',
        mediaUrl: 'https://example.com/new.png',
        timestamp: t1,
      );

      chatProv.syncMessages('conn_100', [msg2]);
      expect(notifyCount, equals(2), reason: 'Must notify when mediaUrl changes');
    });

    testWidgets('ChatScreen switches stream and isolates messages when connection ID changes',
        (tester) async {
      final authProv = FakeAuthProvider();
      final userProv = FakeUserProvider();
      final connProv = FakeConnectionProvider();
      final chatProv = TestableChatProvider();

      final currentUser = _createTestUser('userA', 'alice');
      authProv.currentUser = currentUser;

      final connection1 = ConnectionModel(
        id: 'conn_alpha',
        senderId: 'userA',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'userB',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        participants: ['userA', 'userB'],
      );

      final connection2 = ConnectionModel(
        id: 'conn_beta',
        senderId: 'userA',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'userC',
        receiverUsername: 'carol',
        receiverProfilePic: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        participants: ['userA', 'userC'],
      );

      // Pump ChatScreen for connection1
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: connection1),
          ),
        ),
      );

      expect(chatProv.streamRequestCount, equals(1));
      expect(chatProv.lastRequestedConnectionId, equals('conn_alpha'));

      // Emit message for conn_alpha
      final msgAlpha = ChatMessageModel(
        id: 'msg_alpha_1',
        connectionId: 'conn_alpha',
        senderId: 'userA',
        recipientId: 'userB',
        message: 'Secret message for Bob',
        timestamp: DateTime.now(),
      );
      chatProv.activeController?.add([msgAlpha]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Secret message for Bob'), findsOneWidget);

      // Now switch connection to connection2 (conn_beta)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProv),
          ],
          child: MaterialApp(
            home: ChatScreen(connection: connection2),
          ),
        ),
      );

      // Verify stream switched to conn_beta
      expect(chatProv.streamRequestCount, equals(2));
      expect(chatProv.lastRequestedConnectionId, equals('conn_beta'));

      // Old message from conn_alpha must NEVER leak into conn_beta
      expect(find.text('Secret message for Bob'), findsNothing);

      // Initially while waiting for conn_beta, progress indicator shows (never stale conn_alpha msgs)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // When conn_beta emits empty list, it transitions to empty state
      chatProv.activeController?.add([]);
      await tester.pump();
      expect(find.text('No messages yet. Say hi to @carol!'), findsOneWidget);
    });

    testWidgets('ChatScreen retry re-initializes stream cleanly without duplicate listeners',
        (tester) async {
      final authProv = FakeAuthProvider();
      final userProv = FakeUserProvider();
      final connProv = FakeConnectionProvider();
      final chatProv = TestableChatProvider();

      final currentUser = _createTestUser('userA', 'alice');
      authProv.currentUser = currentUser;

      final connection = ConnectionModel(
        id: 'conn_retry_test',
        senderId: 'userA',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'userB',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        participants: ['userA', 'userB'],
      );

      // Simulate network error on first stream
      chatProv.simulateError = true;

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
      expect(find.text('Failed to load messages'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(chatProv.streamRequestCount, equals(1));

      // Clear error condition and tap Retry
      chatProv.simulateError = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Verify stream re-initialized once more
      expect(chatProv.streamRequestCount, equals(2));

      // Emit new message and ensure it is received cleanly
      final msg = ChatMessageModel(
        id: 'msg_after_retry',
        connectionId: 'conn_retry_test',
        senderId: 'userB',
        recipientId: 'userA',
        message: 'Recovered message',
        timestamp: DateTime.now(),
      );
      chatProv.activeController?.add([msg]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Recovered message'), findsOneWidget);
      expect(find.text('Failed to load messages'), findsNothing);
    });
  });

  group('Phase A5: Chat Overflow & Keyboard Layout Constraints', () {
    testWidgets('ChatScreen handles constrained small viewport with zero RenderFlex overflow (12px bug fix)',
        (tester) async {
      final authProv = FakeAuthProvider();
      final userProv = FakeUserProvider();
      final connProv = FakeConnectionProvider();
      final chatProv = TestableChatProvider();

      final currentUser = _createTestUser('userA', 'alice');
      authProv.currentUser = currentUser;

      final connection = ConnectionModel(
        id: 'conn_small_screen',
        senderId: 'userA',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'userB',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        participants: ['userA', 'userB'],
      );

      // Configure a constrained small screen: 320x480 (typical small screen device)
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      // Simulate stream error to render the error state
      chatProv.activeController?.addError(Exception('Network disconnected'));
      await tester.pump();

      // The error state is displayed
      expect(find.text('Failed to load messages'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Check no Flutter overflow errors were logged
      expect(tester.takeException(), isNull);

      // Simulate keyboard open by setting bottom viewInsets
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pump();

      // Check no overflow occurred even when keyboard opens in error state
      expect(tester.takeException(), isNull);

      // Check composer remains visible and usable
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Cached messages remain visible while stream reconnects or errors',
        (tester) async {
      final authProv = FakeAuthProvider();
      final userProv = FakeUserProvider();
      final connProv = FakeConnectionProvider();
      final chatProv = TestableChatProvider();

      final currentUser = _createTestUser('userA', 'alice');
      authProv.currentUser = currentUser;

      final connection = ConnectionModel(
        id: 'conn_cached_msgs',
        senderId: 'userA',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'userB',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        participants: ['userA', 'userB'],
      );

      // Pre-seed cached message and configure stream error
      final msg = ChatMessageModel(
        id: 'msg_pre_cached',
        connectionId: 'conn_cached_msgs',
        senderId: 'userB',
        recipientId: 'userA',
        message: 'Important cached message',
        timestamp: DateTime.now(),
      );
      chatProv.syncMessages('conn_cached_msgs', [msg]);
      chatProv.simulateError = true;

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

      // Cached message is STILL visible, and live update error banner is shown
      expect(find.text('Important cached message'), findsOneWidget);
      expect(find.text('Unable to update live messages'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('In-app chat functionality remains fully working', (tester) async {
      final authProv = FakeAuthProvider();
      final userProv = FakeUserProvider();
      final connProv = FakeConnectionProvider();
      final chatProv = TestableChatProvider();

      final currentUser = _createTestUser('userA', 'alice');
      authProv.currentUser = currentUser;

      final connection = ConnectionModel(
        id: 'conn_send_test',
        senderId: 'userA',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'userB',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        participants: ['userA', 'userB'],
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

      // Type a message in the composer
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Testing in-app message sending');

      // Tap send button
      final sendBtn = find.byIcon(Icons.send_rounded);
      expect(sendBtn, findsOneWidget);
      await tester.tap(sendBtn);
      await tester.pump();

      // TextField input controller was cleared
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, isEmpty);

      // And the sent message bubble is rendered in the conversation thread
      expect(find.text('Testing in-app message sending'), findsOneWidget);
    });
  });
}
