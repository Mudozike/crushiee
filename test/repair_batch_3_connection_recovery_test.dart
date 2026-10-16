import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crushie/models/connection_model.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/models/notification_model.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/services/firestore_service.dart';
import 'package:crushie/providers/connection_provider.dart';

class MockFirestoreService implements FirestoreService {
  int saveConnectionCallCount = 0;
  int updateConnectionStatusCallCount = 0;
  int createNotificationCallCount = 0;
  int findExistingConnectionCallCount = 0;

  ConnectionModel? existingConnectionToReturn;
  Object? saveConnectionError;
  Object? updateConnectionStatusError;

  ConnectionStatus? lastUpdatedStatus;
  String? lastUpdatedConnectionId;

  bool returnNullOnFirstFind = false;

  @override
  Future<ConnectionModel?> findExistingConnection(
      String uid1, String uid2) async {
    findExistingConnectionCallCount++;
    if (findExistingConnectionCallCount == 1 && returnNullOnFirstFind) {
      return null;
    }
    return existingConnectionToReturn;
  }

  @override
  Future<void> saveConnection(ConnectionModel connection) async {
    saveConnectionCallCount++;
    if (saveConnectionError != null) {
      throw saveConnectionError!;
    }
  }

  @override
  Future<void> updateConnectionStatus(
      String connectionId, ConnectionStatus status) async {
    updateConnectionStatusCallCount++;
    lastUpdatedConnectionId = connectionId;
    lastUpdatedStatus = status;
    if (updateConnectionStatusError != null) {
      throw updateConnectionStatusError!;
    }
  }

  @override
  Stream<List<ConnectionModel>> getUserConnectionsStream(String userId) {
    return Stream.value(existingConnectionToReturn != null
        ? [existingConnectionToReturn!]
        : []);
  }

