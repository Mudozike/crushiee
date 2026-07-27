import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/app_colors.dart';
import '../../models/connection_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';

class MessagesListScreen extends StatelessWidget {
  final Function(ConnectionModel connection) onSelectConnection;

  const MessagesListScreen({
    Key? key,
    required this.onSelectConnection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final connProv = Provider.of<ConnectionProvider>(context);

    final currentUser = authProv.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Please log in")));
    }

    final acceptedConns = connProv.getAcceptedConnections(currentUser.id);
    final pendingConns = connProv.getPendingRequestsForUser(currentUser.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Pending Requests Header (If Any)
          if (pendingConns.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.primary.withOpacity(0.08),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Connection Requests (${pendingConns.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: pendingConns.map((c) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: CachedNetworkImageProvider(c.senderProfilePic),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '@${c.senderUsername}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const Text('Paid connection request', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  connProv.respondToConnectionRequest(c.id, ConnectionStatus.accepted);
                                },
                                style: ElevatedButton.styleFrom(
                                  primary: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                ),
                                child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: () {
                                  connProv.respondToConnectionRequest(c.id, ConnectionStatus.declined);
                                },
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                child: const Text('Decline', style: TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Active Messages / Connections Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Active Connections (${acceptedConns.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ),
          ),

          // Accepted List
          acceptedConns.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 64, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'No active connections yet.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Connect" on any post to private message users.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final conn = acceptedConns[i];
                      final isSender = conn.senderId == currentUser.id;
                      final otherUsername = isSender ? conn.recipientUsername : conn.senderUsername;
                      final otherPic = isSender ? conn.recipientProfilePic : conn.senderProfilePic;

                      return ListTile(
                        onTap: () => onSelectConnection(conn),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundImage: CachedNetworkImageProvider(otherPic),
                        ),
                        title: Text(
                          '@$otherUsername',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Unlocked ${conn.recipientContactMethod}: ${conn.recipientContactDetails}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        trailing: Text(
                          timeago.format(conn.createdAt, locale: 'en_short'),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      );
                    },
                    childCount: acceptedConns.length,
                  ),
                ),
        ],
      ),
    );
  }
}
