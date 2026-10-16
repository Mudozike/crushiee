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
      'createdAt': createdAt.toIso8601String(),
      'timestamp': createdAt.toIso8601String(),
      'isRead': isRead,
      'deliveryStatus': deliveryStatus.name,
      'isDeletedForEveryone': isDeletedForEveryone,
      'deletedForUserIds': deletedForUserIds,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String id) {
    final created = map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt'])
        : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp']) : DateTime.now());

    return ChatMessageModel(
      id: id,
      connectionId: map['connectionId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? map['recipientId'] ?? '',
      content: map['content'] ?? map['message'] ?? '',
      mediaUrl: map['mediaUrl'],
      createdAt: created ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      deliveryStatus: MessageDeliveryStatus.values.firstWhere(
        (e) => e.name == map['deliveryStatus'],
        orElse: () => map['isRead'] == true ? MessageDeliveryStatus.read : MessageDeliveryStatus.delivered,
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
