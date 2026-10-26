import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../services/push_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  NotificationProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  FirestoreService get firestoreService => _firestoreService;

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  StreamSubscription<List<NotificationModel>>? _subscription;
  String? _currentUserId;
  String? _activeConversationConnectionId;

  /// Connection ID currently open in ChatScreen (to suppress redundant alert noise)
  String? get activeConversationConnectionId => _activeConversationConnectionId;
  set activeConversationConnectionId(String? connId) {
    _activeConversationConnectionId = connId;
    PushNotificationService.activeConversationConnectionId = connId;
    if (connId != null && _currentUserId != null) {
      _firestoreService.markMessageNotificationsAsRead(_currentUserId!, connId);
    }
  }

  void initUserNotifications(String userId) {
    if (_currentUserId == userId && _subscription != null) return;
    _currentUserId = userId;
    _subscription?.cancel();

    _subscription =
        _firestoreService.getNotificationsStream(userId).listen((data) {
      _notifications = data;

      // If user is actively viewing a conversation, automatically mark incoming message notifications as read
      if (_activeConversationConnectionId != null && _currentUserId != null) {
        _firestoreService.markMessageNotificationsAsRead(
            _currentUserId!, _activeConversationConnectionId!);
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Cancels active notification subscription and clears cached notifications on logout.
  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _currentUserId = null;
    _activeConversationConnectionId = null;
    PushNotificationService.activeConversationConnectionId = null;
    _notifications = [];
    notifyListeners();
  }

  List<NotificationModel> getNotificationsForUser(String userId) {
    initUserNotifications(userId);
    return _notifications;
  }

  int getUnreadCount(String userId) {
    initUserNotifications(userId);
    return _notifications.where((n) => !n.isRead).length;
  }

  void markAsRead(String userId, String notifId) {
    _firestoreService.markNotificationAsRead(userId, notifId);
  }

  void markAllAsRead(String userId) {
    _firestoreService.markAllNotificationsAsRead(userId);
  }

  void deleteNotification(String userId, String notifId) {
    _firestoreService.deleteNotification(userId, notifId);
  }
}
