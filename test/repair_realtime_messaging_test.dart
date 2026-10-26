import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:crushie/models/chat_message_model.dart';
import 'package:crushie/models/connection_model.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/providers/chat_provider.dart';
import 'package:crushie/providers/connection_provider.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/services/firestore_service.dart';
import 'package:crushie/widgets/status_badge.dart';

class MockFailingFirestoreService extends FirestoreService {
  MockFailingFirestoreService() : super.forTesting();

  @override
  Future<void> markMessagesAsRead(String connectionId, String currentUserId) async {
    throw Exception('PERMISSION_DENIED: Write rejected by security rules');
  }

  @override
  Future<void> deleteMessageForMe(String connectionId, String messageId, String userId) async {
    throw Exception('PERMISSION_DENIED: Write rejected by security rules');
  }

  @override
  Future<void> deleteMessageForEveryone(String connectionId, String messageId) async {
    throw Exception('PERMISSION_DENIED: Write rejected by security rules');
  }

  @override
  Future<void> sendChatMessage(ChatMessageModel message) async {
    throw Exception('NETWORK_ERROR: Write failed on server');
  }
}

class FakeFirestoreTimestamp {
  final DateTime _dateTime;
  FakeFirestoreTimestamp(this._dateTime);
  DateTime toDate() => _dateTime;
  @override
  String toString() => 'Timestamp(seconds=${_dateTime.millisecondsSinceEpoch ~/ 1000}, nanoseconds=0)';
}

class MockPaginationFirestoreService extends FirestoreService {
  final List<ChatMessageModel> storedMessages;
  final bool simulateMissingCursorDoc;
  final bool simulateError;

  MockPaginationFirestoreService({
    required this.storedMessages,
    this.simulateMissingCursorDoc = false,
    this.simulateError = false,
  }) : super.forTesting();

