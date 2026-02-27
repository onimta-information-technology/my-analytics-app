import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ballys_reservation_app/components/badge_service.dart';
import 'package:ballys_reservation_app/components/developer_banner.dart';
import 'package:ballys_reservation_app/components/localNotificationService.dart';
import 'package:ballys_reservation_app/data/services/versioncehck_service.dart';
import 'package:ballys_reservation_app/models/Guest/guest_booking.dart';
import 'package:ballys_reservation_app/navigation/app_navigation.dart';
import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:ballys_reservation_app/providers/guest_booking_provider.dart';
import 'package:ballys_reservation_app/utils/badge_sync_helper.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:ballys_reservation_app/utils/token_refresh_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

Color customGoldColor = const Color(0xFFDAB066);

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  try {
    final badgeService = BadgeService();
    await badgeService.initialize();

    int systemBadge = 0;
    try {
      systemBadge = await AwesomeNotifications().getGlobalBadgeCounter();
    } catch (e) {
      // If plugin not available in background/isolate, ignore and use saved
    }

    final savedCount = await badgeService.getSavedBadgeCount();
    final base = systemBadge > savedCount ? systemBadge : savedCount;
    await badgeService.updateBadge(base + 1);

    try {
      await BadgeSyncHelper.syncBadgeWithServer();
    } catch (e) {
      print('Badge sync error in background: $e');
    }
  } catch (e) {
    print('Background handler error: $e');
  }
}
late ProviderContainer globalContainer;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //await ScreenProtector.preventScreenshotOn();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications (WITHOUT requesting permission)
  await NotificationService().initializeLocalNotifications();

  // Initialize badge service
  await BadgeService().initialize();
 globalContainer = ProviderContainer();
 runApp(ProviderScope(
    parent: globalContainer, // ✅ Link ProviderScope to global container
    child: MyApp(),
  ));
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
    _setupFirebaseListenersOnly();
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
      _syncBadgeIfLoggedIn();
    } else if (state == AppLifecycleState.paused) {
      _syncBadgeIfLoggedIn();
    }
  }
