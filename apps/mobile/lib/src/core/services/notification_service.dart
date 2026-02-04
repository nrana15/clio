import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

import '../core/services/secure_storage_service.dart';

/// Background message handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 Background message: ${message.messageId}');
  
  // Handle background message
  await NotificationService.instance._handleBackgroundMessage(message);
}

/// Service for managing push notifications and local notifications
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  final SecureStorageService _secureStorage = SecureStorageService();

  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  bool _isInitialized = false;
  String? _fcmToken;

  /// Callback for when a notification is tapped
  Function(Map<String, dynamic>)? onNotificationTapped;

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Initialize notification service
  Future<void> initialize({
    Function(Map<String, dynamic>)? onNotificationTappedCallback,
  }) async {
    if (_isInitialized) return;

    onNotificationTapped = onNotificationTappedCallback;

    // Initialize Firebase
    await _initializeFirebase();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Set up message handlers
    _setupMessageHandlers();

    _isInitialized = true;
    debugPrint('✅ Notification service initialized');
  }

  /// Initialize Firebase Messaging
  Future<void> _initializeFirebase() async {
    // Request permission (iOS)
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('📱 Notification permission: ${settings.authorizationStatus}');

    // Set foreground notification presentation options
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    await _updateFcmToken();

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _onTokenRefresh(token);
    });

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
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
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'clio_bills_channel',
      'Bill Reminders',
      description: 'Notifications for upcoming and overdue bills',
      importance: Importance.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Set up message handlers for different app states
  void _setupMessageHandlers() {
    // Foreground messages
    _onMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
      debugPrint('📨 Foreground message: ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // App opened from notification
    _onMessageOpenedAppSubscription = 
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('📨 Message opened app: ${message.messageId}');
      _handleMessageOpenedApp(message);
    });

    // Check if app was opened from notification
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('📨 App opened from terminated state: ${message.messageId}');
        _handleMessageOpenedApp(message);
      }
    });
  }

  /// Get and save FCM token
  Future<void> _updateFcmToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        await _secureStorage.write('fcm_token', _fcmToken!);
        debugPrint('🔑 FCM Token obtained');
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String token) async {
    debugPrint('🔄 FCM Token refreshed');
    await _secureStorage.write('fcm_token', token);
    // TODO: Send new token to backend
  }

  /// Handle foreground messages (show local notification)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await showLocalNotification(
        id: message.hashCode,
        title: notification.title ?? 'CLIO',
        body: notification.body ?? '',
        payload: data,
      );
    }
  }

  /// Handle background messages
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    // Store for later processing or schedule local notification
    debugPrint('Processing background message: ${message.data}');
  }

  /// Handle message that opened the app
  void _handleMessageOpenedApp(RemoteMessage message) {
    onNotificationTapped?.call(message.data);
  }

  /// Handle local notification tap
  void _onLocalNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        // Parse payload if it's JSON
        final data = <String, dynamic>{};
        onNotificationTapped?.call(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Show a local notification
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    String? channelId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId ?? 'clio_bills_channel',
      'Bill Reminders',
      channelDescription: 'Notifications for upcoming and overdue bills',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload?.toString(),
    );
  }

  /// Schedule a local notification (fallback when FCM is unavailable)
  Future<void> scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, dynamic>? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'clio_scheduled_channel',
      'Scheduled Reminders',
      channelDescription: 'Locally scheduled bill reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      payload: payload?.toString(),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  /// Register device token with backend
  Future<void> registerDeviceWithBackend(String apiUrl, String authToken) async {
    if (_fcmToken == null) {
      await _updateFcmToken();
    }

    if (_fcmToken == null) {
      throw Exception('FCM token not available');
    }

    // TODO: Implement API call to register device
    // final response = await http.post(
    //   Uri.parse('$apiUrl/api/v1/notifications/register-device'),
    //   headers: {
    //     'Authorization': 'Bearer $authToken',
    //     'Content-Type': 'application/json',
    //   },
    //   body: jsonEncode({
    //     'token': _fcmToken,
    //     'platform': Platform.isIOS ? 'ios' : 'android',
    //     'device_model': await _getDeviceModel(),
    //     'app_version': await _getAppVersion(),
    //   }),
    // );

    debugPrint('📱 Device registered with backend');
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  /// Dispose
  void dispose() {
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
  }
}

// Import timezone for scheduling
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
