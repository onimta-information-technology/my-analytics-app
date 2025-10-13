import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/services/biometric_service.dart';
import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:ballys_reservation_app/providers/guests_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:local_auth/local_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
      print('🔍 Initializing biometrics...');

      final isAvailable = await _biometricService.isDeviceSupported();
      final isEnabled = await _biometricService.isBiometricEnabled();
      final biometrics = await _biometricService.getAvailableBiometrics();

      print('📊 Biometric status:');
      print('  - Available: $isAvailable');
      print('  - Enabled: $isEnabled');
      print('  - Types: ${biometrics.map((e) => e.name).join(", ")}');

      setState(() {
        _isBiometricAvailable = isAvailable;
        _isBiometricEnabled = isEnabled;
        _availableBiometrics = biometrics;
        _biometricCheckComplete = true;
      });

      // If biometric is enabled and available, trigger login after UI is ready
      if (isEnabled && isAvailable && mounted) {
        print('✅ Biometric is enabled and available - triggering auto-login');

        // Add a delay to ensure UI is fully rendered
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          await _loginWithBiometric();
        }
      }
    } catch (e) {
      print('❌ Error initializing biometrics: $e');
      setState(() {
        _biometricCheckComplete = true;
      });
    }
  }

  Future<void> _loginWithBiometric() async {
    try {
      print('🔐 Starting biometric login...');

      final biometricName = _biometricService.getBiometricTypeName(
        _availableBiometrics,
      );

      print('🔐 Prompting for $biometricName authentication...');

      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to login to Bally\'s',
      );

      print('🔐 Biometric result: $authenticated');

      if (authenticated) {
        final credentials = await _biometricService.getCredentials();

        if (credentials != null) {
          _username = credentials['username']!;
          _password = credentials['password']!;

          print('✅ Credentials retrieved - performing login');
          await _performLogin(showBiometricDialog: false);
        } else {
          print('⚠️ Credentials not found in secure storage');
          _showErrorSnackBar('Credentials not found. Please login manually.');
        }
      } else {
        print('❌ Biometric authentication cancelled or failed');
      }
    } catch (e) {
      print('❌ Biometric login error: $e');
      _showErrorSnackBar('Biometric authentication failed: ${e.toString()}');
    }
  }

  void _onLogin() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      await _performLogin(showBiometricDialog: true);
    }
  }

  Future<void> _performLogin({required bool showBiometricDialog}) async {
    print('Attempting login for username: $_username');

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
        print('Login credentials validated successfully');

        String? phoneNumber = await _getUserPhoneNumber();

        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          print('Phone number retrieved: $phoneNumber');

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

  Future<String?> _getUserPhoneNumber() async {
    try {
      final authState = ref.read(authProvider);

      if (authState?.user?.mobileNumber != null &&
          authState!.user!.mobileNumber!.isNotEmpty) {
        return authState.user!.mobileNumber;
      }
    } catch (e) {
      print('Error getting phone number: $e');
      return null;
    }
    return null;
  }

  Future<void> _sendOTP(String phoneNumber) async {
    try {
      print('Sending OTP to: $phoneNumber');
      await Future.delayed(const Duration(seconds: 1));
      print('OTP simulation sent successfully');
    } catch (e) {
      print('Error sending OTP: $e');
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).clearPendingUser();
    });
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

                          // Biometric Login Button (if enabled and check is complete)
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
                              if (value == "") return "This field is required!";
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