import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ballys_reservation_app/components/localNotificationService.dart';
import 'package:ballys_reservation_app/navigation/app_navigation.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:screen_protector/screen_protector.dart';

Color customGoldColor = const Color(0xFFDAB066);

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message received: ${message.messageId}');

  // Initialize Awesome Notifications for background notifications
  await AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'high_importance_channel',
      channelName: 'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications',
      defaultColor: const Color(0xFFDAB066),
      ledColor: Colors.white,
      importance: NotificationImportance.High,
      channelShowBadge: true,
      playSound: true,
      enableVibration: true,
    ),
  ]);

  // Parse notification data
  String? detailsJson = message.data['Details'];
  Map<String, dynamic>? chatDetails;

  if (detailsJson != null) {
    try {
      chatDetails = json.decode(detailsJson);
    } catch (e) {
      print('Error parsing Details JSON: $e');
    }
  }

  String title =
      message.data['title'] ?? message.notification?.title ?? 'New Message';
  String body = message.data['body'] ?? message.notification?.body ?? '';
  String? imageUrl = message.data['image_url'];

  // Show custom notification for both Android and iOS in background
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      channelKey: 'high_importance_channel',
      title: title,
      body: body,
      notificationLayout: NotificationLayout.Default,
      payload: chatDetails != null
          ? {
              'chatId': chatDetails['chatId']?.toString() ?? '',
              'senderName': chatDetails['senderName']?.toString() ?? '',
              'senderId': chatDetails['senderId']?.toString() ?? '',
              'hostName': chatDetails['hostName']?.toString() ?? '',
              'type': 'chat',
              'screen': 'chat',
            }
          : null,
      largeIcon: imageUrl,
      bigPicture: imageUrl,
      icon: 'resource://mipmap/launcher_icon',
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await ScreenProtector.preventScreenshotOn();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Platform-specific notification setup
  if (Platform.isAndroid) {
    // Android: Suppress default FCM notifications
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
  } else if (Platform.isIOS) {
    // iOS: Allow default system notifications
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications
  await NotificationService().initializeLocalNotifications();

  // Initialize Awesome Notifications listeners
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: NotificationController.onActionReceivedMethod,
  );

  runApp(const ProviderScope(child: MyApp()));
}

// Separate controller for notification actions
class NotificationController {
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    print('Notification action received: ${receivedAction.payload}');

