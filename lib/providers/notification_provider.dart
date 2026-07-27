import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';

class NotificationProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  NotificationProvider() {
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

  List<NotificationModel> getNotificationsForUser(String userId) {
    return _db.notifications.where((n) => n.userId == userId).toList();
  }

  int getUnreadCount(String userId) {
    return _db.notifications.where((n) => n.userId == userId && !n.isRead).length;
  }

  void markAsRead(String notifId) {
    _db.markNotificationAsRead(notifId);
  }
}
