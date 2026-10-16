import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final FirestoreService _firestoreService = FirestoreService();

  final Map<String, List<ChatMessageModel>> _messagesByConnection = {};

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

  List<ChatMessageModel> getMessagesForConnection(String connectionId,
      {String? userId}) {
    final cached = _messagesByConnection[connectionId];
    final list = cached ?? _db.getChatMessages(connectionId, userId: userId);
    if (userId != null) {
      return list.where((m) => !m.deletedForUserIds.contains(userId)).toList();
    }
    return list;
  }

  Stream<List<ChatMessageModel>> getChatMessagesStream(String connectionId,
      {int limit = 50}) {
    return _firestoreService.getMessagesStream(connectionId, limit: limit);
  }

  void syncMessages(
      String connectionId, List<ChatMessageModel> incomingMessages) {
    final existing = _messagesByConnection[connectionId] ?? [];
    final Map<String, ChatMessageModel> deduplicated = {};
    for (final m in incomingMessages) {
      deduplicated[m.id] = m;
    }
    for (final m in existing) {
      if (!deduplicated.containsKey(m.id)) {
        deduplicated[m.id] = m;
      }
    }
    final merged = deduplicated.values.toList();
    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (existing.length == merged.length &&
        existing.isNotEmpty &&
        merged.isNotEmpty &&
        existing.last.id == merged.last.id &&
        existing.first.id == merged.first.id) {
      return;
    }

    _messagesByConnection[connectionId] = merged;
    notifyListeners();
  }

  Future<void> sendMessage({
    required String connectionId,
    required String senderId,
    required String recipientId,
    required String text,
    String? mediaUrl,
  }) async {
    if (text.trim().isEmpty && (mediaUrl == null || mediaUrl.isEmpty)) return;

    final msg = ChatMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      connectionId: connectionId,
      senderId: senderId,
      recipientId: recipientId,
      message: text.trim(),
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
      deliveryStatus: MessageDeliveryStatus.sent,
    );

    // Optimistic local update
    final current =
        List<ChatMessageModel>.from(_messagesByConnection[connectionId] ?? []);
    current.add(msg);
    _messagesByConnection[connectionId] = current;
    _db.sendChatMessage(msg);
    notifyListeners();

    // Persist to Cloud Firestore
    try {
      await _firestoreService.sendChatMessage(msg);
    } catch (e) {
      debugPrint(
          '[CHAT_PROVIDER] Failed to send chat message to Firestore: $e');
      // Revert optimistic addition on failure to prevent false success reporting
      final reverted = List<ChatMessageModel>.from(
          _messagesByConnection[connectionId] ?? []);
      reverted.removeWhere((m) => m.id == msg.id);
      _messagesByConnection[connectionId] = reverted;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(
      String connectionId, String currentUserId) async {
    final current = _messagesByConnection[connectionId];
    if (current != null) {
      bool changed = false;
      for (int i = 0; i < current.length; i++) {
        final m = current[i];
        if (m.recipientId == currentUserId && !m.isRead) {
          current[i] = m.copyWith(
            isRead: true,
            deliveryStatus: MessageDeliveryStatus.read,
          );
          changed = true;
        }
      }
      if (changed) notifyListeners();
    }
    _db.markMessagesAsRead(connectionId, currentUserId);
    try {
      await _firestoreService.markMessagesAsRead(connectionId, currentUserId);
    } catch (e) {
      debugPrint(
          '[CHAT_PROVIDER] Failed to mark messages as read in Firestore: $e');
    }
  }

  Future<void> deleteMessageForMe(
      String connectionId, String messageId, String userId) async {
    _db.deleteMessageForMe(messageId, userId);
    try {
      await _firestoreService.deleteMessageForMe(
          connectionId, messageId, userId);
    } catch (e) {
      debugPrint(
          '[CHAT_PROVIDER] Failed to delete message for me in Firestore: $e');
    }
  }

  Future<void> deleteMessageForEveryone(
      String connectionId, String messageId) async {
    _db.deleteMessageForEveryone(messageId);
    try {
      await _firestoreService.deleteMessageForEveryone(connectionId, messageId);
    } catch (e) {
      debugPrint(
          '[CHAT_PROVIDER] Failed to delete message for everyone in Firestore: $e');
    }
  }

  void clearConversation(String connectionId, String userId) {
    _db.clearConversation(connectionId, userId);
    _messagesByConnection.remove(connectionId);
    notifyListeners();
  }

  void deleteConversation(String connectionId, String userId) {
    _db.deleteConversation(connectionId, userId);
    _messagesByConnection.remove(connectionId);
    notifyListeners();
  }

  void setTypingStatus(String connectionId, String userId, bool isTyping) {
    _db.setTypingStatus(connectionId, userId, isTyping);
  }

  bool isUserTyping(String connectionId, String userId) {
    return _db.isUserTyping(connectionId, userId);
  }

  /// Clears in-memory message caches upon logout to ensure account isolation.
  void clear() {
    _messagesByConnection.clear();
    notifyListeners();
  }
}
