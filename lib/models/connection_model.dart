import 'package:flutter/material.dart';

enum ConnectionStatus { pending, accepted, declined }

class ConnectionModel {
  final String id;
  final String senderId;
  final String senderUsername;
  final String senderProfilePic;
  final String recipientId;
  final String recipientUsername;
  final String recipientProfilePic;
  final String? postId;
  final ConnectionStatus status;
  final double priceKES; // 50.0 or 0 for premium
  final bool isPremiumFree;
  final String recipientContactMethod; // Revealed on accept
  final String recipientContactDetails; // Revealed on accept
  final DateTime createdAt;
  final DateTime? respondedAt;

  ConnectionModel({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.senderProfilePic,
    required this.recipientId,
    required this.recipientUsername,
    required this.recipientProfilePic,
    this.postId,
    this.status = ConnectionStatus.pending,
    this.priceKES = 50.0,
    this.isPremiumFree = false,
    required this.recipientContactMethod,
    required this.recipientContactDetails,
    DateTime? createdAt,
    this.respondedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'senderProfilePic': senderProfilePic,
      'recipientId': recipientId,
      'recipientUsername': recipientUsername,
      'recipientProfilePic': recipientProfilePic,
      'postId': postId,
      'status': status.name,
      'priceKES': priceKES,
      'isPremiumFree': isPremiumFree,
      'recipientContactMethod': recipientContactMethod,
      'recipientContactDetails': recipientContactDetails,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }

  factory ConnectionModel.fromMap(Map<String, dynamic> map, String id) {
    return ConnectionModel(
      id: id,
      senderId: map['senderId'] ?? '',
      senderUsername: map['senderUsername'] ?? '',
      senderProfilePic: map['senderProfilePic'] ?? '',
      recipientId: map['recipientId'] ?? '',
      recipientUsername: map['recipientUsername'] ?? '',
      recipientProfilePic: map['recipientProfilePic'] ?? '',
      postId: map['postId'],
      status: ConnectionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ConnectionStatus.pending,
      ),
      priceKES: (map['priceKES'] ?? 50.0).toDouble(),
      isPremiumFree: map['isPremiumFree'] ?? false,
      recipientContactMethod: map['recipientContactMethod'] ?? 'WhatsApp',
      recipientContactDetails: map['recipientContactDetails'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      respondedAt: map['respondedAt'] != null
          ? DateTime.tryParse(map['respondedAt'])
          : null,
    );
  }

  ConnectionModel copyWith({
    ConnectionStatus? status,
    DateTime? respondedAt,
  }) {
    return ConnectionModel(
      id: id,
      senderId: senderId,
      senderUsername: senderUsername,
      senderProfilePic: senderProfilePic,
      recipientId: recipientId,
      recipientUsername: recipientUsername,
      recipientProfilePic: recipientProfilePic,
      postId: postId,
      status: status ?? this.status,
      priceKES: priceKES,
      isPremiumFree: isPremiumFree,
      recipientContactMethod: recipientContactMethod,
      recipientContactDetails: recipientContactDetails,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}
