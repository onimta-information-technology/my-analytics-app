import 'dart:async';
import 'dart:math';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_autofill/sms_autofill.dart';

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

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen>
    with CodeAutoFill {
  String? _actualOTP;
  bool _isSendingOTP = false;
  String? _appSignature;

  //String? code; // This will be set by SMS auto-fill
  final List<TextEditingController> _otpControllers = List.generate(
    5,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    5,
    (index) => FocusNode(),
  );
  final List<String> _previousValues = List.generate(5, (index) => '');
  Timer? _timer;
  int _resendSeconds = 47;
  bool _isVerifying = false;
  String _currentOTP = '';
  StreamSubscription? _smsSubscription;

  // Auto-fill permission tracking
  bool? _autoFillPermissionGranted;
  String? _pendingSMSCode;

  String _generateOTP() {
    Random random = Random();
    return (10000 + random.nextInt(90000)).toString();
  }

  @override
  void initState() {
    super.initState();
    _initializeOTPFlow();
  }

  Future<void> _initializeOTPFlow() async {
    await _setupSMSAutoFill();
    _startResendTimer();
    await _sendInitialOTP();

    // Focus first field after a delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _otpFocusNodes[0].requestFocus();
        }
      });
    });
  }

  Future<void> _setupSMSAutoFill() async {
    try {
      print('🔧 Setting up SMS auto-fill...');

      _appSignature = await SmsAutoFill().getAppSignature;
      print(' App Signature: $_appSignature');

      try {
        String? phoneHint = await SmsAutoFill().hint;
        print(' Phone hint: $phoneHint');
      } catch (e) {
        print(' Phone hint failed: $e');
      }

      await SmsAutoFill().listenForCode();
      print('👂 Started listening for SMS...');

      _setupManualSMSListener();
    } catch (e) {
      print(' Error setting up SMS auto-fill: $e');
    }
  }

  void _setupManualSMSListener() {
    try {
      _smsSubscription = SmsAutoFill().code.listen((String receivedCode) {
        print(' Manual SMS listener received: $receivedCode');
        if (receivedCode.isNotEmpty) {
          _handleReceivedSMS(receivedCode);
        }
      });
    } catch (e) {
      print(' Error setting up manual SMS listener: $e');
    }
  }

  void _handleReceivedSMS(String receivedCode) {
    print('🔍 Processing received SMS: $receivedCode');

    String extractedOTP = _extractOTPFromCode(receivedCode);

    if (extractedOTP.length == 5 && extractedOTP.isNotEmpty) {
      print('✅ Extracted OTP: $extractedOTP');

      if (_autoFillPermissionGranted == null) {
        _pendingSMSCode = extractedOTP;
        _showAutoFillPermissionDialog(extractedOTP);
      } else if (_autoFillPermissionGranted == true) {
        _fillOTPFields(extractedOTP);
      } else {
        _showInfoMessage('OTP received. Please enter manually.');
      }
    } else {
      print('⚠️ Could not extract valid OTP from: $receivedCode');
    }
  }

  Future<void> _showAutoFillPermissionDialog(String otp) async {
    if (!mounted) return;

    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.sms, color: Colors.orange[700], size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'OTP Auto-fill',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We detected an OTP in your SMS:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: otp
                      .split('')
                      .map(
                        (digit) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            digit,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Would you like to automatically fill this OTP for you?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'You can change this preference anytime in settings.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          // actions: [
          //   TextButton(
          //     onPressed: () => Navigator.of(context).pop(false),
          //     style: TextButton.styleFrom(
          //       padding: const EdgeInsets.symmetric(
          //         horizontal: 20,
          //         vertical: 12,
          //       ),
          //     ),
          //     child: Text(
          //       'Deny',
          //       style: TextStyle(
          //         color: Colors.grey[600],
          //         fontWeight: FontWeight.w500,
          //       ),
          //     ),
          //   ),
          //   ElevatedButton(
          //     onPressed: () => Navigator.of(context).pop(true),
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: Colors.orange,
          //       foregroundColor: Colors.white,
          //       padding: const EdgeInsets.symmetric(
          //         horizontal: 20,
          //         vertical: 12,
          //       ),
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(8),
          //       ),
          //     ),
          //     child: const Text(
          //       'Allow',
          //       style: TextStyle(fontWeight: FontWeight.w600),
          //     ),
          //   ),
          // ],
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Red button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Deny',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12), // space between buttons
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // Green button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Allow',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    // Handle the user's choice
    if (mounted) {
      setState(() {
        _autoFillPermissionGranted = result ?? false;
      });

      if (result == true && _pendingSMSCode != null) {
        _fillOTPFields(_pendingSMSCode!);
      } else if (result == false) {
        _showInfoMessage('OTP received. Please enter manually.');
      }

      // Clear pending SMS code
      _pendingSMSCode = null;
    }
  }

  void _fillOTPFields(String otp) {
    // Fill the OTP fields

    for (int i = 0; i < 5; i++) {
      _otpControllers[i].text = otp[i];
    }
    _otpFocusNodes[4].requestFocus();
    _currentOTP = otp;
    setState(() {});

    _showSuccessMessage('OTP auto-filled successfully!');

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _currentOTP == otp) {
        _verifyOTP();
      }
    });
  }

  String _extractOTPFromCode(String receivedCode) {
    print('🔍 Extracting OTP from: $receivedCode');

    RegExp exactPattern = RegExp(r'Your OTP code is (\d{5})');
    Match? exactMatch = exactPattern.firstMatch(receivedCode);
    if (exactMatch != null) {
      return exactMatch.group(1) ?? '';
    }

    RegExp fallbackPattern = RegExp(r'\b\d{5}\b');
    Match? fallbackMatch = fallbackPattern.firstMatch(receivedCode);
    if (fallbackMatch != null) {
      return fallbackMatch.group(0) ?? '';
    }

    print(' No valid OTP pattern found');
    return '';
  }

  // Auto-fill callback from CodeAutoFill mixin
  @override
  void codeUpdated() {
    print('codeUpdated callback triggered');
    print('Received code: $code');

    if (code != null && code!.isNotEmpty) {
      _handleReceivedSMS(code!);
    }
  }

  // Send OTP via SMS gateway
  Future<bool> _sendOTPSMS(String phoneNumber, String otp) async {
    try {
      String baseUrl =
          'https://richcommunication.dialog.lk/api/sms/inline/send';

      String formattedPhone = phoneNumber;
      if (phoneNumber.startsWith('+94')) {
        formattedPhone = '0${phoneNumber.substring(3)}';
      }

      // ✅ Only clean text (no app signature)
      String message =
          'Your OTP code is $otp. Do not share this code with anyone.';
      if (_appSignature != null && _appSignature!.isNotEmpty) {
        message += '\u200B$_appSignature'; // hidden signature
      }

      String fullUrl =
          '$baseUrl?q=968deddf5fd84b8&destination=$formattedPhone&message=${Uri.encodeComponent(message)}';

      print('📤 Sending SMS to: $formattedPhone');
      print('🔢 OTP: $otp');
      print('💬 Message: $message');

      final response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode == 200) {
        print('✅ SMS sent successfully: ${response.body}');
        return true;
      } else {
        print('❌ SMS send failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending SMS: $e');
      return false;
    }
  }

  Future<void> _sendInitialOTP() async {
    setState(() {
      _isSendingOTP = true;
    });

    try {
      _actualOTP = _generateOTP();
      print('🔢 Generated OTP: $_actualOTP');

      bool sent = await _sendOTPSMS(widget.phoneNumber, _actualOTP!);

      if (!sent) {
        _showErrorMessage('Failed to send OTP. Please try again.');
      } else {
        _showSuccessMessage(
          'OTP sent to ${_formatPhoneNumber(widget.phoneNumber)}',
        );
      }
    } catch (e) {
      _showErrorMessage('Failed to send OTP. Please try again.');
      print('❌ Error in _sendInitialOTP: $e');
    } finally {
      setState(() {
        _isSendingOTP = false;
      });
    }
  }

  @override
  void dispose() {
    print('🧹 Disposing OTP screen...');

    try {
      ref.read(authProvider.notifier).clearPendingUser();
    } catch (e) {
      print('❌ Error clearing pending user data: $e');
    }
    // Clean up SMS auto-fill
    try {
      cancel(); // from CodeAutoFill mixin
      SmsAutoFill().unregisterListener();
      _smsSubscription?.cancel();
    } catch (e) {
      print('❌ Error disposing SMS auto-fill: $e');
    }

    // Clean up other resources
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
    if (_previousValues[index].isNotEmpty && value.isEmpty) {
      // This is backspace - move to previous field if exists
      if (index > 0) {
        Future.delayed(const Duration(milliseconds: 50), () {
          _otpFocusNodes[index - 1].requestFocus();
        });
      }
    }

    // Update previous value for next comparison
    _previousValues[index] = value;
    setState(() {
      _currentOTP = _otpControllers.map((controller) => controller.text).join();
    });

    if (value.isNotEmpty && index < 4) {
      _otpFocusNodes[index + 1].requestFocus();
    }

    // Auto-verify when all 5 digits are entered manually
    if (_currentOTP.length == 5) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _currentOTP.length == 5) {
          _verifyOTP();
        }
      });
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

    if (_isVerifying) return; // Prevent multiple verification attempts

    setState(() {
      _isVerifying = true;
    });

    try {
      print('🔍 Verifying OTP: $_currentOTP against $_actualOTP');

      bool isValid = await _simulateOTPVerification(_currentOTP);

      if (isValid) {
        _showSuccessMessage('OTP verified successfully!');
        await _completeLoginProcess();
      } else {
        _showErrorMessage('Invalid OTP. Please try again.');
        _clearOTPFields();
        // Clear pending user data on OTP failure
        ref.read(authProvider.notifier).clearPendingUser();
      }
    } catch (e) {
      _showErrorMessage('Verification failed. Please try again.');
      print('❌ OTP verification error: $e');
      // Clear pending user data on error
      ref.read(authProvider.notifier).clearPendingUser();
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<bool> _simulateOTPVerification(String otp) async {
    await Future.delayed(const Duration(seconds: 1));
    return otp == _actualOTP;
  }

  Future<void> _completeLoginProcess() async {
    try {
      print('🚀 Starting complete login process...');

      // Complete the login process after successful OTP verification
      await ref.read(authProvider.notifier).completeLoginAfterOTP();

      final authState = ref.read(authProvider);

      if (authState != null && authState.user != null) {
        print('✅ Login completed successfully, processing FCM token...');

        final salesCode = await StorageUtil.getSalesCode();

        if (salesCode != null) {
          // Set the sales code in the app mode provider
          ref.read(appmodeSettingsProvider.notifier).setSalesCode(salesCode);
          print('Sales code set in app mode provider: $salesCode');
        }

        final name = await StorageUtil.getUserName();
        final prefs = await SharedPreferences.getInstance();

        String? fcmtoken = await _getFCMTokenWithRetry();
        print('🔥 FCM Token after OTP verification: $fcmtoken');

        if (fcmtoken != null) {
          await prefs.setString('FCMToken', fcmtoken);
          print('💾 FCM Token saved to preferences');

          if (name != null) {
            await _syncTokenWithServer(name, fcmtoken);
          }
        } else {
          print('⚠️ FCM Token is null - will retry on token refresh');
          _setupTokenRefreshListener(name);
        }

        if (mounted) {
          print('🏠 Navigating to home screen...');
          context.go('/home');
        }
      } else {
        throw Exception('Authentication failed after OTP verification');
      }
    } catch (e) {
      print('❌ Error in complete login process: $e');
      _showErrorMessage('Login completion failed. Please try again.');

      // Clear pending user data on failure
      ref.read(authProvider.notifier).clearPendingUser();
    }
  }

  Future<String?> _getFCMTokenWithRetry({int maxRetries = 3}) async {
    print('🔥 Attempting to get FCM token...');

    for (int i = 0; i < maxRetries; i++) {
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          print('✅ FCM Token fetch attempt ${i + 1} successful');
          return token;
        }

        print('⚠️ FCM Token fetch attempt ${i + 1} returned null, retrying...');
        await Future.delayed(Duration(seconds: 1 + i));
      } catch (e) {
        print('❌ FCM Token fetch attempt ${i + 1} failed: $e');
        if (i == maxRetries - 1) return null;
        await Future.delayed(Duration(seconds: 1 + i));
      }
    }
    print('❌ All FCM token fetch attempts failed');
    return null;
  }

  void _setupTokenRefreshListener(String? name) {
    print('🔄 Setting up FCM token refresh listener...');

    FirebaseMessaging.instance.onTokenRefresh
        .listen((String token) async {
          print('🔄 FCM Token refreshed');

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('FCMToken', token);

          if (name != null) {
            await _syncTokenWithServer(name, token);
          }
        })
        .onError((err) {
          print('❌ FCM Token refresh error: $err');
        });
  }

  Future<void> _syncTokenWithServer(String name, String token) async {
    try {
      print('🔄 Syncing FCM token with server for user: $name');

      var result = await FirebaseApiService.syncFmcToken(name, token);

      if (result['success'] == true) {
        print('✅ FCM Token sent to server successfully');
      } else {
        print('❌ Failed to send FCM Token: ${result['error']}');
      }
    } catch (e) {
      print('❌ Error syncing FCM token with server: $e');
    }
  }

  void _clearOTPFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    // Clear previous values tracking
    for (int i = 0; i < _previousValues.length; i++) {
      _previousValues[i] = '';
    }
    _currentOTP = '';
    setState(() {});
    _otpFocusNodes[0].requestFocus();
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showInfoMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resendOTP() async {
    if (_resendSeconds > 0) return;

    setState(() {
      _isSendingOTP = true;
    });

    try {
      _actualOTP = _generateOTP();
      print('🔢 New OTP generated: $_actualOTP');

      bool sent = await _sendOTPSMS(widget.phoneNumber, _actualOTP!);

      if (sent) {
        _startResendTimer();
        _clearOTPFields();
        _showSuccessMessage('New OTP has been sent');
      } else {
        _showErrorMessage('Failed to resend OTP');
      }
    } catch (e) {
      _showErrorMessage('Failed to resend OTP');
      print('❌ Error in _resendOTP: $e');
    } finally {
      setState(() {
        _isSendingOTP = false;
      });
    }
  }

  String _formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.length > 6) {
      return phoneNumber.substring(0, 3) +
          '*' * (phoneNumber.length - 6) +
          phoneNumber.substring(phoneNumber.length - 3);
    }
    return phoneNumber;
  }

  // Debug button to test auto-fill manually
  void _testAutoFill() {
    String testOTP = _actualOTP ?? '12345';
    _handleReceivedSMS(
      'Your verification code is $testOTP. Do not share this code.',
    );
  }

  bool _programmatic = false;

  void _setDigit(int index, String ch) {
    _programmatic = true;
    _otpControllers[index].text = ch;
    _otpControllers[index].selection = TextSelection.collapsed(
      offset: ch.length,
    );
    _programmatic = false;
  }

  void _distributeFrom(int startIndex, String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    _programmatic = true;
    int i = 0;
    for (int box = startIndex; box < 5 && i < digits.length; box++, i++) {
      _otpControllers[box].text = digits[i];
      _otpControllers[box].selection = TextSelection.collapsed(offset: 1);
    }
    // clear remaining boxes if over-pasted or to reset tail
    for (int box = startIndex + i; box < 5; box++) {
      _otpControllers[box].clear();
    }
    _programmatic = false;

    final nextFocus = (startIndex + digits.length - 1).clamp(0, 4);
    _otpFocusNodes[nextFocus].requestFocus();

    setState(() {
      _currentOTP = _otpControllers.map((c) => c.text).join();
    });

    // Auto-verify if complete
    if (_currentOTP.length == 5 && !_currentOTP.contains('')) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _currentOTP.length == 5) _verifyOTP();
      });
    }
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
        title: const Text(
          'OTP Verification',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        // centerTitle: true,
        // actions: [
        //   // Debug button - remove in production
        //   if (kDebugMode)
        //     IconButton(
        //       icon: const Icon(Icons.bug_report, color: Colors.orange),
        //       onPressed: _testAutoFill,
        //       tooltip: 'Test Auto-fill',
        //     ),
        // ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Hero(
                  tag: 'hero-image',
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 150,
                    height: 150,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Verify Your Phone',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We\'ve sent a verification code to',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
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
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _otpControllers[index].text.isNotEmpty
                              ? Colors.orange
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _otpControllers[index].text.isNotEmpty
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.white,
                      ),
                      child: TextFormField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        keyboardType: TextInputType.number,
                        // IMPORTANT: remove LengthLimitingTextInputFormatter(1)
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        onChanged: (value) {
                          if (_programmatic) return;

                          // If user pasted/multi-typed, distribute across boxes
                          if (value.length > 1) {
                            _distributeFrom(index, value);
                            return;
                          }

                          if (value.isNotEmpty) {
                            // Keep only the last digit (just in case)
                            final last = value[value.length - 1];
                            if (value.length != 1) _setDigit(index, last);

                            // Move to next box
                            if (index < 4) {
                              _otpFocusNodes[index + 1].requestFocus();
                            }
                          } else {
                            // Became empty (likely backspace) → go to previous
                            if (index > 0) {
                              _otpFocusNodes[index - 1].requestFocus();
                              // Optional: also clear previous to emulate "delete previous"
                              // _setDigit(index - 1, '');
                            }
                          }

                          setState(() {
                            _currentOTP = _otpControllers
                                .map((c) => c.text)
                                .join();
                          });

                          if (_currentOTP.length == 5 &&
                              !_currentOTP.contains('')) {
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                if (mounted && _currentOTP.length == 5) {
                                  _verifyOTP();
                                }
                              },
                            );
                          }
                        },
                        onTap: () {
                          // put cursor at end of the char (cosmetic)
                          final t = _otpControllers[index].text;
                          _otpControllers[index].selection =
                              TextSelection.collapsed(offset: t.length);
                        },
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 20),

                // Auto-fill status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _autoFillPermissionGranted == true
                        ? Colors.green.withOpacity(0.1)
                        : _autoFillPermissionGranted == false
                        ? Colors.red.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _autoFillPermissionGranted == true
                            ? Icons.check_circle
                            : _autoFillPermissionGranted == false
                            ? Icons.cancel
                            : Icons.sms,
                        size: 16,
                        color: _autoFillPermissionGranted == true
                            ? Colors.green[700]
                            : _autoFillPermissionGranted == false
                            ? Colors.red[700]
                            : Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _autoFillPermissionGranted == true
                            ? 'Auto-fill enabled'
                            : _autoFillPermissionGranted == false
                            ? 'Auto-fill disabled'
                            : 'SMS Auto-fill ready',
                        style: TextStyle(
                          fontSize: 12,
                          color: _autoFillPermissionGranted == true
                              ? Colors.green[700]
                              : _autoFillPermissionGranted == false
                              ? Colors.red[700]
                              : Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Resend Timer/Button
                if (_resendSeconds > 0)
                  Text(
                    'Resend code in $_resendSeconds seconds',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  )
                else
                  Column(
                    children: [
                      Text(
                        'Didn\'t receive the code?',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _isSendingOTP ? null : _resendOTP,
                        child: const Text(
                          'Resend Code',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 40),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentOTP.length == 5
                          ? Colors.orange
                          : Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: _currentOTP.length == 5 ? 2 : 0,
                    ),
                    onPressed: _currentOTP.length == 5 && !_isVerifying
                        ? _verifyOTP
                        : null,
                    child: _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify & Continue',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),

          // Loading overlay for sending OTP
          if (_isSendingOTP)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.orange,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Sending OTP...',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
