import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:huruchat/firebase_options.dart';

const AndroidNotificationChannel _chatMessagesChannel =
    AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
    );

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService.instance._initializeLocalNotifications();
  await PushNotificationService.instance.showLocalNotification(message);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    await _messaging.setAutoInitEnabled(true);
    await _initializeLocalNotifications();
    await _requestPermissions();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      if (user != null) {
        await syncCurrentToken();
      }
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      await _saveTokenForCurrentUser(token);
    });

    await syncCurrentToken();
  }

  Future<void> syncCurrentToken() async {
    await _logNativePushToken();
    final token = await _messaging.getToken();
    debugPrint('FCM token: $token');
    if (token == null || token.isEmpty) return;
    await _saveTokenForCurrentUser(token);
  }

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('Push notification permission: ${settings.authorizationStatus}');
  }

  Future<void> _logNativePushToken() async {
    try {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        debugPrint('APNs token: $apnsToken');
      }
    } catch (e) {
      debugPrint('Failed to read native push token: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null || response.payload!.isEmpty) return;
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        debugPrint('Notification tapped: $data');
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_chatMessagesChannel);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint(
      'Foreground push received: data=${message.data}, '
      'title=${message.notification?.title}, body=${message.notification?.body}',
    );
    await showLocalNotification(message);
  }

  Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ??
        (message.data['title'] as String?) ??
        'New message';
    final body =
        notification?.body ??
        (message.data['body'] as String?) ??
        'You have a new message';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chatMessagesChannel.id,
          _chatMessagesChannel.name,
          channelDescription: _chatMessagesChannel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint('Notification opened chat payload: ${message.data}');
  }

  Future<void> _saveTokenForCurrentUser(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastNotificationTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
  }
}
