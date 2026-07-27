import 'package:flutter/material.dart';
import '../models/connection_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/paystack_service.dart';
import '../config/app_constants.dart';

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
    return _db.connections.where(
      (c) => (c.senderId == userId || c.recipientId == userId) && c.status == ConnectionStatus.accepted,
    ).toList();
  }

  List<ConnectionModel> getPendingRequestsForUser(String userId) {
    return _db.connections.where(
      (c) => c.recipientId == userId && c.status == ConnectionStatus.pending,
    ).toList();
  }

  // CORE REVENUE FLOW: Handle Connection Request
  Future<bool> initiateConnect({
    required BuildContext context,
    required UserModel sender,
    required UserModel recipient,
    String? postId,
  }) async {
    // Check if recipient is sender
    if (sender.id == recipient.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot connect with your own profile!")),
      );
      return false;
    }

    // Check existing connection
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
      if (existing.status == ConnectionStatus.accepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You are already connected with ${recipient.username}!")),
        );
        return true;
      } else if (existing.status == ConnectionStatus.pending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection request already pending for ${recipient.username}.")),
        );
        return true;
      }
    }

    // Premium Check: Skip KES 50 fee if user is Premium
    if (sender.isPremium) {
      _db.sendConnectionRequest(
        sender: sender,
        recipient: recipient,
        postId: postId,
        priceKES: 0.0,
        isPremiumFree: true,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Premium Benefit: Free Connection request sent to ${recipient.username}! 🎉")),
      );
      return true;
    }

    // Show KES 50 Connection Confirmation / Payment Modal
    final paymentResult = await PaystackService.showPaymentDialog(
      context: context,
      title: 'Connect with @${recipient.username}',
      description: 'Start a private conversation with this user. You\'ll be able to continue the conversation and access the contact method (${recipient.preferredContactMethod}) they have chosen to share.',
      amountKES: AppConstants.connectionFeeKES,
      userEmail: sender.email,
    );

    if (paymentResult != null && paymentResult.success) {
      _db.sendConnectionRequest(
        sender: sender,
        recipient: recipient,
        postId: postId,
        priceKES: AppConstants.connectionFeeKES,
        isPremiumFree: false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection request sent to @${recipient.username}! ❤️")),
      );
      return true;
    }

    return false;
  }

  void respondToConnectionRequest(String connectionId, ConnectionStatus status) {
    _db.respondToConnection(connectionId, status);
  }
}
