import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/app_colors.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/crushie_avatar.dart';
import '../../widgets/post_card.dart';
import '../messages/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../premium/premium_subscription_screen.dart';
import '../profile/verification_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final notifProv = Provider.of<NotificationProvider>(context);

    final currentUser = authProv.currentUser;
    if (currentUser == null) {
      return const Scaffold(
          body: Center(child: Text("Log in to view notifications")));
    }

    final notifs = notifProv.getNotificationsForUser(currentUser.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
              notifProv.markAllAsRead(currentUser.id);
            },
          ),
        ],
      ),
      body: notifs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      size: 64,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifs.length,
              itemBuilder: (ctx, i) {
                final n = notifs[i];
                final isMascot = n.fromUserProfilePic.startsWith('crushie_avatar_') ||
                    n.fromUserProfilePic.isEmpty;
                final mascotIdx = isMascot
                    ? (int.tryParse(n.fromUserProfilePic
                            .replaceAll('crushie_avatar_', '')) ??
                        0)
                    : 0;

                return Dismissible(
                  key: Key('notif_${n.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    notifProv.deleteNotification(currentUser.id, n.id);
                  },
                  child: Material(
                    color: n.isRead
                        ? Colors.transparent
                        : (isDark
                            ? AppColors.primary.withOpacity(0.08)
                            : AppColors.primary.withOpacity(0.04)),
                    child: ListTile(
                      onTap: () => _handleNotificationTap(
                          context, n, currentUser, notifProv),
                      leading: Stack(
                        children: [
                          if (isMascot)
                            CrushieAvatar(index: mascotIdx, radius: 24)
                          else
                            CircleAvatar(
                              radius: 24,
                              backgroundImage:
                                  CachedNetworkImageProvider(n.fromUserProfilePic),
                            ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: _getNotifColor(n.type),
                              child: Icon(_getNotifIcon(n.type),
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight:
                              n.isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        n.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      trailing: Text(
                        timeago.format(n.createdAt, locale: 'en_short'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    NotificationModel n,
    UserModel currentUser,
    NotificationProvider notifProv,
  ) async {
    // 1. Mark as read
    notifProv.markAsRead(currentUser.id, n.id);
    final firestoreService = notifProv.firestoreService;

    // 2. Safe Navigation based on notification event type
    switch (n.type) {
      case NotificationType.message:
        if (n.connectionId != null && n.connectionId!.isNotEmpty) {
          final conn = await firestoreService.getConnection(n.connectionId!);
          if (!context.mounted) return;
          if (conn != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(connection: conn)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Conversation is no longer available.')),
            );
          }
        }
        break;

      case NotificationType.crush:
      case NotificationType.crushComment:
      case NotificationType.commentReply:
      case NotificationType.mention:
      case NotificationType.locationPost:
      case NotificationType.boost:
        if (n.postId != null && n.postId!.isNotEmpty) {
          final post = await firestoreService.getPost(n.postId!);
          if (!context.mounted) return;
          if (post != null) {
            showDialog(
              context: context,
              builder: (ctx) => Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PostCard(post: post),
                  ),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This post has expired or was removed.')),
            );
          }
        }
        break;

      case NotificationType.follow:
      case NotificationType.connectionRequest:
      case NotificationType.connectionAccepted:
      case NotificationType.connectionDeclined:
        if (n.fromUserId.isNotEmpty) {
          final profile = await firestoreService.getUserProfile(n.fromUserId);
          if (!context.mounted) return;
          if (profile != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(user: profile)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile is no longer available.')),
            );
          }
        }
        break;

      case NotificationType.premium:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PremiumSubscriptionScreen(
              onSubscriptionSuccess: () => Navigator.pop(context),
            ),
          ),
        );
        break;

      case NotificationType.verification:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationScreen(
              onVerifiedSuccess: () => Navigator.pop(context),
            ),
          ),
        );
        break;

      case NotificationType.account:
      case NotificationType.system:
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(n.title),
            content: Text(n.body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        break;
    }
  }

  IconData _getNotifIcon(NotificationType type) {
    switch (type) {
      case NotificationType.crush:
        return Icons.favorite;
      case NotificationType.crushComment:
        return Icons.chat_bubble;
      case NotificationType.commentReply:
        return Icons.reply;
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.connectionRequest:
        return Icons.contact_mail;
      case NotificationType.connectionAccepted:
        return Icons.check_circle;
      case NotificationType.connectionDeclined:
        return Icons.cancel;
      case NotificationType.message:
        return Icons.mail_outline;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.locationPost:
        return Icons.location_on;
      case NotificationType.premium:
        return Icons.star;
      case NotificationType.verification:
        return Icons.verified;
      case NotificationType.account:
        return Icons.security;
      case NotificationType.boost:
        return Icons.bolt;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  Color _getNotifColor(NotificationType type) {
    switch (type) {
      case NotificationType.crush:
        return AppColors.primary;
      case NotificationType.crushComment:
        return AppColors.secondary;
      case NotificationType.commentReply:
        return Colors.purple;
      case NotificationType.follow:
        return Colors.blue;
      case NotificationType.connectionRequest:
        return Colors.orange;
      case NotificationType.connectionAccepted:
        return Colors.green;
      case NotificationType.connectionDeclined:
        return Colors.red;
      case NotificationType.message:
        return AppColors.primary;
      case NotificationType.mention:
        return Colors.teal;
      case NotificationType.locationPost:
        return Colors.deepOrange;
      case NotificationType.premium:
        return AppColors.premiumGold;
      case NotificationType.verification:
        return AppColors.verifiedBlue;
      case NotificationType.account:
        return Colors.indigo;
      case NotificationType.boost:
        return AppColors.boostOrange;
      case NotificationType.system:
        return Colors.purple;
    }
  }
}
