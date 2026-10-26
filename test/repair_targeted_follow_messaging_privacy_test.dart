import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:crushie/models/chat_message_model.dart';
import 'package:crushie/providers/chat_provider.dart';
import 'package:crushie/providers/user_provider.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/services/firestore_service.dart';
import 'package:crushie/widgets/contact_reveal_card.dart';

// ---------------------------------------------------------------------------
// Test Doubles and Mocks
// ---------------------------------------------------------------------------

class MockFirestoreServiceForTargetedTests extends Fake implements FirestoreService {
  final Map<String, Set<String>> _follows = {};
  final StreamController<Set<String>> _followingStreamController =
      StreamController<Set<String>>.broadcast();

  bool shouldThrowOnFollow = false;
  Completer<void>? followCompleter;

  void emitStream(Set<String> ids) {
    _followingStreamController.add(ids);
  }

  @override
  Stream<Set<String>> getFollowingUserIdsStream(String userId) {
    return Stream<Set<String>>.multi((controller) {
      controller.add(Set<String>.from(_follows[userId] ?? {}));
      final sub = _followingStreamController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => sub.cancel();
    });
  }

  @override
  Future<bool> followUser({
    required String currentUserId,
    required String targetUserId,
    String? currentUsername,
    String? currentUserProfilePic,
    String? targetUsername,
  }) async {
    if (followCompleter != null) {
      await followCompleter!.future;
    }
    if (shouldThrowOnFollow) {
      throw Exception('PERMISSION_DENIED');
    }
    _follows.putIfAbsent(currentUserId, () => <String>{}).add(targetUserId);
    return true;
  }

