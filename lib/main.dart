import 'dart:async';
import 'dart:io';

import 'package:ballys_reservation_app/components/developer_banner.dart';
import 'package:ballys_reservation_app/navigation/app_navigation.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Color customGoldColor = const Color(0xFFDAB066);

// Top-level function for background message handling
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message received: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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

      // Get FCM token

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
        print('FCM Token refreshed: $token');
        // Update token on your server
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Foreground message received!');
        print('Title: ${message.notification?.title}');
        print('Body: ${message.notification?.body}');

        // Show local notification or handle as needed
        _showForegroundNotification(message);
      });

      // Handle notification taps when app is in background but not terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Notification tapped!');
        print('Title: ${message.notification?.title}');
        print('Body: ${message.notification?.body}');

        // Navigate to specific screen if needed
        _handleNotificationTap(message);
      });
    } else {
      print('User declined notification permission');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    // You can show a dialog, snackbar, or custom notification widget here
    // For now, we'll just print the message
    print('Showing foreground notification: ${message.notification?.title}');
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle navigation based on notification data
    // You can access message.data to get custom data from the notification
    print('Handling notification tap with data: ${message.data}');
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
        return DeveloperBanner(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling, // This disables font scaling
            ),
            child: child!,
          ),
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
  //  bool _hasInternet = true;
  @override
  void initState() {
    super.initState();
    _initializeSplash();
  }

  Future<bool> _checkInternetConnectivity() async {
    try {
      print('Starting internet connectivity check...');

      // First check basic connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      print('Connectivity status: $connectivityResult');

      if (connectivityResult == ConnectivityResult.none) {
        print('No connectivity detected');
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
          print('Internet access confirmed - HTTP 200 response');
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

  Future<void> _initializeSplash() async {
    setState(() {
      _hasInternet = true; // Assume true initially to avoid premature dialog
    });

    // Check internet connectivity first
    _hasInternet = await _checkInternetConnectivity();
    print('Internet check result: $_hasInternet');

    if (!_hasInternet) {
      print('No internet detected - showing dialog');
      // Show no internet dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoInternetDialog();
      });
      return;
    }

    print('Internet available - proceeding with initialization');

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      print(
        'App opened from notification: ${initialMessage.notification?.title}',
      );
      // Handle the notification data if needed
    }

    Future.delayed(const Duration(seconds: 3), () async {
      final expiry = await StorageUtil.getExpiry();
      if (expiry != null) {
        final expiryTime = DateTime.parse(expiry);
        if (DateTime.now().isBefore(expiryTime)) {
          context.go('/home');
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
