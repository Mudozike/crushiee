import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/connection_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/crushie_avatar.dart';
import '../profile/profile_screen.dart';

class MessagesListScreen extends StatelessWidget {
  final Function(ConnectionModel connection) onSelectConnection;

  const MessagesListScreen({
    Key? key,
    required this.onSelectConnection,
  }) : super(key: key);

  String _formatPresenceStatus(bool isOnline, DateTime lastSeen) {
    if (isOnline) return 'Online';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 60) {
      return 'Last seen ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Last seen ${diff.inHours}h ago';
    } else {
      return 'Last seen yesterday';
    }
  }

  String _formatConversationTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);
    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return DateFormat('h:mm a').format(dt); // e.g. 9:30 PM
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (dt.year == now.year) {
      return DateFormat('d MMM').format(dt); // e.g. 12 Aug
    } else {
      return DateFormat('d MMM yyyy').format(dt); // e.g. 12 Aug 2025
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final connProv = Provider.of<ConnectionProvider>(context);
    final chatProv = Provider.of<ChatProvider>(context);
    final dbService = DatabaseService();

    final currentUser = authProv.currentUser;
    final activeUserId = currentUser?.id ?? '';

    final acceptedConns = activeUserId.isNotEmpty
        ? connProv.getAcceptedConnections(activeUserId)
        : <ConnectionModel>[];
    final pendingConns = activeUserId.isNotEmpty
        ? connProv.getPendingRequestsForUser(activeUserId)
        : <ConnectionModel>[];

    // Dynamic Online Users Count
    int onlineCount = 0;
    for (var c in acceptedConns) {
      final String otherUserId =
          c.senderId == activeUserId ? c.recipientId : c.senderId;
      final otherUser = dbService.getUser(otherUserId);
      if (otherUser?.isOnline ?? false) onlineCount++;
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Pending Connection Requests Header (If Any)
            if (pendingConns.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.3), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite,
                              color: AppColors.primary, size: 18),
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
                          final isMascot =
                              c.senderProfilePic.startsWith('crushie_avatar_');
                          final mascotIdx = isMascot
                              ? (int.tryParse(c.senderProfilePic
                                      .replaceAll('crushie_avatar_', '')) ??
                                  0)
                              : 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      _openUserProfile(context, c.senderId),
                                  child: isMascot
                                      ? CrushieAvatar(
                                          index: mascotIdx, radius: 20)
                                      : CircleAvatar(
                                          radius: 20,
                                          backgroundImage:
                                              CachedNetworkImageProvider(
                                                  c.senderProfilePic),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _openUserProfile(context, c.senderId),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '@${c.senderUsername}',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5),
                                        ),
                                        const Text('Paid request',
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    connProv
                                        .respondToConnectionRequest(
                                            c.id, ConnectionStatus.accepted)
                                        .catchError((e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Failed to update connection: $e')),
                                        );
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    minimumSize: const Size(55, 28),
                                  ),
                                  child: const Text('Accept',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5)),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  onPressed: () {
                                    connProv
                                        .respondToConnectionRequest(
                                            c.id, ConnectionStatus.declined)
                                        .catchError((e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Failed to update connection: $e')),
                                        );
                                      }
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: const Size(50, 28),
                                  ),
                                  child: const Text('Decline',
                                      style: TextStyle(
                                          color: Colors.red, fontSize: 11.5)),
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

            // 2. Active Connections Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Connections (${acceptedConns.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$onlineCount Active',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Accepted Active Connections List
            (connProv.isLoading && acceptedConns.isEmpty)
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : acceptedConns.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.forum_outlined,
                                      size: 48, color: AppColors.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No active connections yet.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final conn = acceptedConns[i];
                              final String otherUserId =
                                  conn.senderId == activeUserId
                                      ? conn.recipientId
                                      : conn.senderId;
                              final otherUser = dbService.getUser(otherUserId);
                              final otherUsername = otherUser?.username ??
                                  (conn.senderId == activeUserId
                                      ? conn.recipientUsername
                                      : conn.senderUsername);
                              final otherPic = otherUser?.profilePicUrl ??
                                  (conn.senderId == activeUserId
                                      ? conn.recipientProfilePic
                                      : conn.senderProfilePic);

                              final messages =
                                  chatProv.getMessagesForConnection(conn.id,
                                      userId: activeUserId);
                              final latestMessage =
                                  messages.isNotEmpty ? messages.last : null;

                              final previewText = latestMessage != null
                                  ? latestMessage.message
                                  : (conn.lastMessageText != null &&
                                          conn.lastMessageText!.isNotEmpty)
                                      ? conn.lastMessageText!
                                      : (conn.recipientContactDetails.isNotEmpty
                                          ? 'Unlocked ${conn.recipientContactMethod}: ${conn.recipientContactDetails}'
                                          : 'Tap to start chatting');

                              final previewTime = latestMessage != null
                                  ? latestMessage.timestamp
                                  : (conn.lastMessageTimestamp ??
                                      conn.updatedAt);

                              final persistedUnread =
                                  conn.unreadCountForUser(activeUserId);
                              final unreadCount = persistedUnread > 0
                                  ? persistedUnread
                                  : messages
                                      .where((m) =>
                                          m.senderId == otherUserId &&
                                          !m.isRead)
                                      .length;

                              final isMascot =
                                  otherPic.startsWith('crushie_avatar_');
                              final mascotIdx = isMascot
                                  ? (int.tryParse(otherPic.replaceAll(
                                          'crushie_avatar_', '')) ??
                                      0)
                                  : 0;

                              final hasUnread = unreadCount > 0;
                              final isOnline = otherUser?.isOnline ?? false;
                              final lastSeen =
                                  otherUser?.lastSeen ?? DateTime.now();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => onSelectConnection(conn),
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkCard
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Profile Avatar with Presence Indicator
                                          GestureDetector(
                                            onTap: () => _openUserProfile(
                                                context, otherUserId),
                                            child: Stack(
                                              children: [
                                                if (isMascot)
                                                  CrushieAvatar(
                                                      index: mascotIdx,
                                                      radius: 26)
                                                else
                                                  CircleAvatar(
                                                    radius: 26,
                                                    backgroundColor: AppColors
                                                        .primary
                                                        .withOpacity(0.1),
                                                    backgroundImage: (otherPic
                                                                .isNotEmpty &&
                                                            (otherPic.startsWith(
                                                                    'http') ||
                                                                otherPic
                                                                    .startsWith(
                                                                        'https')))
                                                        ? CachedNetworkImageProvider(
                                                            otherPic)
                                                        : null,
                                                    child: (otherPic.isEmpty ||
                                                            (!otherPic.startsWith(
                                                                    'http') &&
                                                                !otherPic
                                                                    .startsWith(
                                                                        'https')))
                                                        ? Text(
                                                            otherUsername
                                                                    .isNotEmpty
                                                                ? otherUsername[
                                                                        0]
                                                                    .toUpperCase()
                                                                : 'C',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: AppColors
                                                                    .primary),
                                                          )
                                                        : null,
                                                  ),
                                                if (isOnline)
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      width: 13,
                                                      height: 13,
                                                      decoration: BoxDecoration(
                                                        color: AppColors.online,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: isDark
                                                              ? AppColors
                                                                  .darkCard
                                                              : Colors.white,
                                                          width: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),

                                          // Username, Presence & Message Snippet
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        '@$otherUsername',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontWeight: hasUnread
                                                              ? FontWeight.w900
                                                              : FontWeight.bold,
                                                          fontSize: 15,
                                                          color: isDark
                                                              ? AppColors
                                                                  .darkTextPrimary
                                                              : AppColors
                                                                  .lightTextPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    if (otherUser?.isVerified ??
                                                        false) ...[
                                                      const SizedBox(width: 4),
                                                      const Icon(Icons.verified,
                                                          color: AppColors
                                                              .verifiedBlue,
                                                          size: 15),
                                                    ],
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '• ${_formatPresenceStatus(isOnline, lastSeen)}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: isOnline
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
                                                        color: isOnline
                                                            ? Colors.green
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  previewText,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: hasUnread
                                                        ? FontWeight.w700
                                                        : FontWeight.normal,
                                                    color: hasUnread
                                                        ? (isDark
                                                            ? Colors.white
                                                            : Colors.black87)
                                                        : (isDark
                                                            ? AppColors
                                                                .darkTextSecondary
                                                            : AppColors
                                                                .lightTextSecondary),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),

                                          // WhatsApp-Style Timestamp & Unread Count Badge
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                _formatConversationTimestamp(
                                                    previewTime),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: hasUnread
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: hasUnread
                                                      ? AppColors.primary
                                                      : Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              if (hasUnread)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    gradient: AppColors
                                                        .primaryGradient,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors.primary
                                                            .withOpacity(0.4),
                                                        blurRadius: 6,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    '$unreadCount',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: acceptedConns.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  void _openUserProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }
}
