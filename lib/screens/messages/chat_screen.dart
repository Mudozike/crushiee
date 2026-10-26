import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../providers/connection_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
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

  Stream<List<ChatMessageModel>>? _messagesStream;
  Stream<UserModel?>? _otherUserStream;
  String? _streamConnectionId;
  int _streamRetryCounter = 0;
  Timer? _otherUserTypingExpirationTimer;
  final FirestoreService _firestoreService = FirestoreService();

  bool _hasInitiallyScrolledToBottom = false;
  int _lastRenderedMessageCount = 0;

  // --- TEMPORARY DEVELOPER DIAGNOSTICS ---
  String? _diagnosticMarkAsReadError;
  String? _diagnosticPaginationError;

  static String _redactConnectionId(String id) {
    if (id.isEmpty) return '<empty>';
    if (id.length <= 8) return 'conn_***';
    return '${id.substring(0, 5)}...${id.substring(id.length - 3)}';
  }

  static String _categorizeDiagnosticError(dynamic error) {
    if (error == null) return 'UNKNOWN';
    final s = error.toString().toLowerCase();
    if (s.contains('permission-denied') ||
        s.contains('insufficient permissions') ||
        s.contains('permission_denied')) {
      return 'PERMISSION_DENIED';
    }
    if (s.contains('not-found') ||
        s.contains('not_found') ||
        s.contains('document not found') ||
        s.contains('cursor document not found')) {
      return 'DOCUMENT_NOT_FOUND';
    }
    if (s.contains('failed-precondition') ||
        s.contains('index') ||
        s.contains('invalid-argument')) {
      return 'QUERY_OR_INDEX_ERROR';
    }
    if (s.contains('network') ||
        s.contains('unavailable') ||
        s.contains('timeout') ||
        s.contains('deadline-exceeded') ||
        s.contains('connection closed') ||
        s.contains('interrupted')) {
      return 'NETWORK_ERROR';
    }
    if (s.contains('formatexception') ||
        s.contains('typeerror') ||
        s.contains('nosuchmethoderror') ||
        s.contains('is not a subtype of')) {
      return 'PARSING_ERROR';
    }
    if (s.contains('no firebase app') || s.contains('core/no-app')) {
      return 'NO_FIREBASE_APP_INITIALIZED';
    }
    return 'RUNTIME_ERROR';
  }

  static String _formatDiagnosticDetail(dynamic error) {
    if (error == null) return 'Unknown error';
    if (error is FirebaseException) {
      final code = error.code.isNotEmpty ? '[${error.code}] ' : '';
      return '$code${error.message ?? error.toString()}';
    }
    return error.toString();
  }

  void _logDiagnostic({
    required String operation,
    required String connectionId,
    required dynamic error,
  }) {
    final category = _categorizeDiagnosticError(error);
    final detail = _formatDiagnosticDetail(error);
    final redactedId = _redactConnectionId(connectionId);
    final path = 'connections/$redactedId/messages';
    debugPrint(
      '[DEV_DIAGNOSTIC] Op: $operation | Category: $category | Path: $path | Error: $detail',
    );
  }

  void _initMessagesStream({bool force = false}) {
    if (!force &&
        _messagesStream != null &&
        _streamConnectionId == widget.connection.id) {
      return;
    }
    _streamConnectionId = widget.connection.id;
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    _messagesStream =
        chatProv.getChatMessagesStream(widget.connection.id, limit: 50);

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final activeUserId = authProv.currentUser?.id ?? '';
    final String otherUserId = widget.connection.senderId == activeUserId
        ? widget.connection.recipientId
        : widget.connection.senderId;
    if (otherUserId.isNotEmpty) {
      try {
        _otherUserStream = _firestoreService.getUserStream(otherUserId);
      } catch (e) {
        debugPrint('[CHAT_SCREEN] Error setting up user stream: $e');
        _otherUserStream = null;
      }
    }
  }

  bool _isLoadingOlder = false;

  void _onChatScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 100 &&
        !_isLoadingOlder) {
      final chatProv = Provider.of<ChatProvider>(context, listen: false);
      if (chatProv.hasMoreOlderMessages(widget.connection.id) &&
          !chatProv.isLoadingOlderMessages(widget.connection.id)) {
        _fetchOlderMessages();
      }
    }
  }

  Future<void> _fetchOlderMessages() async {
    if (_isLoadingOlder) return;
    _isLoadingOlder = true;
    try {
      final chatProv = Provider.of<ChatProvider>(context, listen: false);
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final activeUserId = authProv.currentUser?.id;

      final prevPixels = _scrollController.hasClients
          ? _scrollController.position.pixels
          : 0.0;
      final prevMaxScroll = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;

      await chatProv.loadOlderMessages(widget.connection.id,
          userId: activeUserId);

      if (mounted && _diagnosticPaginationError != null) {
        setState(() {
          _diagnosticPaginationError = null;
        });
      }

      // Preserve relative scroll offset after prepending older messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final newMaxScroll = _scrollController.position.maxScrollExtent;
          final diff = newMaxScroll - prevMaxScroll;
          if (diff > 0) {
            _scrollController.jumpTo(prevPixels + diff);
          }
        }
      });
    } catch (e) {
      _logDiagnostic(
        operation: 'loadOlderMessages',
        connectionId: widget.connection.id,
        error: e,
      );
      if (mounted) {
        setState(() {
          _diagnosticPaginationError =
              '[${_categorizeDiagnosticError(e)}] ${_formatDiagnosticDetail(e)}';
        });
      }
    } finally {
      _isLoadingOlder = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onChatScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          Provider.of<NotificationProvider>(context, listen: false)
              .activeConversationConnectionId = widget.connection.id;
        } catch (_) {}
        _markAsRead();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initMessagesStream();
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connection.id != widget.connection.id) {
      _hasInitiallyScrolledToBottom = false;
      _lastRenderedMessageCount = 0;
      _otherUserTypingExpirationTimer?.cancel();
      _typingTimer?.cancel();
      try {
        final authProv = Provider.of<AuthProvider>(context, listen: false);
        final user = authProv.currentUser;
        if (user != null) {
          final oldId = oldWidget.connection.id;
          final uid = user.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              if (mounted) {
                final chatProv =
                    Provider.of<ChatProvider>(context, listen: false);
                chatProv.setTypingStatus(oldId, uid, false);
              }
            } catch (_) {}
          });
        }
      } catch (_) {}
      try {
        Provider.of<NotificationProvider>(context, listen: false)
            .activeConversationConnectionId = widget.connection.id;
      } catch (_) {}
      _initMessagesStream(force: true);
      _markAsRead();
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _otherUserTypingExpirationTimer?.cancel();
    try {
      Provider.of<NotificationProvider>(context, listen: false)
          .activeConversationConnectionId = null;
    } catch (_) {}
    try {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final user = authProv.currentUser;
      if (user != null) {
        final chatProv = Provider.of<ChatProvider>(context, listen: false);
        chatProv.setTypingStatus(widget.connection.id, user.id, false);
      }
    } catch (_) {}
    _scrollController.removeListener(_onChatScroll);
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    if (!mounted) return;
    try {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final chatProv = Provider.of<ChatProvider>(context, listen: false);
      final user = authProv.currentUser;
      if (user != null) {
        try {
          final connProv =
              Provider.of<ConnectionProvider>(context, listen: false);
          connProv.markConnectionAsReadLocally(widget.connection.id, user.id);
        } catch (_) {}
        try {
          await chatProv.markMessagesAsRead(widget.connection.id, user.id);
          if (mounted && _diagnosticMarkAsReadError != null) {
            setState(() {
              _diagnosticMarkAsReadError = null;
            });
          }
        } catch (e) {
          _logDiagnostic(
            operation: 'markMessagesAsRead',
            connectionId: widget.connection.id,
            error: e,
          );
          if (mounted) {
            setState(() {
              _diagnosticMarkAsReadError =
                  '[${_categorizeDiagnosticError(e)}] ${_formatDiagnosticDetail(e)}';
            });
          }
        }
      }
    } catch (e) {
      _logDiagnostic(
        operation: 'markAsRead_outer',
        connectionId: widget.connection.id,
        error: e,
      );
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    }
  }

  void _onTextChanged(String text, String connectionId, String currentUserId) {
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    if (text.trim().isEmpty) {
      _typingTimer?.cancel();
      chatProv.setTypingStatus(connectionId, currentUserId, false);
      return;
    }
    chatProv.setTypingStatus(connectionId, currentUserId, true);

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
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
    final fallbackUsername = otherUser?.username ??
        (widget.connection.senderId == activeUserId
            ? widget.connection.recipientUsername
            : widget.connection.senderUsername);
    final fallbackPic = otherUser?.profilePicUrl ??
        (widget.connection.senderId == activeUserId
            ? widget.connection.recipientProfilePic
            : widget.connection.senderProfilePic);
    final isBlocked = dbService.isUserBlocked(activeUserId, otherUserId);

    final messages = chatProv.getMessagesForConnection(widget.connection.id,
        userId: activeUserId);

    return StreamBuilder<UserModel?>(
      stream: _otherUserStream,
      builder: (context, userSnapshot) {
        final liveOtherUser = userSnapshot.data ?? otherUser;
        final liveUsername = liveOtherUser?.username ?? fallbackUsername;
        final otherUsername = liveUsername;
        final livePic = liveOtherUser?.profilePicUrl ?? fallbackPic;
        final liveOnline = liveOtherUser?.isOnline ?? false;
        final liveLastSeen = liveOtherUser?.lastSeen ?? otherUser?.lastSeen;

        final bool isOtherTyping;
        final isTypingInModel =
            liveOtherUser?.isUserTypingInConnection(widget.connection.id) ??
                false;
        final isTypingInProvider =
            chatProv.isUserTyping(widget.connection.id, otherUserId);

        if (isTypingInModel) {
          isOtherTyping = true;
          final updatedAt = liveOtherUser?.typingUpdatedAt;
          if (updatedAt != null) {
            final elapsedMs =
                DateTime.now().difference(updatedAt).inMilliseconds;
            final remainingMs = 5000 - elapsedMs;
            if (remainingMs > 0) {
              _otherUserTypingExpirationTimer?.cancel();
              _otherUserTypingExpirationTimer =
                  Timer(Duration(milliseconds: remainingMs + 50), () {
                if (mounted) setState(() {});
              });
            }
          }
        } else if (isTypingInProvider) {
          isOtherTyping = true;
        } else {
          isOtherTyping = false;
          _otherUserTypingExpirationTimer?.cancel();
        }

        final isMascot = livePic.startsWith('crushie_avatar_');
        final mascotIdx = isMascot
            ? (int.tryParse(livePic.replaceAll('crushie_avatar_', '')) ?? 0)
            : 0;

        return Scaffold(
          resizeToAvoidBottomInset: true,
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
                      backgroundImage: CachedNetworkImageProvider(livePic),
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
                                '@$liveUsername',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (liveOtherUser?.isVerified ?? false) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  color: AppColors.verifiedBlue, size: 14),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (isOtherTyping)
                          const Text(
                            'typing...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          StatusBadge(
                            isOnline: liveOnline,
                            lastSeen: liveLastSeen,
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
                          content: Text('Notifications muted for @$liveUsername')),
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
          // Unlocked Contact Method Card (Handled for blocked state and authorization)
          ContactRevealCard(
            contactMethod: widget.connection.recipientContactMethod,
            contactDetails: widget.connection.recipientContactDetails,
            username: otherUsername,
            isBlocked: isBlocked,
            isPaid: widget.connection.isPaid && widget.connection.senderId == activeUserId,
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
              key: ValueKey('$_streamConnectionId-$_streamRetryCounter'),
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint(
                      '[CHAT_SCREEN] Live messages stream error for connection ${widget.connection.id}: ${snapshot.error}');
                }
                // If waiting for first network response and no cached messages, show loading spinner
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData &&
                    messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError && messages.isEmpty) {
                  _logDiagnostic(
                    operation: 'messagesStream_empty',
                    connectionId: widget.connection.id,
                    error: snapshot.error,
                  );
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 44, color: Colors.red.shade400),
                          const SizedBox(height: 10),
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
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.bug_report,
                                        size: 14, color: Colors.red),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'DIAGNOSTIC [${_categorizeDiagnosticError(snapshot.error)}]',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDiagnosticDetail(snapshot.error),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.redAccent),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Path: connections/${_redactConnectionId(widget.connection.id)}/messages',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              _hasInitiallyScrolledToBottom = false;
                              _lastRenderedMessageCount = 0;
                              _streamRetryCounter++;
                              _initMessagesStream(force: true);
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

                // Abnormal stream completion without data or messages
                if (snapshot.connectionState == ConnectionState.done &&
                    !snapshot.hasData &&
                    !snapshot.hasError &&
                    messages.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_problem_rounded,
                              size: 44, color: Colors.orange.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'Connection interrupted',
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
                            'Live stream closed unexpectedly. Tap to reconnect.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              _hasInitiallyScrolledToBottom = false;
                              _lastRenderedMessageCount = 0;
                              _streamRetryCounter++;
                              _initMessagesStream(force: true);
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reconnect'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final targetId = widget.connection.id;
                final List<ChatMessageModel>? streamMsgs =
                    snapshot.hasData && snapshot.data != null
                        ? snapshot.data!
                            .where((m) =>
                                m.connectionId == targetId ||
                                m.connectionId.isEmpty)
                            .toList()
                        : null;

                if (streamMsgs != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _streamConnectionId == widget.connection.id) {
                      chatProv.syncMessages(widget.connection.id, streamMsgs);
                      final unreadIncoming = streamMsgs.where((m) =>
                          (m.recipientId == activeUserId ||
                              (m.senderId.isNotEmpty &&
                                  m.senderId != activeUserId)) &&
                          !m.isRead);
                      if (unreadIncoming.isNotEmpty) {
                        final unreadIds =
                            unreadIncoming.map((m) => m.id).toSet();
                        final unreadInProvider = chatProv
                            .getMessagesForConnection(widget.connection.id)
                            .where((m) => unreadIds.contains(m.id) && !m.isRead);
                        if (unreadInProvider.isNotEmpty) {
                          _markAsRead();
                        }
                      }
                    }
                  });
                }

                final displayMessages = chatProv.getMergedMessages(
                  widget.connection.id,
                  streamMessages: streamMsgs,
                  userId: activeUserId,
                );

                if (displayMessages.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || !_scrollController.hasClients) return;
                    if (!_hasInitiallyScrolledToBottom) {
                      _scrollToBottom(animate: false);
                      _hasInitiallyScrolledToBottom = true;
                      _lastRenderedMessageCount = displayMessages.length;
                    } else if (displayMessages.length > _lastRenderedMessageCount) {
                      final isNearBottom =
                          (_scrollController.position.maxScrollExtent -
                                  _scrollController.position.pixels) <=
                              300;
                      if (isNearBottom) {
                        _scrollToBottom(animate: true);
                      }
                      _lastRenderedMessageCount = displayMessages.length;
                    }
                  });
                }

                if (displayMessages.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Text(
                        'No messages yet. Say hi to @$liveUsername!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    if (snapshot.hasError)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Unable to update live messages',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _hasInitiallyScrolledToBottom = false;
                                    _lastRenderedMessageCount = 0;
                                    _streamRetryCounter++;
                                    _initMessagesStream(force: true);
                                    setState(() {});
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Retry',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 24, top: 4, bottom: 2),
                              child: Text(
                                '[DEV DIAGNOSTIC] [${_categorizeDiagnosticError(snapshot.error)}] ${_formatDiagnosticDetail(snapshot.error)}\nPath: connections/${_redactConnectionId(widget.connection.id)}/messages',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_diagnosticMarkAsReadError != null)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mark_chat_read_outlined,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '[DEV DIAGNOSTIC: MarkAsRead] $_diagnosticMarkAsReadError\nPath: connections/${_redactConnectionId(widget.connection.id)}/messages',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.amber),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_diagnosticPaginationError != null)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history_toggle_off,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '[DEV DIAGNOSTIC: Pagination] $_diagnosticPaginationError\nPath: connections/${_redactConnectionId(widget.connection.id)}/messages',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: displayMessages.length +
                            (chatProv.isLoadingOlderMessages(widget.connection.id)
                                ? 1
                                : 0),
                        itemBuilder: (ctx, i) {
                          if (chatProv.isLoadingOlderMessages(widget.connection.id)) {
                            if (i == 0) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            i -= 1;
                          }
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
                                    DateFormat('h:mm a')
                                        .format(msg.timestamp.toLocal()),
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
                ),
              ),
            ],
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
                      '@$liveUsername is typing...',
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
          SafeArea(
            top: false,
            child: !isBlocked
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                            onChanged: (v) => _onTextChanged(
                                v, widget.connection.id, activeUserId),
                            decoration: InputDecoration(
                              hintText: 'Type a message to @$liveUsername...',
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
                              final messenger = ScaffoldMessenger.maybeOf(context);
                              final text = _msgController.text.trim();
                              final mediaFile = _attachedMediaFile;
                              if (text.isNotEmpty || mediaFile != null) {
                                _msgController.clear();
                                setState(() {
                                  _attachedMediaFile = null;
                                });
                                _typingTimer?.cancel();
                                chatProv.setTypingStatus(
                                    widget.connection.id, activeUserId, false);

                                String? mediaUrl;
                                if (mediaFile != null) {
                                  try {
                                    mediaUrl =
                                        await StorageService().uploadChatPhoto(
                                      connectionId: widget.connection.id,
                                      userId: activeUserId,
                                      file: mediaFile,
                                    );
                                  } catch (e) {
                                    debugPrint(
                                        '[CHAT_SCREEN] Error uploading chat photo: $e');
                                    if (mounted) {
                                      messenger?.showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Failed to upload image: $e')),
                                      );
                                    }
                                    return;
                                  }
                                }

                                chatProv.sendMessage(
                                  connectionId: widget.connection.id,
                                  senderId: activeUserId,
                                  recipientId: otherUserId,
                                  text: text.isNotEmpty
                                      ? text
                                      : '📷 Photo attachment',
                                  mediaUrl: mediaUrl,
                                ).catchError((e) {
                                  _logDiagnostic(
                                    operation: 'sendMessage',
                                    connectionId: widget.connection.id,
                                    error: e,
                                  );
                                  if (mounted) {
                                    messenger?.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '[DEV DIAGNOSTIC] Send failed [${_categorizeDiagnosticError(e)}]: ${_formatDiagnosticDetail(e)}'),
                                        backgroundColor: Colors.red.shade700,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                });
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
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
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
                                style: TextStyle(
                                    fontSize: 11.5, color: Colors.grey),
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
          ),
        ],
      ),
    );
      },
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
              final messenger = ScaffoldMessenger.maybeOf(context);
              Navigator.pop(ctx);
              chatProv
                  .deleteMessageForMe(
                      widget.connection.id, message.id, currentUserId)
                  .catchError((e) {
                if (mounted) {
                  messenger?.showSnackBar(
                    SnackBar(content: Text('Failed to delete message: $e')),
                  );
                }
              });
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete for Everyone'),
              subtitle: const Text('Remove this message from both sides'),
              onTap: () {
                final messenger = ScaffoldMessenger.maybeOf(context);
                Navigator.pop(ctx);
                chatProv
                    .deleteMessageForEveryone(widget.connection.id, message.id)
                    .catchError((e) {
                  if (mounted) {
                    messenger?.showSnackBar(
                      SnackBar(content: Text('Failed to delete message: $e')),
                    );
                  }
                });
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
