import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../models/report_model.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';

class ReportModal {
  static void show({
    required BuildContext context,
    String? reporterId,
    String? reportedUserId,
    required ReportTargetType targetType,
    required String targetId,
    String? targetName,
    String? targetPreview,
  }) {
    final activeReporterId = reporterId ??
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';

    String selectedReason = 'Inappropriate content';
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    final List<String> reasons = [
      'Inappropriate content',
      'Harassment or bullying',
      'Spam or advertising',
      'Scam or fraud',
      'Impersonation / Fake profile',
      'Hate speech or discrimination',
      'Other',
    ];

    String targetLabel;
    switch (targetType) {
      case ReportTargetType.user:
        targetLabel = targetName != null ? '@$targetName' : (targetPreview ?? 'User');
        break;

      case ReportTargetType.post:
        targetLabel = 'Post';
        break;
      case ReportTargetType.comment:
        targetLabel = 'Comment';
        break;
      case ReportTargetType.message:
        targetLabel = 'Message';
        break;
    }


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Report $targetLabel',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Help us keep Crushie safe and authentic. Reports are private and reviewed confidentially.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    labelText: 'Reason for Report',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedReason = val);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Additional details (optional)',
                    hintText: 'Provide any context that helps our team review...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              final report = ReportModel(
                                id: 'report_${DateTime.now().millisecondsSinceEpoch}',
                                reporterId: activeReporterId,
                                reportedUserId: reportedUserId,
                                targetType: targetType,
                                targetId: targetId,
                                reason: selectedReason,
                                explanation: detailsController.text.trim().isNotEmpty
                                    ? detailsController.text.trim()
                                    : null,
                                targetPreview: targetPreview,
                                status: ReportStatus.pending,
                              );


                              try {
                                await FirestoreService().submitReport(report);
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Report submitted. Thank you for keeping Crushie safe.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to submit report: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Submit Report',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
