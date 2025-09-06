import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:ballys_reservation_app/providers/guests_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  var _username = "";
  var _password = "";
  bool _showPassword = false;
  // String _appVersion = "Loading...";
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _fetchAppVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(guestsProvider.notifier).resetData();
    });
  }

  Future<void> _fetchAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      // _appVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
      _packageInfo = packageInfo;
    });
  }

void _onLogin() async {
  FocusScope.of(context).unfocus();
  if (_formKey.currentState!.validate()) {
    _formKey.currentState!.save();

    await ref
        .read(authProvider.notifier)
        .authenticateAndLogin(_username, _password);

    final authState = ref.read(authProvider);

    if (authState != null && authState.user != null) {
      final name = await StorageUtil.getUserName();
      final prefs = await SharedPreferences.getInstance();
   
      // Try to get FCM token with retry mechanism
      String? fcmtoken = await _getFCMTokenWithRetry();
      print('FCM Token: $fcmtoken');
      
      if (fcmtoken != null) {
        await prefs.setString('FCMToken', fcmtoken);
        
        // Sync token with server
        if (name != null) {
          await _syncTokenWithServer(name, fcmtoken);
        }
      } else {
        print('FCM Token is null - will retry on token refresh');
        // Set up token refresh listener for when token becomes available
        _setupTokenRefreshListener(name);
      }

      // Navigate to home on successful login
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please check your credentials.'),
        ),
      );
    }
  }
}


Future<String?> _getFCMTokenWithRetry({int maxRetries = 3}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) return token;
      
      // Wait before retry
      await Future.delayed(Duration(seconds: 1 + i));
    } catch (e) {
      print('FCM Token fetch attempt ${i + 1} failed: $e');
      if (i == maxRetries - 1) return null;
      await Future.delayed(Duration(seconds: 1 + i));
    }
  }
  return null;
}

// Setup listener for token refresh
void _setupTokenRefreshListener(String? name) {
  FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
    print('FCM Token refreshed: $token');
    
    // Save the new token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('FCMToken', token);
    
    // Sync with server
    if (name != null) {
      await _syncTokenWithServer(name, token);
    }
  }).onError((err) {
    print('FCM Token refresh error: $err');
  });
}

// Separate method for server sync
Future<void> _syncTokenWithServer(String name, String token) async {
  try {
    var result = await FirebaseApiService.syncFmcToken(name, token);
    
    if (result['success'] == true) {
      print('FCM Token sent to server successfully: ${result['data']}');
    } else {
      print('Failed to send FCM Token: ${result['error']}');
    }
  } catch (e) {
    print('Error syncing FCM token with server: $e');
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer(
        builder: (context, watch, child) {
          final authState = ref.watch(authProvider);

          return Center(
            child: Container(
              color: Colors.white,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Hero(
                            tag: 'hero-image',
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 200,
                              height: 200,
                            ),
                          ),
                          const SizedBox(height: 0),
                          const Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Log in to your account',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 40),
                          TextFormField(
                            decoration: InputDecoration(
                              hintText: 'Username',
                              prefixIcon: const Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == "") {
                                return "This field is required!";
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _username = value!;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Colors.grey,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == "") {
                                return "This field is required!";
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _password = value!;
                            },
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Constants
                                    .kSecondaryColor, // Custom gold color
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _onLogin,
                              icon: const Icon(
                                Icons.login,
                                color: Colors.white,
                              ), // Login icon
                              label: const Text(
                                'Log In',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFF333333),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (authState!.user != null)
                            Text('Welcome, ${authState.user?.userName}'),
                          Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: Text(
                              "Version: ${_packageInfo.version} ${_packageInfo.buildNumber}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color.fromARGB(117, 158, 158, 158),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (authState.isLoading)
                    Positioned.fill(
                      child: Container(
                        color: const Color.fromARGB(134, 253, 253, 253),
                        child: const Center(
                          child: RefreshProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Constants.kSecondaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
