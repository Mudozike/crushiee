import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum MessageDeliveryStatus { sent, delivered, read }

class ChatMessageModel {
  final String id;
  final String connectionId;
  final String senderId;
  final String receiverId;
  final String content;
  final String? mediaUrl;
  final DateTime createdAt;
  final bool isRead;
  final MessageDeliveryStatus deliveryStatus;
  final bool isDeletedForEveryone;
  final List<String> deletedForUserIds;

  // Backward compatibility getters
  String get recipientId => receiverId;
  String get message => content;
  DateTime get timestamp => createdAt;

  ChatMessageModel({
    required this.id,
    required this.connectionId,
    required this.senderId,
    String? receiverId,
    String? recipientId,
    String? content,
    String? message,
    this.mediaUrl,
    DateTime? createdAt,
    DateTime? timestamp,
    this.isRead = false,
    MessageDeliveryStatus? deliveryStatus,
    this.isDeletedForEveryone = false,
    this.deletedForUserIds = const [],
  })  : receiverId = receiverId ?? recipientId ?? '',
        content = content ?? message ?? '',
        createdAt = createdAt ?? timestamp ?? DateTime.now(),
        deliveryStatus = deliveryStatus ?? (isRead ? MessageDeliveryStatus.read : MessageDeliveryStatus.delivered);

  /// Generates a collision-resistant message ID combining millisecond epoch and UUID entropy.
  static String generateMessageId() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final entropy = const Uuid().v4().replaceAll('-', '').substring(0, 8);
    return 'msg_${millis}_$entropy';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'connectionId': connectionId,
      'senderId': senderId,
      'receiverId': receiverId,
      'recipientId': receiverId,
      'content': content,
      'message': content,
      'mediaUrl': mediaUrl,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'timestamp': createdAt.toUtc().toIso8601String(),
      'isRead': isRead,
      'deliveryStatus': deliveryStatus.name,
      'isDeletedForEveryone': isDeletedForEveryone,
      'deletedForUserIds': deletedForUserIds,
    };
  }

  /// Resilient timestamp parser supporting Firestore Timestamp, DateTime,
  /// ISO-8601 Strings, integer epochs, and deterministic fallbacks.
  static DateTime parseTimestamp(dynamic raw, {DateTime? fallback}) {
    if (raw == null) return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();

    // Duck-typing support for Timestamp wrappers or mocks across environments
    try {
      if (raw.runtimeType.toString().contains('Timestamp')) {
        return (raw as dynamic).toDate() as DateTime;
      }
    } catch (_) {}

    if (raw is int) {
      if (raw < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }

    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
      final asInt = int.tryParse(raw);
      if (asInt != null) {
        if (asInt < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
        }
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
    }

    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Deterministic fallback timestamp extracted from a message ID if present.
  /// Supports both legacy msg_${millis} and new collision-resistant msg_${millis}_${entropy}.
  static DateTime? fallbackTimestamp(String id) {
    if (id.startsWith('msg_')) {
      final remainder = id.substring(4);
      final parts = remainder.split('_');
      final epochPart = int.tryParse(parts.first);
      if (epochPart != null) {
        if (epochPart < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(epochPart * 1000);
        }
        return DateTime.fromMillisecondsSinceEpoch(epochPart);
      }
    }
    return null;
  }

  factory ChatMessageModel.fromMap(
    Map<String, dynamic> map,
    String id, {
    /// Supplied by the caller with the Firestore parent collection path
    /// (connections/{connectionId}) so that legacy documents that omit the
    /// `connectionId` field are still associated with the correct conversation.
    /// Ignored when the document itself carries a non-empty `connectionId`.
    String? connectionIdFallback,
  }) {
    // Deterministic fallback from ID if id contains epoch
    final idFallback = fallbackTimestamp(id);

    // Prioritize serverTimestamp if present, falling back to timestamp or createdAt
    dynamic rawTime = map['serverTimestamp'] ?? map['timestamp'];
    if (rawTime == null || (rawTime is String && rawTime.trim().isEmpty)) {
      rawTime = map['createdAt'];
    }
    final created = parseTimestamp(rawTime, fallback: idFallback);

    // Phase 1A: prefer the in-document connectionId; only fall back to the
    // parent-path value when the document field is absent or empty.  Never
    // silently accept a conflicting non-empty value from the document.
    final docConnectionId = (map['connectionId'] as String?) ?? '';
    final resolvedConnectionId = docConnectionId.isNotEmpty
        ? docConnectionId
        : (connectionIdFallback ?? '');

    return ChatMessageModel(
      id: id,
      connectionId: resolvedConnectionId,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? map['recipientId'] ?? '',
      content: map['content'] ?? map['message'] ?? '',
      mediaUrl: map['mediaUrl'],
      createdAt: created,
      // Phase 1D backward-compat policy for missing isRead:
      //   - null / absent  -> false (treat as unread; safe conservative default)
      //   - explicit bool  -> use as-is
      // We do NOT auto-mark historical messages as read because doing so would
      // suppress legitimate unread badge counts for recipients who never opened
      // the conversation on the current device.
      isRead: map['isRead'] == true,
      deliveryStatus: MessageDeliveryStatus.values.firstWhere(
        (e) => e.name == (map['deliveryStatus'] as String? ?? ''),
        orElse: () => map['isRead'] == true
            ? MessageDeliveryStatus.read
            : MessageDeliveryStatus.delivered,
      ),
      isDeletedForEveryone: map['isDeletedForEveryone'] ?? false,
      deletedForUserIds: List<String>.from(map['deletedForUserIds'] ?? []),
    );
  }

  ChatMessageModel copyWith({
    String? content,
    String? mediaUrl,
    bool? isRead,
    MessageDeliveryStatus? deliveryStatus,
    bool? isDeletedForEveryone,
    List<String>? deletedForUserIds,
  }) {
    return ChatMessageModel(
      id: id,
      connectionId: connectionId,
      senderId: senderId,
      receiverId: receiverId,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      deletedForUserIds: deletedForUserIds ?? this.deletedForUserIds,
    );
  }
}
