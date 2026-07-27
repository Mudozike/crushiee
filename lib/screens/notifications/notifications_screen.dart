import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/app_colors.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final notifProv = Provider.of<NotificationProvider>(context);

    final currentUser = authProv.currentUser;
    if (currentUser == null) return const Scaffold(body: Center(child: Text("Log in to view notifications")));

    final notifs = notifProv.getNotificationsForUser(currentUser.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: notifs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 64, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifs.length,
              itemBuilder: (ctx, i) {
                final n = notifs[i];

                return Container(
                  color: n.isRead
                      ? Colors.transparent
                      : (isDark ? AppColors.primary.withOpacity(0.08) : AppColors.primary.withOpacity(0.04)),
                  child: ListTile(
                    onTap: () {
                      notifProv.markAsRead(n.id);
                    },
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: CachedNetworkImageProvider(n.fromUserProfilePic),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: _getNotifColor(n.type),
                            child: Icon(_getNotifIcon(n.type), size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      n.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    trailing: Text(
                      timeago.format(n.createdAt, locale: 'en_short'),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _getNotifIcon(NotificationType type) {
    switch (type) {
      case NotificationType.crush:
        return Icons.favorite;
      case NotificationType.crushComment:
        return Icons.chat_bubble;
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.connectionRequest:
        return Icons.contact_mail;
      case NotificationType.connectionAccepted:
        return Icons.check_circle;
      case NotificationType.connectionDeclined:
        return Icons.cancel;
    }
  }

  Color _getNotifColor(NotificationType type) {
    switch (type) {
      case NotificationType.crush:
        return AppColors.primary;
      case NotificationType.crushComment:
        return AppColors.secondary;
      case NotificationType.follow:
        return Colors.blue;
      case NotificationType.connectionRequest:
        return Colors.orange;
      case NotificationType.connectionAccepted:
        return Colors.green;
      case NotificationType.connectionDeclined:
        return Colors.red;
    }
  }
}
