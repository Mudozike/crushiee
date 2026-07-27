

enum NotificationType {
  crush,              // Someone Crushed your post
  crushComment,       // Someone commented (Crushed) on your post
  follow,             // Someone followed you
  connectionRequest,  // Someone requested to Connect
  connectionAccepted, // Someone accepted your Connection
  connectionDeclined, // Someone declined your Connection
}

class NotificationModel {
  final String id;
  final String userId;            // Target user receiving notification
  final String fromUserId;        // Sender user ID
  final String fromUsername;
  final String fromUserProfilePic;
  final NotificationType type;
  final String title;
  final String body;
  final String? postId;
  final String? connectionId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.fromUserId,
    required this.fromUsername,
    required this.fromUserProfilePic,
    required this.type,
    required this.title,
    required this.body,
    this.postId,
    this.connectionId,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'fromUserProfilePic': fromUserProfilePic,
      'type': type.name,
      'title': title,
      'body': body,
      'postId': postId,
      'connectionId': connectionId,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      fromUsername: map['fromUsername'] ?? '',
      fromUserProfilePic: map['fromUserProfilePic'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.crush,
      ),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      postId: map['postId'],
      connectionId: map['connectionId'],
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