  @override
  Future<bool> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (shouldThrowOnFollow) {
      throw Exception('PERMISSION_DENIED');
    }
    _follows[currentUserId]?.remove(targetUserId);
    return false;
  }

  @override
  Future<bool> toggleFollow({
    required String currentUserId,
    required String targetUserId,
    String? currentUsername,
    String? currentUserProfilePic,
    String? targetUsername,
  }) async {
    final isFollowing = _follows[currentUserId]?.contains(targetUserId) ?? false;
    if (isFollowing) {
      return unfollowUser(currentUserId: currentUserId, targetUserId: targetUserId);
    } else {
      return followUser(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        currentUsername: currentUsername,
        currentUserProfilePic: currentUserProfilePic,
        targetUsername: targetUsername,
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // TASK 1: Message Disappearance & Timestamp Handling
  // =========================================================================
  group('Task 1: Message Disappearance & Timestamp Handling', () {
    test('1.1. Stream snapshot temporarily missing optimistic message does not hide it', () {
      final chatProv = ChatProvider();
      const connId = 'conn_test_1';
      final baseTime = DateTime(2026, 10, 19, 10, 0);

      // Server initially has msg1
      final serverMsg1 = ChatMessageModel(
        id: 'msg_server_1',
        connectionId: connId,
        senderId: 'user_bob',
        recipientId: 'user_alice',
        message: 'Hello Alice',
        timestamp: baseTime,
      );
      chatProv.syncMessages(connId, [serverMsg1]);

      // Alice sends an optimistic message
      final optimisticMsg = ChatMessageModel(
        id: 'msg_opt_2',
        connectionId: connId,
        senderId: 'user_alice',
        recipientId: 'user_bob',
        message: 'Hey Bob, what is up?',
        timestamp: baseTime.add(const Duration(seconds: 10)),
        deliveryStatus: MessageDeliveryStatus.sent,
      );
      chatProv.syncMessages(connId, [serverMsg1, optimisticMsg]);

      // A stale/delayed stream snapshot arrives that ONLY contains msg_server_1
      final staleStreamMessages = [serverMsg1];

      // getMergedMessages merges stream messages with local optimistic messages
      final merged = chatProv.getMergedMessages(
        connId,
        streamMessages: staleStreamMessages,
        userId: 'user_alice',
      );

      // Optimistic message MUST still be present in the merged list!
      expect(merged.length, equals(2));
      expect(merged.any((m) => m.id == 'msg_opt_2'), isTrue);
      expect(merged.last.message, equals('Hey Bob, what is up?'));
    });

    test('1.2. Merging eventual persisted server message replaces optimistic message without duplicates', () {
      final chatProv = ChatProvider();
      const connId = 'conn_test_2';
      final baseTime = DateTime(2026, 10, 19, 10, 0);

      final optimisticMsg = ChatMessageModel(
        id: 'msg_opt_100',
        connectionId: connId,
        senderId: 'user_alice',
        recipientId: 'user_bob',
        message: 'Let us meet at 5',
        timestamp: baseTime,
        deliveryStatus: MessageDeliveryStatus.sent,
      );
      chatProv.syncMessages(connId, [optimisticMsg]);

      // Server acknowledges message with same ID and updated delivered status
      final serverAck = ChatMessageModel(
        id: 'msg_opt_100',
        connectionId: connId,
        senderId: 'user_alice',
        recipientId: 'user_bob',
        message: 'Let us meet at 5',
        timestamp: baseTime,
        deliveryStatus: MessageDeliveryStatus.delivered,
      );

      chatProv.syncMessages(connId, [serverAck]);

      final displayMessages = chatProv.getMergedMessages(
        connId,
        streamMessages: [serverAck],
        userId: 'user_alice',
      );

      // Exactly 1 message, delivery status updated, no duplicate
      expect(displayMessages.length, equals(1));
      expect(displayMessages.first.id, equals('msg_opt_100'));
      expect(displayMessages.first.deliveryStatus, equals(MessageDeliveryStatus.delivered));
    });

    test('1.3. ChatMessageModel timestamp parsing handles all supported formats without assigning DateTime.now()', () {
      final testDate = DateTime.utc(2025, 6, 15, 12, 30, 0);

      // 1. Firestore Timestamp
      final ts = Timestamp.fromDate(testDate);
      expect(ChatMessageModel.parseTimestamp(ts).isAtSameMomentAs(testDate), isTrue);

      // 2. DateTime
      expect(ChatMessageModel.parseTimestamp(testDate), equals(testDate));

      // 3. ISO-8601 string
      expect(ChatMessageModel.parseTimestamp('2025-06-15T12:30:00.000Z'), equals(testDate));

      // 4. Integer milliseconds
      final millis = testDate.millisecondsSinceEpoch;
      expect(ChatMessageModel.parseTimestamp(millis).millisecondsSinceEpoch, equals(millis));
      expect(ChatMessageModel.parseTimestamp(millis).isAtSameMomentAs(testDate), isTrue);

      // 5. Integer seconds
      final seconds = millis ~/ 1000;
      expect(ChatMessageModel.parseTimestamp(seconds).millisecondsSinceEpoch, equals(seconds * 1000));
      expect(ChatMessageModel.parseTimestamp(seconds).isAtSameMomentAs(testDate), isTrue);

      // 6. Missing/null with fallback: must NOT default to DateTime.now()
      final fallbackEpoch = DateTime.fromMillisecondsSinceEpoch(0);
      final parsedNull = ChatMessageModel.parseTimestamp(null);
      expect(parsedNull, equals(fallbackEpoch));
      expect(parsedNull.isBefore(DateTime(2000)), isTrue);

      // 7. Deterministic fallback from msg_<epoch> ID
      const msgIdWithEpoch = 'msg_1718454600000';
      final fallbackFromId = ChatMessageModel.fallbackTimestamp(msgIdWithEpoch);
      expect(fallbackFromId, isNotNull);
      expect(fallbackFromId!.millisecondsSinceEpoch, equals(1718454600000));
    });

    test('1.4. ChatMessageModel.fromMap prefers timestamp field and falls back to createdAt safely', () {
      // Both present: timestamp is preferred
      final mapBoth = {
        'timestamp': '2026-01-01T00:00:00.000Z',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };
      final msgBoth = ChatMessageModel.fromMap(mapBoth, 'msg_1');
      expect(msgBoth.createdAt, equals(DateTime.utc(2026, 1, 1)));

      // timestamp empty string: falls back to createdAt
      final mapEmptyTs = {
        'timestamp': '',
        'createdAt': '2025-05-10T10:00:00.000Z',
      };
      final msgEmptyTs = ChatMessageModel.fromMap(mapEmptyTs, 'msg_2');
      expect(msgEmptyTs.createdAt, equals(DateTime.utc(2025, 5, 10, 10, 0)));

      // only createdAt present
      final mapCreatedAtOnly = {
        'createdAt': '2025-08-20T15:00:00.000Z',
      };
      final msgCreatedOnly = ChatMessageModel.fromMap(mapCreatedAtOnly, 'msg_3');
      expect(msgCreatedOnly.createdAt, equals(DateTime.utc(2025, 8, 20, 15, 0)));
    });
  });

  // =========================================================================
  // TASK 2: Contact Privacy & WhatsApp Authorization
  // =========================================================================
  group('Task 2: Contact Privacy & WhatsApp Access Security', () {
    testWidgets('2.1. Unauthorized viewer (isPaid == false) does NOT see raw contact details', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactRevealCard(
              contactMethod: 'WhatsApp',
              contactDetails: '+254712345678',
              username: 'bob',
              isPaid: false,
            ),
          ),
        ),
      );

      // Card is displayed with locked state
      expect(find.text('PRIVATE CONTACT LOCKED'), findsOneWidget);
      expect(find.text('WhatsApp: Private Contact Locked'), findsOneWidget);

      // Raw phone number MUST NOT exist in the widget tree
      expect(find.textContaining('+254712345678'), findsNothing);
      expect(find.textContaining('712345678'), findsNothing);
    });

    testWidgets('2.2. Authorized viewer (isPaid == true) sees revealed contact details', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactRevealCard(
              contactMethod: 'WhatsApp',
              contactDetails: '+254712345678',
              username: 'bob',
              isPaid: true,
            ),
          ),
        ),
      );

      // Card is displayed with unlocked state
      expect(find.text('UNLOCKED CONTACT METHOD'), findsOneWidget);
      expect(find.text('WhatsApp: +254712345678'), findsOneWidget);
    });

    testWidgets('2.3. Blocked user does NOT see contact details even if connection is paid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactRevealCard(
              contactMethod: 'WhatsApp',
              contactDetails: '+254712345678',
              username: 'bob',
              isPaid: true,
              isBlocked: true,
            ),
          ),
        ),
      );

      expect(find.text('CONTACT BLOCKED'), findsOneWidget);
      expect(find.text('Contact unavailable while blocked'), findsOneWidget);
      expect(find.textContaining('+254712345678'), findsNothing);
    });

    testWidgets('2.4. Empty or invalid contact details hide card completely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactRevealCard(
              contactMethod: 'WhatsApp',
              contactDetails: '',
              username: 'bob',
              isPaid: true,
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.textContaining('CONTACT'), findsNothing);
    });

    testWidgets('2.5. Direct external contact opening remains disabled and fail-closed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactRevealCard(
              contactMethod: 'WhatsApp',
              contactDetails: '+254712345678',
              username: 'bob',
              isPaid: true,
            ),
          ),
        ),
      );

      // Action button is fail-closed with warning
      expect(find.text('Contact Opening Unavailable'), findsOneWidget);

      await tester.tap(find.text('Contact Opening Unavailable'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('temporarily unavailable pending server verification'), findsOneWidget);
    });
  });

  // =========================================================================
  // TASK 3: Follow State Synchronization & Reconciliation
  // =========================================================================
  group('Task 3: Follow State Synchronization & Reconciliation', () {
    test('3.1. Stale stream snapshot (missing recent follow) does NOT clear optimistic follow', () async {
      final mockFirestore = MockFirestoreServiceForTargetedTests();
      final db = DatabaseService();
      db.clearUserData();
      final userProv = UserProvider(db: db, firestoreService: mockFirestore);

      // Alice follows Bob
      userProv.initUserFollowing('user_alice');
      await pumpEventQueue();

      final followFuture = userProv.followUser('user_alice', 'user_bob', targetUsername: 'bob');
      await followFuture;

      expect(userProv.isFollowing('user_bob'), isTrue);

      // Simulate a stale snapshot from Firestore that does NOT yet include user_bob
      mockFirestore.emitStream(<String>{});
      await pumpEventQueue();

      // Reconciliation guard prevents the stale snapshot from clearing Bob!
      expect(userProv.isFollowing('user_bob'), isTrue);
      expect(db.isFollowing('user_bob'), isTrue);
    });

    test('3.2. Stale stream snapshot (containing old follow) does NOT restore unfollowed relationship', () async {
      final mockFirestore = MockFirestoreServiceForTargetedTests();
      final db = DatabaseService();
      db.clearUserData();
      final userProv = UserProvider(db: db, firestoreService: mockFirestore);

      // Alice initially follows Bob
      userProv.initUserFollowing('user_alice');
      await userProv.followUser('user_alice', 'user_bob', targetUsername: 'bob');
      mockFirestore.emitStream({'user_bob'});
      await pumpEventQueue();
      expect(userProv.isFollowing('user_bob'), isTrue);

      // Alice unfollows Bob
      final unfollowFuture = userProv.unfollowUser('user_alice', 'user_bob');
      await unfollowFuture;

      expect(userProv.isFollowing('user_bob'), isFalse);

      // Stale stream snapshot still has user_bob
      mockFirestore.emitStream({'user_bob'});
      await pumpEventQueue();

      // Reconciliation guard prevents stale snapshot from restoring the follow!
      expect(userProv.isFollowing('user_bob'), isFalse);
      expect(db.isFollowing('user_bob'), isFalse);
    });

    test('3.3. When stream snapshot confirms expected state, guard is cleaned up', () async {
      final mockFirestore = MockFirestoreServiceForTargetedTests();
      final db = DatabaseService();
      db.clearUserData();
      final userProv = UserProvider(db: db, firestoreService: mockFirestore);

      userProv.initUserFollowing('user_alice');
      await userProv.followUser('user_alice', 'user_bob', targetUsername: 'bob');
      expect(userProv.isFollowing('user_bob'), isTrue);

      // Fresh stream snapshot from Firestore confirms user_bob is followed
      mockFirestore.emitStream({'user_bob'});
      await pumpEventQueue();

      expect(userProv.isFollowing('user_bob'), isTrue);
      expect(userProv.followingUserIds.contains('user_bob'), isTrue);
    });

    test('3.4. Write failure rolls back optimistic follow and removes guard immediately', () async {
      final mockFirestore = MockFirestoreServiceForTargetedTests();
      mockFirestore.shouldThrowOnFollow = true;

      final db = DatabaseService();
      db.clearUserData();
      final userProv = UserProvider(db: db, firestoreService: mockFirestore);

      userProv.initUserFollowing('user_alice');
      await pumpEventQueue();

      expect(userProv.isFollowing('user_bob'), isFalse);

      // Attempt follow which throws
      expect(
        () => userProv.followUser('user_alice', 'user_bob', targetUsername: 'bob'),
        throwsA(isA<Exception>()),
      );

      await pumpEventQueue();

      // State is rolled back to false
      expect(userProv.isFollowing('user_bob'), isFalse);
      expect(userProv.isFollowPending('user_bob'), isFalse);
    });
  });
}
