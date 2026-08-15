import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../services/database_service.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  ChatProvider() {
    _db.addListener(_onDbChanged);
  }

  void _onDbChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChanged);
    super.dispose();
  }

  List<ChatMessageModel> getMessagesForConnection(String connectionId, {String? userId}) {
    return _db.getChatMessages(connectionId, userId: userId);
  }

  void sendMessage({
    required String connectionId,
    required String senderId,
    required String recipientId,
    required String text,
  }) {
    if (text.trim().isEmpty) return;

    final msg = ChatMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      connectionId: connectionId,
      senderId: senderId,
      recipientId: recipientId,
      message: text.trim(),
      timestamp: DateTime.now(),
    );

    _db.sendChatMessage(msg);
  }

  void markMessagesAsRead(String connectionId, String currentUserId) {
    _db.markMessagesAsRead(connectionId, currentUserId);
  }

  void deleteMessageForMe(String messageId, String userId) {
    _db.deleteMessageForMe(messageId, userId);
  }

  void deleteMessageForEveryone(String messageId) {
    _db.deleteMessageForEveryone(messageId);
  }

  void clearConversation(String connectionId, String userId) {
    _db.clearConversation(connectionId, userId);
  }

  void deleteConversation(String connectionId, String userId) {
    _db.deleteConversation(connectionId, userId);
  }

  void setTypingStatus(String connectionId, String userId, bool isTyping) {
    _db.setTypingStatus(connectionId, userId, isTyping);
  }

  bool isUserTyping(String connectionId, String userId) {
    return _db.isUserTyping(connectionId, userId);
  }
}
