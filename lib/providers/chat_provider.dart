import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseService _db;
  final FirestoreService _firestoreService;

  final Map<String, List<ChatMessageModel>> _messagesByConnection = {};
  final Map<String, Set<String>> _localDeletedForMeByMessageId = {};
  final Set<String> _localDeletedForEveryoneMessageIds = {};
  final Map<String, bool> _hasMoreOlderMessages = {};
  final Map<String, bool> _isLoadingOlderMessages = {};


  bool hasMoreOlderMessages(String connectionId) =>
      _hasMoreOlderMessages[connectionId] ?? true;

  bool isLoadingOlderMessages(String connectionId) =>
      _isLoadingOlderMessages[connectionId] ?? false;

  ChatProvider({DatabaseService? db, FirestoreService? firestoreService})
      : _db = db ?? DatabaseService(),
        _firestoreService = firestoreService ?? FirestoreService() {
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

  /// Returns the merged, deduplicated, correctly sorted list of messages for a connection,
  /// preserving in-flight optimistic messages, persistent read states, and deletion flags
  /// when the Firestore stream snapshot is older or arrives out-of-order.
  List<ChatMessageModel> getMergedMessages(
    String connectionId, {
    List<ChatMessageModel>? streamMessages,
    String? userId,
  }) {
    final existing = _messagesByConnection[connectionId] ??
        _db.getChatMessages(connectionId, userId: userId);
    final Map<String, ChatMessageModel> existingMap = {
      for (final m in existing) m.id: m,
    };
    final Map<String, ChatMessageModel> deduplicated = {};
    if (streamMessages != null) {
      for (final m in streamMessages) {
        // Phase 1A: accept messages belonging to this connection. After the
        // fromMap connectionIdFallback fix, legacy docs without a body field
        // will have connectionId == connectionId (resolved from path). We
        // still guard against messages from a different connection ID.
        if (m.connectionId == connectionId || m.connectionId.isEmpty) {
          final existingMsg = existingMap[m.id];
          if (existingMsg != null) {
            // Reconcile and preserve monotonic read states
            final bool effectiveIsRead = m.isRead || existingMsg.isRead;
            final MessageDeliveryStatus effectiveStatus =
                (effectiveIsRead && m.deliveryStatus != MessageDeliveryStatus.read)
                    ? MessageDeliveryStatus.read
                    : m.deliveryStatus;
            final localDeleted = _localDeletedForMeByMessageId[m.id];
            final List<String> effectiveDeletedFor;
            if (localDeleted != null && localDeleted.isNotEmpty) {
              effectiveDeletedFor =
                  {...m.deletedForUserIds, ...localDeleted}.toList();
            } else {
              effectiveDeletedFor = m.deletedForUserIds;
            }
            final bool effectiveDeletedEveryone =
                m.isDeletedForEveryone ||
                existingMsg.isDeletedForEveryone ||
                _localDeletedForEveryoneMessageIds.contains(m.id);
            final String effectiveContent = effectiveDeletedEveryone
                ? 'This message was deleted'
                : (m.content.isNotEmpty ? m.content : existingMsg.content);

            deduplicated[m.id] = m.copyWith(
              isRead: effectiveIsRead,
              deliveryStatus: effectiveStatus,
              deletedForUserIds: effectiveDeletedFor,
              isDeletedForEveryone: effectiveDeletedEveryone,
              content: effectiveContent,
            );
          } else {
            deduplicated[m.id] = m;
          }
        }
      }
    }
    for (final m in existing) {
      if ((m.connectionId == connectionId || m.connectionId.isEmpty) &&
          !deduplicated.containsKey(m.id)) {
        deduplicated[m.id] = m;
      }
    }
    final merged = deduplicated.values.toList();
    merged.sort((a, b) {
      final cmp = a.timestamp.compareTo(b.timestamp);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
    if (userId != null) {
      return merged.where((m) => !m.deletedForUserIds.contains(userId)).toList();
    }
    return merged;
  }

  Stream<List<ChatMessageModel>> getChatMessagesStream(String connectionId,
      {int limit = 50}) {
    return _firestoreService.getMessagesStream(connectionId, limit: limit);
  }

  /// Loads older messages using cursor-based pagination and merges them with existing conversation state.
  Future<List<ChatMessageModel>> loadOlderMessages(
    String connectionId, {
    int limit = 50,
    String? userId,
  }) async {
    if (_isLoadingOlderMessages[connectionId] == true) {
      return getMessagesForConnection(connectionId, userId: userId);
    }
    if (_hasMoreOlderMessages[connectionId] == false) {
      return getMessagesForConnection(connectionId, userId: userId);
    }

    final currentMessages = _messagesByConnection[connectionId] ??
        _db.getChatMessages(connectionId, userId: userId);
    if (currentMessages.isEmpty) {
      return [];
    }

    final oldestMessage = currentMessages.first;

    _isLoadingOlderMessages[connectionId] = true;
    notifyListeners();

    try {
      final olderMessages = await _firestoreService.fetchOlderMessages(
        connectionId: connectionId,
        oldestMessage: oldestMessage,
        limit: limit,
      );

      if (olderMessages.length < limit) {
        _hasMoreOlderMessages[connectionId] = false;
      }

      if (olderMessages.isNotEmpty) {
        final Map<String, ChatMessageModel> mergedMap = {
          for (final m in olderMessages) m.id: m,
        };
        for (final m in currentMessages) {
          if (!mergedMap.containsKey(m.id)) {
            mergedMap[m.id] = m;
          }
        }

        final mergedList = mergedMap.values.toList();
        mergedList.sort((a, b) {
          final cmp = a.timestamp.compareTo(b.timestamp);
          if (cmp != 0) return cmp;
          return a.id.compareTo(b.id);
        });

        _messagesByConnection[connectionId] = mergedList;
        _db.setChatMessagesForConnection(connectionId, mergedList);
      }

      _isLoadingOlderMessages[connectionId] = false;
      notifyListeners();
      return getMessagesForConnection(connectionId, userId: userId);
    } catch (e) {
      _isLoadingOlderMessages[connectionId] = false;
      notifyListeners();
      debugPrint('[CHAT_PROVIDER] Error loading older messages: $e');
      rethrow;
    }
  }

  void syncMessages(
      String connectionId, List<ChatMessageModel> incomingMessages) {
    final existing = _messagesByConnection[connectionId] ?? [];
    final Map<String, ChatMessageModel> existingMap = {
      for (final m in existing) m.id: m,
    };
    final Map<String, ChatMessageModel> deduplicated = {};
    for (final m in incomingMessages) {
      final existingMsg = existingMap[m.id];
      if (existingMsg != null) {
        // Reconcile and preserve monotonic read states
        final bool effectiveIsRead = m.isRead || existingMsg.isRead;
        final MessageDeliveryStatus effectiveStatus =
            (effectiveIsRead && m.deliveryStatus != MessageDeliveryStatus.read)
                ? MessageDeliveryStatus.read
                : m.deliveryStatus;
        final localDeleted = _localDeletedForMeByMessageId[m.id];
        final List<String> effectiveDeletedFor;
        if (localDeleted != null && localDeleted.isNotEmpty) {
          effectiveDeletedFor =
              {...m.deletedForUserIds, ...localDeleted}.toList();
        } else {
          effectiveDeletedFor = m.deletedForUserIds;
        }
        final bool effectiveDeletedEveryone =
            m.isDeletedForEveryone ||
            existingMsg.isDeletedForEveryone ||
            _localDeletedForEveryoneMessageIds.contains(m.id);
        final String effectiveContent = effectiveDeletedEveryone
            ? 'This message was deleted'
            : (m.content.isNotEmpty ? m.content : existingMsg.content);

        deduplicated[m.id] = m.copyWith(
          isRead: effectiveIsRead,
          deliveryStatus: effectiveStatus,
          deletedForUserIds: effectiveDeletedFor,
          isDeletedForEveryone: effectiveDeletedEveryone,
          content: effectiveContent,
        );
      } else {
        deduplicated[m.id] = m;
      }
    }
    for (final m in existing) {
      if (!deduplicated.containsKey(m.id)) {
        deduplicated[m.id] = m;
      }
    }
    final merged = deduplicated.values.toList();
    merged.sort((a, b) {
      final cmp = a.timestamp.compareTo(b.timestamp);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    if (existing.length == merged.length) {
      bool isIdentical = true;
      for (int i = 0; i < existing.length; i++) {
        final e = existing[i];
        final m = merged[i];
        if (e.id != m.id ||
            e.content != m.content ||
            e.mediaUrl != m.mediaUrl ||
            e.isRead != m.isRead ||
            e.deliveryStatus != m.deliveryStatus ||
            e.isDeletedForEveryone != m.isDeletedForEveryone ||
            !listEquals(e.deletedForUserIds, m.deletedForUserIds) ||
            e.timestamp != m.timestamp) {
          isIdentical = false;
          break;
        }
      }
      if (isIdentical) {
        return;
      }
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
      id: ChatMessageModel.generateMessageId(),
      connectionId: connectionId,
      senderId: senderId,
      recipientId: recipientId,
      message: text.trim(),
      mediaUrl: mediaUrl,
      timestamp: DateTime.now().toUtc(),
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
      _db.removeChatMessage(msg.id);
      final reverted = List<ChatMessageModel>.from(
          _messagesByConnection[connectionId] ?? []);
      reverted.removeWhere((m) => m.id == msg.id);
      _messagesByConnection[connectionId] = reverted;
      notifyListeners();
      rethrow;
    }
  }

  // Phase 2B (F-03): Two-flag mechanism to prevent silent drops and overlapping reads.
  // _pendingMarkAsRead: connection IDs currently awaiting a Firestore batch.
  // _needsReadDrain: connection IDs that received a new read trigger while the
  //   batch was in-flight and need a follow-up pass once the active one completes.
  final Set<String> _pendingMarkAsRead = {};
  final Map<String, bool> _needsReadDrain = {};

  Future<void> markMessagesAsRead(
      String connectionId, String currentUserId) async {
    // If a read operation is already in-flight for this connection, record that
    // a drain pass is needed rather than silently discarding the trigger.
    if (_pendingMarkAsRead.contains(connectionId)) {
      _needsReadDrain[connectionId] = true;
      return;
    }

    final current = _messagesByConnection[connectionId];
    final previous = current != null
        ? List<ChatMessageModel>.from(current)
        : List<ChatMessageModel>.from(_db.getChatMessages(connectionId));

    // Optimistic local update: mark messages addressed to currentUserId as read.
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

    _pendingMarkAsRead.add(connectionId);
    try {
      await _firestoreService.markMessagesAsRead(connectionId, currentUserId);
    } catch (e) {
      debugPrint(
          '[CHAT_PROVIDER] Failed to mark messages as read in Firestore: $e');
      final isNoApp = e.toString().contains('no-app') ||
          e.toString().contains('No Firebase App');
      if (!isNoApp) {
        // Rollback optimistic read state in memory and database.
        _messagesByConnection[connectionId] = previous;
        _db.setChatMessagesForConnection(connectionId, previous);
        notifyListeners();
        rethrow;
      }
    } finally {
      // Always release the mutex so subsequent calls can proceed.
      _pendingMarkAsRead.remove(connectionId);
    }

    // Drain pass: if a new read trigger arrived while the batch was in-flight,
    // run a single follow-up immediately now that the mutex is released.
    if (_needsReadDrain.remove(connectionId) == true) {
      debugPrint(
          '[CHAT_PROVIDER] Running drain read pass for connection: $connectionId');
      // Recursive call is safe: mutex is already cleared, and we never set
      // _needsReadDrain inside the recursive call unless another concurrent
      // trigger fires, which would again defer to the next drain cycle.
      await markMessagesAsRead(connectionId, currentUserId);
    }
  }


  Future<void> deleteMessageForMe(
      String connectionId, String messageId, String userId) async {
    final current = _messagesByConnection[connectionId];
    final previous = current != null
        ? List<ChatMessageModel>.from(current)
        : List<ChatMessageModel>.from(_db.getChatMessages(connectionId));

    // 1. Optimistic update in ChatProvider cache and tracking
    _localDeletedForMeByMessageId
        .putIfAbsent(messageId, () => <String>{})
        .add(userId);
    if (current != null) {
      final index = current.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final msg = current[index];
        if (!msg.deletedForUserIds.contains(userId)) {
          final updatedDeleted = List<String>.from(msg.deletedForUserIds)..add(userId);
          current[index] = msg.copyWith(deletedForUserIds: updatedDeleted);
          notifyListeners();
        }
      }
    }
    _db.deleteMessageForMe(messageId, userId);
    try {
      await _firestoreService.deleteMessageForMe(
          connectionId, messageId, userId);
    } catch (e) {
      debugPrint(
          '[CHAT_PROVIDER] Failed to delete message for me in Firestore: $e');
      final isNoApp =
          e.toString().contains('no-app') || e.toString().contains('No Firebase App');
      if (!isNoApp) {
        _localDeletedForMeByMessageId[messageId]?.remove(userId);
        _messagesByConnection[connectionId] = previous;
        _db.setChatMessagesForConnection(connectionId, previous);
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> deleteMessageForEveryone(
      String connectionId, String messageId) async {
    final current = _messagesByConnection[connectionId];
    final previous = current != null
        ? List<ChatMessageModel>.from(current)
        : List<ChatMessageModel>.from(_db.getChatMessages(connectionId));

    // 1. Optimistic update in ChatProvider cache and tracking
    _localDeletedForEveryoneMessageIds.add(messageId);
    if (current != null) {
      final index = current.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        current[index] = current[index].copyWith(
          isDeletedForEveryone: true,
          content: 'This message was deleted',
        );
        notifyListeners();
      }
    }
    _db.deleteMessageForEveryone(messageId);
    try {
      await _firestoreService.deleteMessageForEveryone(connectionId, messageId);
    } catch (e) {
      debugPrint(
          '[CHAT_PROVIDER] Failed to delete message for everyone in Firestore: $e');
      final isNoApp =
          e.toString().contains('no-app') || e.toString().contains('No Firebase App');
      if (!isNoApp) {
        _localDeletedForEveryoneMessageIds.remove(messageId);
        _messagesByConnection[connectionId] = previous;
        _db.setChatMessagesForConnection(connectionId, previous);
        notifyListeners();
        rethrow;
      }
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

  DateTime? _lastTypingWriteTime;
  String? _lastTypingConnectionId;

  void setTypingStatus(String connectionId, String userId, bool isTyping) {
    _db.setTypingStatus(connectionId, userId, isTyping);

    final now = DateTime.now();
    if (isTyping) {
      if (_lastTypingConnectionId != connectionId ||
          _lastTypingWriteTime == null ||
          now.difference(_lastTypingWriteTime!).inSeconds >= 3) {
        _lastTypingWriteTime = now;
        _lastTypingConnectionId = connectionId;
        _firestoreService.setUserTyping(userId, connectionId).catchError((_) {});
      }
    } else {
      _lastTypingConnectionId = null;
      _lastTypingWriteTime = null;
      _firestoreService.setUserTyping(userId, null).catchError((_) {});
    }
  }

  bool isUserTyping(String connectionId, String userId) {
    return _db.isUserTyping(connectionId, userId);
  }

  /// Clears in-memory message caches upon logout to ensure account isolation.
  void clear() {
    _lastTypingConnectionId = null;
    _lastTypingWriteTime = null;
    _messagesByConnection.clear();
    _pendingMarkAsRead.clear();
    _needsReadDrain.clear();
    _localDeletedForMeByMessageId.clear();
    _localDeletedForEveryoneMessageIds.clear();
    _lastTypingConnectionId = null;
    _lastTypingWriteTime = null;
    notifyListeners();
  }

}
