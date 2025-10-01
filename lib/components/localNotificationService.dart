import 'package:ballys_reservation_app/main.dart' show navigatorKey;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Initialize local notifications
  Future<void> initializeLocalNotifications() async {
    await AwesomeNotifications().initialize(
      null, // Use default app icon
      [
        NotificationChannel(
          channelKey: 'high_importance_channel',
          channelName: 'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications',
          defaultColor: Color(0xFFDAB066),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
      ],
    );

    // Request permission
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    // Listen to notification actions
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );

    print('Awesome Notifications initialized successfully');
  }

  // Show notification when app is in foreground
  Future<void> showForegroundNotification(RemoteMessage message) async {
    // Create payload with navigation data
    Map<String, String> payload = {
      'type': message.data['type']?.toString() ?? 'chat',
      'screen': message.data['screen']?.toString() ?? 'chat',
    };

    // Get the icon from Firebase notification or use default
    String? largeIcon = message.notification?.android?.imageUrl;
    String? bigPicture = message.notification?.android?.imageUrl;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: message.hashCode,
        channelKey: 'high_importance_channel',
        title: message.notification?.title ?? 'New Notification',
        body: message.notification?.body ?? '',
        notificationLayout: NotificationLayout.Default,
        payload: payload,
        largeIcon: largeIcon, // Use same icon as Firebase notification
        bigPicture: bigPicture, // Use same image if available
        icon: 'resource://mipmap/launcher_icon', // Your app icon
      ),
    );

    print('Foreground notification displayed: ${message.notification?.title}');
  }

  // Notification action received (when user taps notification)
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    print('Notification action received: ${receivedAction.payload}');

    // Navigate to chat screen
    if (receivedAction.payload != null && receivedAction.payload!.isNotEmpty) {
      final payload = receivedAction.payload!;

      // Check if payload indicates chat notification
      if (payload['type'] == 'chat' ||
          payload['screen'] == 'chat' ||
          payload.containsKey('chat')) {
        // Use the global navigator key to navigate
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          // Small delay to ensure app is ready
          await Future.delayed(Duration(milliseconds: 500));
          context.go('/menu/chats');
        }
      }
    }
  }

  // Notification created
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    print('Notification created: ${receivedNotification.id}');
  }

  // Notification displayed
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    print('Notification displayed: ${receivedNotification.id}');
  }

  // Notification dismissed
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    print('Notification dismissed: ${receivedAction.id}');
  }

  // Handle notification tap
  void handleNotificationTap(String? payload) {
    print('Handling notification tap with payload: $payload');

    // Navigate to chat screen
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.go('/menu/chats');
    }
  }

  // Get current FCM token
  Future<String?> getFCMToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  // Delete FCM token (useful for logout)
  Future<void> deleteFCMToken() async {
    await FirebaseMessaging.instance.deleteToken();
    print('FCM token deleted');
  }
}
