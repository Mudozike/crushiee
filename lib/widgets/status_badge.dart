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
    this.dotSize = 8.0,
  }) : super(key: key);

  String get _statusText {
    if (isOnline) return 'Online';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last seen yesterday';
    return 'Last seen ${diff.inDays}d ago';
  }

  Color get _statusColor {
    if (isOnline) return AppColors.online;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOnline) ...[
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
            ),
          ),
          if (showText) const SizedBox(width: 5),
        ],
        if (showText)
          Text(
            _statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
              color: isOnline
                  ? (isDark ? Colors.white70 : Colors.black87)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
      ],
    );
  }
}
