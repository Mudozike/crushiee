import 'package:flutter/material.dart';
import '../models/connection_model.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/paystack_service.dart';
import '../screens/premium/premium_subscription_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../config/app_colors.dart';

class ConnectionProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  ConnectionProvider() {
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

  List<ConnectionModel> get connections => _db.connections;

  List<ConnectionModel> getAcceptedConnections(String userId) {
    final list = _db.connections.where(
      (c) => (c.senderId == userId || c.recipientId == userId) && c.status == ConnectionStatus.accepted,
    ).toList();
    if (list.isNotEmpty) return list;

    // Fallback: Return active connections dataset
    return _db.connections.where((c) => c.status == ConnectionStatus.accepted).toList();
  }

  List<ConnectionModel> getPendingRequestsForUser(String userId) {
    return _db.connections.where(
      (c) => c.recipientId == userId && c.status == ConnectionStatus.pending,
    ).toList();
  }

  // CONNECT BUTTON Flow:
  // Step 1: Premium User -> Send Request -> Open Messages (FREE, UNLIMITED)
  // Step 2: Free User (Under 2/day AND under 20/month) -> Send Request -> Open Messages (FREE)
  // Step 3: Free User (Hit 2/day or 20/month Limit) -> Show Payment Popup:
  //         [Pay KES 50] -> Process payment -> Send Request -> Open Messages
  //         [Upgrade to Premium - KES 200/mo] -> Navigate to Premium Screen
  //         [Cancel] -> Close Popup
  Future<ConnectionModel?> initiateConnect({
    required BuildContext context,
    required UserModel sender,
    required UserModel recipient,
    String? postId,
    bool autoNavigateToChat = true,
  }) async {
    if (sender.id == recipient.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot connect with your own profile!")),
      );
      return null;
    }

    final existing = _db.connections.firstWhere(
      (c) => (c.senderId == sender.id && c.recipientId == recipient.id) ||
             (c.senderId == recipient.id && c.recipientId == sender.id),
      orElse: () => ConnectionModel(
        id: '',
        senderId: '',
        senderUsername: '',
        senderProfilePic: '',
        recipientId: '',
        recipientUsername: '',
        recipientProfilePic: '',
        recipientContactMethod: '',
        recipientContactDetails: '',
      ),
    );

    if (existing.id.isNotEmpty) {
      if (autoNavigateToChat) {
        _navigateToChat(context, existing);
      }
      return existing;
    }

    // STEP 1: Check if Premium
    if (sender.isPremium) {
      final newConn = _db.sendConnectionRequest(
        sender: sender,
        recipient: recipient,
        postId: postId,
        priceKES: 0.0,
        isPremiumFree: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connected with @${recipient.username}!")),
      );

      if (autoNavigateToChat && newConn != null) {
        _navigateToChat(context, newConn);
      }
      return newConn;
    }

    // STEP 2: Free User -> Check Daily & Monthly Connection Counts
    final dailyUsage = sender.activeDailyConnections;
    final monthlyUsage = sender.activeMonthlyConnections;

    if (dailyUsage < 2 && monthlyUsage < 20) {
      final newConn = _db.sendConnectionRequest(
        sender: sender,
        recipient: recipient,
        postId: postId,
        priceKES: 0.0,
        isPremiumFree: true,
      );
      _db.incrementUserConnectionUsage(sender.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connected with @${recipient.username}! (${dailyUsage + 1}/2 free today)")),
      );

      if (autoNavigateToChat && newConn != null) {
        _navigateToChat(context, newConn);
      }
      return newConn;
    } else {
      // STEP 3: SHOW PAYMENT POPUP
      _showLimitReachedPopup(context, sender, recipient, postId, autoNavigateToChat);
      return null;
    }
  }

  void _showLimitReachedPopup(
    BuildContext context,
    UserModel sender,
    UserModel recipient,
    String? postId,
    bool autoNavigateToChat,
  ) {
    final isDailyLimit = sender.activeDailyConnections >= 2;
    final limitMsg = isDailyLimit
        ? "You've used all 2 free connections today."
        : "You've used all 20 free connections this month.";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: const [
            Icon(Icons.lock_clock_outlined, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text('Connection Limit Reached', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              limitMsg,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
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
                description: 'Unlock direct chat with @${recipient.username}',
                amountKES: 50.0,
                userEmail: sender.email,
              );

              if (res != null && res.success) {
                _db.recordTransaction(
                  TransactionModel(
                    id: res.transactionId,
                    userId: sender.id,
                    type: 'connection',
                    amount: 50.0,
                    paymentReference: res.transactionId,
                    status: 'success',
                  ),
                );
                final newConn = _db.sendConnectionRequest(
                  sender: sender,
                  recipient: recipient,
                  postId: postId,
                  priceKES: 50.0,
                  isPremiumFree: false,
                );
                _db.incrementUserConnectionUsage(sender.id);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Connected with @${recipient.username}!")),
                );

                if (autoNavigateToChat && newConn != null) {
                  _navigateToChat(context, newConn);
                }
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Pay KES 50', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
              primary: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Upgrade to Premium - KES 200/mo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
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

  void respondToConnectionRequest(String connectionId, ConnectionStatus status) {
    _db.respondToConnection(connectionId, status);
  }
}
