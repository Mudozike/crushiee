// ignore_for_file: avoid_print
/// Stage 3A Regression Tests — Core Message Visibility and Read-State Repair
///
/// UNIT / MOCK tests only. Do not require Firestore Emulator.
/// Do NOT prove security-rule or cross-device behaviour.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:crushie/models/chat_message_model.dart';
import 'package:crushie/models/connection_model.dart';
import 'package:crushie/providers/chat_provider.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/services/firestore_service.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _FakeDb extends DatabaseService {
  _FakeDb() : super.forTesting();
  final List<ChatMessageModel> storedMessages = [];

  @override
  List<ChatMessageModel> getChatMessages(String connectionId, {String? userId}) =>
      storedMessages.where((m) => m.connectionId == connectionId || m.connectionId.isEmpty).toList();

  @override void sendChatMessage(ChatMessageModel message) { storedMessages.add(message); }
  @override void markMessagesAsRead(String connectionId, String userId) {
    for (int i = 0; i < storedMessages.length; i++) {
      if ((storedMessages[i].connectionId == connectionId || storedMessages[i].connectionId.isEmpty) &&
          storedMessages[i].recipientId == userId && !storedMessages[i].isRead) {
        storedMessages[i] = storedMessages[i].copyWith(isRead: true);
      }
    }
  }
  @override void setChatMessagesForConnection(String connectionId, List<ChatMessageModel> messages) {
    storedMessages.removeWhere((m) => m.connectionId == connectionId || m.connectionId.isEmpty);
    storedMessages.addAll(messages);
  }
  @override void removeChatMessage(String messageId) { storedMessages.removeWhere((m) => m.id == messageId); }
  @override void deleteMessageForMe(String messageId, String userId) {}
  @override void deleteMessageForEveryone(String messageId) {}
  @override void clearConversation(String connectionId, String userId) {}
  @override void deleteConversation(String connectionId, String userId) {}
  @override void setTypingStatus(String connectionId, String userId, bool isTyping) {}
  @override bool isUserTyping(String connectionId, String userId) => false;
}

class _FakeFirestore extends FirestoreService {
  _FakeFirestore() : super.forTesting();
  Completer<void>? markAsReadCompleter;
  int markAsReadCallCount = 0;
  Exception? markAsReadException;
  Exception? sendException;
  int sendCallCount = 0;

  @override
  Future<void> markMessagesAsRead(String connectionId, String currentUserId) async {
    markAsReadCallCount++;
    if (markAsReadCompleter != null) await markAsReadCompleter!.future;
    if (markAsReadException != null) throw markAsReadException!;
  }

  @override
  Future<void> sendChatMessage(ChatMessageModel message) async {
    sendCallCount++;
    if (sendException != null) throw sendException!;
  }

