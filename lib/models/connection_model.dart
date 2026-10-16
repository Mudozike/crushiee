enum ConnectionStatus { pending, accepted, declined }

class ConnectionModel {
  final String id;
  final String senderId;
  final String senderUsername;
  final String senderProfilePic;
  final String receiverId;
  final String receiverUsername;
  final String receiverProfilePic;
  final String? postId;
  final bool isPaid;
  final int amount;
  final ConnectionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> participants;
  final String? lastMessageText;
  final DateTime? lastMessageTimestamp;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCounts;

  /// Generates a deterministic, order-independent canonical conversation ID from two Firebase UIDs.
  static String getConversationId(String uid1, String uid2) {
    final u1 = uid1.trim();
    final u2 = uid2.trim();
    if (u1.isEmpty || u2.isEmpty) {
      throw ArgumentError('Participant UIDs must not be empty');
    }
    if (u1 == u2) {
      throw ArgumentError('Cannot create conversation with self');
    }
    final sorted = [u1, u2]..sort();
    return 'conn_${sorted[0]}_${sorted[1]}';
  }

  /// Checks if a conversation ID uses a legacy timestamp-based format (e.g. conn_1729000000000).
  static bool isLegacyConversationId(String id) {
    return RegExp(r'^conn_\d+$').hasMatch(id);
  }

  // Backward compatibility getters
  String get recipientId => receiverId;
  String get recipientUsername => receiverUsername;
  String get recipientProfilePic => receiverProfilePic;
  double get priceKES => amount.toDouble();
  bool get isPremiumFree => !isPaid;
  String get recipientContactMethod => 'WhatsApp';
  String get recipientContactDetails => '';

  int unreadCountForUser(String userId) => unreadCounts[userId] ?? 0;

  ConnectionModel({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.senderProfilePic,
    String? receiverId,
    String? recipientId,
    String? receiverUsername,
    String? recipientUsername,
    String? receiverProfilePic,
    String? recipientProfilePic,
    String? recipientContactMethod,
    String? recipientContactDetails,
    this.postId,
    bool isPaid = false,
    bool? isPremiumFree,
    int amount = 0,
    num? priceKES,
    this.status = ConnectionStatus.accepted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? respondedAt,
    List<String>? participants,
    this.lastMessageText,
    this.lastMessageTimestamp,
    this.lastMessageSenderId,
    this.unreadCounts = const {},
  })  : receiverId = receiverId ?? recipientId ?? '',
        receiverUsername = receiverUsername ?? recipientUsername ?? '',
        receiverProfilePic = receiverProfilePic ?? recipientProfilePic ?? '',
        isPaid = isPremiumFree != null ? !isPremiumFree : isPaid,
        amount = priceKES != null ? priceKES.toInt() : amount,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? respondedAt ?? DateTime.now(),
        participants =
            participants ?? [senderId, receiverId ?? recipientId ?? ''];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'senderProfilePic': senderProfilePic,
      'receiverId': receiverId,
      'receiverUsername': receiverUsername,
      'receiverProfilePic': receiverProfilePic,
      // Backward compatibility fields in Firestore
      'recipientId': receiverId,
      'recipientUsername': receiverUsername,
      'recipientProfilePic': receiverProfilePic,
      'postId': postId,
      'isPaid': isPaid,
      'amount': amount,
      'status': status.name,
      'participants': participants,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastMessageText': lastMessageText,
      'lastMessageTimestamp': lastMessageTimestamp?.toIso8601String(),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCounts': unreadCounts,
    };
  }

  factory ConnectionModel.fromMap(Map<String, dynamic> map, String id) {
    final sender = map['senderId'] ?? '';
    final receiver = map['receiverId'] ?? map['recipientId'] ?? '';
    final created = map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
        : DateTime.now();

    final lastMsgTime = map['lastMessageTimestamp'] != null
        ? DateTime.tryParse(map['lastMessageTimestamp'])
        : null;

    Map<String, int> unreads = {};
    if (map['unreadCounts'] is Map) {
      (map['unreadCounts'] as Map).forEach((k, v) {
        if (v is num) {
          unreads[k.toString()] = v.toInt();
        }
      });
    }

    return ConnectionModel(
      id: id,
      senderId: sender,
      senderUsername: map['senderUsername'] ?? '',
      senderProfilePic: map['senderProfilePic'] ?? '',
      receiverId: receiver,
      receiverUsername:
          map['receiverUsername'] ?? map['recipientUsername'] ?? '',
      receiverProfilePic:
          map['receiverProfilePic'] ?? map['recipientProfilePic'] ?? '',
      postId: map['postId'],
      isPaid: map['isPaid'] ?? false,
      amount: map['amount'] ??
          (map['priceKES'] != null ? (map['priceKES'] as num).toInt() : 0),
      status: ConnectionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ConnectionStatus.accepted,
      ),
      createdAt: created,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? created
          : created,
      participants:
          List<String>.from(map['participants'] ?? [sender, receiver]),
      lastMessageText: map['lastMessageText'] as String?,
      lastMessageTimestamp: lastMsgTime,
      lastMessageSenderId: map['lastMessageSenderId'] as String?,
      unreadCounts: unreads,
    );
  }

  ConnectionModel copyWith({
    ConnectionStatus? status,
    bool? isPaid,
    int? amount,
    DateTime? updatedAt,
    DateTime? respondedAt,
    String? lastMessageText,
    DateTime? lastMessageTimestamp,
    String? lastMessageSenderId,
    Map<String, int>? unreadCounts,
  }) {
    return ConnectionModel(
      id: id,
      senderId: senderId,
      senderUsername: senderUsername,
      senderProfilePic: senderProfilePic,
      receiverId: receiverId,
      receiverUsername: receiverUsername,
      receiverProfilePic: receiverProfilePic,
      postId: postId,
      isPaid: isPaid ?? this.isPaid,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? respondedAt ?? DateTime.now(),
      participants: participants,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCounts: unreadCounts ?? this.unreadCounts,
    );
  }
}
