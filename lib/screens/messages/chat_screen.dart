import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/app_colors.dart';
import '../../models/connection_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/contact_reveal_card.dart';

class ChatScreen extends StatefulWidget {
  final ConnectionModel connection;

  const ChatScreen({
    Key? key,
    required this.connection,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final chatProv = Provider.of<ChatProvider>(context);

    final currentUser = authProv.currentUser;
    if (currentUser == null) return const SizedBox();

    final isSender = widget.connection.senderId == currentUser.id;
    final otherUsername = isSender ? widget.connection.recipientUsername : widget.connection.senderUsername;
    final otherPic = isSender ? widget.connection.recipientProfilePic : widget.connection.senderProfilePic;
    final otherUserId = isSender ? widget.connection.recipientId : widget.connection.senderId;

    final messages = chatProv.getMessagesForConnection(widget.connection.id);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: CachedNetworkImageProvider(otherPic),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$otherUsername', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Text('Connected', style: TextStyle(fontSize: 11, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner revealing private contact method (WhatsApp, Telegram, Phone, Email)
          ContactRevealCard(
            contactMethod: widget.connection.recipientContactMethod,
            contactDetails: widget.connection.recipientContactDetails,
            username: otherUsername,
          ),

          // Messages Stream / Thread
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (ctx, i) {
                final msg = messages[i];
                final isMe = msg.senderId == currentUser.id;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      gradient: isMe ? AppColors.primaryGradient : null,
                      color: isMe
                          ? null
                          : (isDark ? AppColors.darkCard : Colors.grey.withOpacity(0.15)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.message,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: isMe
                                ? Colors.white
                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(msg.timestamp, locale: 'en_short'),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withOpacity(0.7)
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? AppColors.darkSurface : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: 'Type a message to @$otherUsername...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: () {
                    final text = _msgController.text.trim();
                    if (text.isNotEmpty) {
                      chatProv.sendMessage(
                        connectionId: widget.connection.id,
                        senderId: currentUser.id,
                        recipientId: otherUserId,
                        text: text,
                      );
                      _msgController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