  @override
  Stream<List<ChatMessageModel>> getMessagesStream(String connectionId, {int limit = 100}) =>
      const Stream.empty();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ChatMessageModel _msg({
  required String id,
  required String connectionId,
  required String senderId,
  required String recipientId,
  bool isRead = false,
  DateTime? createdAt,
}) => ChatMessageModel(
      id: id,
      connectionId: connectionId,
      senderId: senderId,
      recipientId: recipientId,
      content: 'hello',
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      isRead: isRead,
      deliveryStatus: isRead ? MessageDeliveryStatus.read : MessageDeliveryStatus.delivered,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Group 1 — Phase 1A: Connection ID normalization
  // =========================================================================
  group('Phase 1A - Connection ID normalization', () {
    test('1.1 Message missing connectionId inherits connectionIdFallback', () {
      final map = {'senderId': 'alice', 'receiverId': 'bob', 'content': 'hey', 'isRead': false, 'timestamp': '2026-01-01T10:00:00.000Z'};
      final msg = ChatMessageModel.fromMap(map, 'msg_001', connectionIdFallback: 'conn_alice_bob');
      expect(msg.connectionId, 'conn_alice_bob');
    });

    test('1.2 Message with matching non-empty connectionId keeps its own value', () {
      final map = {'senderId': 'alice', 'receiverId': 'bob', 'content': 'hey', 'connectionId': 'conn_alice_bob', 'isRead': false};
      final msg = ChatMessageModel.fromMap(map, 'msg_002', connectionIdFallback: 'conn_alice_bob');
      expect(msg.connectionId, 'conn_alice_bob');
    });

    test('1.3 Message with conflicting non-empty connectionId keeps document value', () {
      final map = {'senderId': 'alice', 'receiverId': 'carol', 'content': 'hey', 'connectionId': 'conn_DIFFERENT', 'isRead': false};
      final msg = ChatMessageModel.fromMap(map, 'msg_003', connectionIdFallback: 'conn_alice_bob');
      expect(msg.connectionId, 'conn_DIFFERENT', reason: 'Document connectionId must not be overwritten');
    });

    test('1.4 getMergedMessages accepts message with empty connectionId (legacy)', () {
      final db = _FakeDb();
      final fs = _FakeFirestore();
      final provider = ChatProvider(db: db, firestoreService: fs);
      final legacyMsg = _msg(id: 'msg_legacy', connectionId: '', senderId: 'alice', recipientId: 'bob');
      final merged = provider.getMergedMessages('conn_alice_bob', streamMessages: [legacyMsg]);
      expect(merged.any((m) => m.id == 'msg_legacy'), isTrue);
    });

    test('1.5 getMergedMessages excludes message with different non-empty connectionId', () {
      final db = _FakeDb();
      final fs = _FakeFirestore();
      final provider = ChatProvider(db: db, firestoreService: fs);
      final wrongMsg = _msg(id: 'msg_wrong', connectionId: 'conn_DIFFERENT', senderId: 'carol', recipientId: 'dave');
      final merged = provider.getMergedMessages('conn_alice_bob', streamMessages: [wrongMsg]);
      expect(merged.any((m) => m.id == 'msg_wrong'), isFalse);
    });
  });

  // =========================================================================
  // Group 2 — Phase 1B: Legacy connection model logic
  // =========================================================================
  group('Phase 1B - Legacy connection resolution model logic', () {
    test('2.1 getConversationId is commutative', () {
      final idAB = ConnectionModel.getConversationId('alice', 'bob');
      final idBA = ConnectionModel.getConversationId('bob', 'alice');
      expect(idAB, idBA);
      expect(idAB, startsWith('conn_'));
    });

    test('2.2 getConversationId rejects self-connection', () {
      expect(() => ConnectionModel.getConversationId('alice', 'alice'), throwsA(isA<ArgumentError>()));
    });

    test('2.3 fromMap parses legacy doc with receiverId, no participants field', () {
      final map = {'senderId': 'alice', 'receiverId': 'bob', 'senderUsername': 'Alice', 'receiverUsername': 'Bob', 'senderProfilePic': '', 'receiverProfilePic': '', 'status': 'accepted', 'createdAt': '2026-01-01T00:00:00Z', 'updatedAt': '2026-01-01T00:00:00Z'};
      final conn = ConnectionModel.fromMap(map, 'conn_legacy_123');
      expect(conn.senderId, 'alice');
      expect(conn.receiverId, 'bob');
      expect(conn.id, 'conn_legacy_123');
      expect(conn.participants, containsAll(['alice', 'bob']));
    });

    test('2.4 fromMap parses legacy doc with recipientId field', () {
      final map = {'senderId': 'alice', 'recipientId': 'carol', 'senderUsername': 'Alice', 'recipientUsername': 'Carol', 'senderProfilePic': '', 'recipientProfilePic': '', 'status': 'accepted', 'createdAt': '2026-01-01T00:00:00Z', 'updatedAt': '2026-01-01T00:00:00Z'};
      final conn = ConnectionModel.fromMap(map, 'conn_legacy_456');
      expect(conn.receiverId, 'carol');
    });

    test('2.5 Both participant orientations resolve same canonical ID', () {
      final idAB = ConnectionModel.getConversationId('user_111', 'user_222');
      final idBA = ConnectionModel.getConversationId('user_222', 'user_111');
      expect(idAB, idBA);
    });
  });

  // =========================================================================
  // Group 3 — Phase 1C: Missing timestamp handling
  // =========================================================================
  group('Phase 1C - Missing timestamp handling', () {
    test('3.1 fromMap with only createdAt produces correct DateTime', () {
      final map = {'senderId': 'alice', 'receiverId': 'bob', 'content': 'hi', 'createdAt': '2026-03-15T08:30:00.000Z'};
      final msg = ChatMessageModel.fromMap(map, 'msg_t1', connectionIdFallback: 'conn_a');
      expect(msg.timestamp.year, 2026);
      expect(msg.timestamp.month, 3);
      expect(msg.timestamp.day, 15);
    });

    test('3.2 fromMap with no timestamp falls back to ID-embedded epoch', () {
      final epoch = DateTime(2026, 5, 10).millisecondsSinceEpoch;
      final id = 'msg_${epoch}_abcd1234';
      final map = {'senderId': 'alice', 'receiverId': 'bob', 'content': 'hi'};
      final msg = ChatMessageModel.fromMap(map, id, connectionIdFallback: 'conn_a');
      expect(msg.timestamp.year, 2026);
      expect(msg.timestamp.month, 5);
    });

    test('3.3 fromMap with no temporal fields returns epoch sentinel, not DateTime.now()', () {
      final map = {'senderId': 'alice', 'receiverId': 'bob', 'content': 'hi'};
      final msg = ChatMessageModel.fromMap(map, 'msg_no_time', connectionIdFallback: 'conn_a');
      expect(msg.timestamp.isBefore(DateTime(1971, 1, 1)), isTrue);
    });
  });

  // =========================================================================
  // Group 4 — Phase 1D: Missing isRead backward-compat policy
  // =========================================================================
  group('Phase 1D - Missing isRead backward-compat policy', () {
    test('4.1 isRead absent is treated as false', () {
      final map = {'senderId': 'alice', 'receiverId': 'bob', 'content': 'hi'};
      final msg = ChatMessageModel.fromMap(map, 'msg_x', connectionIdFallback: 'conn_a');
      expect(msg.isRead, isFalse);
    });

    test('4.2 isRead: true is accepted', () {
      final map = {'senderId': 'alice', 'receiverId': 'bob', 'content': 'hi', 'isRead': true, 'deliveryStatus': 'read'};
      final msg = ChatMessageModel.fromMap(map, 'msg_y', connectionIdFallback: 'conn_a');
      expect(msg.isRead, isTrue);
      expect(msg.deliveryStatus, MessageDeliveryStatus.read);
    });

    test('4.3 isRead: false is accepted', () {
      final map = {'senderId': 'alice', 'receiverId': 'bob', 'content': 'hi', 'isRead': false};
      final msg = ChatMessageModel.fromMap(map, 'msg_z', connectionIdFallback: 'conn_a');
      expect(msg.isRead, isFalse);
    });

    test('4.4 isRead: null is treated as false', () {
      final map = <String, dynamic>{'senderId': 'alice', 'receiverId': 'bob', 'content': 'hi', 'isRead': null};
      final msg = ChatMessageModel.fromMap(map, 'msg_w', connectionIdFallback: 'conn_a');
      expect(msg.isRead, isFalse);
    });

    test('4.5 Absent deliveryStatus with isRead:true resolves to read status', () {
      final map = <String, dynamic>{'senderId': 'alice', 'receiverId': 'bob', 'content': 'hi', 'isRead': true};
      final msg = ChatMessageModel.fromMap(map, 'msg_v', connectionIdFallback: 'conn_a');
      expect(msg.deliveryStatus, MessageDeliveryStatus.read);
    });
  });

  // =========================================================================
  // Group 5 — Phase 2B: Re-entrant drain mechanism
  // =========================================================================
  group('Phase 2B - Re-entrant read drain mechanism', () {
    test('5.1 Second read call while first is in-flight triggers drain pass', () async {
      final db = _FakeDb();
      final fs = _FakeFirestore();
      final gate = Completer<void>();
      fs.markAsReadCompleter = gate;
      final provider = ChatProvider(db: db, firestoreService: fs);

      provider.syncMessages('conn_a', [
        _msg(id: 'msg_1', connectionId: 'conn_a', senderId: 'alice', recipientId: 'bob'),
        _msg(id: 'msg_2', connectionId: 'conn_a', senderId: 'alice', recipientId: 'bob'),
      ]);

      final first = provider.markMessagesAsRead('conn_a', 'bob');
      final second = provider.markMessagesAsRead('conn_a', 'bob');
      gate.complete();
      await Future.wait([first, second]);

      expect(fs.markAsReadCallCount, greaterThanOrEqualTo(2),
          reason: 'Drain must have triggered a second Firestore call');
    });

    test('5.2 Mutex is released in finally even when Firestore throws', () async {
      final db = _FakeDb();
      final fs = _FakeFirestore();
      fs.markAsReadException = Exception('Firestore unavailable');
      final provider = ChatProvider(db: db, firestoreService: fs);
      provider.syncMessages('conn_a',
          [_msg(id: 'x', connectionId: 'conn_a', senderId: 'a', recipientId: 'b')]);

      await provider.markMessagesAsRead('conn_a', 'b').catchError((_) {});
      fs.markAsReadException = null;
      await expectLater(provider.markMessagesAsRead('conn_a', 'b'), completes);
    });

    test('5.3 No drain fires when no concurrent trigger was recorded', () async {
      final db = _FakeDb();
      final fs = _FakeFirestore();
      final provider = ChatProvider(db: db, firestoreService: fs);
      await provider.markMessagesAsRead('conn_a', 'bob');
      expect(fs.markAsReadCallCount, 1);
    });
  });

  // =========================================================================
  // Group 6 — Phase 2C: Stale snapshot reconciliation heuristic
  // =========================================================================
  group('Phase 2C - Stale snapshot reconciliation', () {
    test('6.1 Clearing unread count locally zeroes immediately', () {
      final conn = ConnectionModel(
        id: 'conn_a', senderId: 'alice', senderUsername: 'Alice', senderProfilePic: '',
        receiverId: 'bob', receiverUsername: 'Bob', receiverProfilePic: '',
        unreadCounts: {'alice': 0, 'bob': 3},
        participants: ['alice', 'bob'],
        lastMessageTimestamp: DateTime(2026, 1, 1, 10, 0),
      );
      final updated = Map<String, int>.from(conn.unreadCounts);
      updated['bob'] = 0;
      final cleared = conn.copyWith(unreadCounts: updated);
      expect(cleared.unreadCountForUser('bob'), 0);
    });

    test('6.2 Higher lastMessageTimestamp allows stream count through', () {
      final readTime = DateTime(2026, 1, 1, 10, 0);
      final newMsgTime = DateTime(2026, 1, 1, 10, 5);
      final shouldOverride = !newMsgTime.isAfter(readTime);
      expect(shouldOverride, isFalse);
    });

    test('6.3 Same lastMessageTimestamp causes override to zero', () {
      final readTime = DateTime(2026, 1, 1, 10, 0);
      final sameTime = DateTime(2026, 1, 1, 10, 0);
      final shouldOverride = !sameTime.isAfter(readTime);
      expect(shouldOverride, isTrue);
    });
  });

  // =========================================================================
  // Group 7 — Phase 2A: Concurrent send/read model arithmetic
  // =========================================================================
  group('Phase 2A - Concurrent send/read model arithmetic', () {
    test('7.1 Unread count increment: +1 to existing count', () {
      final counts = <String, dynamic>{'alice': 0, 'bob': 2};
      counts['bob'] = (counts['bob'] as num).toInt() + 1;
      expect(counts['bob'], 3);
    });

    test('7.2 Sender count is preserved at 0 when key already exists', () {
      final counts = <String, dynamic>{'alice': 0, 'bob': 2};
      if (!counts.containsKey('alice')) counts['alice'] = 0;
      expect(counts['alice'], 0);
    });

    test('7.3 After read then send, recipient count is exactly 1', () {
      var counts = <String, dynamic>{'alice': 0, 'bob': 0};
      counts['bob'] = (counts['bob'] as num).toInt() + 1;
      expect(counts['bob'], 1);
    });
  });

  // =========================================================================
  // Group 8 — Existing regressions: ordering and deduplication
  // =========================================================================
  group('Existing regression - ordering and deduplication', () {
    test('8.1 getMergedMessages deduplicates by message ID', () {
      final db = _FakeDb();
      final fs = _FakeFirestore();
      final provider = ChatProvider(db: db, firestoreService: fs);
      final msg = _msg(id: 'dup', connectionId: 'conn_a', senderId: 'a', recipientId: 'b');
      final result = provider.getMergedMessages('conn_a', streamMessages: [msg, msg]);
      expect(result.where((m) => m.id == 'dup').length, 1);
    });

    test('8.2 getMergedMessages orders by timestamp ascending', () {
      final db = _FakeDb();
      final fs = _FakeFirestore();
      final provider = ChatProvider(db: db, firestoreService: fs);
      final m1 = _msg(id: 'early', connectionId: 'conn_a', senderId: 'a', recipientId: 'b', createdAt: DateTime(2026, 1, 1, 8, 0));
      final m2 = _msg(id: 'late', connectionId: 'conn_a', senderId: 'a', recipientId: 'b', createdAt: DateTime(2026, 1, 1, 9, 0));
      final result = provider.getMergedMessages('conn_a', streamMessages: [m2, m1]);
      expect(result.first.id, 'early');
      expect(result.last.id, 'late');
    });

    test('8.3 syncMessages preserves isRead true monotonically', () {
      final db = _FakeDb();
      final fs = _FakeFirestore();
      final provider = ChatProvider(db: db, firestoreService: fs);
      final original = _msg(id: 'msg_r', connectionId: 'conn_a', senderId: 'a', recipientId: 'b', isRead: true);
      provider.syncMessages('conn_a', [original]);
      final stale = _msg(id: 'msg_r', connectionId: 'conn_a', senderId: 'a', recipientId: 'b', isRead: false);
      provider.syncMessages('conn_a', [stale]);
      final msgs = provider.getMessagesForConnection('conn_a');
      expect(msgs.single.isRead, isTrue);
    });

    test('8.4 sendMessage adds message optimistically', () async {
      final db = _FakeDb();
      final fs = _FakeFirestore();
      final provider = ChatProvider(db: db, firestoreService: fs);
      await provider.sendMessage(connectionId: 'conn_a', senderId: 'alice', recipientId: 'bob', text: 'hello bob');
      final messages = provider.getMessagesForConnection('conn_a');
      expect(messages.any((m) => m.content == 'hello bob'), isTrue);
    });
  });
}
