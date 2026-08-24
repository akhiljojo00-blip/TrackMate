import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final DatabaseService _databaseService = DatabaseService();
  
  String? _deviceToken;
  bool _isLocalNotificationsInitialized = false;

  String? get deviceToken => _deviceToken;

  static const String _channelId = 'trackmate_channel';
  static const String _channelName = 'TrackMate Notifications';
  static const String _channelDescription = 'Alerts for friend requests, connections, and messages';

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.high,
    playSound: true,
  );

  Future<void> initialize() async {
    try {
      // Register top-level background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request FCM permissions
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

      // Configure foreground presentation options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Initialize local notification plugin for heads-up display
      await _initializeLocalNotifications();

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _deviceToken = await getDeviceToken();
      }

      // 1. Foreground message stream
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground message received: ${message.messageId}');
        final notification = message.notification;
        if (notification != null) {
          _showLocalNotification(
            id: message.hashCode,
            title: notification.title ?? 'TrackMate',
            body: notification.body ?? '',
            payload: message.data['chatId'] ?? message.data['type'],
          );
        }
      });

      // 2. Notification opened when app in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM notification opened from background: ${message.messageId}');
      });

      // 3. Initial message when app opened from terminated state
      final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM app opened from terminated state via notification: ${initialMessage.messageId}');
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

  Future<void> _initializeLocalNotifications() async {
    if (_isLocalNotificationsInitialized) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Local notification clicked: payload=${response.payload}');
        },
      );

      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_androidChannel);
      }

      _isLocalNotificationsInitialized = true;
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isLocalNotificationsInitialized) {
        await _initializeLocalNotifications();
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      );

      await _localNotifications.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error displaying local notification: $e');
    }
  }

  // Application Notification Triggers (FCM-5, FCM-6, FCM-7)
  Future<void> showFriendRequestNotification({required String senderName}) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'New Connection Request',
      body: '$senderName sent you a connection request.',
      payload: 'connection_requests',
    );
  }

  Future<void> showRequestAcceptedNotification({required String friendName}) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'Connection Accepted',
      body: '$friendName accepted your connection request.',
      payload: 'connections',
    );
  }

  Future<void> showChatMessageNotification({
    required String senderName,
    required String messageText,
    required String chatId,
  }) async {
    await _showLocalNotification(
      id: chatId.hashCode,
      title: senderName,
      body: messageText,
      payload: chatId,
    );
  }

  Future<void> showGroupChatMessageNotification({
    required String groupName,
    required String senderName,
    required String messageText,
    required String groupId,
  }) async {
    await _showLocalNotification(
      id: groupId.hashCode,
      title: groupName,
      body: '$senderName: $messageText',
      payload: 'group_chat:$groupId',
    );
  }

  Future<void> showEmergencySosNotification({required String senderName}) async {
    await _showLocalNotification(
      id: senderName.hashCode,
      title: '🚨 EMERGENCY ALERT',
      body: '$senderName has triggered an SOS beacon! Tap to view live location.',
      payload: 'emergency_sos',
    );
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
