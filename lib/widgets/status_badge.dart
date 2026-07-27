import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final bool isOnline;
  final DateTime lastSeen;
  final bool showText;
  final double dotSize;

  const StatusBadge({
    Key? key,
    required this.isOnline,
    required this.lastSeen,
    this.showText = true,
    this.dotSize = 10.0,
  }) : super(key: key);

  String get _statusText {
    if (isOnline) return 'Online';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last seen yesterday';
    return 'Last seen ${diff.inDays}d ago';
  }

  Color get _statusColor {
    if (isOnline) return AppColors.online;
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inHours < 24) return AppColors.activeToday;
    return AppColors.offline;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: _statusColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.darkCard : Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              if (isOnline)
                BoxShadow(
                  color: AppColors.online.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 6),
          Text(
            _statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
