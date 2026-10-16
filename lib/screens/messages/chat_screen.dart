import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/connection_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/contact_reveal_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/crushie_avatar.dart';
import '../../widgets/report_modal.dart';
import '../profile/profile_screen.dart';

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
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  XFile? _attachedMediaFile;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickAttachment(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _attachedMediaFile = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select attachment: $e')),
      );
    }
  }

  void _showChatAttachmentOptionsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Send Media Attachment',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library,
                        color: AppColors.primary),
                  ),
                  title: const Text('Choose Photo from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select an image from device gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAttachment(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: AppColors.secondary),
                  ),
                  title: const Text('Take Photo with Camera',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Capture a new photo using camera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAttachment(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _markAsRead() {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    final user = authProv.currentUser;
    if (user != null) {
      chatProv.markMessagesAsRead(widget.connection.id, user.id);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTextChanged(String text, String connectionId, String currentUserId) {
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    chatProv.setTypingStatus(connectionId, currentUserId, true);

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      chatProv.setTypingStatus(connectionId, currentUserId, false);
    });
  }

  // Delivery Ticks
  Widget _buildDeliveryTicks(MessageDeliveryStatus status) {
    switch (status) {
      case MessageDeliveryStatus.sent:
        return const Text('✓',
            style: TextStyle(fontSize: 11, color: Colors.white70));
      case MessageDeliveryStatus.delivered:
        return const Text('✓✓',
            style: TextStyle(fontSize: 11, color: Colors.white70));
      case MessageDeliveryStatus.read:
        return const Text('✓✓',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.accent,
                fontWeight: FontWeight.bold));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final chatProv = Provider.of<ChatProvider>(context);
    final dbService = DatabaseService();

    final currentUser = authProv.currentUser;
    final activeUserId = currentUser?.id ?? '';

    final String otherUserId = widget.connection.senderId == activeUserId
        ? widget.connection.recipientId
        : widget.connection.senderId;
    final otherUser = dbService.getUser(otherUserId);
    final otherUsername = otherUser?.username ??
        (widget.connection.senderId == activeUserId
            ? widget.connection.recipientUsername
            : widget.connection.senderUsername);
    final otherPic = otherUser?.profilePicUrl ??
        (widget.connection.senderId == activeUserId
            ? widget.connection.recipientProfilePic
            : widget.connection.senderProfilePic);
    final isBlocked = dbService.isUserBlocked(activeUserId, otherUserId);
    final isOtherTyping =
        chatProv.isUserTyping(widget.connection.id, otherUserId);

    final messages = chatProv.getMessagesForConnection(widget.connection.id,
        userId: activeUserId);

    final isMascot = otherPic.startsWith('crushie_avatar_');
    final mascotIdx = isMascot
        ? (int.tryParse(otherPic.replaceAll('crushie_avatar_', '')) ?? 0)
        : 0;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => _openUserProfile(context, otherUserId),
          child: Row(
            children: [
              // Clean Avatar (No duplicate dot on avatar in header)
              if (isMascot)
                CrushieAvatar(index: mascotIdx, radius: 18)
              else
                CircleAvatar(
                  radius: 18,
                  backgroundImage: CachedNetworkImageProvider(otherPic),
                ),
              const SizedBox(width: 10),

              // Title & Single Status Line
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '@$otherUsername',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (otherUser?.isVerified ?? false) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              color: AppColors.verifiedBlue, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    StatusBadge(
                      isOnline: otherUser?.isOnline ?? false,
                      lastSeen: otherUser?.lastSeen ?? DateTime.now(),
                      showText: true,
                      dotSize: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Three-Dot Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'profile') {
                _openUserProfile(context, otherUserId);
              } else if (val == 'mute') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Notifications muted for @$otherUsername')),
                );
              } else if (val == 'clear') {
                _showClearConversationConfirmation(
                    context, widget.connection.id, activeUserId, chatProv);
              } else if (val == 'delete') {
                _showDeleteConversationConfirmation(
                    context,
                    widget.connection.id,
                    otherUsername,
                    activeUserId,
                    chatProv);
              } else if (val == 'block') {
                _showBlockConfirmation(context, activeUserId, otherUserId,
                    otherUsername, dbService);
              } else if (val == 'report') {
                _showReportModal(context, activeUserId, otherUserId,
                    otherUsername, dbService);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline, size: 20),
                  title: Text('View Profile'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'mute',
                child: ListTile(
                  leading: Icon(Icons.notifications_off_outlined, size: 20),
                  title: Text('Mute Notifications'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.cleaning_services_outlined, size: 20),
                  title: Text('Clear Conversation'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading:
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  title: Text('Delete Conversation',
                      style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: ListTile(
                  leading: Icon(
                    isBlocked ? Icons.lock_open : Icons.block,
                    size: 20,
                    color: isBlocked ? Colors.green : Colors.red,
                  ),
                  title: Text(isBlocked ? 'Unblock User' : 'Block User'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: ListTile(
                  leading:
                      Icon(Icons.flag_outlined, size: 20, color: Colors.orange),
                  title: Text('Report User'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Unlocked Contact Method Card (Handled for blocked state)
          ContactRevealCard(
            contactMethod: widget.connection.recipientContactMethod,
            contactDetails: widget.connection.recipientContactDetails,
            username: otherUsername,
            isBlocked: isBlocked,
          ),

          // Compact Professional Blocked Warning Banner
          if (isBlocked)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.red.withOpacity(0.2), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, color: Colors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You blocked @$otherUsername',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'They can\'t message or connect with you.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Provider.of<UserProvider>(context, listen: false)
                          .unblockUser(activeUserId, otherUserId);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Unblock',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.red,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          // Messages Thread with Real-Time Stream Integration
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: chatProv.getChatMessagesStream(widget.connection.id,
                  limit: 50),
              builder: (context, snapshot) {
                // If waiting for first network response and no cached messages, show loading spinner
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.red.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load messages',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please check your connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasData && snapshot.data != null) {
                  final streamMsgs = snapshot.data!;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      chatProv.syncMessages(widget.connection.id, streamMsgs);
                      final hasUnread = streamMsgs.any(
                          (m) => m.recipientId == activeUserId && !m.isRead);
                      if (hasUnread) {
                        _markAsRead();
                      }
                    }
                  });
                }

                final rawMessages = snapshot.data ?? messages;
                final displayMessages = rawMessages
                    .where((m) => !m.deletedForUserIds.contains(activeUserId))
                    .toList();

                if (displayMessages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hi to @$otherUsername!',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: displayMessages.length,
                  itemBuilder: (ctx, i) {
                    final msg = displayMessages[i];
                    final isMe = msg.senderId == activeUserId;

                    return GestureDetector(
                      onLongPress: () => _showMessageOptionsSheet(
                          context, msg, isMe, activeUserId, chatProv),
                      child: Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            gradient: (isMe && !msg.isDeletedForEveryone)
                                ? AppColors.primaryGradient
                                : null,
                            color: msg.isDeletedForEveryone
                                ? (isDark
                                    ? AppColors.darkCard
                                    : Colors.grey.shade200)
                                : (isMe
                                    ? null
                                    : (isDark
                                        ? AppColors.darkCard
                                        : Colors.white)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (msg.mediaUrl != null &&
                                  msg.mediaUrl!.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: msg.mediaUrl!.startsWith('http')
                                      ? CachedNetworkImage(
                                          imageUrl: msg.mediaUrl!,
                                          height: 160,
                                          width: 200,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(msg.mediaUrl!),
                                          height: 160,
                                          width: 200,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                  Icons.insert_drive_file,
                                                  size: 40),
                                        ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (msg.isDeletedForEveryone)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.block,
                                      size: 14,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Message deleted',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                )
                              else if (msg.message.isNotEmpty)
                                Text(
                                  msg.message,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    color: isMe
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary),
                                  ),
                                ),
                              const SizedBox(height: 4),

                              // Timestamp + Delivery Ticks
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('h:mm a').format(msg.timestamp),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isMe && !msg.isDeletedForEveryone
                                          ? Colors.white.withOpacity(0.75)
                                          : (isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary),
                                    ),
                                  ),
                                  if (isMe && !msg.isDeletedForEveryone) ...[
                                    const SizedBox(width: 4),
                                    _buildDeliveryTicks(msg.deliveryStatus),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Typing Indicator
          if (isOtherTyping && !isBlocked)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '@$otherUsername is typing...',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Attachment Preview Bar (if attachment selected)
          if (_attachedMediaFile != null && !isBlocked)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_attachedMediaFile!.path),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Photo attachment ready',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () => setState(() => _attachedMediaFile = null),
                  ),
                ],
              ),
            ),

          // Message Composer (Normal OR Clean Blocked State Replacement)
          if (!isBlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: isDark ? AppColors.darkSurface : Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded,
                        color: AppColors.primary),
                    onPressed: _showChatAttachmentOptionsSheet,
                    tooltip: 'Send Attachment',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      onChanged: (v) =>
                          _onTextChanged(v, widget.connection.id, activeUserId),
                      decoration: InputDecoration(
                        hintText: 'Type a message to @$otherUsername...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () async {
                        final text = _msgController.text.trim();
                        final mediaFile = _attachedMediaFile;
                        if (text.isNotEmpty || mediaFile != null) {
                          _msgController.clear();
                          setState(() {
                            _attachedMediaFile = null;
                          });

                          String? mediaUrl;
                          if (mediaFile != null) {
                            try {
                              mediaUrl = await StorageService().uploadChatPhoto(
                                connectionId: widget.connection.id,
                                userId: activeUserId,
                                file: mediaFile,
                              );
                            } catch (e) {
                              debugPrint(
                                  '[CHAT_SCREEN] Error uploading chat photo: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Failed to upload image: $e')),
                                );
                              }
                              return;
                            }
                          }

                          chatProv.sendMessage(
                            connectionId: widget.connection.id,
                            senderId: activeUserId,
                            recipientId: otherUserId,
                            text:
                                text.isNotEmpty ? text : '📷 Photo attachment',
                            mediaUrl: mediaUrl,
                          );
                          chatProv.setTypingStatus(
                              widget.connection.id, activeUserId, false);
                          _scrollToBottom();
                        }
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            // Clean Composer Replacement State when Blocked
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: isDark ? AppColors.darkCard : Colors.grey.shade100,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'You blocked this user',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Unblock to send messages',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Provider.of<UserProvider>(context, listen: false)
                          .unblockUser(activeUserId, otherUserId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Unblock',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openUserProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  // Delete / Report Message Options
  void _showMessageOptionsSheet(
    BuildContext context,
    ChatMessageModel message,
    bool isMe,
    String currentUserId,
    ChatProvider chatProv,
  ) {
    if (message.isDeletedForEveryone) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.orange),
            title: const Text('Delete for Me'),
            subtitle: const Text('Remove this message only from your view'),
            onTap: () {
              Navigator.pop(ctx);
              chatProv.deleteMessageForMe(
                  widget.connection.id, message.id, currentUserId);
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete for Everyone'),
              subtitle: const Text('Remove this message from both sides'),
              onTap: () {
                Navigator.pop(ctx);
                chatProv.deleteMessageForEveryone(
                    widget.connection.id, message.id);
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.orange),
              title: const Text('Report Message'),
              subtitle:
                  const Text('Report offensive or abusive message content'),
              onTap: () {
                Navigator.pop(ctx);
                ReportModal.show(
                  context: context,
                  targetType: ReportTargetType.message,
                  targetId: message.id,
                  reportedUserId: message.senderId,
                  targetPreview: message.content.isNotEmpty
                      ? message.content
                      : 'Photo attachment',
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.close, color: Colors.grey),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // Clear Conversation Confirmation Dialog
  void _showClearConversationConfirmation(
    BuildContext context,
    String connectionId,
    String currentUserId,
    ChatProvider chatProv,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Conversation?'),
        content: const Text(
            'This will clear all messages in this conversation from your view. The connection remains active.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              chatProv.clearConversation(connectionId, currentUserId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation cleared.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Delete Conversation Confirmation Dialog
  void _showDeleteConversationConfirmation(
    BuildContext context,
    String connectionId,
    String targetUsername,
    String currentUserId,
    ChatProvider chatProv,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Conversation with @$targetUsername?'),
        content: const Text(
            'This will delete the conversation and remove it from your messages list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              chatProv.deleteConversation(connectionId, currentUserId);
              Navigator.pop(context); // Return back to Messages list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Deleted conversation with @$targetUsername.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Block User Confirmation Dialog
  void _showBlockConfirmation(
    BuildContext context,
    String currentUserId,
    String targetUserId,
    String targetUsername,
    DatabaseService dbService,
  ) {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final isBlocked = userProv.isUserBlocked(currentUserId, targetUserId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isBlocked
            ? 'Unblock @$targetUsername?'
            : 'Block @$targetUsername?'),
        content: Text(
          isBlocked
              ? 'Are you sure you want to unblock @$targetUsername?'
              : 'They won\'t be able to message or connect with you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (isBlocked) {
                  await userProv.unblockUser(currentUserId, targetUserId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Unblocked @$targetUsername.')),
                    );
                  }
                } else {
                  await userProv.blockUser(currentUserId, targetUserId,
                      targetUsername: targetUsername);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Blocked @$targetUsername.')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Action failed: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isBlocked ? AppColors.primary : Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isBlocked ? 'Unblock' : 'Block',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Report User Dialog
  void _showReportModal(
    BuildContext context,
    String currentUserId,
    String targetUserId,
    String targetUsername,
    DatabaseService dbService,
  ) {
    ReportModal.show(
      context: context,
      targetType: ReportTargetType.user,
      targetId: targetUserId,
      reportedUserId: targetUserId,
      targetPreview: '@$targetUsername',
    );
  }
}
