class TransactionModel {
  final String id;
  final String userId;
  final String type; // connection, premium, verified, boost
  final double amount;
  final String currency;
  final String paymentMethod; // mpesa, airtel, card
  final String paymentReference;
  final String status; // completed, pending, failed
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? completedAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.currency = 'KES',
    this.paymentMethod = 'mpesa',
    required this.paymentReference,
    this.status = 'completed',
    this.metadata = const {},
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
      'status': status,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String() ?? createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'KES',
      paymentMethod: map['paymentMethod'] ?? 'mpesa',
      paymentReference: map['paymentReference'] ?? '',
      status: map['status'] ?? 'completed',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'])
          : null,
    );
  }
}