Future<void> _reloadGuestBookingsGlobally() async {
  try {
    await globalContainer
        .read(guestBookingProvider.notifier)
        .getAllBookings();
    print('✅ Guest bookings reloaded from global listener');
  } catch (e) {
    print('Error reloading guest bookings globally: $e');
  }
}
  Future<void> _syncBadgeIfLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      if (isLoggedIn) {
        BadgeSyncHelper.syncBadgeWithServer();
      }
    } catch (e) {
      print('Error checking login status: $e');
    }
  }

  Future<void> _setupFirebaseListenersOnly() async {
    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      // Token updated — handled after login
    });

    // Handle foreground messages
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   // Only show notification UI for non-guest-booking messages
    //   // (guest booking reload is handled in chat_screen.dart)
    //   if (message.data['msg_type'] != '35') {
    //     _showForegroundNotification(message);
    //     _badgeService.addBadge(1);
    //   }
    // });
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  if (message.data['msg_type'] == '35') {
_showForegroundNotification(message); 
 _badgeService.addBadge(1);    
    _reloadGuestBookingsGlobally();
  } else {
    _showForegroundNotification(message);
    _badgeService.addBadge(1);
  }
});

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      BadgeSyncHelper.syncBadgeWithServer();
      _handleNotificationTap(message);
    });

    // Handle notification tap when app was terminated
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        BadgeSyncHelper.syncBadgeWithServer();
        _handleNotificationTap(message);
      }
    });
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    await _notificationService.showForegroundNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    // ─── Guest Booking Notification (msg_type: 35) ───────────────────────────
    if (message.data['msg_type'] == '35') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            final booking = GuestBooking(
              idNo: 0, // Not available in notification payload
              mid: message.data['MID'] ?? '',
              pkgStart: message.data['Pkg_Start'] ?? '',
              pkgEnd: message.data['Pkg_End'] ?? '',
              insertDate: message.data['InsertDate'] ?? '',
              pkgStatus: false, // Incoming notifications are always pending
            );

            context.go('/guest-bookings/view-booking', extra: {
              'booking': booking,
              'isPending': true,
            });
          }
        });
      });
      return; // Skip chat handling
    }

    // ─── Chat Notification ────────────────────────────────────────────────────
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          if (chatData != null && chatData['chatId'] != '') {
            context.go('/menu/chats', extra: chatData);
          } else {
            context.go('/menu/chats');
          }
        }
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
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontFamily: 'ABCArizonaFlare'),
        ),
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
        // child: MediaQuery(
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
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
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
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

        return response.statusCode == 204 || response.statusCode == 200;
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

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async {
            exit(0);
          },
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.system_update, color: customGoldColor, size: 28),
                SizedBox(width: 10),
                Text(
                  'Update Available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'A new version of the app is available. Please update to continue using the app.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  exit(0);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final url = Uri.parse(VersionCheckService.getUpdateUrl());
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not open update link'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  'Update',
                  style: TextStyle(
                    color: customGoldColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _animateLoadingBar() async {
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
      _hasInternet = true;
      _loadingProgress = 0.0;
    });
    _animateLoadingBar();

    // Check internet connectivity first
    _hasInternet = await _checkInternetConnectivity();

    if (!_hasInternet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoInternetDialog();
      });
      return;
    }

    final versionCheck = await VersionCheckService.checkVersion();
    if (!versionCheck['isLatest']) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUpdateDialog();
      });
      return;
    }

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    // Check awesome notifications for initial action
    ReceivedAction? receivedAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: true);

    // Initialize badge service
    await BadgeService().initialize();

    // ─── Guest Booking: terminated app tapped notification ──────────────────
    if (initialMessage != null && initialMessage.data['msg_type'] == '35') {
      Future.delayed(const Duration(seconds: 3), () async {
        final expiry = await StorageUtil.getExpiry();
        if (expiry != null) {
          final expiryTime = DateTime.parse(expiry);
          if (DateTime.now().isBefore(expiryTime)) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_logged_in', true);

            final container = ProviderScope.containerOf(context);
            final authRepo = container.read(authRepositoryProvider);
            TokenRefreshService().start(authRepo);

            final booking = GuestBooking(
              idNo: 0, // Not available in notification payload
              mid: initialMessage.data['MID'] ?? '',
              pkgStart: initialMessage.data['Pkg_Start'] ?? '',
              pkgEnd: initialMessage.data['Pkg_End'] ?? '',
              insertDate: initialMessage.data['InsertDate'] ?? '',
              pkgStatus: false, // Notification-triggered bookings are pending
            );

            context.go('/guest-bookings/view-booking', extra: {
              'booking': booking,
              'isPending': true,
            });
          } else {
            await StorageUtil.clearUserData();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_logged_in', false);
            context.go('/login');
          }
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', false);
          context.go('/login');
        }
      });
      return; // Skip normal chat/home routing
    }

    // ─── Chat / Normal notification routing ─────────────────────────────────
    Map<String, dynamic>? notificationChatData;

    if (initialMessage != null) {
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
          // Mark as logged in
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);

          final container = ProviderScope.containerOf(context);
          final authRepo = container.read(authRepositoryProvider);
          TokenRefreshService().start(authRepo);

          // Navigate based on notification data
          if (notificationChatData != null &&
              notificationChatData['chatId'] != '') {
            context.go('/menu/chats', extra: notificationChatData);
          } else {
            context.go('/home');
          }
        } else {
          await StorageUtil.clearUserData();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', false);

          context.go('/login');
        }
      } else {
        // Not logged in
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', false);

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
              child: Image.asset(
                'assets/images/logo.png',
                width: 400,
                height: 400,
              ),
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