    if (receivedAction.payload != null && receivedAction.payload!.isNotEmpty) {
      final payload = receivedAction.payload!;

      // Wait for app to be fully initialized
      await Future.delayed(Duration(milliseconds: 800));

      // Try to navigate using the router
      try {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          print('Navigating to chat screen with payload: $payload');
          context.go(
            '/menu/chats',
            extra: {
              'chatId': payload['chatId'] ?? '',
              'senderName': payload['senderName'] ?? '',
              'senderId': payload['senderId'] ?? '',
              'hostName': payload['hostName'] ?? '',
              'openChat': true,
            },
          );
        } else {
          print('Context not available, trying router navigation');
          AppNavigation.router.go(
            '/menu/chats',
            extra: {
              'chatId': payload['chatId'] ?? '',
              'senderName': payload['senderName'] ?? '',
              'senderId': payload['senderId'] ?? '',
              'hostName': payload['hostName'] ?? '',
              'openChat': true,
            },
          );
        }
      } catch (e) {
        print('Error navigating from notification: $e');
      }
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeFirebaseMessaging();
  }

  Future<void> _initializeFirebaseMessaging() async {
    // Request permission for notifications
    NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');

      // Get and print FCM token
      String? token = await FirebaseMessaging.instance.getToken();
      print('FCM Token: $token');

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
        print('FCM Token refreshed: $token');
        // TODO: Update token on your server
      });

      // Platform-specific foreground presentation setup
      if (Platform.isAndroid) {
        // Android: Suppress default notifications and show custom ones
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: false,
              badge: false,
              sound: false,
            );

        // Handle foreground messages - show custom notifications
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('Foreground message received on Android!');
          print('Message data: ${message.data}');
          _showForegroundNotification(message);
        });
      } else if (Platform.isIOS) {
        // iOS: Allow default system notifications
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );

        // For iOS, listen but use system notification
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print(
            'Foreground message received on iOS - using system notification',
          );
          print('Message data: ${message.data}');
          // iOS will show system notification automatically
        });
      }

      // Handle notification taps when app is in background or terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Notification tapped (background)!');
        _handleNotificationTap(message);
      });

      // Check for notification that launched the app from terminated state
      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        print('App launched from notification (terminated state)');
        // Handle with delay to ensure app is fully initialized
        Future.delayed(Duration(milliseconds: 1000), () {
          _handleNotificationTap(initialMessage);
        });
      }
    } else {
      print('User declined notification permission');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    // Show custom notification for Android foreground messages
    if (Platform.isAndroid) {
      await _notificationService.showForegroundNotification(message);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Handling notification tap with data: ${message.data}');

    String? detailsJson = message.data['Details'];
    Map<String, dynamic>? chatDetails;

    if (detailsJson != null) {
      try {
        chatDetails = json.decode(detailsJson);
        print('Parsed chat details: $chatDetails');
      } catch (e) {
        print('Error parsing Details JSON: $e');
      }
    }

    // Check if this is a chat notification
    if (message.data['msg_type'] == '11' ||
        message.data['type'] == 'chat' ||
        message.data['screen'] == 'chat' ||
        chatDetails != null) {
      // Navigate to chat screen with extracted data
      final chatData = {
        'chatId': chatDetails?['chatId'] ?? message.data['chatId'] ?? '',
        'senderName':
            chatDetails?['senderName'] ?? message.data['senderName'] ?? '',
        'senderId': chatDetails?['senderId'] ?? message.data['senderId'] ?? '',
        'hostName': chatDetails?['hostName'] ?? message.data['hostName'] ?? '',
        'openChat': true,
      };

      print('Navigating to chat with data: $chatData');

      // Use a reliable delay and context check
      Future.delayed(Duration(milliseconds: 500), () {
        final currentContext = navigatorKey.currentContext;
        if (currentContext != null && currentContext.mounted) {
          currentContext.go('/menu/chats', extra: chatData);
        } else {
          // Fallback to router navigation
          AppNavigation.router.go('/menu/chats', extra: chatData);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Bally\'s Reservation App',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.amber,
        textTheme: GoogleFonts.poppinsTextTheme(),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: customGoldColor,
          elevation: 20.0,
          selectedItemColor: Colors.black26,
          unselectedItemColor: Colors.black54,
        ),
      ),
      routerConfig: AppNavigation.router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _initializeSplash();
  }

  Future<bool> _checkInternetConnectivity() async {
    try {
      print('Starting internet connectivity check...');

      final connectivityResult = await Connectivity().checkConnectivity();
      print('Connectivity status: $connectivityResult');

      if (connectivityResult == ConnectivityResult.none) {
        print('No connectivity detected');
        return false;
      }

      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: 2);

      try {
        final request = await client
            .getUrl(Uri.parse('http://clients3.google.com/generate_204'))
            .timeout(Duration(seconds: 2));

        final response = await request.close().timeout(Duration(seconds: 2));
        client.close();

        if (response.statusCode == 204 || response.statusCode == 200) {
          print('Internet access confirmed');
          return true;
        } else {
          print('HTTP request failed with status: ${response.statusCode}');
          return false;
        }
      } on SocketException catch (e) {
        print('Socket exception: $e');
        client.close();
        return false;
      } on TimeoutException catch (e) {
        print('Timeout exception: $e');
        client.close();
        return false;
      } on HandshakeException catch (e) {
        print('Handshake exception: $e');
        client.close();
        return false;
      }
    } catch (e) {
      print('General error checking connectivity: $e');
      return false;
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text(
                'No Internet Connection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Please check your internet connection and try again. This app requires an active internet connection to function properly.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initializeSplash();
              },
              child: Text(
                'Retry',
                style: TextStyle(
                  color: customGoldColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                exit(0);
              },
              child: Text(
                'Exit',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeSplash() async {
    setState(() {
      _hasInternet = true;
    });

    _hasInternet = await _checkInternetConnectivity();
    print('Internet check result: $_hasInternet');

    if (!_hasInternet) {
      print('No internet detected - showing dialog');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoInternetDialog();
      });
      return;
    }

    print('Internet available - proceeding with initialization');

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();

    // Check awesome notifications for initial action
    ReceivedAction? receivedAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: true);

    Map<String, dynamic>? notificationChatData;

    // Handle FCM initial message
    if (initialMessage != null) {
      print('App opened from FCM notification: ${initialMessage.data}');

      String? detailsJson = initialMessage.data['Details'];
      if (detailsJson != null) {
        try {
          final chatDetails = json.decode(detailsJson);
          notificationChatData = {
            'chatId': chatDetails['chatId'] ?? '',
            'senderName': chatDetails['senderName'] ?? '',
            'senderId': chatDetails['senderId'] ?? '',
            'hostName': chatDetails['hostName'] ?? '',
            'openChat': true,
          };
          print('Extracted chat data from FCM: $notificationChatData');
        } catch (e) {
          print('Error parsing notification Details: $e');
        }
      }
    }
    // Handle Awesome Notifications initial action
    else if (receivedAction != null && receivedAction.payload != null) {
      print('App opened from Awesome notification: ${receivedAction.payload}');

      notificationChatData = {
        'chatId': receivedAction.payload!['chatId'] ?? '',
        'senderName': receivedAction.payload!['senderName'] ?? '',
        'senderId': receivedAction.payload!['senderId'] ?? '',
        'hostName': receivedAction.payload!['hostName'] ?? '',
        'openChat': true,
      };
      print('Extracted chat data from Awesome: $notificationChatData');
    }

    // Delayed navigation after splash screen
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;

      final expiry = await StorageUtil.getExpiry();
      if (expiry != null) {
        final expiryTime = DateTime.parse(expiry);
        if (DateTime.now().isBefore(expiryTime)) {
          // Navigate to chats if opened from notification, otherwise home
          if (notificationChatData != null) {
            print('Navigating to chats with notification data');
            context.go('/menu/chats', extra: notificationChatData);
          } else {
            context.go('/home');
          }
        } else {
          await StorageUtil.clearUserData();
          context.go('/login');
        }
      } else {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Hero(
          tag: 'hero-image',
          child: Image.asset('assets/images/logo.png', width: 400, height: 400),
        ),
      ),
    );
  }
}
