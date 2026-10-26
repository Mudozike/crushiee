import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';
import '../models/connection_model.dart';
import '../screens/messages/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/premium/premium_subscription_screen.dart';
import '../screens/profile/verification_screen.dart';
import '../widgets/post_card.dart';
import 'firestore_service.dart';

/// Top-level background message handler required by firebase_messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[PUSH] Background Firebase initialization error: $e');
  }
  debugPrint('[PUSH] Handling background message: ${message.messageId}');
}

/// Top-level background notification response handler for flutter_local_notifications
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('[PUSH] Notification background response received: ${response.actionId}');
  PushNotificationService.instance.handleNotificationResponse(response);
}

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._internal();
  factory PushNotificationService() => instance;

  PushNotificationService._internal({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirestoreService? firestoreService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin(),
        _firestoreService = firestoreService ?? FirestoreService(),
        _auth = auth,
        _firestore = firestore;

  /// Constructor for dependency injection and tests
  PushNotificationService.withDependencies({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirestoreService? firestoreService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin(),
        _firestoreService = firestoreService ?? FirestoreService(),
        _auth = auth,
        _firestore = firestore;

  final FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FirestoreService _firestoreService;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Notification channel configuration
  static const String notificationChannelId = 'crushie_notifications';
  static const String notificationChannelName = 'Crushie Notifications';
  static const String notificationChannelDesc = 'Crushie push and message notifications';

  /// Currently active conversation connection ID (synced to suppress redundant foreground alerts)
  static String? activeConversationConnectionId;

  bool _isInitialized = false;
  String? _currentRegisteredUid;

  /// Initialize push notifications, request permissions, and register local channel
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Request notification permissions (Android 13+ POST_NOTIFICATIONS & iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[PUSH] Notification authorization status: ${settings.authorizationStatus}');

      // 2. Initialize local notifications plugin
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          handleNotificationResponse(response);
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // 3. Create Android notification channel
      const androidChannel = AndroidNotificationChannel(
        notificationChannelId,
        notificationChannelName,
        description: notificationChannelDesc,
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // 4. Set foreground presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Register background FCM handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 6. Handle foreground push notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // 7. Handle background-to-foreground notification taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[PUSH] Notification opened from background: ${message.messageId}');
        handleNotificationTap(message.data);
      });

      // 8. Handle cold-start launch notification (terminated app)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[PUSH] App launched from terminated state via notification: ${initialMessage.messageId}');
        // Delay slightly to let initial widget tree attach
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationTap(initialMessage.data);
        });
      }

      // 9. Handle token refresh
      messaging.onTokenRefresh.listen((newToken) {
        if (_currentRegisteredUid != null) {
          registerUserToken(_currentRegisteredUid!, tokenOverride: newToken);
        }
      });

      _isInitialized = true;
      debugPrint('[PUSH] PushNotificationService initialized successfully');
    } catch (e) {
      debugPrint('[PUSH] Error during PushNotificationService initialization: $e');
    }
  }

  /// Securely register device FCM token for authenticated user
  Future<String?> registerUserToken(String userId, {String? tokenOverride}) async {
    if (userId.trim().isEmpty) return null;
    _currentRegisteredUid = userId;

    try {
      final token = tokenOverride ?? await messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[PUSH] Unable to obtain FCM token for user: $userId');
        return null;
      }

      await firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[PUSH] Successfully registered FCM token for user $userId');
      return token;
    } catch (e) {
      debugPrint('[PUSH] Error registering FCM token for user $userId: $e');
      return null;
    }
  }

  /// Remove and invalidate device FCM token on sign-out
  Future<void> clearUserToken(String userId) async {
    if (userId.trim().isEmpty) return;
    _currentRegisteredUid = null;

    try {
      String? currentToken;
      try {
        currentToken = await messaging.getToken();
      } catch (_) {}

      final updateMap = <String, dynamic>{
        'fcmToken': FieldValue.delete(),
      };
      if (currentToken != null && currentToken.isNotEmpty) {
        updateMap['fcmTokens'] = FieldValue.arrayRemove([currentToken]);
      }

      await firestore.collection('users').doc(userId).update(updateMap);

      try {
        await messaging.deleteToken();
      } catch (_) {}

      debugPrint('[PUSH] Successfully cleared FCM token for user: $userId');
    } catch (e) {
      debugPrint('[PUSH] Error clearing FCM token for user $userId: $e');
    }
  }

  /// Handle incoming foreground notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final connectionId = data['connectionId'] as String?;

    // Suppress noisy alert if recipient is actively chatting in that conversation
    if (connectionId != null &&
        connectionId.isNotEmpty &&
        activeConversationConnectionId == connectionId) {
      debugPrint('[PUSH] Suppressing foreground notification for active conversation: $connectionId');
      return;
    }

    final title = message.notification?.title ?? data['title'] ?? 'Crushie Alert';
    final body = message.notification?.body ?? data['body'] ?? '';
    final type = data['type'] as String? ?? '';

    await showLocalNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(data),
      isMessage: type == 'message',
    );
  }

  /// Displays local heads-up notification with Android reply action
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
    bool isMessage = false,
  }) async {
    final actions = <AndroidNotificationAction>[];

    // Add Direct Reply action for message notifications
    if (isMessage) {
      actions.add(
        const AndroidNotificationAction(
          'reply_action',
          'Reply',
          inputs: [
            AndroidNotificationActionInput(
              label: 'Type a reply...',
            ),
          ],
          showsUserInterface: true,
          cancelNotification: true,
        ),
      );
    }

    final androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: actions,
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Handles user interaction with local notification (tap or reply action)
  Future<void> handleNotificationResponse(NotificationResponse response) async {
    final actionId = response.actionId;
    final payloadStr = response.payload;

    Map<String, dynamic> data = {};
    if (payloadStr != null && payloadStr.isNotEmpty) {
      try {
        data = Map<String, dynamic>.from(jsonDecode(payloadStr));
      } catch (e) {
        debugPrint('[PUSH] Error parsing notification payload: $e');
      }
    }

    // 1. Direct Reply Action
    if (actionId == 'reply_action') {
      final replyText = response.input?.trim();
      if (replyText != null && replyText.isNotEmpty) {
        await executeDirectReply(data: data, replyText: replyText);
      }
      return;
    }

    // 2. Normal Notification Tap
    handleNotificationTap(data);
  }

  /// Authenticates, validates, and sends inline notification reply
  Future<bool> executeDirectReply({
    required Map<String, dynamic> data,
    required String replyText,
  }) async {
    final connectionId = data['connectionId'] as String?;
    final recipientId = data['fromUserId'] as String?;
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      debugPrint('[REPLY] Direct reply failed: user is not authenticated');
      return false;
    }

    if (connectionId == null || connectionId.isEmpty || recipientId == null || recipientId.isEmpty) {
      debugPrint('[REPLY] Direct reply failed: missing connectionId or recipientId');
      return false;
    }

    if (replyText.trim().isEmpty) {
      debugPrint('[REPLY] Direct reply failed: empty reply text');
      return false;
    }

    try {
      await _firestoreService.sendNotificationReply(
        connectionId: connectionId,
        senderId: currentUser.uid,
        senderUsername: currentUser.displayName ?? 'Someone',
        senderProfilePic: currentUser.photoURL ?? '',
        recipientId: recipientId,
        content: replyText.trim(),
      );
      debugPrint('[REPLY] Direct notification reply sent successfully to $recipientId in $connectionId');
      return true;
    } catch (e) {
      debugPrint('[REPLY] Error sending direct notification reply: $e');
      return false;
    }
  }

  /// Dispatches navigation to the appropriate destination based on notification data
  Future<void> handleNotificationTap(Map<String, dynamic> data) async {
    final typeStr = data['type'] as String? ?? '';
    final connectionId = data['connectionId'] as String?;
    final postId = data['postId'] as String?;
    final fromUserId = data['fromUserId'] as String?;

    final navContext = navigatorKey.currentContext;
    if (navContext == null) {
      debugPrint('[PUSH] Navigation context is null; unable to navigate');
      return;
    }

    // 1. Message Notification -> ChatScreen
    if (typeStr == 'message' && connectionId != null && connectionId.isNotEmpty) {
      try {
        final conn = await _firestoreService.getConnection(connectionId);
        if (conn != null && navContext.mounted) {
          Navigator.push(
            navContext,
            MaterialPageRoute(builder: (_) => ChatScreen(connection: conn)),
          );
          return;
        }
      } catch (e) {
        debugPrint('[PUSH] Error navigating to connection $connectionId: $e');
      }
      _showStaleNotice(navContext, 'Conversation is no longer available.');
      return;
    }

    // 2. Post / Comment / Like / Location Post -> Post Preview
    if (postId != null && postId.isNotEmpty) {
      try {
        final post = await _firestoreService.getPost(postId);
        if (post != null && navContext.mounted) {
          showDialog(
            context: navContext,
            builder: (ctx) => Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: PostCard(post: post),
                ),
              ),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('[PUSH] Error navigating to post $postId: $e');
      }
      _showStaleNotice(navContext, 'This post has expired or was removed.');
      return;
    }

    // 3. Follow / Connection -> ProfileScreen
    if ((typeStr == 'follow' ||
            typeStr == 'connectionRequest' ||
            typeStr == 'connectionAccepted') &&
        fromUserId != null &&
        fromUserId.isNotEmpty) {
      try {
        final user = await _firestoreService.getUserProfile(fromUserId);
        if (user != null && navContext.mounted) {
          Navigator.push(
            navContext,
            MaterialPageRoute(builder: (_) => ProfileScreen(user: user)),
          );
          return;
        }
      } catch (e) {
        debugPrint('[PUSH] Error navigating to profile $fromUserId: $e');
      }
      _showStaleNotice(navContext, 'Profile is no longer available.');
      return;
    }

    // 4. Premium Notification -> PremiumSubscriptionScreen
    if (typeStr == 'premium') {
      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (_) => PremiumSubscriptionScreen(
            onSubscriptionSuccess: () => Navigator.pop(navContext),
          ),
        ),
      );
      return;
    }

    // 5. Verification Notification -> VerificationScreen
    if (typeStr == 'verification') {
      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (_) => VerificationScreen(
            onVerifiedSuccess: () => Navigator.pop(navContext),
          ),
        ),
      );
      return;
    }
  }

  void _showStaleNotice(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
