import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  String? _deviceToken;

  String? get deviceToken => _deviceToken;

  Future<void> initialize() async {
    try {
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

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _deviceToken = await getDeviceToken();
      }

      // Listen for token refresh events
      _fcm.onTokenRefresh.listen((newToken) {
        _deviceToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
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
      debugPrint('FCM Registration Token: $token');
      return token;
    } catch (e) {
      debugPrint('Error retrieving FCM registration token: $e');
      return null;
    }
  }
}
