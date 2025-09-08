import 'dart:async';
import 'dart:math';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OTPVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String username;
  final String password;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.username,
    required this.password,
  });

  @override
  ConsumerState<OTPVerificationScreen> createState() =>
      _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
    String? _actualOTP; // Store the generated OTP
  bool _isSendingOTP = false;
  final List<TextEditingController> _otpControllers = List.generate(
    5,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    5,
    (index) => FocusNode(),
  );
String _generateOTP() {
  Random random = Random();
  return (10000 + random.nextInt(90000)).toString(); // 5-digit OTP
}
// Send OTP via SMS gateway
Future<bool> _sendOTPSMS(String phoneNumber, String otp) async {
  try {
    // Your SMS gateway URL
    String baseUrl = 'https://richcommunication.dialog.lk/api/sms/inline/send';
    
    // Format phone number (remove +94 and add 0 if needed)
    String formattedPhone = phoneNumber;
    if (phoneNumber.startsWith('+94')) {
      formattedPhone = '0${phoneNumber.substring(3)}';
    }
    
    // Create the message
    String message = 'Your OTP code is: $otp. Do not share this code with anyone.';
    
    // Build the full URL with parameters
    String fullUrl = '$baseUrl?q=968deddf5fd84b8&destination=$formattedPhone&message=${Uri.encodeComponent(message)}';
    
    print('Sending SMS to: $formattedPhone');
    print('OTP: $otp');
    
    // Make the HTTP request
    final response = await http.get(Uri.parse(fullUrl));
    
    if (response.statusCode == 200) {
      print('SMS sent successfully: ${response.body}');
      return true;
    } else {
      print('SMS send failed: ${response.statusCode} - ${response.body}');
      return false;
    }
  } catch (e) {
    print('Error sending SMS: $e');
    return false;
  }
}
  Timer? _timer;
  int _resendSeconds = 47;
  bool _isVerifying = false;
  String _currentOTP = '';

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  _sendInitialOTP();
    // Auto-focus first input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNodes[0].requestFocus();
    });
  }
  Future<void> _sendInitialOTP() async {
  setState(() {
    _isSendingOTP = true;
  });
  
  _actualOTP = _generateOTP();
  bool sent = await _sendOTPSMS(widget.phoneNumber, _actualOTP!);
  
  if (!sent) {
    _showErrorMessage('Failed to send OTP. Please try again.');
  }
  
  setState(() {
    _isSendingOTP = false;
  });
}

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() {
      _resendSeconds = 47;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() {
          _resendSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _onOTPChanged(String value, int index) {
    if (value.isNotEmpty && index < 4) {
      // Move to next field
      _otpFocusNodes[index + 1].requestFocus();
    }

    // Update current OTP
    _currentOTP = _otpControllers.map((controller) => controller.text).join();

    // Auto-verify when all 5 digits are entered
    if (_currentOTP.length == 5) {
      _verifyOTP();
    }
  }

  void _onBackspace(int index) {
    if (index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOTP() async {
    if (_currentOTP.length != 5) {
      _showErrorMessage('Please enter complete OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      // Simulate OTP verification - replace with actual API call
      bool isValid = await _simulateOTPVerification(_currentOTP);

      if (isValid) {
        // OTP is valid, proceed with complete login process
        await _completeLoginProcess();
      } else {
        _showErrorMessage('Invalid OTP. Please try again.');
        _clearOTPFields();
      }
    } catch (e) {
      _showErrorMessage('Verification failed. Please try again.');
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<bool> _simulateOTPVerification(String otp) async {
    // Simulate OTP verification - replace with actual API call
   await Future.delayed(const Duration(seconds: 1));
  return otp == _actualOTP;
  }

  // Complete login process after successful OTP verification
  Future<void> _completeLoginProcess() async {
    try {
      print('Starting complete login process...');

      // Re-authenticate to ensure user is properly logged in
      await ref
          .read(authProvider.notifier)
          .authenticateAndLogin(widget.username, widget.password);

      final authState = ref.read(authProvider);

      if (authState != null && authState.user != null) {
        print('Authentication successful, processing FCM token...');

        final name = await StorageUtil.getUserName();
        final prefs = await SharedPreferences.getInstance();

        // Try to get FCM token with retry mechanism
        String? fcmtoken = await _getFCMTokenWithRetry();
        print('FCM Token after OTP verification: $fcmtoken');

        if (fcmtoken != null) {
          await prefs.setString('FCMToken', fcmtoken);
          print('FCM Token saved to preferences: $fcmtoken');

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
        if (mounted) {
          print('Navigating to home screen...');
          context.go('/home');
        }
      } else {
        throw Exception('Authentication failed after OTP verification');
      }
    } catch (e) {
      print('Error in complete login process: $e');
      _showErrorMessage('Login completion failed. Please try again.');
    }
  }

  Future<String?> _getFCMTokenWithRetry({int maxRetries = 3}) async {
    print('Attempting to get FCM token...');

    for (int i = 0; i < maxRetries; i++) {
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          print(
            'FCM Token fetch attempt ${i + 1} successful: ${token.substring(0, 20)}...',
          );
          return token;
        }

        print('FCM Token fetch attempt ${i + 1} returned null, retrying...');
        // Wait before retry
        await Future.delayed(Duration(seconds: 1 + i));
      } catch (e) {
        print('FCM Token fetch attempt ${i + 1} failed: $e');
        if (i == maxRetries - 1) return null;
        await Future.delayed(Duration(seconds: 1 + i));
      }
    }
    print('All FCM token fetch attempts failed');
    return null;
  }

  // Setup listener for token refresh
  void _setupTokenRefreshListener(String? name) {
    print('Setting up FCM token refresh listener...');

    FirebaseMessaging.instance.onTokenRefresh
        .listen((String token) async {
          print('FCM Token refreshed: ${token.substring(0, 20)}...');

          // Save the new token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('FCMToken', token);

          // Sync with server
          if (name != null) {
            await _syncTokenWithServer(name, token);
          }
        })
        .onError((err) {
          print('FCM Token refresh error: $err');
        });
  }

  // Separate method for server sync
  Future<void> _syncTokenWithServer(String name, String token) async {
    try {
      print('Syncing FCM token with server for user: $name');

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

  void _clearOTPFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _currentOTP = '';
    _otpFocusNodes[0].requestFocus();
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

Future<void> _resendOTP() async {
  if (_resendSeconds > 0) return;

  setState(() {
    _isSendingOTP = true;
  });

  try {
    // Generate new OTP
    _actualOTP = _generateOTP();
    
    // Send new OTP
    bool sent = await _sendOTPSMS(widget.phoneNumber, _actualOTP!);
    
    if (sent) {
      _startResendTimer();
      _clearOTPFields();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP has been resent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      _showErrorMessage('Failed to resend OTP');
    }
  } catch (e) {
    _showErrorMessage('Failed to resend OTP');
  } finally {
    setState(() {
      _isSendingOTP = false;
    });
  }
}
  String _formatPhoneNumber(String phoneNumber) {
    // Format phone number for display (e.g., +94*****996)
    if (phoneNumber.length > 6) {
      return phoneNumber.substring(0, 3) +
          '*' * (phoneNumber.length - 6) +
          phoneNumber.substring(phoneNumber.length - 3);
    }
    return phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
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

                // Title
                const Text(
                  'OTP Verification',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),

                const SizedBox(height: 16),

                // Subtitle
                Text(
                  'Enter the OTP you received at',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),

                const SizedBox(height: 8),

                // Phone number
                Text(
                  _formatPhoneNumber(widget.phoneNumber),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),

                const SizedBox(height: 40),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextFormField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        onChanged: (value) => _onOTPChanged(value, index),
                        onTap: () {
                          // Clear the field when tapped for better UX
                          _otpControllers[index].selection =
                              TextSelection.fromPosition(
                                TextPosition(
                                  offset: _otpControllers[index].text.length,
                                ),
                              );
                        },
                        onEditingComplete: () {
                          if (_otpControllers[index].text.isEmpty &&
                              index > 0) {
                            _onBackspace(index);
                          }
                        },
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 30),

                // Resend Timer
                Text(
                  _resendSeconds > 0
                      ? 'Resend in $_resendSeconds seconds'
                      : 'Didn\'t receive OTP?',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),

                const SizedBox(height: 10),

                // Resend Button
                if (_resendSeconds == 0)
                  TextButton(
                    onPressed: _resendOTP,
                    child: const Text(
                      'Resend OTP',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // Verify Button (optional, since auto-verify is enabled)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _currentOTP.length == 5 ? _verifyOTP : null,
                    child: const Text(
                      'Verify OTP',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (_isVerifying)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.8),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ),
            ),
            if (_isSendingOTP)
  Positioned.fill(
    child: Container(
      color: Colors.white.withOpacity(0.8),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            SizedBox(height: 16),
            Text(
              'Sending OTP...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    ),
  ),
        ],
      ),
    );
  }
}
