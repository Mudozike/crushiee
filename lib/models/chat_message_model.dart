enum MessageDeliveryStatus { sent, delivered, read }

class ChatMessageModel {
  final String id;
  final String connectionId;
  final String senderId;
  final String recipientId;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final MessageDeliveryStatus deliveryStatus;
  final bool isDeletedForEveryone;
  final List<String> deletedForUserIds;

  ChatMessageModel({
    required this.id,
    required this.connectionId,
    required this.senderId,
    required this.recipientId,
    required this.message,
    DateTime? timestamp,
    this.isRead = false,
    MessageDeliveryStatus? deliveryStatus,
    this.isDeletedForEveryone = false,
    this.deletedForUserIds = const [],
  })  : timestamp = timestamp ?? DateTime.now(),
        deliveryStatus = deliveryStatus ?? (isRead ? MessageDeliveryStatus.read : MessageDeliveryStatus.delivered);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'connectionId': connectionId,
      'senderId': senderId,
      'recipientId': recipientId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'deliveryStatus': deliveryStatus.name,
      'isDeletedForEveryone': isDeletedForEveryone,
      'deletedForUserIds': deletedForUserIds,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessageModel(
      id: id,
      connectionId: map['connectionId'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
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
    String? message,
    bool? isRead,
    MessageDeliveryStatus? deliveryStatus,
    bool? isDeletedForEveryone,
    List<String>? deletedForUserIds,
  }) {
    return ChatMessageModel(
      id: id,
      connectionId: connectionId,
      senderId: senderId,
      recipientId: recipientId,
      message: message ?? this.message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      deletedForUserIds: deletedForUserIds ?? this.deletedForUserIds,
    );
  }
}
