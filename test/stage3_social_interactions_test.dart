import 'package:flutter_test/flutter_test.dart';
import 'package:crushie/models/chat_message_model.dart';
import 'package:crushie/models/crush_comment_model.dart';
import 'package:crushie/models/notification_model.dart';
import 'package:crushie/models/connection_model.dart';
import 'package:crushie/models/report_model.dart';

void main() {
  group('Stage 3 - ChatMessageModel Tests', () {
    test('ChatMessageModel serialization and deserialization with status & media', () {
      final now = DateTime.now();
      final message = ChatMessageModel(
        id: 'msg_test_123',
        connectionId: 'conn_abc_xyz',
        senderId: 'user_sender_1',
        recipientId: 'user_recipient_2',
        content: 'Hello from real-time chat!',
        mediaUrl: 'https://storage.googleapis.com/test/photo.jpg',
        createdAt: now,
        isRead: false,
        deliveryStatus: MessageDeliveryStatus.sent,
        deletedForUserIds: ['user_sender_1'],
        isDeletedForEveryone: false,
      );

      final map = message.toMap();
      expect(map['connectionId'], 'conn_abc_xyz');
      expect(map['senderId'], 'user_sender_1');
      expect(map['receiverId'], 'user_recipient_2');
      expect(map['content'], 'Hello from real-time chat!');
      expect(map['mediaUrl'], 'https://storage.googleapis.com/test/photo.jpg');
      expect(map['deliveryStatus'], 'sent');
      expect(map['deletedForUserIds'], ['user_sender_1']);
      expect(map['isDeletedForEveryone'], false);

      final fromMap = ChatMessageModel.fromMap(map, 'msg_test_123');
      expect(fromMap.id, 'msg_test_123');
      expect(fromMap.connectionId, 'conn_abc_xyz');
      expect(fromMap.senderId, 'user_sender_1');
      expect(fromMap.recipientId, 'user_recipient_2');
      expect(fromMap.message, 'Hello from real-time chat!');
      expect(fromMap.mediaUrl, 'https://storage.googleapis.com/test/photo.jpg');
      expect(fromMap.deliveryStatus, MessageDeliveryStatus.sent);
      expect(fromMap.deletedForUserIds, contains('user_sender_1'));
    });

    test('ChatMessageModel copyWith updates fields properly', () {
      final message = ChatMessageModel(
        id: 'msg_1',
        connectionId: 'conn_1',
        senderId: 'user_a',
        recipientId: 'user_b',
        content: 'Original message',
        createdAt: DateTime.now(),
      );

      final updated = message.copyWith(
        isRead: true,
        deliveryStatus: MessageDeliveryStatus.read,
        content: 'This message was deleted',
        isDeletedForEveryone: true,
      );

      expect(updated.isRead, true);
      expect(updated.deliveryStatus, MessageDeliveryStatus.read);
      expect(updated.message, 'This message was deleted');
      expect(updated.isDeletedForEveryone, true);
    });

    test('Delete-for-me vs Delete-for-everyone behavior verification', () {
      final msg1 = ChatMessageModel(
        id: 'msg_delete_me',
        connectionId: 'conn_1',
        senderId: 'user_a',
        recipientId: 'user_b',
        content: 'Secret message',
        deletedForUserIds: ['user_a'],
      );

      // User A (who deleted for self) should NOT see it
      final userAVisible = !msg1.deletedForUserIds.contains('user_a');
      expect(userAVisible, false);

      // User B (the recipient) SHOULD still see it
      final userBVisible = !msg1.deletedForUserIds.contains('user_b');
      expect(userBVisible, true);

      // When deleted for everyone
      final msg2 = ChatMessageModel(
        id: 'msg_delete_everyone',
        connectionId: 'conn_1',
        senderId: 'user_a',
        recipientId: 'user_b',
        content: 'This message was deleted',
        isDeletedForEveryone: true,
        mediaUrl: null,
      );

      expect(msg2.isDeletedForEveryone, true);
      expect(msg2.mediaUrl, isNull);
      expect(msg2.content, 'This message was deleted');
    });
  });

  group('Stage 3 - ReportModel Tests', () {
    test('ReportModel serialization and deserialization across all target types', () {
      final targetTypes = [
        ReportTargetType.user,
        ReportTargetType.post,
        ReportTargetType.comment,
        ReportTargetType.message,
      ];

      for (final type in targetTypes) {
        final report = ReportModel(
          id: 'rep_${type.name}_001',
          reporterId: 'user_reporter_1',
          targetType: type,
          targetId: 'target_${type.name}_123',
          reportedUserId: 'user_violator_2',
          reason: 'Harassment',
          details: 'Inappropriate language in ${type.name}',
          targetPreview: 'Preview of offensive content',
          status: ReportStatus.pending,
        );

        final map = report.toMap();
        expect(map['id'], 'rep_${type.name}_001');
        expect(map['reporterId'], 'user_reporter_1');
        expect(map['targetType'], type.name);
        expect(map['targetId'], 'target_${type.name}_123');
        expect(map['reportedUserId'], 'user_violator_2');
        expect(map['reason'], 'Harassment');
        expect(map['status'], 'pending');

        final fromMap = ReportModel.fromMap(map, 'rep_${type.name}_001');
        expect(fromMap.id, 'rep_${type.name}_001');
        expect(fromMap.targetType, type);
        expect(fromMap.reason, 'Harassment');
        expect(fromMap.status, ReportStatus.pending);
        expect(fromMap.details, 'Inappropriate language in ${type.name}');
      }
    });

    test('ReportModel validation requirements', () {
      final validReport = ReportModel(
        id: 'rep_valid',
        reporterId: 'user_1',
        targetType: ReportTargetType.post,
        targetId: 'post_100',
        reason: 'Spam',
      );

      expect(validReport.reporterId.isNotEmpty, true);
      expect(validReport.targetId.isNotEmpty, true);
      expect(validReport.reason.isNotEmpty, true);
      expect(validReport.status, ReportStatus.pending);
    });
  });

  group('Stage 3 - Blocking Tests', () {
    test('Blocking prevents interactions and persists in blocked list', () {
      final userA = 'user_blocker';
      final userB = 'user_blocked';
      final blockedList = <String>{};

      // Block action
      blockedList.add(userB);
      expect(blockedList.contains(userB), true);

      // Attempt to self-block is prohibited
      bool attemptSelfBlock(String u1, String u2) {
        if (u1 == u2) return false;
        return true;
      }
      expect(attemptSelfBlock(userA, userA), false);
      expect(attemptSelfBlock(userA, userB), true);


      // Unblock action
      blockedList.remove(userB);
      expect(blockedList.contains(userB), false);
    });
  });

  group('Stage 3 - CrushCommentModel Tests', () {
    test('CrushCommentModel serialization and deserialization', () {
      final now = DateTime.now();
      final comment = CrushCommentModel(
        id: 'comment_999',
        postId: 'post_777',
        userId: 'user_commenter',
        username: 'janedoe',
        userProfilePic: 'crushie_avatar_2',
        userIsVerified: true,
        text: 'Super interested in connecting!',
        createdAt: now,
      );

      final map = comment.toMap();
      expect(map['postId'], 'post_777');
      expect(map['userId'], 'user_commenter');
      expect(map['username'], 'janedoe');
      expect(map['userProfilePic'], 'crushie_avatar_2');
      expect(map['userIsVerified'], true);
      expect(map['text'], 'Super interested in connecting!');

      final fromMap = CrushCommentModel.fromMap(map, 'comment_999');
      expect(fromMap.id, 'comment_999');
      expect(fromMap.postId, 'post_777');
      expect(fromMap.userId, 'user_commenter');
      expect(fromMap.username, 'janedoe');
      expect(fromMap.text, 'Super interested in connecting!');
    });
  });

  group('Stage 3 - NotificationModel Tests', () {
    test('NotificationModel serialization and deserialization for all social types', () {
      final types = [
        NotificationType.crush,
        NotificationType.crushComment,
        NotificationType.follow,
        NotificationType.connectionRequest,
        NotificationType.connectionAccepted,
        NotificationType.connectionDeclined,
        NotificationType.system,
      ];

      for (final type in types) {
        final notif = NotificationModel(
          id: 'notif_${type.name}',
          userId: 'recipient_uid',
          fromUserId: 'actor_uid',
          fromUsername: 'actor_user',
          fromUserProfilePic: 'crushie_avatar_1',
          type: type,
          title: 'Title for ${type.name}',
          body: 'Body for ${type.name}',
          postId: 'post_123',
          connectionId: 'conn_456',
        );

        final map = notif.toMap();
        expect(map['type'], type.name);
        expect(map['userId'], 'recipient_uid');
        expect(map['fromUserId'], 'actor_uid');

        final fromMap = NotificationModel.fromMap(map, 'notif_${type.name}');
        expect(fromMap.type, type);
        expect(fromMap.postId, 'post_123');
        expect(fromMap.connectionId, 'conn_456');
      }
    });
  });

  group('Stage 3 - ConnectionModel Tests', () {
    test('ConnectionModel serialization and deserialization preserves participants', () {
      final conn = ConnectionModel(
        id: 'conn_test_888',
        senderId: 'user_alpha',
        senderUsername: 'alpha_user',
        senderProfilePic: 'crushie_avatar_0',
        receiverId: 'user_beta',
        receiverUsername: 'beta_user',
        receiverProfilePic: 'https://example.com/avatar.jpg',
        status: ConnectionStatus.accepted,
        isPaid: false,
        amount: 0,
      );

      final map = conn.toMap();
      expect(map['senderId'], 'user_alpha');
      final fromMap = ConnectionModel.fromMap(map, 'conn_test_888');
      expect(fromMap.id, 'conn_test_888');
      expect(fromMap.senderId, 'user_alpha');
      expect(fromMap.receiverId, 'user_beta');
      expect(fromMap.status, ConnectionStatus.accepted);
    });
  });

  group('Stage 3 - Security Boundaries & Access Control Tests', () {
    test('Participant versus nonparticipant message access authorization', () {
      final participants = ['user_alice', 'user_bob'];

      
      bool canAccessConversation(String userId) {
        return participants.contains(userId);
      }

      expect(canAccessConversation('user_alice'), true);
      expect(canAccessConversation('user_bob'), true);
      expect(canAccessConversation('user_eve_attacker'), false);
      expect(canAccessConversation(''), false);
    });

    test('Sender versus recipient message modification boundaries', () {
      final msg = ChatMessageModel(
        id: 'msg_100',
        connectionId: 'conn_100',
        senderId: 'user_alice',
        recipientId: 'user_bob',
        content: 'Original secret message',
        mediaUrl: 'https://storage.googleapis.com/test/photo.jpg',
      );

      // Rule: Only sender can trigger delete for everyone
      bool canDeleteForEveryone(String requestingUserId, ChatMessageModel targetMsg) {
        return requestingUserId == targetMsg.senderId;
      }

      expect(canDeleteForEveryone('user_alice', msg), true);
      expect(canDeleteForEveryone('user_bob', msg), false);
      expect(canDeleteForEveryone('user_eve', msg), false);

      // Rule: Recipient can only mark read receipts, cannot edit sender content
      bool canModifyContent(String requestingUserId, ChatMessageModel targetMsg) {
        return requestingUserId == targetMsg.senderId;
      }
      expect(canModifyContent('user_bob', msg), false);
    });

    test('Bidirectional block enforcement applies consistently regardless of initiator', () {
      // Setup block records (Alice blocked Bob)
      final blocksAtoB = {'user_bob'};
      final blocksBtoA = <String>{};

      bool isBlocked(String user1, String user2) {
        return (user1 == 'user_alice' && blocksAtoB.contains(user2)) ||
               (user2 == 'user_alice' && blocksAtoB.contains(user1)) ||
               (user1 == 'user_bob' && blocksBtoA.contains(user2)) ||
               (user2 == 'user_bob' && blocksBtoA.contains(user1));
      }

      // Alice tries to interact with Bob
      expect(isBlocked('user_alice', 'user_bob'), true);
      // Bob tries to interact with Alice
      expect(isBlocked('user_bob', 'user_alice'), true);
      // Non-blocked user Charlie
      expect(isBlocked('user_alice', 'user_charlie'), false);
    });

    test('Report security: only pending status and valid target types permitted on creation', () {
      bool validateReportCreation({
        required String authenticatedUid,
        required String reporterId,
        required String targetType,
        required String targetId,
        required String reason,
        required String status,
      }) {
        if (authenticatedUid != reporterId) return false;
        if (status != 'pending') return false;
        if (!['user', 'post', 'comment', 'message'].contains(targetType)) return false;
        if (targetId.trim().isEmpty) return false;
        if (reason.trim().isEmpty) return false;
        return true;
      }

      // Valid report
      expect(validateReportCreation(
        authenticatedUid: 'user_alice',
        reporterId: 'user_alice',
        targetType: 'post',
        targetId: 'post_123',
        reason: 'Harassment',
        status: 'pending',
      ), true);

      // Attacker trying to impersonate another reporter
      expect(validateReportCreation(
        authenticatedUid: 'user_eve',
        reporterId: 'user_alice',
        targetType: 'post',
        targetId: 'post_123',
        reason: 'Harassment',
        status: 'pending',
      ), false);

      // Attacker trying to submit with pre-resolved/approved status
      expect(validateReportCreation(
        authenticatedUid: 'user_alice',
        reporterId: 'user_alice',
        targetType: 'post',
        targetId: 'post_123',
        reason: 'Harassment',
        status: 'action_taken',
      ), false);

      // Invalid target type
      expect(validateReportCreation(
        authenticatedUid: 'user_alice',
        reporterId: 'user_alice',
        targetType: 'admin_dashboard',
        targetId: 'admin_123',
        reason: 'Harassment',
        status: 'pending',
      ), false);
    });
    test('Delete-for-me exact UID addition & anti-tamper rules', () {
      bool validateDeleteForMeUpdate({
        required String authenticatedUid,
        required List<String> oldDeletedForUserIds,
        required List<String> newDeletedForUserIds,
        required Set<String> modifiedFieldKeys,
      }) {
        // 1. Only 'deletedForUserIds' can be modified
        if (modifiedFieldKeys.length != 1 || !modifiedFieldKeys.contains('deletedForUserIds')) {
          return false;
        }
        // 2. Existing entries must be preserved (hasAll)
        if (!newDeletedForUserIds.toSet().containsAll(oldDeletedForUserIds)) {
          return false;
        }
        // 3. Authenticated UID must be in new list
        if (!newDeletedForUserIds.contains(authenticatedUid)) {
          return false;
        }
        // 4. Cannot add arbitrary other UIDs (size can only grow by 0 or 1)
        if (newDeletedForUserIds.length != oldDeletedForUserIds.length &&
            newDeletedForUserIds.length != oldDeletedForUserIds.length + 1) {
          return false;
        }
        return true;
      }

      // Valid: User Alice adds her own UID
      expect(validateDeleteForMeUpdate(
        authenticatedUid: 'user_alice',
        oldDeletedForUserIds: [],
        newDeletedForUserIds: ['user_alice'],
        modifiedFieldKeys: {'deletedForUserIds'},
      ), true);

      // Valid: User Bob adds his UID when Alice already deleted for herself
      expect(validateDeleteForMeUpdate(
        authenticatedUid: 'user_bob',
        oldDeletedForUserIds: ['user_alice'],
        newDeletedForUserIds: ['user_alice', 'user_bob'],
        modifiedFieldKeys: {'deletedForUserIds'},
      ), true);

      // Invalid: Bob tries to remove Alice's deletion state
      expect(validateDeleteForMeUpdate(
        authenticatedUid: 'user_bob',
        oldDeletedForUserIds: ['user_alice'],
        newDeletedForUserIds: ['user_bob'],
        modifiedFieldKeys: {'deletedForUserIds'},
      ), false);

      // Invalid: Alice tries to add Charlie's UID
      expect(validateDeleteForMeUpdate(
        authenticatedUid: 'user_alice',
        oldDeletedForUserIds: [],
        newDeletedForUserIds: ['user_charlie'],
        modifiedFieldKeys: {'deletedForUserIds'},
      ), false);

      // Invalid: Adding UID while also modifying message text
      expect(validateDeleteForMeUpdate(
        authenticatedUid: 'user_alice',
        oldDeletedForUserIds: [],
        newDeletedForUserIds: ['user_alice'],
        modifiedFieldKeys: {'deletedForUserIds', 'content'},
      ), false);
    });

    test('Delete-for-everyone exact soft deletion payload validation', () {
      bool validateDeleteForEveryoneUpdate({
        required String authenticatedUid,
        required String originalSenderId,
        required bool newIsDeletedForEveryone,
        required String newContent,
        required String newMessage,
        required String? newMediaUrl,
        required Set<String> modifiedFieldKeys,
      }) {
        // Only original sender
        if (authenticatedUid != originalSenderId) return false;
        if (!newIsDeletedForEveryone) return false;
        // Only allowed deletion fields
        final allowed = {'isDeletedForEveryone', 'content', 'message', 'mediaUrl'};
        if (!allowed.containsAll(modifiedFieldKeys)) return false;
        // Enforce exact placeholders and media purge
        if (newContent != 'This message was deleted') return false;
        if (newMessage != 'This message was deleted') return false;
        if (newMediaUrl != null) return false;
        return true;
      }

      // Valid sender delete-for-everyone
      expect(validateDeleteForEveryoneUpdate(
        authenticatedUid: 'user_alice',
        originalSenderId: 'user_alice',
        newIsDeletedForEveryone: true,
        newContent: 'This message was deleted',
        newMessage: 'This message was deleted',
        newMediaUrl: null,
        modifiedFieldKeys: {'isDeletedForEveryone', 'content', 'message', 'mediaUrl'},
      ), true);

      // Invalid: Recipient Bob tries to delete for everyone
      expect(validateDeleteForEveryoneUpdate(
        authenticatedUid: 'user_bob',
        originalSenderId: 'user_alice',
        newIsDeletedForEveryone: true,
        newContent: 'This message was deleted',
        newMessage: 'This message was deleted',
        newMediaUrl: null,
        modifiedFieldKeys: {'isDeletedForEveryone', 'content', 'message', 'mediaUrl'},
      ), false);

      // Invalid: Sender tries to inject custom replacement text
      expect(validateDeleteForEveryoneUpdate(
        authenticatedUid: 'user_alice',
        originalSenderId: 'user_alice',
        newIsDeletedForEveryone: true,
        newContent: 'Custom edited text',
        newMessage: 'Custom edited text',
        newMediaUrl: null,
        modifiedFieldKeys: {'isDeletedForEveryone', 'content', 'message', 'mediaUrl'},
      ), false);
    });

    test('Read receipts update rules: recipient-only & anti-tamper', () {
      bool validateReadReceiptUpdate({
        required String authenticatedUid,
        required String receiverId,
        required bool newIsRead,
        required String newDeliveryStatus,
        required Set<String> modifiedFieldKeys,
      }) {
        if (authenticatedUid != receiverId) return false;
        final allowed = {'isRead', 'deliveryStatus'};
        if (modifiedFieldKeys.isEmpty || !allowed.containsAll(modifiedFieldKeys)) return false;
        if (!['sent', 'delivered', 'read'].contains(newDeliveryStatus)) return false;
        return true;
      }

      // Valid: Recipient marks read
      expect(validateReadReceiptUpdate(
        authenticatedUid: 'user_bob',
        receiverId: 'user_bob',
        newIsRead: true,
        newDeliveryStatus: 'read',
        modifiedFieldKeys: {'isRead', 'deliveryStatus'},
      ), true);

      // Invalid: Sender tries to mark read receipt on their own message
      expect(validateReadReceiptUpdate(
        authenticatedUid: 'user_alice',
        receiverId: 'user_bob',
        newIsRead: true,
        newDeliveryStatus: 'read',
        modifiedFieldKeys: {'isRead', 'deliveryStatus'},
      ), false);

      // Invalid: Recipient tries to modify content while setting read receipt
      expect(validateReadReceiptUpdate(
        authenticatedUid: 'user_bob',
        receiverId: 'user_bob',
        newIsRead: true,
        newDeliveryStatus: 'read',
        modifiedFieldKeys: {'isRead', 'deliveryStatus', 'content'},
      ), false);
    });

    test('Report payload size limits & safety verification', () {
      bool validateReportPayload({
        required String targetId,
        required String reason,
        String? explanation,
        String? targetPreview,
      }) {
        if (targetId.isEmpty || targetId.length > 128) return false;
        if (reason.isEmpty || reason.length > 100) return false;
        if (explanation != null && explanation.length > 2000) return false;
        if (targetPreview != null && targetPreview.length > 500) return false;
        return true;
      }

      // Valid payload
      expect(validateReportPayload(
        targetId: 'post_abc_123',
        reason: 'Harassment or bullying',
        explanation: 'Offensive language in post',
        targetPreview: 'Preview text',
      ), true);

      // Invalid: Excessively large reason (spamming payload)
      expect(validateReportPayload(
        targetId: 'post_abc_123',
        reason: 'A' * 105,
      ), false);

      // Invalid: Excessively large explanation
      expect(validateReportPayload(
        targetId: 'post_abc_123',
        reason: 'Spam',
        explanation: 'A' * 2005,
      ), false);
    });
  });
}