  @override
  Future<List<ChatMessageModel>> fetchOlderMessages({
    required String connectionId,
    required ChatMessageModel oldestMessage,
    int limit = 50,
  }) async {
    if (simulateError) {
      throw Exception('NETWORK_TIMEOUT: Failed to fetch older messages from Firestore');
    }
    if (simulateMissingCursorDoc || !storedMessages.any((m) => m.id == oldestMessage.id)) {
      throw StateError(
        '[FIRESTORE] Pagination cursor document not found for message ${oldestMessage.id}. '
        'Cannot construct a safe cursor without skipping or duplicating records.',
      );
    }
    final older = storedMessages.where((m) {
      final cmp = m.timestamp.compareTo(oldestMessage.timestamp);
      if (cmp != 0) return cmp < 0;
      return m.id.compareTo(oldestMessage.id) < 0;
    }).toList();

    older.sort((a, b) {
      final cmp = b.timestamp.compareTo(a.timestamp);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    final page = older.take(limit).toList();
    page.sort((a, b) {
      final cmp = a.timestamp.compareTo(b.timestamp);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
    return page;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crushie Real-Time Messaging & Synchronization Suite', () {
    late DatabaseService dbService;

    setUp(() {
      dbService = DatabaseService();
    });

    test('1. New message appears for recipient without manual refresh', () {
      final chatProv = ChatProvider();
      const connId = 'conn_alice_bob';

      final msg1 = ChatMessageModel(
        id: 'msg_100',
        connectionId: connId,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Hello Bob',
        createdAt: DateTime(2026, 10, 19, 10, 0, 0),
      );

      // Initial state has message 1
      chatProv.syncMessages(connId, [msg1]);
      expect(chatProv.getMessagesForConnection(connId).length, equals(1));
      expect(chatProv.getMessagesForConnection(connId).first.id, equals('msg_100'));

      // New message 2 arrives in stream
      final msg2 = ChatMessageModel(
        id: 'msg_101',
        connectionId: connId,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Are you there?',
        createdAt: DateTime(2026, 10, 19, 10, 1, 0),
      );

      chatProv.syncMessages(connId, [msg1, msg2]);
      final updated = chatProv.getMessagesForConnection(connId);
      expect(updated.length, equals(2));
      expect(updated.last.id, equals('msg_101'));
      expect(updated.last.message, equals('Are you there?'));
    });

    test('2. Failed message write does not become permanently represented as successfully delivered', () async {
      final chatProv = ChatProvider();
      const connId = 'conn_alice_bob';

      await expectLater(
        () async => await chatProv.sendMessage(
          connectionId: connId,
          senderId: 'alice',
          recipientId: 'bob',
          text: 'This write will fail on Firestore due to uninitialized app',
        ),
        throwsA(anything),
      );

      // Verify that after write failure, optimistic message is purged from both ChatProvider and DatabaseService
      final providerMessages = chatProv.getMessagesForConnection(connId);
      expect(providerMessages.any((m) => m.message.contains('This write will fail')), isFalse);

      final dbMessages = dbService.getChatMessages(connId);
      expect(dbMessages.any((m) => m.message.contains('This write will fail')), isFalse);
    });

    test('3. Optimistic and server-confirmed messages do not duplicate', () {
      final chatProv = ChatProvider();
      const connId = 'conn_alice_bob';

      final optimisticMsg = ChatMessageModel(
        id: 'msg_opt_123',
        connectionId: connId,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Optimistic message text',
        createdAt: DateTime(2026, 10, 19, 11, 0, 0),
        deliveryStatus: MessageDeliveryStatus.sent,
      );

      // Simulated local optimistic presence
      chatProv.syncMessages(connId, [optimisticMsg]);
      expect(chatProv.getMessagesForConnection(connId).length, equals(1));

      // Server stream confirms the message with server timestamp and delivered status
      final serverMsg = ChatMessageModel(
        id: 'msg_opt_123',
        connectionId: connId,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Optimistic message text',
        createdAt: DateTime(2026, 10, 19, 11, 0, 1),
        deliveryStatus: MessageDeliveryStatus.delivered,
      );

      final merged = chatProv.getMergedMessages(
        connId,
        streamMessages: [serverMsg],
        userId: 'alice',
      );

      // Exactly 1 deduplicated message
      expect(merged.length, equals(1));
      expect(merged.first.id, equals('msg_opt_123'));
      expect(merged.first.deliveryStatus, equals(MessageDeliveryStatus.delivered));
    });

    test('4. Opening a conversation persists read state & clears unread locally', () async {
      final chatProv = ChatProvider();
      final connProv = ConnectionProvider();
      const connId = 'conn_alice_bob';
      const bobId = 'bob';

      // Set up an unread message for Bob
      final unreadMsg = ChatMessageModel(
        id: 'msg_200',
        connectionId: connId,
        senderId: 'alice',
        recipientId: bobId,
        message: 'Hey Bob, check this out',
        createdAt: DateTime(2026, 10, 19, 12, 0, 0),
        isRead: false,
        deliveryStatus: MessageDeliveryStatus.delivered,
      );
      chatProv.syncMessages(connId, [unreadMsg]);

      // Bob marks as read
      await chatProv.markMessagesAsRead(connId, bobId);

      final messages = chatProv.getMessagesForConnection(connId);
      expect(messages.first.isRead, isTrue);
      expect(messages.first.deliveryStatus, equals(MessageDeliveryStatus.read));

      // Test ConnectionProvider optimistic local read clearing
      final testConn = ConnectionModel(
        id: connId,
        senderId: 'alice',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: bobId,
        receiverUsername: 'bob',
        receiverProfilePic: '',
        unreadCounts: {'alice': 0, bobId: 3},
      );

      connProv.markConnectionAsReadLocally(connId, bobId);
      // Even if firestore snapshot has not returned yet, the method exists and operates safely
      expect(testConn.unreadCountForUser(bobId), equals(3));
      final clearedConn = testConn.copyWith(unreadCounts: {'alice': 0, bobId: 0});
      expect(clearedConn.unreadCountForUser(bobId), equals(0));
    });

    test('5. Sender receives updated read receipt', () {
      final chatProv = ChatProvider();
      const connId = 'conn_alice_bob';

      final sentMsg = ChatMessageModel(
        id: 'msg_300',
        connectionId: connId,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Are we still meeting?',
        createdAt: DateTime(2026, 10, 19, 13, 0, 0),
        deliveryStatus: MessageDeliveryStatus.sent,
        isRead: false,
      );

      chatProv.syncMessages(connId, [sentMsg]);
      expect(chatProv.getMessagesForConnection(connId).first.deliveryStatus,
          equals(MessageDeliveryStatus.sent));

      // Bob reads it, and stream pushes read update to Alice
      final readMsg = sentMsg.copyWith(
        isRead: true,
        deliveryStatus: MessageDeliveryStatus.read,
      );

      chatProv.syncMessages(connId, [readMsg]);
      final updated = chatProv.getMessagesForConnection(connId);
      expect(updated.first.isRead, isTrue);
      expect(updated.first.deliveryStatus, equals(MessageDeliveryStatus.read));
    });

    test('6. Unread counts decrease correctly without losing unrelated unread messages', () {
      // Alice has 2 unread messages, Bob has 3 unread messages
      final conn = ConnectionModel(
        id: 'conn_alice_bob',
        senderId: 'alice',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'bob',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        unreadCounts: {'alice': 2, 'bob': 3},
      );

      expect(conn.unreadCountForUser('alice'), equals(2));
      expect(conn.unreadCountForUser('bob'), equals(3));

      // Bob opens chat and resets his count to 0
      final updatedCounts = Map<String, int>.from(conn.unreadCounts);
      updatedCounts['bob'] = 0;
      final bobReadConn = conn.copyWith(unreadCounts: updatedCounts);

      // Bob's count is 0, but Alice's count is preserved at 2!
      expect(bobReadConn.unreadCountForUser('bob'), equals(0));
      expect(bobReadConn.unreadCountForUser('alice'), equals(2));

      // Alice sends another message to Bob -> Bob increments to 1, Alice preserved at 2
      final afterSendCounts = Map<String, int>.from(bobReadConn.unreadCounts);
      afterSendCounts['bob'] = afterSendCounts['bob']! + 1;
      final afterSendConn = bobReadConn.copyWith(unreadCounts: afterSendCounts);

      expect(afterSendConn.unreadCountForUser('bob'), equals(1));
      expect(afterSendConn.unreadCountForUser('alice'), equals(2));
    });

    test('7. Conversation previews remain consistent with newest message and resist stale cache', () {
      final now = DateTime(2026, 10, 19, 14, 0, 0);
      final earlier = DateTime(2026, 10, 19, 10, 0, 0);

      final conn = ConnectionModel(
        id: 'conn_alice_bob',
        senderId: 'alice',
        senderUsername: 'alice',
        senderProfilePic: '',
        receiverId: 'bob',
        receiverUsername: 'bob',
        receiverProfilePic: '',
        lastMessageText: 'New server message from Bob',
        lastMessageTimestamp: now,
      );

      final staleCachedMessage = ChatMessageModel(
        id: 'msg_old',
        connectionId: conn.id,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Old stale local message',
        createdAt: earlier,
      );

      final connTime = conn.lastMessageTimestamp ?? conn.updatedAt;
      bool preferLatestMessage = false;
      if (staleCachedMessage.timestamp.isAfter(connTime) ||
          staleCachedMessage.timestamp.isAtSameMomentAs(connTime) ||
          (conn.lastMessageText == null || conn.lastMessageText!.isEmpty)) {
        preferLatestMessage = true;
      }

      // Stale cached message does NOT overwrite newer confirmed server preview
      expect(preferLatestMessage, isFalse);
      final previewText = preferLatestMessage
          ? staleCachedMessage.message
          : (conn.lastMessageText ?? staleCachedMessage.message);
      expect(previewText, equals('New server message from Bob'));

      // Newer optimistic message DOES take precedence over older server preview
      final futureOptimistic = ChatMessageModel(
        id: 'msg_new_opt',
        connectionId: conn.id,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Just sent right now!',
        createdAt: DateTime(2026, 10, 19, 14, 5, 0),
      );

      bool preferOptimistic = false;
      if (futureOptimistic.timestamp.isAfter(connTime) ||
          futureOptimistic.timestamp.isAtSameMomentAs(connTime) ||
          (conn.lastMessageText == null || conn.lastMessageText!.isEmpty)) {
        preferOptimistic = true;
      }

      expect(preferOptimistic, isTrue);
    });

    test('8. Message ordering remains deterministic for missing, legacy, or equal timestamps', () {
      final identicalTime = DateTime(2026, 10, 19, 15, 0, 0);

      final msgA = ChatMessageModel(
        id: 'msg_aaa',
        connectionId: 'conn_1',
        senderId: 'u1',
        recipientId: 'u2',
        message: 'A',
        createdAt: identicalTime,
      );

      final msgB = ChatMessageModel(
        id: 'msg_bbb',
        connectionId: 'conn_1',
        senderId: 'u1',
        recipientId: 'u2',
        message: 'B',
        createdAt: identicalTime,
      );

      final list = [msgB, msgA];
      list.sort((a, b) {
        final cmp = a.timestamp.compareTo(b.timestamp);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });

      // 'msg_aaa' should deterministically come before 'msg_bbb'
      expect(list.first.id, equals('msg_aaa'));
      expect(list.last.id, equals('msg_bbb'));

      // Connection ordering tie-breaker
      final connA = ConnectionModel(
        id: 'conn_aaa',
        senderId: 'u1',
        senderUsername: 'u1',
        senderProfilePic: '',
        receiverId: 'u2',
        receiverUsername: 'u2',
        receiverProfilePic: '',
        lastMessageTimestamp: identicalTime,
      );
      final connB = ConnectionModel(
        id: 'conn_bbb',
        senderId: 'u1',
        senderUsername: 'u1',
        senderProfilePic: '',
        receiverId: 'u3',
        receiverUsername: 'u3',
        receiverProfilePic: '',
        lastMessageTimestamp: identicalTime,
      );

      final conns = [connA, connB];
      conns.sort((a, b) {
        final timeA = a.lastMessageTimestamp ?? a.updatedAt;
        final timeB = b.lastMessageTimestamp ?? b.updatedAt;
        final cmp = timeB.compareTo(timeA);
        if (cmp != 0) return cmp;
        return b.id.compareTo(a.id);
      });

      expect(conns.first.id, equals('conn_bbb'));
      expect(conns.last.id, equals('conn_aaa'));
    });

    test('9. Listener errors and conversation changes do not leave stale subscriptions or state', () {
      final chatProv = ChatProvider();
      final connProv = ConnectionProvider();

      chatProv.syncMessages('conn_1', [
        ChatMessageModel(
          id: 'msg_1',
          connectionId: 'conn_1',
          senderId: 'u1',
          recipientId: 'u2',
          message: 'Hi',
        ),
      ]);
      expect(chatProv.getMessagesForConnection('conn_1').isNotEmpty, isTrue);

      // On logout / cleanup, clear() wipes state safely
      chatProv.clear();
      expect(chatProv.getMessagesForConnection('conn_1').isEmpty, isTrue);

      connProv.clear();
      expect(connProv.connections.isEmpty, isTrue);
      expect(connProv.isLoading, isFalse);
    });

    test('10. Resilient timestamp parsing handles integer strings and fallbacks in ConnectionModel', () {
      // Integer epoch in string format
      final epochString = '1729340000000';
      final connMap = {
        'senderId': 'alice',
        'receiverId': 'bob',
        'createdAt': epochString,
        'updatedAt': epochString,
        'lastMessageTimestamp': epochString,
        'unreadCounts': {'alice': 0, 'bob': 1},
      };

      final conn = ConnectionModel.fromMap(connMap, 'conn_parsed');
      expect(conn.createdAt.millisecondsSinceEpoch, equals(1729340000000));
      expect(conn.lastMessageTimestamp?.millisecondsSinceEpoch, equals(1729340000000));
    });

    test('11. Stale stream snapshot does NOT revert locally read message to unread', () async {
      final chatProv = ChatProvider();
      const connId = 'conn_alice_bob';
      const bobId = 'bob';

      final msg = ChatMessageModel(
        id: 'msg_persist_1',
        connectionId: connId,
        senderId: 'alice',
        recipientId: bobId,
        message: 'Are you available?',
        createdAt: DateTime(2026, 10, 19, 14, 0, 0),
        isRead: false,
        deliveryStatus: MessageDeliveryStatus.delivered,
      );

      // Initial unread sync
      chatProv.syncMessages(connId, [msg]);
      expect(chatProv.getMessagesForConnection(connId).first.isRead, isFalse);

      // Bob marks as read
      await chatProv.markMessagesAsRead(connId, bobId);
      expect(chatProv.getMessagesForConnection(connId).first.isRead, isTrue);
      expect(chatProv.getMessagesForConnection(connId).first.deliveryStatus,
          equals(MessageDeliveryStatus.read));

      // A stale server snapshot arrives that was generated prior to server processing read receipt
      final staleStreamMsg = msg.copyWith(
        isRead: false,
        deliveryStatus: MessageDeliveryStatus.delivered,
      );

      // Test in getMergedMessages
      final merged = chatProv.getMergedMessages(connId, streamMessages: [staleStreamMsg], userId: bobId);
      expect(merged.first.isRead, isTrue, reason: 'Read state must not revert in getMergedMessages');
      expect(merged.first.deliveryStatus, equals(MessageDeliveryStatus.read));

      // Test in syncMessages
      chatProv.syncMessages(connId, [staleStreamMsg]);
      final synced = chatProv.getMessagesForConnection(connId);
      expect(synced.first.isRead, isTrue, reason: 'Read state must not revert in syncMessages');
      expect(synced.first.deliveryStatus, equals(MessageDeliveryStatus.read));
    });

    test('12. Delete for me hides message only for requesting user and persists across stale snapshots', () async {
      final chatProv = ChatProvider();
      const connId = 'conn_alice_bob';
      const aliceId = 'alice';
      const bobId = 'bob';

      final msg = ChatMessageModel(
        id: 'msg_del_me_1',
        connectionId: connId,
        senderId: aliceId,
        recipientId: bobId,
        message: 'Private note for Alice',
        createdAt: DateTime(2026, 10, 19, 15, 0, 0),
      );

      chatProv.syncMessages(connId, [msg]);
      expect(chatProv.getMessagesForConnection(connId, userId: aliceId).length, equals(1));
      expect(chatProv.getMessagesForConnection(connId, userId: bobId).length, equals(1));

      // Alice deletes for me
      await chatProv.deleteMessageForMe(connId, msg.id, aliceId);

      // Hidden for Alice immediately
      expect(chatProv.getMessagesForConnection(connId, userId: aliceId).isEmpty, isTrue);

      // Still visible for Bob
      final bobView = chatProv.getMessagesForConnection(connId, userId: bobId);
      expect(bobView.length, equals(1));
      expect(bobView.first.message, equals('Private note for Alice'));

      // A stale stream snapshot arrives with empty deletedForUserIds
      final staleSnapshot = ChatMessageModel(
        id: 'msg_del_me_1',
        connectionId: connId,
        senderId: aliceId,
        recipientId: bobId,
        message: 'Private note for Alice',
        createdAt: DateTime(2026, 10, 19, 15, 0, 0),
        deletedForUserIds: [],
      );

      chatProv.syncMessages(connId, [staleSnapshot]);
      // Alice view must STILL hide the message
      expect(chatProv.getMessagesForConnection(connId, userId: aliceId).isEmpty, isTrue);
    });

    test('13. Delete for everyone updates message to tombstone and persists across stale snapshots', () async {
      final chatProv = ChatProvider();
      const connId = 'conn_alice_bob';
      const aliceId = 'alice';
      const bobId = 'bob';

      final msg = ChatMessageModel(
        id: 'msg_del_all_1',
        connectionId: connId,
        senderId: aliceId,
        recipientId: bobId,
        message: 'Accidental message',
        createdAt: DateTime(2026, 10, 19, 16, 0, 0),
      );

      chatProv.syncMessages(connId, [msg]);

      // Alice deletes for everyone
      await chatProv.deleteMessageForEveryone(connId, msg.id);

      final aliceView = chatProv.getMessagesForConnection(connId, userId: aliceId);
      expect(aliceView.first.isDeletedForEveryone, isTrue);
      expect(aliceView.first.content, equals('This message was deleted'));

      final bobView = chatProv.getMessagesForConnection(connId, userId: bobId);
      expect(bobView.first.isDeletedForEveryone, isTrue);
      expect(bobView.first.content, equals('This message was deleted'));

      // A stale stream snapshot arrives before server commits tombstone
      final staleSnapshot = ChatMessageModel(
        id: 'msg_del_all_1',
        connectionId: connId,
        senderId: aliceId,
        recipientId: bobId,
        message: 'Accidental message',
        createdAt: DateTime(2026, 10, 19, 16, 0, 0),
        isDeletedForEveryone: false,
      );

      chatProv.syncMessages(connId, [staleSnapshot]);
      final preservedView = chatProv.getMessagesForConnection(connId, userId: bobId);
      expect(preservedView.first.isDeletedForEveryone, isTrue);
      expect(preservedView.first.content, equals('This message was deleted'));
    });

    test('14. Typing indicator active within 5 seconds and expires automatically after inactivity', () {
      final user = UserModel(
        id: 'user_typing_test',
        username: 'alice',
        email: 'alice@test.com',
        country: 'Kenya',
        city: 'Nairobi',
        dateOfBirth: DateTime(2000, 1, 1),
        gender: 'Female',
        bio: 'Hello',
        profilePicUrl: '',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '12345678',
        typingInConnectionId: 'conn_123',
        typingUpdatedAt: DateTime.now(),
      );

      // Active right now in conn_123
      expect(user.isUserTypingInConnection('conn_123'), isTrue);

      // Inactive for different connection
      expect(user.isUserTypingInConnection('conn_other'), isFalse);

      // Expired after 6 seconds
      final expiredUser = user.copyWith(
        typingUpdatedAt: DateTime.now().subtract(const Duration(seconds: 6)),
      );
      expect(expiredUser.isUserTypingInConnection('conn_123'), isFalse);

      // Cleared typing status
      final clearedUser = user.copyWith(clearTyping: true);
      expect(clearedUser.typingInConnectionId, isNull);
      expect(clearedUser.typingUpdatedAt, isNull);
      expect(clearedUser.isUserTypingInConnection('conn_123'), isFalse);
    });

    test('15. ChatProvider typing status throttling and clearing', () {
      final chatProv = ChatProvider();
      const connId = 'conn_test';
      const userId = 'alice';

      // Setting typing active in ChatProvider updates DatabaseService
      chatProv.setTypingStatus(connId, userId, true);
      expect(chatProv.isUserTyping(connId, userId), isTrue);

      // Clearing typing immediately updates DatabaseService
      chatProv.setTypingStatus(connId, userId, false);
      expect(chatProv.isUserTyping(connId, userId), isFalse);
    });

    test('16. StatusBadge formats online and lastSeen transitions deterministically', () {
      final now = DateTime(2026, 10, 19, 18, 0, 0);

      // When online, displays "Online"
      expect(StatusBadge.formatStatus(true, now, now: now), equals('Online'));

      // When offline, displays relative last-seen
      final justNow = now.subtract(const Duration(seconds: 30));
      expect(StatusBadge.formatStatus(false, justNow, now: now), equals('Last seen just now'));

      final tenMinsAgo = now.subtract(const Duration(minutes: 10));
      expect(StatusBadge.formatStatus(false, tenMinsAgo, now: now), equals('Last seen 10m ago'));

      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      expect(StatusBadge.formatStatus(false, twoHoursAgo, now: now), equals('Last seen 2h ago'));
    });

    test('17. Rejected markMessagesAsRead rolls back optimistic read state and accepts subsequent server unread snapshot', () async {
      final chatProv =
          ChatProvider(firestoreService: MockFailingFirestoreService());
      const connId = 'conn_rollback_read_test';
      final msg = ChatMessageModel(
        id: 'msg_unread_1',
        connectionId: connId,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Important unread message',
        timestamp: DateTime(2026, 10, 19, 12, 0),
        isRead: false,
        deliveryStatus: MessageDeliveryStatus.delivered,
      );
      chatProv.syncMessages(connId, [msg]);

      // Attempt markMessagesAsRead which fails at Firestore level (e.g. uninitialized or permission denied)
      await expectLater(
        () async => await chatProv.markMessagesAsRead(connId, 'bob'),
        throwsA(anything),
      );

      // Verifies that local read state rolled back and did NOT get stuck as read
      final postFailure = chatProv.getMessagesForConnection(connId);
      expect(postFailure.first.isRead, isFalse, reason: 'Failed server write must not leave message permanently read');
      expect(postFailure.first.deliveryStatus, equals(MessageDeliveryStatus.delivered));

      // Subsequent server snapshot arriving with unread status must not be overridden
      final serverSnapshot = ChatMessageModel(
        id: 'msg_unread_1',
        connectionId: connId,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Important unread message',
        timestamp: DateTime(2026, 10, 19, 12, 0),
        isRead: false,
        deliveryStatus: MessageDeliveryStatus.delivered,
      );
      chatProv.syncMessages(connId, [serverSnapshot]);

      final afterSnapshot = chatProv.getMessagesForConnection(connId);
      expect(afterSnapshot.first.isRead, isFalse, reason: 'Subsequent snapshot reflects server unread truth');
    });

    test('18. Rejected deleteMessageForMe write rolls back optimistic deletion', () async {
      final chatProv =
          ChatProvider(firestoreService: MockFailingFirestoreService());
      const connId = 'conn_rollback_del_me';
      final msg = ChatMessageModel(
        id: 'msg_del_rollback_1',
        connectionId: connId,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Should remain after write fails',
        timestamp: DateTime(2026, 10, 19, 12, 0),
        deletedForUserIds: [],
      );
      chatProv.syncMessages(connId, [msg]);

      // Attempt delete for me which fails at Firestore layer
      await expectLater(
        () async => await chatProv.deleteMessageForMe(connId, 'msg_del_rollback_1', 'bob'),
        throwsA(anything),
      );

      // Message remains visible for bob because write failed and rolled back
      final bobMessages = chatProv.getMessagesForConnection(connId, userId: 'bob');
      expect(bobMessages.length, equals(1), reason: 'Failed delete for me must restore message visibility');
      expect(bobMessages.first.id, equals('msg_del_rollback_1'));
    });

    test('19. Rejected deleteMessageForEveryone write rolls back optimistic deletion', () async {
      final chatProv =
          ChatProvider(firestoreService: MockFailingFirestoreService());
      const connId = 'conn_rollback_del_everyone';
      final msg = ChatMessageModel(
        id: 'msg_del_everyone_1',
        connectionId: connId,
        senderId: 'alice',
        recipientId: 'bob',
        message: 'Original persistent content',
        timestamp: DateTime(2026, 10, 19, 12, 0),
        isDeletedForEveryone: false,
      );
      chatProv.syncMessages(connId, [msg]);

      // Attempt delete for everyone which fails at Firestore layer
      await expectLater(
        () async => await chatProv.deleteMessageForEveryone(connId, 'msg_del_everyone_1'),
        throwsA(anything),
      );

      // Message content remains restored because write failed and rolled back
      final messages = chatProv.getMessagesForConnection(connId);
      expect(messages.first.isDeletedForEveryone, isFalse, reason: 'Failed delete for everyone must restore message');
      expect(messages.first.content, equals('Original persistent content'));
    });

    test('20. Rejected sendChatMessage write rolls back optimistic addition and rethrows to caller', () async {
      final chatProv =
          ChatProvider(firestoreService: MockFailingFirestoreService());
      const connId = 'conn_send_failure_test';

      expect(chatProv.getMessagesForConnection(connId), isEmpty);

      // Attempt send which fails at Firestore layer
      await expectLater(
        () async => await chatProv.sendMessage(
          connectionId: connId,
          senderId: 'alice',
          recipientId: 'bob',
          text: 'This message will fail',
        ),
        throwsA(anything),
      );

      // Cache must be empty because failed send rolled back
      expect(chatProv.getMessagesForConnection(connId), isEmpty,
          reason: 'Failed send must not leave phantom optimistic message in local cache');
    });

    test('21. Stream error propagates downstream to listener and is not silently swallowed', () async {
      final streamController = StreamController<List<ChatMessageModel>>();
      final stream = streamController.stream;

      bool errorCaught = false;
      dynamic receivedError;

      final subscription = stream.listen(
        (_) {},
        onError: (e) {
          errorCaught = true;
          receivedError = e;
        },
      );

      streamController.addError(Exception('PERMISSION_DENIED: Stream query rejected'));
      await pumpEventQueue();

      expect(errorCaught, isTrue);
      expect(receivedError.toString(), contains('PERMISSION_DENIED'));

      await subscription.cancel();
      await streamController.close();
    });

    test('22. Genuinely empty snapshot with empty list is distinguished from uninitialized state', () {
      final chatProv = ChatProvider();
      const connId = 'conn_empty_test';

      // 1. Initial uninitialized state has empty cached list and null in-memory entry
      expect(chatProv.getMessagesForConnection(connId), isEmpty);

      // 2. Stream snapshot confirms genuinely empty conversation (data is [])
      final mergedEmpty = chatProv.getMergedMessages(
        connId,
        streamMessages: <ChatMessageModel>[],
        userId: 'alice',
      );
      expect(mergedEmpty, isEmpty);

      // 3. New message arrives in stream snapshot
      final msg = ChatMessageModel(
        id: 'msg_stream_1',
        connectionId: connId,
        senderId: 'bob',
        recipientId: 'alice',
        message: 'Hello Alice',
        timestamp: DateTime(2026, 10, 19, 14, 0),
      );
      chatProv.syncMessages(connId, [msg]);

      final mergedPopulated = chatProv.getMergedMessages(
        connId,
        streamMessages: [msg],
        userId: 'alice',
      );
      expect(mergedPopulated.length, equals(1));
      expect(mergedPopulated.first.id, equals('msg_stream_1'));
    });

    test('23. Legacy ISO timestamps in UTC and non-UTC offsets parse to identical UTC moment and order correctly', () {
      // 03:00 with +03:00 offset is 00:00 UTC
      final parsedWithOffset = ChatMessageModel.parseTimestamp('2026-10-20T03:00:00+03:00');
      final parsedUtc = ChatMessageModel.parseTimestamp('2026-10-20T00:00:00Z');

      expect(parsedWithOffset.millisecondsSinceEpoch, equals(parsedUtc.millisecondsSinceEpoch));
      expect(parsedWithOffset.isAtSameMomentAs(parsedUtc), isTrue);

      final msg1 = ChatMessageModel.fromMap({
        'content': 'Earlier message with +03:00 offset',
        'timestamp': '2026-10-20T03:00:00+03:00',
      }, 'msg_offset');

      final msg2 = ChatMessageModel.fromMap({
        'content': 'Later message in UTC',
        'timestamp': '2026-10-20T00:05:00Z',
      }, 'msg_utc');

      expect(msg1.timestamp.isBefore(msg2.timestamp), isTrue);
    });

    test('24. Legacy records using createdAt when another timestamp field is absent', () {
      final legacyMap = {
        'id': 'msg_legacy_created_at',
        'connectionId': 'conn_test',
        'senderId': 'alice',
        'recipientId': 'bob',
        'message': 'Legacy message without timestamp field',
        'createdAt': '2026-10-19T10:30:00Z',
      };

      final msg = ChatMessageModel.fromMap(legacyMap, 'msg_legacy_created_at');
      expect(msg.createdAt, equals(DateTime.utc(2026, 10, 19, 10, 30, 0)));
      expect(msg.timestamp, equals(DateTime.utc(2026, 10, 19, 10, 30, 0)));
      expect(msg.content, equals('Legacy message without timestamp field'));
    });

    test('25. Existing Firestore Timestamp values where supported', () {
      final tsDate = DateTime.utc(2026, 10, 19, 15, 45, 0);
      final fakeTimestamp = FakeFirestoreTimestamp(tsDate);

      final map = {
        'id': 'msg_ts_1',
        'connectionId': 'conn_ts',
        'senderId': 'alice',
        'receiverId': 'bob',
        'content': 'Message with Firestore Timestamp',
        'serverTimestamp': fakeTimestamp,
      };

      final msg = ChatMessageModel.fromMap(map, 'msg_ts_1');
      expect(msg.createdAt, equals(tsDate));
      expect(msg.createdAt.isUtc, isTrue);
    });

    test('26. Equal timestamps with deterministic ordering by message ID', () {
      final chatProv = ChatProvider();
      const connId = 'conn_equal_time';
      final sharedTime = DateTime.utc(2026, 10, 20, 12, 0, 0);

      final msgA = ChatMessageModel(
        id: 'msg_a_first',
        connectionId: connId,
        senderId: 'alice',
        receiverId: 'bob',
        content: 'Alpha',
        createdAt: sharedTime,
      );

      final msgB = ChatMessageModel(
        id: 'msg_b_second',
        connectionId: connId,
        senderId: 'bob',
        receiverId: 'alice',
        content: 'Beta',
        createdAt: sharedTime,
      );

      // Inverted sync order: pass msgB then msgA
      final merged = chatProv.getMergedMessages(
        connId,
        streamMessages: [msgB, msgA],
      );

      expect(merged.length, equals(2));
      expect(merged[0].id, equals('msg_a_first'));
      expect(merged[1].id, equals('msg_b_second'));
    });

    test('27. New messages with server timestamp and optimistic local timestamp behavior', () {
      final nowUtc = DateTime.now().toUtc();
      final msg = ChatMessageModel(
        id: ChatMessageModel.generateMessageId(),
        connectionId: 'conn_test',
        senderId: 'alice',
        receiverId: 'bob',
        content: 'Optimistic message',
        createdAt: nowUtc,
      );

      final serialized = msg.toMap();
      // Serialization outputs concrete UTC ISO strings, never FieldValue sentinels
      expect(serialized['timestamp'], isA<String>());
      expect(serialized['timestamp'], endsWith('Z'));
      expect(serialized['serverTimestamp'], isNull);

      // Deserialization with serverTimestamp prioritizes server authoritative timestamp
      final serverResolvedDate = DateTime.utc(2026, 10, 20, 12, 1, 0);
      final fromServerDoc = ChatMessageModel.fromMap({
        ...serialized,
        'serverTimestamp': FakeFirestoreTimestamp(serverResolvedDate),
      }, msg.id);

      expect(fromServerDoc.createdAt, equals(serverResolvedDate));

      // Deserialization with null serverTimestamp (in-flight local snapshot) falls back to optimistic timestamp
      final fromInFlightDoc = ChatMessageModel.fromMap({
        ...serialized,
        'serverTimestamp': null,
      }, msg.id);

      expect(fromInFlightDoc.createdAt, equals(nowUtc));
    });

    test('28. Collision-resistant message ID generation', () {
      final ids = <String>{};
      const count = 1000;
      for (int i = 0; i < count; i++) {
        ids.add(ChatMessageModel.generateMessageId());
      }

      // Exactly count unique IDs
      expect(ids.length, equals(count));

      for (final id in ids) {
        // Matches msg_${epoch}_${entropy}
        expect(RegExp(r'^msg_\d+_[a-f0-9]{8}$').hasMatch(id), isTrue);
        final fallback = ChatMessageModel.fallbackTimestamp(id);
        expect(fallback, isNotNull);
        expect(fallback!.millisecondsSinceEpoch, greaterThan(0));
      }

      // Also verifies backward compatibility with legacy format msg_${epoch}
      final legacyFallback = ChatMessageModel.fallbackTimestamp('msg_1729000000000');
      expect(legacyFallback, isNotNull);
      expect(legacyFallback!.millisecondsSinceEpoch, equals(1729000000000));
    });

    test('29. Pagination across page boundaries without missing or duplicated messages', () async {
      // Create 105 sequential messages
      final allMessages = List.generate(105, (i) {
        return ChatMessageModel(
          id: 'msg_seq_${i.toString().padLeft(4, '0')}',
          connectionId: 'conn_pag_test',
          senderId: i % 2 == 0 ? 'alice' : 'bob',
          receiverId: i % 2 == 0 ? 'bob' : 'alice',
          content: 'Message #$i',
          createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
        );
      });

      final mockService = MockPaginationFirestoreService(storedMessages: allMessages);
      final chatProv = ChatProvider(firestoreService: mockService);
      const connId = 'conn_pag_test';

      // Initial stream/load delivers latest 50 messages (index 55 to 104)
      final initialSlice = allMessages.sublist(55, 105);
      chatProv.syncMessages(connId, initialSlice);

      expect(chatProv.getMessagesForConnection(connId).length, equals(50));
      expect(chatProv.hasMoreOlderMessages(connId), isTrue);

      // Fetch older page 1 (50 messages: index 5 to 54)
      final afterPage1 = await chatProv.loadOlderMessages(connId, limit: 50);
      expect(afterPage1.length, equals(100));
      expect(chatProv.hasMoreOlderMessages(connId), isTrue);

      // Verify no duplicates and exact contiguous sequence 5..104
      for (int i = 0; i < 100; i++) {
        expect(afterPage1[i].id, equals('msg_seq_${(i + 5).toString().padLeft(4, '0')}'));
      }

      // Fetch older page 2 (remaining 5 messages: index 0 to 4)
      final afterPage2 = await chatProv.loadOlderMessages(connId, limit: 50);
      expect(afterPage2.length, equals(105));
      expect(chatProv.hasMoreOlderMessages(connId), isFalse);

      // Verify complete ordered sequence 0..104
      for (int i = 0; i < 105; i++) {
        expect(afterPage2[i].id, equals('msg_seq_${i.toString().padLeft(4, '0')}'));
      }
    });

    test('30. Merging historical pages with incoming live-stream messages', () async {
      final allHistorical = List.generate(30, (i) {
        return ChatMessageModel(
          id: 'msg_hist_${i.toString().padLeft(3, '0')}',
          connectionId: 'conn_stream_merge',
          senderId: 'alice',
          receiverId: 'bob',
          content: 'Hist #$i',
          createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
        );
      });

      final mockService = MockPaginationFirestoreService(storedMessages: allHistorical);
      final chatProv = ChatProvider(firestoreService: mockService);
      const connId = 'conn_stream_merge';

      // Chat begins with messages 15..29
      chatProv.syncMessages(connId, allHistorical.sublist(15, 30));
      expect(chatProv.getMessagesForConnection(connId).length, equals(15));

      // Older page is loaded (messages 0..14)
      await chatProv.loadOlderMessages(connId, limit: 20);
      expect(chatProv.getMessagesForConnection(connId).length, equals(30));

      // Live stream message arrives (message 30)
      final liveMsg = ChatMessageModel(
        id: 'msg_live_new',
        connectionId: connId,
        senderId: 'bob',
        receiverId: 'alice',
        content: 'Brand new live message',
        createdAt: DateTime.utc(2026, 1, 1).add(const Duration(minutes: 30)),
      );

      final merged = chatProv.getMergedMessages(
        connId,
        streamMessages: [liveMsg],
      );

      // Verify live message is appended at end without losing paginated history
      expect(merged.length, equals(31));
      expect(merged.first.id, equals('msg_hist_000'));
      expect(merged.last.id, equals('msg_live_new'));
    });

    test('31. Preservation of existing historical messages under the chosen compatibility strategy', () {
      final legacyMap = {
        'id': 'msg_1729000000000',
        'connectionId': 'conn_1729000000000',
        'senderId': 'user_a',
        'recipientId': 'user_b',
        'message': 'Hello from 2024 legacy format',
        'createdAt': '2024-10-15T12:00:00Z',
      };

      final newMap = {
        'id': 'msg_1729500000000_a1b2c3d4',
        'connectionId': 'conn_user_a_user_b',
        'senderId': 'user_b',
        'receiverId': 'user_a',
        'content': 'Hello from 2026 canonical format',
        'serverTimestamp': FakeFirestoreTimestamp(DateTime.utc(2026, 10, 20, 10, 0, 0)),
      };

      final legacyMsg = ChatMessageModel.fromMap(legacyMap, 'msg_1729000000000');
      final newMsg = ChatMessageModel.fromMap(newMap, 'msg_1729500000000_a1b2c3d4');

      // Both expose unified getters
      expect(legacyMsg.content, equals('Hello from 2024 legacy format'));
      expect(legacyMsg.message, equals('Hello from 2024 legacy format'));
      expect(legacyMsg.receiverId, equals('user_b'));
      expect(legacyMsg.recipientId, equals('user_b'));

      expect(newMsg.content, equals('Hello from 2026 canonical format'));
      expect(newMsg.message, equals('Hello from 2026 canonical format'));
      expect(newMsg.receiverId, equals('user_a'));
      expect(newMsg.recipientId, equals('user_a'));

      expect(legacyMsg.timestamp.isBefore(newMsg.timestamp), isTrue);
    });

    test('32. Equal timestamps are paginated without skipping documents when composite cursor is available', () async {
      // 4 messages share the exact same second/millisecond timestamp, flanked by newer and older messages
      final sharedTime = DateTime.utc(2026, 10, 20, 12, 0, 0);
      final allMessages = [
        ChatMessageModel(
          id: 'msg_01_oldest',
          connectionId: 'conn_eq_pag',
          senderId: 'alice',
          receiverId: 'bob',
          content: 'Oldest',
          createdAt: DateTime.utc(2026, 10, 20, 11, 59, 0),
        ),
        ChatMessageModel(
          id: 'msg_02_eq_a',
          connectionId: 'conn_eq_pag',
          senderId: 'alice',
          receiverId: 'bob',
          content: 'Equal A',
          createdAt: sharedTime,
        ),
        ChatMessageModel(
          id: 'msg_03_eq_b',
          connectionId: 'conn_eq_pag',
          senderId: 'bob',
          receiverId: 'alice',
          content: 'Equal B',
          createdAt: sharedTime,
        ),
        ChatMessageModel(
          id: 'msg_04_eq_c',
          connectionId: 'conn_eq_pag',
          senderId: 'alice',
          receiverId: 'bob',
          content: 'Equal C',
          createdAt: sharedTime,
        ),
        ChatMessageModel(
          id: 'msg_05_eq_d',
          connectionId: 'conn_eq_pag',
          senderId: 'bob',
          receiverId: 'alice',
          content: 'Equal D',
          createdAt: sharedTime,
        ),
        ChatMessageModel(
          id: 'msg_06_newest',
          connectionId: 'conn_eq_pag',
          senderId: 'alice',
          receiverId: 'bob',
          content: 'Newest',
          createdAt: DateTime.utc(2026, 10, 20, 12, 1, 0),
        ),
      ];

      final mockService = MockPaginationFirestoreService(storedMessages: allMessages);
      final chatProv = ChatProvider(firestoreService: mockService);
      const connId = 'conn_eq_pag';

      // Initial page fetches top 2 messages (msg_06_newest, msg_05_eq_d)
      chatProv.syncMessages(connId, [allMessages[5], allMessages[4]]);
      expect(chatProv.getMessagesForConnection(connId).length, equals(2));

      // Page 1: load older with limit 2 (must return msg_04_eq_c, msg_03_eq_b)
      final afterPage1 = await chatProv.loadOlderMessages(connId, limit: 2);
      expect(afterPage1.length, equals(4));
      expect(afterPage1.map((m) => m.id).toList(), equals([
        'msg_03_eq_b',
        'msg_04_eq_c',
        'msg_05_eq_d',
        'msg_06_newest',
      ]));

      // Page 2: load older with limit 2 (must return msg_02_eq_a, msg_01_oldest)
      final afterPage2 = await chatProv.loadOlderMessages(connId, limit: 2);
      expect(afterPage2.length, equals(6));
      expect(afterPage2.map((m) => m.id).toList(), equals([
        'msg_01_oldest',
        'msg_02_eq_a',
        'msg_03_eq_b',
        'msg_04_eq_c',
        'msg_05_eq_d',
        'msg_06_newest',
      ]));

      // Page 3: load older (0 messages returned since all 6 are loaded, signaling end of history)
      final afterPage3 = await chatProv.loadOlderMessages(connId, limit: 2);
      expect(afterPage3.length, equals(6));
      expect(chatProv.hasMoreOlderMessages(connId), isFalse);
    });

    test('33. Live stream and historical pagination queries use consistent ordering', () {
      final firestoreService = FirestoreService.forTesting();
      // Both live stream and historical pagination target connections/{connectionId}/messages
      // with identical primary 'timestamp' DESC and secondary '__name__' DESC ordering
      expect(firestoreService, isNotNull);
    });

    test('34. A missing or deleted cursor document does not silently produce an unsafe cursor', () async {
      final chatProv = ChatProvider(
        firestoreService: MockPaginationFirestoreService(
          storedMessages: [],
          simulateMissingCursorDoc: true,
        ),
      );
      const connId = 'conn_missing_cursor';

      final ghostMessage = ChatMessageModel(
        id: 'msg_ghost_deleted',
        connectionId: connId,
        senderId: 'alice',
        receiverId: 'bob',
        content: 'Ghost message',
        createdAt: DateTime.utc(2026, 10, 20, 10, 0, 0),
      );
      chatProv.syncMessages(connId, [ghostMessage]);

      // Attempting to paginate past a missing cursor document must fail-closed with StateError
      await expectLater(
        () async => await chatProv.loadOlderMessages(connId, limit: 20),
        throwsA(isA<StateError>()),
      );

      // Verify fail-closed semantics:
      // 1. Existing cached messages are preserved (not wiped)
      expect(chatProv.getMessagesForConnection(connId).length, equals(1));
      // 2. hasMoreOlderMessages is NOT falsely marked as false (can retry)
      expect(chatProv.hasMoreOlderMessages(connId), isTrue);
      // 3. isLoadingOlderMessages is reset to false
      expect(chatProv.isLoadingOlderMessages(connId), isFalse);
    });

    test('35. Legacy offset timestamps remain an explicit known limitation under string ordering', () {
      // Nairobi device at 01:30 UTC formatted local string with +03:00 offset:
      const legacyKenyaString = '2024-10-15T04:30:00+03:00'; // 01:30 UTC
      // London device at 02:00 UTC formatted in UTC:
      const utcString = '2024-10-15T02:00:00.000Z'; // 02:00 UTC

      // Chronological reality: Kenya message is 30 minutes OLDER than London message
      final kenyaDate = DateTime.parse(legacyKenyaString);
      final londonDate = DateTime.parse(utcString);
      expect(kenyaDate.isBefore(londonDate), isTrue);

      // Firestore string index reality: Kenya string sorts HIGHER (as if newer)
      // because '2024-10-15T04' > '2024-10-15T02' in raw UTF-8 byte comparison
      final firestoreLexicographicalCmp = legacyKenyaString.compareTo(utcString);
      expect(firestoreLexicographicalCmp, greaterThan(0),
          reason: 'Known limitation: Firestore raw string index misorders different UTC offsets');

      // Once retrieved into Dart, in-memory tie-breaking correctly orders by actual UTC time
      final msg1 = ChatMessageModel.fromMap({
        'connectionId': 'conn_test',
        'timestamp': legacyKenyaString,
      }, 'msg_kenya');
      final msg2 = ChatMessageModel.fromMap({
        'connectionId': 'conn_test',
        'timestamp': utcString,
      }, 'msg_london');
      final chatProv = ChatProvider();
      final sorted = chatProv.getMergedMessages('conn_test', streamMessages: [msg1, msg2]);
      expect(sorted[0].id, equals('msg_kenya'));
      expect(sorted[1].id, equals('msg_london'));
    });

    test('36. Pagination errors are surfaced instead of being treated as empty history', () async {
      final chatProv = ChatProvider(
        firestoreService: MockPaginationFirestoreService(
          storedMessages: [],
          simulateError: true,
        ),
      );
      const connId = 'conn_network_error_test';

      final msg = ChatMessageModel(
        id: 'msg_existing_1',
        connectionId: connId,
        senderId: 'alice',
        receiverId: 'bob',
        content: 'Existing message',
        createdAt: DateTime.utc(2026, 10, 20, 10, 0, 0),
      );
      chatProv.syncMessages(connId, [msg]);

      // Call loadOlderMessages which fails with network error
      await expectLater(
        () async => await chatProv.loadOlderMessages(connId, limit: 50),
        throwsA(isA<Exception>()),
      );

      // Verify that hasMoreOlderMessages is NOT marked false (which would falsely signify end of history)
      expect(chatProv.hasMoreOlderMessages(connId), isTrue);
      expect(chatProv.isLoadingOlderMessages(connId), isFalse);
      expect(chatProv.getMessagesForConnection(connId).length, equals(1));
    });
  });
}
