import 'dart:convert';
import 'dart:io'; // Import for Platform check
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

  bool _isInitialized = false;

  // Initialize local notifications
  Future<void> initializeLocalNotifications() async {
    if (_isInitialized) {
      print('Notifications already initialized');
      return;
    }

    try {
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

      _isInitialized = true;
      print('Awesome Notifications initialized successfully');
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> showForegroundNotification(RemoteMessage message) async {
    try {
      // For iOS, skip custom notifications and let FCM handle natively
      if (Platform.isIOS) {
        print('iOS detected - using native FCM notifications');
        // iOS will show notifications natively through FCM
        // We only need to handle the tap action, not display
        return;
      }

      // Android: Show custom notification using Awesome Notifications
      String title =
          message.data['title'] ?? message.notification?.title ?? 'New Message';
      String body = message.data['body'] ?? message.notification?.body ?? '';

      // Parse the Details field
      String? detailsJson = message.data['Details'];
      Map<String, dynamic>? chatDetails;

      if (detailsJson != null && detailsJson.isNotEmpty) {
        try {
          chatDetails = json.decode(detailsJson);
        } catch (e) {
          print('Error parsing Details JSON: $e');
        }
      }

      Map<String, String> payload = {
        'type': message.data['msg_type']?.toString() ?? 'chat',
        'screen': 'chat',
        'chatId': chatDetails?['chatId']?.toString() ?? '',
        'senderId': chatDetails?['senderId']?.toString() ?? '',
        'senderName': chatDetails?['senderName']?.toString() ?? '',
        'hostName': chatDetails?['hostName']?.toString() ?? '',
      };

      // Get image from data payload
      String? imageUrl = message.data['image_url'];

      // Generate unique ID
      int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
        100000,
      );

      print('Creating notification with ID: $notificationId');
      print('Title: $title, Body: $body');

      // Create notification with error handling
      bool created = await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: 'high_importance_channel',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          payload: payload,
          largeIcon: imageUrl,
          bigPicture: imageUrl,
          icon: 'resource://mipmap/launcher_icon',
          wakeUpScreen: true,
          category: NotificationCategory.Message,
        ),
      );

      if (created) {
        print('✅ Notification created successfully');
      } else {
        print('❌ Failed to create notification');
      }
    } catch (e) {
      print('❌ Error in showForegroundNotification: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Notification action received (when user taps notification)
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    try {
      print('Notification action received: ${receivedAction.payload}');

      // Navigate to specific chat
      if (receivedAction.payload != null &&
          receivedAction.payload!.isNotEmpty) {
        final payload = receivedAction.payload!;

        // Check if it's a chat notification
        if (payload['type'] == '11' ||
            payload['screen'] == 'chat' ||
            payload.containsKey('chatId')) {
          final chatId = payload['chatId'] ?? '';
          final senderName = payload['senderName'] ?? '';
          final senderId = payload['senderId'] ?? '';
          final hostName = payload['hostName'] ?? '';

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
                'senderId': senderId,
                'hostName': hostName,
                'openChat': true,
              },
            );
          }
        }
      }
    } catch (e) {
      print('Error in onActionReceivedMethod: $e');
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
    try {
      print('Handling notification tap');

      // Parse chat details
      String? detailsJson = message.data['Details'];
      Map<String, dynamic>? chatDetails;

      if (detailsJson != null && detailsJson.isNotEmpty) {
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
            'senderId': chatDetails?['senderId'] ?? '',
            'hostName': chatDetails?['hostName'] ?? '',
            'openChat': true,
          },
        );
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  // Get current FCM token
  Future<String?> getFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // Delete FCM token (useful for logout)
  Future<void> deleteFCMToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      print('FCM token deleted');
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }
}
