import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ballys_reservation_app/components/badge_service.dart';
import 'package:ballys_reservation_app/components/localNotificationService.dart';
import 'package:ballys_reservation_app/navigation/app_navigation.dart';
import 'package:ballys_reservation_app/utils/badge_sync_helper.dart';
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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  try {
    final badgeService = BadgeService();
    await badgeService.initialize();

    // Try to read the system/global badge counter (plugin) to avoid
    // overwriting a badge set by the OS (APNs payload). Fall back to
    // the locally saved count.
    int systemBadge = 0;
    try {
      systemBadge = await AwesomeNotifications().getGlobalBadgeCounter();
    } catch (e) {
      // If plugin not available in background/isolate, ignore and use saved
    }

    final savedCount = await badgeService.getSavedBadgeCount();
    final base = systemBadge > savedCount ? systemBadge : savedCount;
    await badgeService.updateBadge(base + 1);

    // Sync with server for accurate count
    try {
      await BadgeSyncHelper.syncBadgeWithServer();
    } catch (e) {
      print('Badge sync error in background: $e');
    }
  } catch (e) {
    print('Background handler error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await ScreenProtector.preventScreenshotOn();

  // Initialize Firebases
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService().initializeLocalNotifications();
  // Initialize badge service
  await BadgeService().initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  final BadgeService _badgeService = BadgeService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFirebaseMessaging();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Sync badge with server when app comes to foreground
      BadgeSyncHelper.syncBadgeWithServer();
    } else if (state == AppLifecycleState.paused) {
      // Update badge when going to background
      BadgeSyncHelper.syncBadgeWithServer();
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    // Request permission for notifications with badge enabled
    NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          badge: true, // CRITICAL for iOS
          sound: true,
        );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
        // Update token on your server
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
        // Increment badge
        _badgeService.addBadge(1);
      });

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // Sync badge with server to get accurate count
        BadgeSyncHelper.syncBadgeWithServer();
        _handleNotificationTap(message);
      });

      // Handle notification tap when app was terminated
      FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? message,
      ) {
        if (message != null) {
          // Sync badge with server
          BadgeSyncHelper.syncBadgeWithServer();
          _handleNotificationTap(message);
        }
      });
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    // Use NotificationService to show the notification
    await _notificationService.showForegroundNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Parse the notification data
    Map<String, dynamic>? chatData;
    String? detailsJson = message.data['Details'];

    if (detailsJson != null) {
      try {
        final chatDetails = json.decode(detailsJson);
        chatData = {
          'chatId': chatDetails['chatId'] ?? '',
          'senderName': chatDetails['senderName'] ?? '',
          'senderId': chatDetails['senderId'] ?? '',
          'openChat': true,
        };
      } catch (e) {}
    }

    // Check for direct chat data in message.data
    if (chatData == null &&
        (message.data['type'] == 'chat' ||
            message.data['screen'] == 'chat' ||
            message.data.containsKey('chatId'))) {
      chatData = {
        'chatId': message.data['chatId'] ?? '',
        'senderName': message.data['senderName'] ?? '',
        'senderId': message.data['senderId'] ?? '',
        'openChat': true,
      };
    }

    // Use WidgetsBinding to ensure navigation happens after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait a bit longer to ensure the app is fully in foreground
      Future.delayed(const Duration(milliseconds: 500), () {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          if (chatData != null && chatData['chatId'] != '') {
            context.go('/menu/chats', extra: chatData);
          } else {
            context.go('/menu/chats');
          }
        } else {}
      });
    });
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
        // return DeveloperBanner(
        return MediaQuery(
          // child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling, // This disables font scaling
          ),
          child: child!,
          // ),
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
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeSplash();
  }

  Future<bool> _checkInternetConnectivity() async {
    try {
      // First check basic connectivity
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Test actual internet access with HTTP request
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: 2);

      try {
        // Try to make an actual HTTP request to a reliable server
        final request = await client
            .getUrl(Uri.parse('http://clients3.google.com/generate_204'))
            .timeout(Duration(seconds: 2));

        final response = await request.close().timeout(Duration(seconds: 2));

        client.close();

        if (response.statusCode == 204 || response.statusCode == 200) {
          return true;
        } else {
          return false;
        }
      } on SocketException catch (_) {
        client.close();
        return false;
      } on TimeoutException catch (_) {
        client.close();
        return false;
      } on HandshakeException catch (_) {
        client.close();
        return false;
      }
    } catch (e) {
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
                // Retry checking internet connection
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
                // Exit the app
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
   Future<void> _animateLoadingBar() async {
    // Animate loading bar from 0 to 1 over 2.5 seconds
    for (int i = 0; i <= 100; i++) {
      if (mounted) {
        setState(() {
          _loadingProgress = i / 100;
        });
        await Future.delayed(Duration(milliseconds: 25));
      }
    }
  }

  Future<void> _initializeSplash() async {
    setState(() {
      _hasInternet = true; // Assume true initially to avoid premature dialog
      _loadingProgress = 0.0;
    });
 _animateLoadingBar();

    // Check internet connectivity first
    _hasInternet = await _checkInternetConnectivity();

    if (!_hasInternet) {
      // Show no internet dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoInternetDialog();
      });
      return;
    }
    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();

    // Check awesome notifications for initial action
    ReceivedAction? receivedAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: true);
    // Initialize badge service
    await BadgeService().initialize();
    // Extract chat details from notification
    Map<String, dynamic>? notificationChatData;

    if (initialMessage != null) {
      // Parse Details from FCM notification
      String? detailsJson = initialMessage.data['Details'];
      if (detailsJson != null) {
        try {
          final chatDetails = json.decode(detailsJson);
          notificationChatData = {
            'chatId': chatDetails['chatId'] ?? '',
            'senderName': chatDetails['senderName'] ?? '',
            'senderId': chatDetails['senderId'] ?? '',
            'openChat': true,
          };
        } catch (e) {}
      }
    } else if (receivedAction != null && receivedAction.payload != null) {
      // Extract from Awesome Notifications payload
      notificationChatData = {
        'chatId': receivedAction.payload!['chatId'] ?? '',
        'senderName': receivedAction.payload!['senderName'] ?? '',
        'senderId': receivedAction.payload!['senderId'] ?? '',
        'openChat': true,
      };
    }

    Future.delayed(const Duration(seconds: 3), () async {
      final expiry = await StorageUtil.getExpiry();
      if (expiry != null) {
        final expiryTime = DateTime.parse(expiry);
        if (DateTime.now().isBefore(expiryTime)) {
          // Check if opened from notification
          if (notificationChatData != null &&
              notificationChatData['chatId'] != '') {
            // Navigate directly to chat with the notification data
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'hero-image',
              child: Image.asset('assets/images/logo.png', width: 400, height: 400),
            ),
            SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60.0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _loadingProgress,
                    backgroundColor: Colors.grey[300],
                    color: customGoldColor,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

