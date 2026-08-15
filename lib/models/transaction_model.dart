class TransactionModel {
  final String id;
  final String userId;
  final String type; // connection, premium, verification, bundle, boost
  final double amount;
  final String paymentReference;
  final String status; // success, failed
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.paymentReference,
    required this.status,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'amount': amount,
      'paymentReference': paymentReference,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentReference: map['paymentReference'] ?? '',
      status: map['status'] ?? 'success',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
