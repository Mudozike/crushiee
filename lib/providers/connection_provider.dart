import 'dart:async';
import 'package:flutter/material.dart';
import '../models/connection_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/paystack_service.dart';
import '../screens/premium/premium_subscription_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../config/app_colors.dart';

class ConnectionProvider extends ChangeNotifier {
  final DatabaseService _db;
  final FirestoreService _firestoreService;

  ConnectionProvider({
    DatabaseService? db,
    FirestoreService? firestoreService,
  })  : _db = db ?? DatabaseService(),
        _firestoreService = firestoreService ?? FirestoreService();

  List<ConnectionModel> _firestoreConnections = [];
  List<ConnectionModel> get connections {
    if (_currentUserId == null) return [];
    return _firestoreConnections.isNotEmpty
        ? _firestoreConnections
        : _db.connections;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  StreamSubscription<List<ConnectionModel>>? _subscription;
  String? _currentUserId;

  // Phase 2C (F-02): Local read-zero override registry.
  // Key: connectionId. Value: server lastMessageTimestamp at the time the user
  // opened the chat (captured from the existing connection model).
  // When a stream snapshot arrives with unreadCount > 0 for this user, we check
  // whether the connection's lastMessageTimestamp is still the same as the value
  // we recorded — meaning no genuinely new message arrived — and if so we
  // override the stream count to 0 locally.
  // When lastMessageTimestamp advances (new message from other party), we
  // remove the override and let the stream count through.
  //
  // LIMITATION: This heuristic relies on the connection document's
  // lastMessageTimestamp, which is written server-side as part of message send.
  // It cannot guarantee correctness when both a new message and a read happen
  // within the same server timestamp window, or across devices where the local
  // read has not yet propagated. Do not claim this is race-free across devices.
  final Map<String, DateTime?> _localReadZeroByConnection = {};


  void initUserConnections(String userId) {
    if (userId.trim().isEmpty) return;
    if (_currentUserId == userId && _subscription != null) return;
    _currentUserId = userId;
    _subscription?.cancel();
    _isLoading = true;

    try {
      _subscription =
          _firestoreService.getUserConnectionsStream(userId).listen((data) {
        // De-duplicate connections by other participant ID to guarantee unique inbox rows
        final Map<String, ConnectionModel> uniqueByOtherUser = {};
        for (final conn in data) {
          final otherId =
              conn.senderId == userId ? conn.receiverId : conn.senderId;
          if (!uniqueByOtherUser.containsKey(otherId)) {
            uniqueByOtherUser[otherId] = conn;
          } else {
            final existing = uniqueByOtherUser[otherId]!;
            final timeExisting =
                existing.lastMessageTimestamp ?? existing.updatedAt;
            final timeConn = conn.lastMessageTimestamp ?? conn.updatedAt;
            if (timeConn.isAfter(timeExisting)) {
              uniqueByOtherUser[otherId] = conn;
            }
          }
        }
        final list = uniqueByOtherUser.values.map((conn) {
          // Phase 2C: apply local read-zero override if the connection's
          // lastMessageTimestamp has not advanced past the recorded value.
          final userId = _currentUserId;
          if (userId != null &&
              _localReadZeroByConnection.containsKey(conn.id)) {
            final recordedTimestamp = _localReadZeroByConnection[conn.id];
            final currentTimestamp =
                conn.lastMessageTimestamp ?? conn.updatedAt;
            // If the server timestamp is the same as when we read (or earlier),
            // no new message has arrived; preserve the local zero.
            if (recordedTimestamp != null &&
                !currentTimestamp.isAfter(recordedTimestamp)) {
              if (conn.unreadCountForUser(userId) > 0) {
                final overridden = Map<String, int>.from(conn.unreadCounts);
                overridden[userId] = 0;
                return conn.copyWith(unreadCounts: overridden);
              }
              return conn;
            } else {
              // New message arrived — remove override and accept stream count.
              _localReadZeroByConnection.remove(conn.id);
            }
          }
          return conn;
        }).toList();

        list.sort((a, b) {
          final timeA = a.lastMessageTimestamp ?? a.updatedAt;
          final timeB = b.lastMessageTimestamp ?? b.updatedAt;
          final cmp = timeB.compareTo(timeA);
          if (cmp != 0) return cmp;
          return b.id.compareTo(a.id);
        });
        _firestoreConnections = list;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        debugPrint('[CONN_PROVIDER] Error in user connections stream: $e');
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[CONN_PROVIDER] Error starting connections stream: $e');
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Cancels active connection subscription and clears cached connections on logout.
  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _currentUserId = null;
    _firestoreConnections = [];
    _localReadZeroByConnection.clear();
    _isLoading = false;
    notifyListeners();
  }


  /// Optimistically clears unread badge for a connection locally when user views the chat.
  /// Records the connection's current lastMessageTimestamp so stale snapshots
  /// arriving later can be suppressed (Phase 2C).
  void markConnectionAsReadLocally(String connectionId, String userId) {
    bool changed = false;
    for (int i = 0; i < _firestoreConnections.length; i++) {
      final conn = _firestoreConnections[i];
      if (conn.id == connectionId) {
        if (conn.unreadCountForUser(userId) > 0) {
          final updatedUnreads = Map<String, int>.from(conn.unreadCounts);
          updatedUnreads[userId] = 0;
          _firestoreConnections[i] =
              conn.copyWith(unreadCounts: updatedUnreads);
          changed = true;
        }
        // Record the lastMessageTimestamp at the time of the read so Phase 2C
        // can distinguish stale snapshots from genuinely new messages.
        _localReadZeroByConnection[connectionId] =
            conn.lastMessageTimestamp ?? conn.updatedAt;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }


  List<ConnectionModel> getAcceptedConnections(String userId) {
    initUserConnections(userId);
    if (_firestoreConnections.isNotEmpty) {
      return _firestoreConnections;
    }
    return _db.connections;
  }

  List<ConnectionModel> getPendingRequestsForUser(String userId) {
    initUserConnections(userId);
    return [];
  }

  Future<ConnectionModel> _persistOrRecoverConnection({
    required ConnectionModel newConn,
    required String senderId,
    required String recipientId,
  }) async {
    try {
      await _firestoreService.saveConnection(newConn);
      return newConn;
    } catch (e) {
      // Handle the expected Firestore permission-denied or already-existing-conversation scenario safely.
      // Re-query the canonical conversation after the initial write fails.
      try {
        final existing = await _firestoreService.findExistingConnection(
            senderId, recipientId);
        if (existing != null &&
            existing.id.isNotEmpty &&
            existing.participants.contains(senderId) &&
            existing.participants.contains(recipientId)) {
          debugPrint(
              '[CONNECTION_PROVIDER] Concurrent connection detected. Reusing existing canonical connection: ${existing.id}');
          return existing;
        }
      } catch (_) {
        // Fall through to rethrow the original error 'e'
      }
      // Rethrow unrelated errors instead of hiding them
      rethrow;
    }
  }

  // CONNECT BUTTON Flow:
  // Step 1: Premium User -> Create Connection -> Open Messages (FREE, UNLIMITED)
  // Step 2: Free User (Under 10/day AND under 60/month) -> Create Connection -> Open Messages (FREE)
  // Step 3: Free User (Hit 10/day or 60/month Limit) -> Show Payment Popup:
  //         [Pay KES 50] -> Create Connection -> Open Messages
  //         [Upgrade to Premium - KES 200/mo] -> Navigate to Premium Screen
  Future<ConnectionModel?> initiateConnect({
    required BuildContext context,
    required UserModel sender,
    required UserModel recipient,
    String? postId,
    bool autoNavigateToChat = true,
  }) async {
    if (sender.id == recipient.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("You cannot connect with your own profile!")),
      );
      return null;
    }

    initUserConnections(sender.id);

    // 1. Check existing in-memory connections
    ConnectionModel? existing = connections.firstWhere(
      (c) =>
          (c.senderId == sender.id && c.receiverId == recipient.id) ||
          (c.senderId == recipient.id && c.receiverId == sender.id) ||
          c.id == ConnectionModel.getConversationId(sender.id, recipient.id),
      orElse: () => ConnectionModel(
        id: '',
        senderId: '',
        senderUsername: '',
        senderProfilePic: '',
        receiverId: '',
        receiverUsername: '',
        receiverProfilePic: '',
      ),
    );

    // 2. If not found in memory, check Firestore (canonical and legacy)
    if (existing.id.isEmpty) {
      existing = await _firestoreService.findExistingConnection(
          sender.id, recipient.id);
    }

    if (existing != null && existing.id.isNotEmpty) {
      if (autoNavigateToChat && context.mounted) {
        _navigateToChat(context, existing);
      }
      return existing;
    }

    final canonicalId =
        ConnectionModel.getConversationId(sender.id, recipient.id);

    // STEP 1: Check if Premium
    final isPremium = sender.isPremium &&
        (sender.premiumExpiry == null ||
            sender.premiumExpiry!.isAfter(DateTime.now()));
    if (isPremium) {
      final newConn = ConnectionModel(
        id: canonicalId,
        senderId: sender.id,
        senderUsername: sender.username,
        senderProfilePic: sender.profilePicUrl,
        receiverId: recipient.id,
        receiverUsername: recipient.username,
        receiverProfilePic: recipient.profilePicUrl,
        postId: postId,
        isPaid: false,
        amount: 0,
      );

      ConnectionModel connToUse;
      bool isExisting = false;
      try {
        connToUse = await _persistOrRecoverConnection(
          newConn: newConn,
          senderId: sender.id,
          recipientId: recipient.id,
        );
        isExisting = (connToUse.id == newConn.id &&
            connToUse.senderId != newConn.senderId);
      } catch (e) {
        debugPrint('[CONNECTION_PROVIDER] Error initiating connection: $e');
        rethrow;
      }

      if (!isExisting) {
        _db.incrementUserConnectionUsage(sender.id);
        final notif = NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          userId: recipient.id,
          fromUserId: sender.id,
          fromUsername: sender.username,
          fromUserProfilePic: sender.profilePicUrl,
          type: NotificationType.connectionRequest,
          title: 'New Connection!',
          body: '${sender.username} connected with you',
          connectionId: connToUse.id,
        );
        await _firestoreService.createNotification(notif).catchError((_) {});
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connected with @${recipient.username}!")),
        );

        if (autoNavigateToChat) {
          _navigateToChat(context, connToUse);
        }
      }
      return connToUse;
    }

    // STEP 2: Free User -> Check Daily (10) & Monthly (60) Limits
    final dailyUsage = sender.activeDailyConnections;
    final monthlyUsage = sender.activeMonthlyConnections;

    if (dailyUsage < 10 && monthlyUsage < 60) {
      final newConn = ConnectionModel(
        id: canonicalId,
        senderId: sender.id,
        senderUsername: sender.username,
        senderProfilePic: sender.profilePicUrl,
        receiverId: recipient.id,
        receiverUsername: recipient.username,
        receiverProfilePic: recipient.profilePicUrl,
        postId: postId,
        isPaid: false,
        amount: 0,
      );

      ConnectionModel connToUse;
      bool isExisting = false;
      try {
        connToUse = await _persistOrRecoverConnection(
          newConn: newConn,
          senderId: sender.id,
          recipientId: recipient.id,
        );
        isExisting = (connToUse.id == newConn.id &&
            connToUse.senderId != newConn.senderId);
      } catch (e) {
        debugPrint('[CONNECTION_PROVIDER] Error initiating connection: $e');
        rethrow;
      }

      if (!isExisting) {
        _db.incrementUserConnectionUsage(sender.id);
        final notif = NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          userId: recipient.id,
          fromUserId: sender.id,
          fromUsername: sender.username,
          fromUserProfilePic: sender.profilePicUrl,
          type: NotificationType.connectionRequest,
          title: 'New Connection!',
          body: '${sender.username} connected with you',
          connectionId: connToUse.id,
        );
        await _firestoreService.createNotification(notif).catchError((_) {});
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Connected with @${recipient.username}! (${dailyUsage + (isExisting ? 0 : 1)}/10 free today)")),
        );

        if (autoNavigateToChat) {
          _navigateToChat(context, connToUse);
        }
      }
      return connToUse;
    } else {
      // STEP 3: SHOW PAYMENT POPUP
      if (context.mounted) {
        _showLimitReachedPopup(context, sender, recipient, postId,
            autoNavigateToChat, canonicalId);
      }
      return null;
    }
  }

