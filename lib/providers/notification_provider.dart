import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  StreamSubscription<List<NotificationModel>>? _subscription;
  String? _currentUserId;

  void initUserNotifications(String userId) {
    if (_currentUserId == userId && _subscription != null) return;
    _currentUserId = userId;
    _subscription?.cancel();

    _subscription =
        _firestoreService.getNotificationsStream(userId).listen((data) {
      _notifications = data;
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
}
