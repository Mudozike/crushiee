import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final bool isOnline;
  final DateTime? lastSeen;
  final bool showText;
  final double dotSize;

  const StatusBadge({
    Key? key,
    required this.isOnline,
    this.lastSeen,
    this.showText = true,
    this.dotSize = 8.0,
  }) : super(key: key);

  static bool isEffectiveOnline(bool isOnline, DateTime? lastSeen,
      {DateTime? now}) {
    if (!isOnline) return false;
    if (lastSeen == null) return true;
    final current = (now ?? DateTime.now()).toLocal();
    final localSeen = lastSeen.toLocal();
    final diff = current.difference(localSeen);
    // If heartbeat is older than 5 minutes, user disconnected unexpectedly
    return diff.isNegative || diff.inMinutes < 5;
  }

  static String formatStatus(bool isOnline, DateTime? lastSeen,
      {DateTime? now}) {
    final effectiveOnline = isEffectiveOnline(isOnline, lastSeen, now: now);
    if (effectiveOnline) return 'Online';
    if (lastSeen == null) return 'Offline';
    final current = (now ?? DateTime.now()).toLocal();
    final localSeen = lastSeen.toLocal();
    final diff = current.difference(localSeen);

    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Last seen just now';
    }
    if (diff.inMinutes < 60) {
      return 'Last seen ${diff.inMinutes}m ago';
    }

    final today = DateTime(current.year, current.month, current.day);
    final seenDate = DateTime(localSeen.year, localSeen.month, localSeen.day);
    final dayDiff = today.difference(seenDate).inDays;

    if (dayDiff <= 0) {
      return 'Last seen ${diff.inHours}h ago';
    }
    if (dayDiff == 1) {
      return 'Last seen yesterday';
    }
    return 'Last seen ${dayDiff}d ago';
  }

  bool get _effectiveOnline => isEffectiveOnline(isOnline, lastSeen);
  String get _statusText => formatStatus(isOnline, lastSeen);

  Color get _statusColor {
    if (_effectiveOnline) return AppColors.online;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final online = _effectiveOnline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (online) ...[
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
              fontWeight: online ? FontWeight.w600 : FontWeight.normal,
              color: online
                  ? (isDark ? Colors.white70 : Colors.black87)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
      ],
    );
  }
}