  void _showLimitReachedPopup(
    BuildContext context,
    UserModel sender,
    UserModel recipient,
    String? postId,
    bool autoNavigateToChat,
    String canonicalId,
  ) {
    final isDailyLimit = sender.activeDailyConnections >= 10;
    final limitMsg = isDailyLimit
        ? "You've used all 10 free connections today."
        : "You've used all 60 free connections this month.";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: const [
            Icon(Icons.lock_clock_outlined, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text('Connection Limit Reached',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              limitMsg,
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pay KES 50 to connect directly, or upgrade to Premium for unlimited free connections.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await PaystackService.showPaymentDialog(
                context: context,
                title: 'Pay KES 50 for Connection',
                description:
                    'Unlock direct connection & chat with @${recipient.username}',
                amountKES: 50.0,
                userEmail: sender.email,
              );

              if (res != null && res.success) {
                final tx = TransactionModel(
                  id: res.transactionId,
                  userId: sender.id,
                  type: 'connection',
                  amount: 50.0,
                  paymentMethod: res.paymentMethod,
                  paymentReference: res.transactionId,
                  status: 'completed',
                  metadata: {
                    'receiverId': recipient.id,
                    'postId': postId,
                  },
                );
                await _firestoreService.saveTransaction(tx);

                final newConn = ConnectionModel(
                  id: canonicalId,
                  senderId: sender.id,
                  senderUsername: sender.username,
                  senderProfilePic: sender.profilePicUrl,
                  receiverId: recipient.id,
                  receiverUsername: recipient.username,
                  receiverProfilePic: recipient.profilePicUrl,
                  postId: postId,
                  isPaid: true,
                  amount: 50,
                );

                ConnectionModel connToUse;
                bool isExisting = false;
                try {
                  connToUse = await _persistOrRecoverConnection(
                    newConn: newConn,
                    senderId: sender.id,
                    recipientId: recipient.id,
                  );
                  isExisting = (connToUse.id == newConn.id &&
                      connToUse.senderId != newConn.senderId);
                } catch (e) {
                  debugPrint(
                      '[CONNECTION_PROVIDER] Error saving paid connection: $e');
                  rethrow;
                }

                if (!isExisting) {
                  _db.incrementUserConnectionUsage(sender.id);
                  final notif = NotificationModel(
                    id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
                    userId: recipient.id,
                    fromUserId: sender.id,
                    fromUsername: sender.username,
                    fromUserProfilePic: sender.profilePicUrl,
                    type: NotificationType.connectionRequest,
                    title: 'New Connection!',
                    body: '${sender.username} connected with you',
                    connectionId: connToUse.id,
                  );
                  await _firestoreService
                      .createNotification(notif)
                      .catchError((_) {});
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text("Connected with @${recipient.username}!")),
                  );

                  if (autoNavigateToChat) {
                    _navigateToChat(context, connToUse);
                  }
                }
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Pay KES 50',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PremiumSubscriptionScreen(
                    onSubscriptionSuccess: () => Navigator.pop(context),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Upgrade to Premium - KES 200/mo',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToChat(BuildContext context, ConnectionModel connection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(connection: connection),
      ),
    );
  }

  Future<void> respondToConnectionRequest(
      String connectionId, ConnectionStatus status) async {
    ConnectionStatus? prevStatus;
    final existingIndex =
        _db.connections.indexWhere((c) => c.id == connectionId);
    if (existingIndex != -1) {
      prevStatus = _db.connections[existingIndex].status;
    }

    _db.respondToConnection(connectionId, status);
    notifyListeners();
    try {
      await _firestoreService.updateConnectionStatus(connectionId, status);
    } catch (e) {
      debugPrint(
          '[CONNECTION_PROVIDER] Error updating connection status in Firestore: $e');
      if (prevStatus != null && prevStatus != status) {
        _db.respondToConnection(connectionId, prevStatus);
        notifyListeners();
      }
      rethrow;
    }
  }
}
