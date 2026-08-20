import 'dart:async';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/services/biometric_service.dart';
import 'package:ballys_reservation_app/data/services/device_config_service.dart';
import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:ballys_reservation_app/providers/guests_provider.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:ballys_reservation_app/data/services/fcm_token_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with ConnectivityMixin {
  final _formKey = GlobalKey<FormState>();
  final _biometricService = BiometricService();

  var _username = "";
  var _password = "";
  bool _showPassword = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];
  bool _biometricCheckComplete = false;

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
      _initializeBiometrics();
    });
  }

  Future<void> _fetchAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  Future<void> _initializeBiometrics() async {
    try {
      final isAvailable = await _biometricService.isDeviceSupported();
      final isEnabled = await _biometricService.isBiometricEnabled();
      final biometrics = await _biometricService.getAvailableBiometrics();

      setState(() {
        _isBiometricAvailable = isAvailable;
        _isBiometricEnabled = isEnabled;
        _availableBiometrics = biometrics;
        _biometricCheckComplete = true;
      });

      if (isEnabled && isAvailable && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          await _loginWithBiometric();
        }
      }
    } catch (e) {
      setState(() {
        _biometricCheckComplete = true;
      });
    }
  }

  Future<void> _loginWithBiometric() async {
    try {
      final biometricName = _biometricService.getBiometricTypeName(
        _availableBiometrics,
      );

      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to login to Bally\'s',
      );

      if (authenticated) {
        final credentials = await _biometricService.getCredentials();

        if (credentials != null) {
          _username = credentials['username']!;
          _password = credentials['password']!;
 showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    // SizedBox(height: 16),
                    // Text('Checking device configuration...'),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          // Fetch device configuration
          final configResult = await DeviceConfigService.fetchDeviceConfig(username: _username,
  password: _password,);

          // Close loading dialog
          if (mounted) Navigator.of(context).pop();

          if (!configResult.isConfigured) {
            _showErrorSnackBar(
              configResult.errorMessage ?? 'Device is not registered',
            );
            return;
          }

          if (configResult.isAdmin) {
            await StorageUtil.saveAdminStatus(true);
          }
 await _performLogin(showBiometricDialog: false);
          
        } catch (e) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          _showErrorSnackBar(
            'Failed to fetch device configuration: ${e.toString()}',
          );
        }
      } else {
        _showErrorSnackBar('Credentials not found. Please login manually.');
      }
    }
  } catch (e) {
    _showErrorSnackBar('Biometric authentication failed: ${e.toString()}');
  }
}
  void _onLogin() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
   showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                // SizedBox(height: 16),
                // Text('Checking device configuration...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Fetch device configuration first
      final configResult = await DeviceConfigService.fetchDeviceConfig(username: _username,
  password: _password,
);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (!configResult.isConfigured) {
        // Device not registered
        _showErrorSnackBar(
          configResult.errorMessage ?? 'Device is not registered',
        );
        return;
      }
   if (configResult.isAdmin) {
        await StorageUtil.saveAdminStatus(true);
      }

      // Device is configured, proceed with login
      await _performLogin(showBiometricDialog: true);
      
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      _showErrorSnackBar(
        'Failed to fetch device configuration: ${e.toString()}',
      );
    }
  }
}
  Future<void> _performLogin({required bool showBiometricDialog}) async {
    ref.read(authProvider.notifier).clearError();

    await ref
        .read(authProvider.notifier)
        .authenticateAndLogin(_username, _password);

    final authState = ref.read(authProvider);

    if (authState != null) {
      if (authState.error != null) {
        _showErrorSnackBar(authState.error!);
        return;
      }

      if (authState.user != null) {
        // Check if password is APPCHECK - bypass OTP
        if (_password.toUpperCase() == "APPCHECK" || _password.toUpperCase() == "APPCHECK1") {
          await _directLoginBypass();
          return;
        }

        String? phoneNumber = await _getUserPhoneNumber();

        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          try {
            await _sendOTP(phoneNumber);

            if (mounted) {
              context.push(
                '/otp-verification',
                extra: {
                  'phoneNumber': phoneNumber,
                  'username': _username,
                  'password': _password,
                },
              );
            }
          } catch (e) {
            _showErrorSnackBar('Failed to send OTP: ${e.toString()}');
          }
        } else {
          _showErrorSnackBar('Phone number not found. Please contact support.');
        }
      }
    }
  }

 Future<void> _directLoginBypass() async {
  try {
    await ref.read(authProvider.notifier).completeLoginAfterOTP();

    final authState = ref.read(authProvider);

    if (authState != null && authState.user != null) {
      final salesCode = await StorageUtil.getSalesCode();

      if (salesCode != null) {
        ref.read(appmodeSettingsProvider.notifier).setSalesCode(salesCode);
      }

      // ✅ MARK USER AS LOGGED IN
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);

      // ✅ Navigate immediately. Notification permission + FCM token work must
      // NOT block navigation — getToken() can hang in the same app session.
      if (mounted) {
        context.go('/home');
      }

      // Fire-and-forget: runs in the background.
      unawaited(_completePostLoginSetupBypass());
    } else {
      throw Exception('Authentication failed');
    }
  } catch (e) {
    _showErrorSnackBar('Login failed. Please try again.');
    ref.read(authProvider.notifier).clearPendingUser();
  }
}

  Future<void> _completePostLoginSetupBypass() async {
    try {
      await _requestNotificationPermissionsForBypass();

      // FcmTokenService owns fetching, storing and syncing the token, and its
      // global onTokenRefresh listener covers the case where the SDK is still
      // re-registering and has nothing to hand back yet.
      await FcmTokenService.registerAfterLogin();
    } catch (e) {
      print('Post-login setup failed (non-blocking): $e');
    }
  }
  Future<void> _requestNotificationPermissionsForBypass() async {
    try {
      // Small delay so user sees they've logged in successfully
      await Future.delayed(const Duration(milliseconds: 500));

      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('Notification permissions granted (bypass flow)');
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('Notification permissions denied (bypass flow)');
        // Don't show error or redirect - continue normally
      }
    } catch (e) {
      print('Error requesting notification permissions: $e');
      // Don't show error to user - just continue
    }
  }




  Future<String?> _getUserPhoneNumber() async {
    try {
      final authState = ref.read(authProvider);

      if (authState?.user?.mobileNumber != null &&
          authState!.user!.mobileNumber!.isNotEmpty) {
        return authState.user!.mobileNumber;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _sendOTP(String phoneNumber) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      rethrow;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

@override
void dispose() {
  // Do NOT mutate provider state here. Pushing a new AuthState during the
  // dispose/teardown of this widget notifies listeners mid-navigation, which
  // crashes the element tree ("deactivated ancestor", "ref after disposed",
  // duplicate GlobalKey). It also wrongly clears the authenticated user right
  // after a successful login. Backing out of OTP already clears the pending
  // user via the OTP screen's back button.
  super.dispose();
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
                          // NOTE: not a Hero — the shared 'hero-image' tag
                          // caused duplicate-GlobalKey crashes when flights were
                          // interrupted by fast auth navigations.
                          Image.asset(
                            'assets/images/logo.png',
                            width: 200,
                            height: 200,
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

                          if (_biometricCheckComplete &&
                              _isBiometricEnabled &&
                              _isBiometricAvailable)
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      side: const BorderSide(
                                        color: Colors.orange,
                                        width: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _loginWithBiometric,
                                    icon: Icon(
                                      _availableBiometrics.contains(
                                            BiometricType.face,
                                          )
                                          ? Icons.face
                                          : Icons.fingerprint,
                                      color: Colors.orange,
                                    ),
                                    label: Text(
                                      'Login with ${_biometricService.getBiometricTypeName(_availableBiometrics)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(color: Colors.grey[400]),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Text(
                                        'OR',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),

                          TextFormField(
                             maxLength: 20,       
                            decoration: InputDecoration(
                              hintText: 'Username',
                              prefixIcon: const Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                                counterText: '',  
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == "") return "This field is required!";
                              return null;
                            },
                            onSaved: (value) {
                              _username = value!;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                             maxLength: 20, 
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Colors.grey,
                              ),
                               counterText: '',   
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
                              if (value == "") return "This field is required!";
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
                                backgroundColor: Constants.kSecondaryColor,
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
                              ),
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
                  if (authState!.isLoading)
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
