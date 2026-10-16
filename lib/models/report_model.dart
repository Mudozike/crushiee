enum ReportTargetType { user, post, comment, message }

enum ReportStatus { pending, reviewed, dismissed, action_taken }

class ReportModel {
  final String id;
  final String reporterId;
  final String? reportedUserId;
  final ReportTargetType targetType;
  final String targetId;
  final String reason;
  final String? explanation;
  final String? targetPreview;
  final DateTime createdAt;
  final ReportStatus status;

  String? get details => explanation;

  ReportModel({
    required this.id,
    required this.reporterId,
    this.reportedUserId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    String? explanation,
    String? details,
    this.targetPreview,
    DateTime? createdAt,
    this.status = ReportStatus.pending,
  })  : explanation = explanation ?? details,
        createdAt = createdAt ?? DateTime.now();



  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'targetType': targetType.name,
      'targetId': targetId,
      'reason': reason,
      'explanation': explanation,
      'targetPreview': targetPreview,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    return ReportModel(
      id: id,
      reporterId: map['reporterId'] ?? '',
      reportedUserId: map['reportedUserId'],
      targetType: ReportTargetType.values.firstWhere(
        (e) => e.name == map['targetType'],
        orElse: () => ReportTargetType.user,
      ),
      targetId: map['targetId'] ?? '',
      reason: map['reason'] ?? 'Other',
      explanation: map['explanation'] ?? map['details'],
      targetPreview: map['targetPreview'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      status: ReportStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReportStatus.pending,
      ),
    );
  }
}

