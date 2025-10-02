import 'dart:convert';
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
    // Parse the Details field to extract chat information
    String? detailsJson = message.data['Details'];
    Map<String, dynamic>? chatDetails;

    if (detailsJson != null) {
      try {
        chatDetails = json.decode(detailsJson);
      } catch (e) {
        print('Error parsing Details JSON: $e');
      }
    }

    // Debug: Print the parsed details
    print('Parsed chat details: $chatDetails');

    // Create payload with navigation data including chat details
    Map<String, String> payload = {
      'type': message.data['msg_type']?.toString() ?? 'chat',
      'screen': 'chat',
      'chatId': chatDetails?['chatId']?.toString() ?? '',
      'senderId': chatDetails?['senderId']?.toString() ?? '',
      'senderName': chatDetails?['senderName']?.toString() ?? '',
      'hostName': chatDetails?['hostName']?.toString() ?? '',
    };

    print('Notification payload: $payload');

    // Get the icon from Firebase notification or use default
    String? largeIcon = message.notification?.android?.imageUrl;
    String? bigPicture = message.notification?.android?.imageUrl;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: message.hashCode,
        channelKey: 'high_importance_channel',
        title: message.notification?.title ?? 'New Message',
        body: message.notification?.body ?? '',
        notificationLayout: NotificationLayout.Default,
        payload: payload,
        largeIcon: largeIcon,
        bigPicture: bigPicture,
        icon: 'resource://mipmap/launcher_icon',
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

    // Navigate to specific chat
    if (receivedAction.payload != null && receivedAction.payload!.isNotEmpty) {
      final payload = receivedAction.payload!;

      // Check if it's a chat notification
      if (payload['type'] == '11' ||
          payload['screen'] == 'chat' ||
          payload.containsKey('chatId')) {
        final chatId = payload['chatId'] ?? '';
        final senderName = payload['senderName'] ?? '';

        // Use the global navigator key to navigate
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          // Small delay to ensure app is ready
          await Future.delayed(Duration(milliseconds: 500));

          // Navigate to chat screen with specific chat data
          context.go(
            '/menu/chats',
            extra: {
              'chatId': chatId,
              'senderName': senderName,
              'openChat':
                  true, // Flag to indicate we should open this specific chat
            },
          );
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

  // Handle notification tap with chat data
  void handleNotificationTap(RemoteMessage message) {
    print('Handling notification tap');

    // Parse chat details
    String? detailsJson = message.data['Details'];
    Map<String, dynamic>? chatDetails;

    if (detailsJson != null) {
      try {
        chatDetails = json.decode(detailsJson);
      } catch (e) {
        print('Error parsing Details JSON: $e');
      }
    }

    // Navigate to chat screen with specific chat
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.go(
        '/menu/chats',
        extra: {
          'chatId': chatDetails?['chatId'] ?? '',
          'senderName': chatDetails?['senderName'] ?? '',
          'openChat': true,
        },
      );
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
