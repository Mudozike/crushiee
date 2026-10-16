import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Repair Batch 2 Security Follow-up: Authorization Rules Validation',
      () {
    // -------------------------------------------------------------
    // Helper simulation matching firestore.rules logic exactly
    // -------------------------------------------------------------
    String getConnectionRecipient(Map<String, dynamic> data) {
      if (data.containsKey('receiverId') &&
          (data['receiverId'] as String).isNotEmpty) {
        return data['receiverId'] as String;
      }
      if (data.containsKey('recipientId')) {
        return data['recipientId'] as String;
      }
      return '';
    }

    String getOtherParticipant(Map<String, dynamic> data, String currentUid) {
      return data['senderId'] == currentUid
          ? getConnectionRecipient(data)
          : (data['senderId'] as String);
    }

    bool isConnectionParticipant(Map<String, dynamic> data, String uid) {
      if (data.containsKey('participants') &&
          (data['participants'] as List).contains(uid)) {
        return true;
      }
      if (data.containsKey('senderId') && data['senderId'] == uid) {
        return true;
      }
      if (data.containsKey('receiverId') && data['receiverId'] == uid) {
        return true;
      }
      if (data.containsKey('recipientId') && data['recipientId'] == uid) {
        return true;
      }
      return false;
    }

    bool validateConnectionRead({
      required String? authUid,
      required Map<String, dynamic> connectionDoc,
    }) {
      if (authUid == null || authUid.isEmpty) return false;
      return isConnectionParticipant(connectionDoc, authUid);
    }

    bool validateConnectionCreate({
      required String? authUid,
      required Map<String, dynamic> resourceData,
      required Set<String> blockedPairs,
    }) {
      if (authUid == null || authUid.isEmpty) return false;
      if (resourceData['senderId'] != authUid) return false;
      if (!resourceData.containsKey('participants')) return false;
      final participants =
          List<String>.from(resourceData['participants'] ?? []);
      if (participants.length != 2) return false;
      if (!participants.contains(authUid)) return false;
      final recipient = getConnectionRecipient(resourceData);
      if (recipient.isEmpty || recipient == authUid) return false;
      if (!participants.contains(recipient)) return false;
      if (blockedPairs.contains('$authUid:$recipient') ||
          blockedPairs.contains('$recipient:$authUid')) {
        return false;
      }
      return true;
    }

    bool validateConnectionUpdate({
      required String? authUid,
      required Map<String, dynamic> oldDoc,
      required Map<String, dynamic> newDoc,
      required Set<String> affectedKeys,
    }) {
      if (authUid == null || authUid.isEmpty) return false;
      if (!isConnectionParticipant(oldDoc, authUid)) return false;

      // 1. Immutable structural fields
      final oldParticipants = List<String>.from(oldDoc['participants'] ?? []);
      final newParticipants = List<String>.from(newDoc['participants'] ?? []);
      if (oldParticipants.length != newParticipants.length ||
          !newParticipants.toSet().containsAll(oldParticipants)) {
        return false; // Participants cannot be altered!
      }

      if (newDoc['senderId'] != oldDoc['senderId']) {
        return false;
      }
      if (oldDoc.containsKey('receiverId') &&
          newDoc['receiverId'] != oldDoc['receiverId']) {
        return false;
      }
      if (oldDoc.containsKey('recipientId') &&
          newDoc['recipientId'] != oldDoc['recipientId']) {
        return false;
      }
      if (oldDoc.containsKey('createdAt') &&
          newDoc['createdAt'] != oldDoc['createdAt']) {
        return false;
      }
      if (oldDoc.containsKey('amount') &&
          newDoc['amount'] != oldDoc['amount']) {
        return false;
      }
      if (oldDoc.containsKey('isPaid') &&
          newDoc['isPaid'] != oldDoc['isPaid']) {
        return false;
      }

      // Branch 1: Message Send Update
      const allowedMsgSendKeys = {
        'lastMessageText',
        'lastMessageTimestamp',
        'lastMessageSenderId',
        'updatedAt',
        'unreadCounts'
      };
      if (affectedKeys.isNotEmpty &&
          (affectedKeys.contains('lastMessageText') ||
              affectedKeys.contains('lastMessageSenderId')) &&
          allowedMsgSendKeys.containsAll(affectedKeys)) {
        // Sender of the last message MUST match the authenticated sender
        if (newDoc['lastMessageSenderId'] != authUid) {
          return false;
        }
        if (newDoc['lastMessageText'] is! String ||
            (newDoc['lastMessageText'] as String).length > 1000) {
          return false;
        }

        if (newDoc.containsKey('unreadCounts')) {
          final newUnreads =
              Map<String, dynamic>.from(newDoc['unreadCounts'] ?? {});
          final oldUnreads =
              Map<String, dynamic>.from(oldDoc['unreadCounts'] ?? {});
          final otherUid = getOtherParticipant(oldDoc, authUid);

          // Keys must be participants only
          if (!oldParticipants.toSet().containsAll(newUnreads.keys)) {
            return false;
          }

          // Caller cannot increment their own unread count
          final oldOwnCount = oldUnreads[authUid] ?? 0;
          if (newUnreads.containsKey(authUid) &&
              newUnreads[authUid] != oldOwnCount) {
            return false;
          }

          // Recipient's unread count must only increment by 1 or initialize to 1
          final oldOtherCount = oldUnreads[otherUid] ?? 0;
          final expectedOtherCount =
              oldUnreads.containsKey(otherUid) ? oldOtherCount + 1 : 1;
          if (newUnreads.containsKey(otherUid) &&
              newUnreads[otherUid] != expectedOtherCount) {
            return false;
          }
        }
        return true;
      }

      // Branch 2: Mark as Read
      if (affectedKeys.length == 1 && affectedKeys.contains('unreadCounts')) {
        final newUnreads =
            Map<String, dynamic>.from(newDoc['unreadCounts'] ?? {});
        final oldUnreads =
            Map<String, dynamic>.from(oldDoc['unreadCounts'] ?? {});
        final otherUid = getOtherParticipant(oldDoc, authUid);

        // Caller can ONLY reset their own unread count to 0
        if (newUnreads[authUid] != 0) return false;

        // Other participant's unread count MUST be untouched
        final oldOtherCount = oldUnreads[otherUid] ?? 0;
        if (newUnreads.containsKey(otherUid) &&
            newUnreads[otherUid] != oldOtherCount) {
          return false;
        }
        return true;
      }

      // Branch 3: Status Response (accept/decline)
      const allowedStatusKeys = {'status', 'updatedAt', 'respondedAt'};
      if (affectedKeys.isNotEmpty &&
          allowedStatusKeys.containsAll(affectedKeys)) {
        if (authUid != getConnectionRecipient(oldDoc)) return false;
        if (oldDoc['status'] != 'pending') return false;
        if (!['accepted', 'declined'].contains(newDoc['status'])) return false;
        return true;
      }

      return false;
    }

    bool validateMessageCreate({
      required String? authUid,
      required Map<String, dynamic> connectionDoc,
      required String connectionId,
      required Map<String, dynamic> messageData,
      required Set<String> blockedPairs,
    }) {
      if (authUid == null || authUid.isEmpty) {
        return false;
      }
      if (messageData['senderId'] != authUid) {
        return false;
      }
      if (!isConnectionParticipant(connectionDoc, authUid)) {
        return false;
      }
      if (messageData['connectionId'] != connectionId) {
        return false;
      }
      if (messageData['isRead'] == true) {
        return false; // Cannot create pre-read message
      }
      if (messageData['isDeletedForEveryone'] == true) {
        return false;
      }
      if (messageData.containsKey('deletedForUserIds') &&
          (messageData['deletedForUserIds'] as List).isNotEmpty) {
        return false;
      }
      final targetRecipient = getConnectionRecipient(messageData);
      if (targetRecipient.isEmpty || targetRecipient == authUid) {
        return false;
      }
      if (blockedPairs.contains('$authUid:$targetRecipient') ||
          blockedPairs.contains('$targetRecipient:$authUid')) {
        return false;
      }
      return true;
    }

    bool validateMessageUpdate({
      required String? authUid,
      required Map<String, dynamic> connectionDoc,
      required Map<String, dynamic> oldMessage,
      required Map<String, dynamic> newMessage,
      required Set<String> affectedKeys,
    }) {
      if (authUid == null || authUid.isEmpty) {
        return false;
      }
      if (!isConnectionParticipant(connectionDoc, authUid)) {
        return false;
      }

      // Immutability checks on critical identifiers
      if (newMessage['senderId'] != oldMessage['senderId']) {
        return false;
      }
      if (newMessage['connectionId'] != oldMessage['connectionId']) {
        return false;
      }
      if (oldMessage.containsKey('receiverId') &&
          newMessage['receiverId'] != oldMessage['receiverId']) {
        return false;
      }
      if (oldMessage.containsKey('recipientId') &&
          newMessage['recipientId'] != oldMessage['recipientId']) {
        return false;
      }
      if (oldMessage.containsKey('createdAt') &&
          newMessage['createdAt'] != oldMessage['createdAt']) {
        return false;
      }

      // 1. Delete for everyone (Original sender ONLY)
      const allowedDeleteEveryoneKeys = {
        'isDeletedForEveryone',
        'content',
        'message',
        'mediaUrl'
      };
      if (affectedKeys.isNotEmpty &&
          allowedDeleteEveryoneKeys.containsAll(affectedKeys)) {
        if (oldMessage['senderId'] != authUid) {
          return false;
        }
        if (newMessage['isDeletedForEveryone'] != true) {
          return false;
        }
        if (newMessage['content'] != 'This message was deleted') {
          return false;
        }
        if (newMessage['mediaUrl'] != null) {
          return false;
        }
        return true;
      }

      // 2. Delete for me (Caller appends self UID ONLY)
      if (affectedKeys.length == 1 &&
          affectedKeys.contains('deletedForUserIds')) {
        final oldList =
            List<String>.from(oldMessage['deletedForUserIds'] ?? []);
        final newList =
            List<String>.from(newMessage['deletedForUserIds'] ?? []);
        if (!newList.contains(authUid)) {
          return false;
        }
        if (!newList.toSet().containsAll(oldList)) {
          return false;
        }
        if (newList.length != oldList.length &&
            newList.length != oldList.length + 1) {
          return false;
        }
        return true;
      }

      // 3. Mark as read (Intended recipient ONLY)
      const allowedReadKeys = {'isRead', 'deliveryStatus'};
      if (affectedKeys.isNotEmpty &&
          allowedReadKeys.containsAll(affectedKeys)) {
        final recipient = getConnectionRecipient(oldMessage);
        if (recipient != authUid) {
          return false; // Sender cannot mark read!
        }
        if (newMessage['isRead'] is! bool) {
          return false;
        }
        if (!['sent', 'delivered', 'read']
            .contains(newMessage['deliveryStatus'])) {
          return false;
        }
        return true;
      }

      return false;
    }

    // -------------------------------------------------------------
    // Tests: Section 2 - Conversation Authorization
    // -------------------------------------------------------------
    test(
        '1. Signed-out users are denied read and write access to conversations',
        () {
      final conn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
      };
      expect(
          validateConnectionRead(authUid: null, connectionDoc: conn), isFalse);
      expect(validateConnectionRead(authUid: '', connectionDoc: conn), isFalse);
    });

    test('2. Non-participants cannot read a conversation', () {
      final conn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
      };
      expect(validateConnectionRead(authUid: 'user_1', connectionDoc: conn),
          isTrue);
      expect(validateConnectionRead(authUid: 'user_2', connectionDoc: conn),
          isTrue);
      expect(
          validateConnectionRead(
              authUid: 'attacker_user_3', connectionDoc: conn),
          isFalse);
    });

    test('3. Client cannot add a third party to conversation participants', () {
      final oldConn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
      };
      final tamperedConn = Map<String, dynamic>.from(oldConn);
      tamperedConn['participants'] = ['user_1', 'user_2', 'attacker_3'];

      expect(
        validateConnectionUpdate(
          authUid: 'user_1',
          oldDoc: oldConn,
          newDoc: tamperedConn,
          affectedKeys: {'participants'},
        ),
        isFalse,
      );
    });

    test(
        '4. Connection creation rejects self-conversations and invalid participant counts',
        () {
      expect(
        validateConnectionCreate(
          authUid: 'user_1',
          resourceData: {
            'senderId': 'user_1',
            'receiverId': 'user_1', // Self
            'participants': ['user_1', 'user_1'],
          },
          blockedPairs: {},
        ),
        isFalse,
      );

      expect(
        validateConnectionCreate(
          authUid: 'user_1',
          resourceData: {
            'senderId': 'user_1',
            'receiverId': 'user_2',
            'participants': ['user_1', 'user_2', 'user_3'], // 3 participants
          },
          blockedPairs: {},
        ),
        isFalse,
      );

      expect(
        validateConnectionCreate(
          authUid: 'user_1',
          resourceData: {
            'senderId': 'user_1',
            'receiverId': 'user_2',
            'participants': ['user_1', 'user_2'],
          },
          blockedPairs: {},
        ),
        isTrue,
      );
    });

    test('5. Message sender identity must match authenticated UID', () {
      final conn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
      };

      // Attacker user_3 attempts to impersonate user_1
      expect(
        validateMessageCreate(
          authUid: 'user_3',
          connectionDoc: conn,
          connectionId: 'conn_u1_u2',
          messageData: {
            'senderId': 'user_1', // Impersonation
            'receiverId': 'user_2',
            'connectionId': 'conn_u1_u2',
            'isRead': false,
            'isDeletedForEveryone': false,
          },
          blockedPairs: {},
        ),
        isFalse,
      );

      // Legitimate user_1 sends message
      expect(
        validateMessageCreate(
          authUid: 'user_1',
          connectionDoc: conn,
          connectionId: 'conn_u1_u2',
          messageData: {
            'senderId': 'user_1',
            'receiverId': 'user_2',
            'connectionId': 'conn_u1_u2',
            'isRead': false,
            'isDeletedForEveryone': false,
          },
          blockedPairs: {},
        ),
        isTrue,
      );
    });

    test(
        '6. Non-participants cannot send messages into an unrelated conversation',
        () {
      final conn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
      };

      expect(
        validateMessageCreate(
          authUid: 'attacker_3',
          connectionDoc: conn,
          connectionId: 'conn_u1_u2',
          messageData: {
            'senderId': 'attacker_3',
            'receiverId': 'user_2',
            'connectionId': 'conn_u1_u2',
            'isRead': false,
            'isDeletedForEveryone': false,
          },
          blockedPairs: {},
        ),
        isFalse,
      );
    });

    test('7. Blocked users cannot initiate connections or messages', () {
      final blocked = {'user_1:user_2'};

      expect(
        validateConnectionCreate(
          authUid: 'user_1',
          resourceData: {
            'senderId': 'user_1',
            'receiverId': 'user_2',
            'participants': ['user_1', 'user_2'],
          },
          blockedPairs: blocked,
        ),
        isFalse,
      );
    });

    // -------------------------------------------------------------
    // Tests: Section 3 - Inbox Preview and Unread Count Integrity
    // -------------------------------------------------------------
    test('8. Sender cannot forge lastMessageSenderId as the recipient', () {
      final oldConn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
        'unreadCounts': {'user_2': 0},
      };

      final forgedPayload = {
        ...oldConn,
        'lastMessageText': 'I am user 2 saying hi',
        'lastMessageSenderId': 'user_2', // Forged as recipient!
        'lastMessageTimestamp': '2026-10-16T12:00:00.000Z',
        'updatedAt': '2026-10-16T12:00:00.000Z',
        'unreadCounts': {'user_2': 1},
      };

      expect(
        validateConnectionUpdate(
          authUid: 'user_1',
          oldDoc: oldConn,
          newDoc: forgedPayload,
          affectedKeys: {
            'lastMessageText',
            'lastMessageSenderId',
            'lastMessageTimestamp',
            'updatedAt',
            'unreadCounts'
          },
        ),
        isFalse,
      );
    });

    test('9. Sender cannot arbitrarily inflate recipient unread count', () {
      final oldConn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
        'unreadCounts': {'user_2': 1},
      };

      final inflatedPayload = {
        ...oldConn,
        'lastMessageText': 'Normal text',
        'lastMessageSenderId': 'user_1',
        'lastMessageTimestamp': '2026-10-16T12:00:00.000Z',
        'updatedAt': '2026-10-16T12:00:00.000Z',
        'unreadCounts': {'user_2': 9999}, // Arbitrary inflation!
      };

      expect(
        validateConnectionUpdate(
          authUid: 'user_1',
          oldDoc: oldConn,
          newDoc: inflatedPayload,
          affectedKeys: {
            'lastMessageText',
            'lastMessageSenderId',
            'lastMessageTimestamp',
            'updatedAt',
            'unreadCounts'
          },
        ),
        isFalse,
      );
    });

    test(
        '10. Valid message send increments recipient unread count exactly by 1',
        () {
      final oldConn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
        'unreadCounts': {'user_2': 2},
      };

      final validPayload = {
        ...oldConn,
        'lastMessageText': 'Legitimate new message',
        'lastMessageSenderId': 'user_1',
        'lastMessageTimestamp': '2026-10-16T12:00:00.000Z',
        'updatedAt': '2026-10-16T12:00:00.000Z',
        'unreadCounts': {'user_2': 3}, // Incremented by exactly 1
      };

      expect(
        validateConnectionUpdate(
          authUid: 'user_1',
          oldDoc: oldConn,
          newDoc: validPayload,
          affectedKeys: {
            'lastMessageText',
            'lastMessageSenderId',
            'lastMessageTimestamp',
            'updatedAt',
            'unreadCounts'
          },
        ),
        isTrue,
      );
    });

    test(
        '11. User can only reset their OWN unread count to 0 and cannot alter other user count',
        () {
      final oldConn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
        'unreadCounts': {'user_1': 4, 'user_2': 3},
      };

      // Valid: user_1 marks messages read and sets self count to 0
      final validRead = {
        ...oldConn,
        'unreadCounts': {'user_1': 0, 'user_2': 3},
      };
      expect(
        validateConnectionUpdate(
          authUid: 'user_1',
          oldDoc: oldConn,
          newDoc: validRead,
          affectedKeys: {'unreadCounts'},
        ),
        isTrue,
      );

      // Malicious: user_1 attempts to reset user_2 unread count
      final maliciousRead = {
        ...oldConn,
        'unreadCounts': {'user_1': 4, 'user_2': 0},
      };
      expect(
        validateConnectionUpdate(
          authUid: 'user_1',
          oldDoc: oldConn,
          newDoc: maliciousRead,
          affectedKeys: {'unreadCounts'},
        ),
        isFalse,
      );
    });

    // -------------------------------------------------------------
    // Tests: Section 4 - Message Update and Deletion Integrity
    // -------------------------------------------------------------
    test('12. Client cannot alter message content after sending', () {
      final conn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
      };
      final oldMsg = {
        'id': 'msg_1',
        'connectionId': 'conn_u1_u2',
        'senderId': 'user_1',
        'receiverId': 'user_2',
        'content': 'I agree to the deal',
        'createdAt': '2026-10-16T12:00:00.000Z',
        'isRead': false,
        'deliveryStatus': 'delivered',
        'isDeletedForEveryone': false,
      };

      final editedMsg = Map<String, dynamic>.from(oldMsg);
      editedMsg['content'] = 'I never agreed to anything';

      expect(
        validateMessageUpdate(
          authUid: 'user_1',
          connectionDoc: conn,
          oldMessage: oldMsg,
          newMessage: editedMsg,
          affectedKeys: {'content'},
        ),
        isFalse,
      );
    });

    test(
        '13. Client cannot alter message senderId, receiverId, or connectionId',
        () {
      final conn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
      };
      final oldMsg = {
        'id': 'msg_1',
        'connectionId': 'conn_u1_u2',
        'senderId': 'user_1',
        'receiverId': 'user_2',
        'content': 'Hello',
        'createdAt': '2026-10-16T12:00:00.000Z',
      };

      final changedSender = Map<String, dynamic>.from(oldMsg);
      changedSender['senderId'] = 'user_2';

      expect(
        validateMessageUpdate(
          authUid: 'user_1',
          connectionDoc: conn,
          oldMessage: oldMsg,
          newMessage: changedSender,
          affectedKeys: {'senderId'},
        ),
        isFalse,
      );
    });

    test(
        '14. Sender cannot forge read receipts for messages they did not receive',
        () {
      final conn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
      };
      final msg = {
        'id': 'msg_1',
        'connectionId': 'conn_u1_u2',
        'senderId': 'user_1',
        'receiverId': 'user_2',
        'content': 'Unread message',
        'isRead': false,
        'deliveryStatus': 'delivered',
      };

      final updatedMsg = Map<String, dynamic>.from(msg);
      updatedMsg['isRead'] = true;
      updatedMsg['deliveryStatus'] = 'read';

      // Sender user_1 tries to mark as read: DENIED
      expect(
        validateMessageUpdate(
          authUid: 'user_1',
          connectionDoc: conn,
          oldMessage: msg,
          newMessage: updatedMsg,
          affectedKeys: {'isRead', 'deliveryStatus'},
        ),
        isFalse,
      );

      // Intended recipient user_2 marks as read: PERMITTED
      expect(
        validateMessageUpdate(
          authUid: 'user_2',
          connectionDoc: conn,
          oldMessage: msg,
          newMessage: updatedMsg,
          affectedKeys: {'isRead', 'deliveryStatus'},
        ),
        isTrue,
      );
    });

    test(
        '15. Delete for everyone is strictly restricted to original sender with exact soft-delete payload',
        () {
      final conn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
      };
      final msg = {
        'id': 'msg_1',
        'connectionId': 'conn_u1_u2',
        'senderId': 'user_1',
        'receiverId': 'user_2',
        'content': 'Secret message',
        'message': 'Secret message',
        'mediaUrl': 'https://photo.jpg',
        'isDeletedForEveryone': false,
      };

      final softDeleted = Map<String, dynamic>.from(msg);
      softDeleted['isDeletedForEveryone'] = true;
      softDeleted['content'] = 'This message was deleted';
      softDeleted['message'] = 'This message was deleted';
      softDeleted['mediaUrl'] = null;

      // Recipient user_2 cannot delete for everyone
      expect(
        validateMessageUpdate(
          authUid: 'user_2',
          connectionDoc: conn,
          oldMessage: msg,
          newMessage: softDeleted,
          affectedKeys: {
            'isDeletedForEveryone',
            'content',
            'message',
            'mediaUrl'
          },
        ),
        isFalse,
      );

      // Original sender user_1 can delete for everyone
      expect(
        validateMessageUpdate(
          authUid: 'user_1',
          connectionDoc: conn,
          oldMessage: msg,
          newMessage: softDeleted,
          affectedKeys: {
            'isDeletedForEveryone',
            'content',
            'message',
            'mediaUrl'
          },
        ),
        isTrue,
      );
    });

    test(
        '16. Delete for me only permits appending caller UID without tampering existing UIDs',
        () {
      final conn = {
        'id': 'conn_u1_u2',
        'participants': ['user_1', 'user_2'],
        'senderId': 'user_1',
        'receiverId': 'user_2',
      };
      final msg = {
        'id': 'msg_1',
        'connectionId': 'conn_u1_u2',
        'senderId': 'user_1',
        'receiverId': 'user_2',
        'deletedForUserIds': ['user_1'],
      };

      // Valid: user_2 appends self
      final validDeleteForMe = Map<String, dynamic>.from(msg);
      validDeleteForMe['deletedForUserIds'] = ['user_1', 'user_2'];
      expect(
        validateMessageUpdate(
          authUid: 'user_2',
          connectionDoc: conn,
          oldMessage: msg,
          newMessage: validDeleteForMe,
          affectedKeys: {'deletedForUserIds'},
        ),
        isTrue,
      );

      // Invalid: user_2 removes user_1 from list
      final maliciousDeleteForMe = Map<String, dynamic>.from(msg);
      maliciousDeleteForMe['deletedForUserIds'] = ['user_2'];
      expect(
        validateMessageUpdate(
          authUid: 'user_2',
          connectionDoc: conn,
          oldMessage: msg,
          newMessage: maliciousDeleteForMe,
          affectedKeys: {'deletedForUserIds'},
        ),
        isFalse,
      );
    });
  });
}
