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

  List<ChatMessageModel> getMessagesForConnection(String connectionId) {
    return _db.getChatMessages(connectionId);
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
}
