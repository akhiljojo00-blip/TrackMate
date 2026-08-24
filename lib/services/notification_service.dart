import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId}');
  // Reserved for background payload handling
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final DatabaseService _databaseService = DatabaseService();
  String? _deviceToken;

  String? get deviceToken => _deviceToken;

  Future<void> initialize() async {
    try {
      // Register top-level background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request notification permissions
      final NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM permission authorization status: ${settings.authorizationStatus}');

      // Configure foreground presentation options (heads-up alerts, badges, sounds)
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _deviceToken = await getDeviceToken();
      }

      // 1. Foreground message stream
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground message received: ${message.messageId}');
        // Reserved for foreground handling
      });

      // 2. Notification opened when app in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM notification opened from background: ${message.messageId}');
        // Reserved for notification tap navigation
      });

      // 3. Initial message when app opened from terminated state
      final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM app opened from terminated state via notification: ${initialMessage.messageId}');
        // Reserved for initial notification routing
      }

      // 4. Token refresh listener
      _fcm.onTokenRefresh.listen((newToken) async {
        _deviceToken = newToken;
        debugPrint('FCM registration token refreshed successfully');

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            await _databaseService.saveUserDeviceToken(currentUser.uid, newToken);
            debugPrint('Refreshed FCM token synchronized to user profile');
          } catch (e) {
            debugPrint('Error syncing refreshed FCM token: $e');
          }
        }
      });
    } catch (e, stackTrace) {
      debugPrint('NotificationService initialization notice: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<String?> getDeviceToken() async {
    try {
      final token = await _fcm.getToken();
      _deviceToken = token;
      if (token != null && token.isNotEmpty) {
        debugPrint('FCM registration token acquired successfully');
      }
      return token;
    } catch (e) {
      debugPrint('Error retrieving FCM registration token: $e');
      return null;
    }
  }
}