  @override
  Future<void> createNotification(NotificationModel notification) async {
    createNotificationCallCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUserAlice = UserModel(
    id: 'uid_alice',
    username: 'alice',
    email: 'alice@example.com',
    country: 'Kenya',
    city: 'Nairobi',
    dateOfBirth: DateTime(1998, 5, 20),
    gender: 'Female',
    bio: 'Alice bio',
    profilePicUrl: 'https://example.com/alice.png',
    preferredContactMethod: 'WhatsApp',
    contactDetails: '+254700000001',
    isPremium: true,
  );

  final testUserBob = UserModel(
    id: 'uid_bob',
    username: 'bob',
    email: 'bob@example.com',
    country: 'Kenya',
    city: 'Nairobi',
    dateOfBirth: DateTime(1996, 8, 15),
    gender: 'Male',
    bio: 'Bob bio',
    profilePicUrl: 'https://example.com/bob.png',
    preferredContactMethod: 'Telegram',
    contactDetails: '@bob_tg',
    isPremium: false,
    dailyConnections: 2,
    monthlyConnections: 5,
  );

  group('Repair Batch 3: Simultaneous Connection Initiation and Recovery', () {
    testWidgets(
        'Concurrent initiation recovers existing connection and avoids duplicate notification & usage',
        (tester) async {
      final mockFirestore = MockFirestoreService();
      final db = DatabaseService();
      final provider = ConnectionProvider(
        db: db,
        firestoreService: mockFirestore,
      );

      final canonicalId =
          ConnectionModel.getConversationId(testUserBob.id, testUserAlice.id);

      // Alice already created the connection
      final existingFromAlice = ConnectionModel(
        id: canonicalId,
        senderId: testUserAlice.id,
        senderUsername: testUserAlice.username,
        senderProfilePic: testUserAlice.profilePicUrl,
        receiverId: testUserBob.id,
        receiverUsername: testUserBob.username,
        receiverProfilePic: testUserBob.profilePicUrl,
        participants: [testUserAlice.id, testUserBob.id],
      );

      // Bob's concurrent write fails with permission-denied because document exists with immutable senderId
      mockFirestore.saveConnectionError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      mockFirestore.existingConnectionToReturn = existingFromAlice;
      mockFirestore.returnNullOnFirstFind = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final result = await provider.initiateConnect(
                      context: context,
                      sender: testUserBob,
                      recipient: testUserAlice,
                      autoNavigateToChat: false,
                    );
                    expect(result, isNotNull);
                    expect(result!.id, equals(canonicalId));
                    expect(result.senderId, equals(testUserAlice.id));
                  },
                  child: const Text('Connect'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // Verified: save was attempted, recovered from findExistingConnection
      expect(mockFirestore.saveConnectionCallCount, equals(1));
      expect(mockFirestore.findExistingConnectionCallCount, greaterThan(0));
      // Bob did not create duplicate notification
      expect(mockFirestore.createNotificationCallCount, equals(0));
    });

    testWidgets(
        'Unrelated error with no existing connection rethrows original exception',
        (tester) async {
      final mockFirestore = MockFirestoreService();
      final db = DatabaseService();
      final provider = ConnectionProvider(
        db: db,
        firestoreService: mockFirestore,
      );

      mockFirestore.saveConnectionError =
          Exception('Simulated network connection timeout');
      mockFirestore.existingConnectionToReturn = null;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  Object? thrown;
                  try {
                    await provider.initiateConnect(
                      context: context,
                      sender: testUserBob,
                      recipient: testUserAlice,
                      autoNavigateToChat: false,
                    );
                  } catch (e) {
                    thrown = e;
                  }
                  expect(thrown, isA<Exception>());
                },
                child: const Text('Connect Error'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Connect Error'));
      await tester.pumpAndSettle();

      expect(mockFirestore.saveConnectionCallCount, equals(1));
    });

    testWidgets(
        'Existing conversation in memory or Firestore is reused without writing',
        (tester) async {
      final mockFirestore = MockFirestoreService();
      final db = DatabaseService();
      final provider = ConnectionProvider(
        db: db,
        firestoreService: mockFirestore,
      );

      final canonicalId =
          ConnectionModel.getConversationId(testUserAlice.id, testUserBob.id);
      final existing = ConnectionModel(
        id: canonicalId,
        senderId: testUserAlice.id,
        senderUsername: testUserAlice.username,
        senderProfilePic: testUserAlice.profilePicUrl,
        receiverId: testUserBob.id,
        receiverUsername: testUserBob.username,
        receiverProfilePic: testUserBob.profilePicUrl,
      );
      mockFirestore.existingConnectionToReturn = existing;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  final res = await provider.initiateConnect(
                    context: context,
                    sender: testUserAlice,
                    recipient: testUserBob,
                    autoNavigateToChat: false,
                  );
                  expect(res, isNotNull);
                  expect(res!.id, equals(canonicalId));
                },
                child: const Text('Connect Existing'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Connect Existing'));
      await tester.pumpAndSettle();

      // No new document was created because existing connection was reused
      expect(mockFirestore.saveConnectionCallCount, equals(0));
      expect(mockFirestore.createNotificationCallCount, equals(0));
    });

    testWidgets('Self connection is rejected before any Firestore interaction',
        (tester) async {
      final mockFirestore = MockFirestoreService();
      final db = DatabaseService();
      final provider = ConnectionProvider(
        db: db,
        firestoreService: mockFirestore,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final res = await provider.initiateConnect(
                      context: context,
                      sender: testUserAlice,
                      recipient: testUserAlice,
                    );
                    expect(res, isNull);
                  },
                  child: const Text('Self Connect'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Self Connect'));
      await tester.pumpAndSettle();

      expect(mockFirestore.saveConnectionCallCount, equals(0));
      expect(mockFirestore.findExistingConnectionCallCount, equals(0));
      expect(find.text('You cannot connect with your own profile!'),
          findsOneWidget);
    });
  });

  group('Repair Batch 3: Redundant Connection Write Elimination', () {
    testWidgets(
        'Accepting a connection updates status with single authoritative updateConnectionStatus write',
        (tester) async {
      final mockFirestore = MockFirestoreService();
      final db = DatabaseService();
      final provider = ConnectionProvider(
        db: db,
        firestoreService: mockFirestore,
      );

      const connId = 'conn_test_pending_1';
      final pendingConn = ConnectionModel(
        id: connId,
        senderId: testUserAlice.id,
        senderUsername: testUserAlice.username,
        senderProfilePic: testUserAlice.profilePicUrl,
        receiverId: testUserBob.id,
        receiverUsername: testUserBob.username,
        receiverProfilePic: testUserBob.profilePicUrl,
        status: ConnectionStatus.pending,
      );

      db.addConnection(pendingConn);

      await provider.respondToConnectionRequest(
          connId, ConnectionStatus.accepted);

      // Verify single authoritative write occurred
      expect(mockFirestore.updateConnectionStatusCallCount, equals(1));
      expect(mockFirestore.lastUpdatedConnectionId, equals(connId));
      expect(
          mockFirestore.lastUpdatedStatus, equals(ConnectionStatus.accepted));

      // CRITICAL: saveConnection must NOT be called (redundant write eliminated)
      expect(mockFirestore.saveConnectionCallCount, equals(0));

      // In-memory status updated
      final updated = db.connections.firstWhere((c) => c.id == connId);
      expect(updated.status, equals(ConnectionStatus.accepted));
    });

    testWidgets(
        'Declining a connection updates status without corrupting metadata or calling saveConnection',
        (tester) async {
      final mockFirestore = MockFirestoreService();
      final db = DatabaseService();
      final provider = ConnectionProvider(
        db: db,
        firestoreService: mockFirestore,
      );

      const connId = 'conn_test_pending_2';
      final pendingConn = ConnectionModel(
        id: connId,
        senderId: testUserAlice.id,
        senderUsername: testUserAlice.username,
        senderProfilePic: testUserAlice.profilePicUrl,
        receiverId: testUserBob.id,
        receiverUsername: testUserBob.username,
        receiverProfilePic: testUserBob.profilePicUrl,
        status: ConnectionStatus.pending,
        lastMessageText: 'Hello there!',
        lastMessageSenderId: testUserAlice.id,
      );

      db.addConnection(pendingConn);

      await provider.respondToConnectionRequest(
          connId, ConnectionStatus.declined);

      // Verify single authoritative update
      expect(mockFirestore.updateConnectionStatusCallCount, equals(1));
      expect(
          mockFirestore.lastUpdatedStatus, equals(ConnectionStatus.declined));
      expect(mockFirestore.saveConnectionCallCount, equals(0));

      // Metadata remains intact
      final updated = db.connections.firstWhere((c) => c.id == connId);
      expect(updated.status, equals(ConnectionStatus.declined));
      expect(updated.lastMessageText, equals('Hello there!'));
    });

    testWidgets(
        'Error during updateConnectionStatus rolls back in-memory state',
        (tester) async {
      final mockFirestore = MockFirestoreService();
      final db = DatabaseService();
      final provider = ConnectionProvider(
        db: db,
        firestoreService: mockFirestore,
      );

      const connId = 'conn_test_pending_3';
      final pendingConn = ConnectionModel(
        id: connId,
        senderId: testUserAlice.id,
        senderUsername: testUserAlice.username,
        senderProfilePic: testUserAlice.profilePicUrl,
        receiverId: testUserBob.id,
        receiverUsername: testUserBob.username,
        receiverProfilePic: testUserBob.profilePicUrl,
        status: ConnectionStatus.pending,
      );

      db.addConnection(pendingConn);
      mockFirestore.updateConnectionStatusError =
          Exception('Simulated Firestore write failure');

      Object? thrown;
      try {
        await provider.respondToConnectionRequest(
            connId, ConnectionStatus.accepted);
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<Exception>());

      // Ensure state is rolled back to pending
      final conn = db.connections.firstWhere((c) => c.id == connId);
      expect(conn.status, equals(ConnectionStatus.pending));
    });
  });
}
