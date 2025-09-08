import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:ballys_reservation_app/providers/guests_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
      _packageInfo = packageInfo;
    });
  }

  // void _onLogin() async {
  //   FocusScope.of(context).unfocus();
  //   if (_formKey.currentState!.validate()) {
  //     _formKey.currentState!.save();

  //     print('Attempting login for username: $_username');

  //     // First, validate username and password
  //     await ref
  //         .read(authProvider.notifier)
  //         .authenticateAndLogin(_username, _password);

  //     final authState = ref.read(authProvider);

  //     if (authState != null && authState.user != null) {
  //       print('Login credentials validated successfully');

  //       // If credentials are valid, get phone number and navigate to OTP screen
  //       String? phoneNumber = await _getUserPhoneNumber();

  //       if (phoneNumber != null && phoneNumber.isNotEmpty) {
  //         print('Phone number retrieved: $phoneNumber');

  //         // Send OTP (simulate for now since no SMS gateway)
  //         await _sendOTP(phoneNumber);

  //         // Navigate to OTP verification screen
  //         if (mounted) {
  //           context.push('/otp-verification', extra: {
  //             'phoneNumber': phoneNumber,
  //             'username': _username,
  //             'password': _password,
  //           });
  //         }
  //       } else {
  //         // If no phone number, show error
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //             content: Text('Phone number not found. Please contact support.'),
  //           ),
  //         );
  //       }
  //     } else {
  //       print('Login failed - invalid credentials');
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Login failed. Please check your credentials.'),
  //         ),
  //       );
  //     }
  //   }
  // }
  void _onLogin() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      print('Attempting login for username: $_username');

      // Clear any previous errors
      ref.read(authProvider.notifier).clearError();

      // Attempt authentication and login
      await ref
          .read(authProvider.notifier)
          .authenticateAndLogin(_username, _password);

      final authState = ref.read(authProvider);

      if (authState != null) {
        // Check if there's an error and display it
        if (authState.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authState.error!),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          return; // Don't proceed further if there's an error
        }

        // If no error and user is authenticated, proceed with OTP flow
        if (authState.user != null) {
          print('Login credentials validated successfully');

          // If credentials are valid, get phone number and navigate to OTP screen
          String? phoneNumber = await _getUserPhoneNumber();
          print(phoneNumber);
          if (phoneNumber != null && phoneNumber.isNotEmpty) {
            print('Phone number retrieved: $phoneNumber');

            // Send OTP (simulate for now since no SMS gateway)
            try {
              await _sendOTP(phoneNumber);

              // Navigate to OTP verification screen
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send OTP: ${e.toString()}'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            // If no phone number, show error
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Phone number not found. Please contact support.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    }
  }

  // Get user's phone number from your user data
  Future<String?> _getUserPhoneNumber() async {
    try {
 final authState = ref.read(authProvider);
    print('Auth state: ${authState?.user}');
    print('Mobile from auth: ${authState?.user?.mobileNumber}');
    
    if (authState?.user?.mobileNumber != null && 
        authState!.user!.mobileNumber!.isNotEmpty) {
      return authState.user!.mobileNumber;
    }

      // Example of how you might get it from your auth state:
      // final authState = ref.read(authProvider);
      // return authState?.user?.phoneNumber;

      // Or from an API call:
      // final userData = await FirebaseApiService.getUserData(_username);
      // return userData['phoneNumber'];
    } catch (e) {
      print('Error getting phone number: $e');
      return null;
    }
  }

  // Send OTP to user's phone (simulate for now)
  Future<void> _sendOTP(String phoneNumber) async {
    try {
      // Since you don't have SMS gateway yet, this is just a placeholder
      // Replace this with your actual SMS service integration

      print('Sending OTP to: $phoneNumber');

      // Example of how you might integrate with an SMS service:
      /*
      await FirebaseApiService.sendOTP({
        'phoneNumber': phoneNumber,
        'username': _username,
      });
      */

      // For now, just simulate a delay
      await Future.delayed(const Duration(seconds: 1));
      print('OTP simulation sent successfully');
    } catch (e) {
      print('Error sending OTP: $e');
      throw e;
    }
  }

  @override
  void dispose() {
    // Clear any pending authentication data when leaving login screen
    // This ensures that if user closes app before completing OTP,
    // they won't be auto-logged in
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
