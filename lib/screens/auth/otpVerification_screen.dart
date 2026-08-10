import 'dart:async';
import 'dart:math';
import 'package:ballys_reservation_app/data/services/biometric_service.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:sms_autofill/sms_autofill.dart';

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

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> with ConnectivityMixin{
    // with CodeAutoFill {
  String? _actualOTP;
  bool _isSendingOTP = false;
  //String? _appSignature;
  final _biometricService = BiometricService();

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
  bool _verificationCompleted = false;
  String _currentOTP = '';
  StreamSubscription? _smsSubscription;

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
    //await _setupSMSAutoFill();
    _startResendTimer();
    await _sendInitialOTP();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _otpFocusNodes[0].requestFocus();
        }
      });
    });
  }

  // Future<void> _setupSMSAutoFill() async {
  //   try {
  //     _appSignature = await SmsAutoFill().getAppSignature;
  //     try {
  //       String? phoneHint = await SmsAutoFill().hint;
  //     } catch (e) {}

  //     await SmsAutoFill().listenForCode();

  //     _setupManualSMSListener();
  //   } catch (e) {}
  // }

  // void _setupManualSMSListener() {
  //   try {
  //     _smsSubscription = SmsAutoFill().code.listen((String receivedCode) {
  //       if (receivedCode.isNotEmpty) {
  //         _handleReceivedSMS(receivedCode);
  //       }
  //     });
  //   } catch (e) {}
  // }

  // void _handleReceivedSMS(String receivedCode) {
  //   String extractedOTP = _extractOTPFromCode(receivedCode);

  //   if (extractedOTP.length == 5 && extractedOTP.isNotEmpty) {
  //     if (_autoFillPermissionGranted == null) {
  //       _pendingSMSCode = extractedOTP;
  //       _showAutoFillPermissionDialog(extractedOTP);
  //     } else if (_autoFillPermissionGranted == true) {
  //       _fillOTPFields(extractedOTP);
  //     } else {
  //       _showInfoMessage('OTP received. Please enter manually.');
  //     }
  //   } else {}
  // }

  // Future<void> _showAutoFillPermissionDialog(String otp) async {
  //   if (!mounted) return;

  //   bool? result = await showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(16),
  //         ),
  //         title: Row(
  //           children: [
  //             Container(
  //               padding: const EdgeInsets.all(8),
  //               decoration: BoxDecoration(
  //                 color: Colors.orange.withOpacity(0.1),
  //                 borderRadius: BorderRadius.circular(8),
  //               ),
  //               child: Icon(Icons.sms, color: Colors.orange[700], size: 24),
  //             ),
  //             const SizedBox(width: 12),
  //             const Expanded(
  //               child: Text(
  //                 'OTP Auto-fill',
  //                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  //               ),
  //             ),
  //           ],
  //         ),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             const Text(
  //               'We detected an OTP in your SMS:',
  //               style: TextStyle(fontSize: 16),
  //             ),
  //             const SizedBox(height: 12),
  //             Container(
  //               padding: const EdgeInsets.all(12),
  //               decoration: BoxDecoration(
  //                 color: Colors.grey[100],
  //                 borderRadius: BorderRadius.circular(8),
  //                 border: Border.all(color: Colors.grey[300]!),
  //               ),
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.center,
  //                 children: otp
  //                     .split('')
  //                     .map(
  //                       (digit) => Container(
  //                         margin: const EdgeInsets.symmetric(horizontal: 4),
  //                         padding: const EdgeInsets.symmetric(
  //                           horizontal: 8,
  //                           vertical: 4,
  //                         ),
  //                         decoration: BoxDecoration(
  //                           color: Colors.orange.withOpacity(0.1),
  //                           borderRadius: BorderRadius.circular(6),
  //                         ),
  //                         child: Text(
  //                           digit,
  //                           style: const TextStyle(
  //                             fontSize: 18,
  //                             fontWeight: FontWeight.bold,
  //                             color: Colors.orange,
  //                           ),
  //                         ),
  //                       ),
  //                     )
  //                     .toList(),
  //               ),
  //             ),
  //             const SizedBox(height: 16),
  //             const Text(
  //               'Would you like to automatically fill this OTP for you?',
  //               style: TextStyle(fontSize: 16),
  //             ),
  //             const SizedBox(height: 8),
  //             Text(
  //               'You can change this preference anytime in settings.',
  //               style: TextStyle(fontSize: 14, color: Colors.grey[600]),
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.end,
  //             children: [
  //               ElevatedButton(
  //                 onPressed: () => Navigator.of(context).pop(false),
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: Colors.red,
  //                   foregroundColor: Colors.white,
  //                   padding: const EdgeInsets.symmetric(
  //                     horizontal: 20,
  //                     vertical: 12,
  //                   ),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                 ),
  //                 child: const Text(
  //                   'Deny',
  //                   style: TextStyle(fontWeight: FontWeight.w600),
  //                 ),
  //               ),
  //               const SizedBox(width: 12),
  //               ElevatedButton(
  //                 onPressed: () => Navigator.of(context).pop(true),
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: Colors.green,
  //                   foregroundColor: Colors.white,
  //                   padding: const EdgeInsets.symmetric(
  //                     horizontal: 20,
  //                     vertical: 12,
  //                   ),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                 ),
  //                 child: const Text(
  //                   'Allow',
  //                   style: TextStyle(fontWeight: FontWeight.w600),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ],
  //       );
  //     },
  //   );

  //   if (mounted) {
  //     setState(() {
  //       _autoFillPermissionGranted = result ?? false;
  //     });

  //     if (result == true && _pendingSMSCode != null) {
  //       _fillOTPFields(_pendingSMSCode!);
  //     } else if (result == false) {
  //       _showInfoMessage('OTP received. Please enter manually.');
  //     }

  //     _pendingSMSCode = null;
  //   }
  // }

  void _fillOTPFields(String otp) {
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

    return '';
  }

  // @override
  // void codeUpdated() {
  //   if (code != null && code!.isNotEmpty) {
  //     _handleReceivedSMS(code!);
  //   }
  // }

  // Future<bool> _sendOTPSMS(String phoneNumber, String otp) async {
  //   try {
  //     String baseUrl =
  //         'https://richcommunication.dialog.lk/api/sms/inline/send';

  //     String formattedPhone = phoneNumber;
  //     if (phoneNumber.startsWith('+94')) {
  //       formattedPhone = '0${phoneNumber.substring(3)}';
  //     }

  //     String message =
  //         'Your OTP code is $otp. Do not share this code with anyone.';
  //     // if (_appSignature != null && _appSignature!.isNotEmpty) {
  //     //   message += '\u200B$_appSignature';
  //     // }

  //     String fullUrl =
  //         '$baseUrl?q=968deddf5fd84b8&destination=$formattedPhone&message=${Uri.encodeComponent(message)}';

  //     final response = await http.get(Uri.parse(fullUrl));

  //     if (response.statusCode == 200) {
  //       return true;
  //     } else {
  //       return false;
  //     }
  //   } catch (e) {
  //     return false;
  //   }
  // }
Future<bool> _sendOTPSMS(String phoneNumber, String otp) async {
  try {
    // Get SMS gateway URL from current location
    final smsGatewayUrl = await StorageUtil.getSmsGatewayUrl();
    print("text");
print(smsGatewayUrl);
    if (smsGatewayUrl == null || smsGatewayUrl.isEmpty) {
      return false;
    }

    String formattedPhone = phoneNumber;
    if (phoneNumber.startsWith('+94')) {
      formattedPhone = '0${phoneNumber.substring(3)}';
    }

    final message = 'Your OTP code is $otp. Do not share this code with anyone.';

    // Replace placeholders: xxxxx = destination, yyyyy = message
    final fullUrl = smsGatewayUrl
        .replaceAll('xxxxx', formattedPhone)
        .replaceAll('yyyyy', Uri.encodeComponent(message));
print(fullUrl);
    final response = await http
        .get(Uri.parse(fullUrl))
        .timeout(const Duration(seconds: 10));
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}

  // Fires SMS and WhatsApp at the same time so the loader isn't held open by
  // the slower channel after the OTP has already reached the phone.
  Future<bool> _dispatchOTP(String otp) async {
    final authRepo = ref.read(authRepositoryProvider);

    final results = await Future.wait([
      _sendOTPSMS(widget.phoneNumber, otp),
      authRepo.sendOtpWhatsApp(widget.phoneNumber, otp),
    ]);

    // The user only needs the code to arrive on one channel.
    return results.any((sent) => sent);
  }

  Future<void> _sendInitialOTP() async {
    setState(() {
      _isSendingOTP = true;
    });

    try {
      _actualOTP = _generateOTP();
      final sent = await _dispatchOTP(_actualOTP!);

      if (!mounted) return;
      if (sent) {
        _showSuccessMessage(
          'OTP sent to ${_formatPhoneNumber(widget.phoneNumber)}',
        );
      } else {
        _showErrorMessage('Failed to send OTP. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to send OTP. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOTP = false;
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      // cancel();
      // SmsAutoFill().unregisterListener();
      _smsSubscription?.cancel();
    } catch (e) {}

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

  Future<void> _verifyOTP() async {
    if (_currentOTP.length != 5) {
      _showErrorMessage('Please enter complete OTP');
      return;
    }

    // Guard against re-entry AND against a second auto-verify firing after a
    // successful verification has already navigated away — otherwise the second
    // call runs on a deactivated widget and crashes.
    if (_isVerifying || _verificationCompleted) return;

    setState(() {
      _isVerifying = true;
    });

    try {
      bool isValid = await _simulateOTPVerification(_currentOTP);

      if (isValid) {
        _verificationCompleted = true;
        _showSuccessMessage('OTP verified successfully!');

        // Check if biometric should be offered
        await _checkAndOfferBiometric();

        await _completeLoginProcess();
      } else {
        _showErrorMessage('Invalid OTP. Please try again.');
        _clearOTPFields();
      }
    } catch (e) {
      _verificationCompleted = false;
      _showErrorMessage('Verification failed. Please try again.');

      ref.read(authProvider.notifier).clearPendingUser();
    } finally {
      // Widget may already be navigating away (and thus unmounted) after a
      // successful verification — never call setState on a dead element.
      if (mounted && !_verificationCompleted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _checkAndOfferBiometric() async {
    try {
      // Check if device supports biometrics
      final isAvailable = await _biometricService.isDeviceSupported();
      if (!isAvailable) {
        return;
      }

      // Check if biometric is already enabled
      final isEnabled = await _biometricService.isBiometricEnabled();
      if (isEnabled) {
        return;
      }

      // Show biometric enable dialog
      await _showBiometricEnableDialog();
    } catch (e) {}
  }

  Future<void> _showBiometricEnableDialog() async {
    if (!mounted) return;

    final availableBiometrics = await _biometricService
        .getAvailableBiometrics();
    final biometricName = _biometricService.getBiometricTypeName(
      availableBiometrics,
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                availableBiometrics.contains(BiometricType.face)
                    ? Icons.face
                    : Icons.fingerprint,
                color: Colors.orange[700],
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enable $biometricName?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use $biometricName for quick and secure login next time?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your credentials will be stored securely on your device',
                      style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Not Now',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
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
                  'Enable',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _enableBiometric();
    }
  }

  Future<void> _enableBiometric() async {
    try {
      // Save the credentials that were used for this login
      await _biometricService.saveCredentials(widget.username, widget.password);

      _showSuccessMessage('Biometric authentication enabled successfully!');
    } catch (e) {
      _showErrorMessage('Failed to enable biometric authentication');
    }
  }

  Future<bool> _simulateOTPVerification(String otp) async {
    await Future.delayed(const Duration(seconds: 1));
    return otp == _actualOTP;
  }

  Future<void> _completeLoginProcess() async {
  try {
    await ref.read(authProvider.notifier).completeLoginAfterOTP();

    final authState = ref.read(authProvider);

    if (authState != null && authState.user != null) {
      final salesCode = await StorageUtil.getSalesCode();

      if (salesCode != null) {
        ref.read(appmodeSettingsProvider.notifier).setSalesCode(salesCode);
      }

      final name = await StorageUtil.getUserName();

      // ✅ MARK USER AS LOGGED IN
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);

      // ✅ Navigate to home immediately. Notification permission + FCM token
      // work must NOT block navigation — after logout deletes the FCM token,
      // getToken() can hang in the same app session and would otherwise leave
      // the user stuck on the OTP screen.
      if (mounted) {
        context.go('/home');
      }

      // Fire-and-forget: runs in the background, does not touch this widget.
      unawaited(_completePostLoginSetup(name));
    } else {
      throw Exception('Authentication failed after OTP verification');
    }
  } catch (e) {
    _showErrorMessage('Login completion failed. Please try again.');
    ref.read(authProvider.notifier).clearPendingUser();
  }
}

  Future<void> _completePostLoginSetup(String? name) async {
    try {
      await _requestNotificationPermissions();

      final prefs = await SharedPreferences.getInstance();
      String? fcmtoken = await _getFCMTokenWithRetry();
      if (fcmtoken != null) {
        await prefs.setString('FCMToken', fcmtoken);

        if (name != null) {
          await _syncTokenWithServer(name, fcmtoken);
        }
      } else {
        _setupTokenRefreshListener(name);
      }
    } catch (e) {
      print('Post-login setup failed (non-blocking): $e');
    }
  }


  Future<void> _requestNotificationPermissions() async {
    try {
      // Small delay so user sees successful verification
      await Future.delayed(const Duration(milliseconds: 500));

      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('Notification permissions granted');
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('Notification permissions denied');
        // Don't show error or redirect - continue normally
      }
    } catch (e) {
      print('Error requesting notification permissions: $e');
      // Don't show error to user - just continue
    }
  }

  Future<String?> _getFCMTokenWithRetry({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        // Guard against getToken() hanging (e.g. after deleteToken() on logout
        // without an app restart) — never let it block the caller indefinitely.
        String? token = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 5));
        if (token != null) {
          return token;
        }
        await Future.delayed(Duration(seconds: 1 + i));
      } catch (e) {
        if (i == maxRetries - 1) return null;
        await Future.delayed(Duration(seconds: 1 + i));
      }
    }
    return null;
  }

  void _setupTokenRefreshListener(String? name) {
    FirebaseMessaging.instance.onTokenRefresh
        .listen((String token) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('FCMToken', token);

          if (name != null) {
            await _syncTokenWithServer(name, token);
          }
        })
        .onError((err) {});
  }

  Future<void> _syncTokenWithServer(String name, String token) async {
    try {
      var result = await FirebaseApiService.syncFmcToken(name, token);

      if (result['success'] == true) {
      } else {}
    } catch (e) {}
  }

  void _clearOTPFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    for (int i = 0; i < _previousValues.length; i++) {
      _previousValues[i] = '';
    }
    _currentOTP = '';
    setState(() {});
    _otpFocusNodes[0].requestFocus();
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    try {
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
    } catch (_) {
      // Widget is mid-deactivation (e.g. navigating away) — ancestor lookup
      // is unsafe; skip the snackbar rather than throw.
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    try {
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
    } catch (_) {
      // See _showErrorMessage.
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
      final sent = await _dispatchOTP(_actualOTP!);

      if (!mounted) return;
      if (sent) {
        _startResendTimer();
        _clearOTPFields();
        _showSuccessMessage('New OTP has been sent');
      } else {
        _showErrorMessage('Failed to resend OTP');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to resend OTP');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOTP = false;
        });
      }
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
    for (int box = startIndex + i; box < 5; box++) {
      _otpControllers[box].clear();
    }
    _programmatic = false;

    final nextFocus = (startIndex + digits.length - 1).clamp(0, 4);
    _otpFocusNodes[nextFocus].requestFocus();

    setState(() {
      _currentOTP = _otpControllers.map((c) => c.text).join();
    });

    if (_currentOTP.length == 5 && !_isVerifying) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _currentOTP.length == 5 && !_isVerifying) {
          _verifyOTP();
        }
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
          onPressed: () {
            ref.read(authProvider.notifier).clearPendingUser();
            context.pop();
          },
        ),
        title: const Text(
          'OTP Verification',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // NOTE: intentionally NOT a Hero. Sharing the 'hero-image' tag
                // with the login screen caused a GlobalKey reparenting crash
                // ("_elements.contains(element)") when context.go('/home')
                // tears down both routes at once with no matching hero on home.
                Image.asset(
                  'assets/images/logo.png',
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verify Your Phone',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'We\'ve sent a verification code to',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPhoneNumber(widget.phoneNumber),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 20),

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
                         autofillHints: const [AutofillHints.oneTimeCode],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        onChanged: (value) {
                          if (_programmatic) return;

                          if (value.length > 1) {
                            _distributeFrom(index, value);
                            return;
                          }

                          if (value.isNotEmpty) {
                            final last = value[value.length - 1];
                            if (value.length != 1) _setDigit(index, last);

                            if (index < 4) {
                              _otpFocusNodes[index + 1].requestFocus();
                            }
                          } else {
                            if (index > 0) {
                              _otpFocusNodes[index - 1].requestFocus();
                            }
                          }

                          setState(() {
                            _currentOTP = _otpControllers
                                .map((c) => c.text)
                                .join();
                          });

                          if (_currentOTP.length == 5 && !_isVerifying) {
                            Future.delayed(
                              const Duration(milliseconds: 800),
                              () {
                                if (mounted &&
                                    _currentOTP.length == 5 &&
                                    !_isVerifying) {
                                  _verifyOTP();
                                }
                              },
                            );
                          }
                        },
                        onTap: () {
                          final t = _otpControllers[index].text;
                          _otpControllers[index].selection =
                              TextSelection.collapsed(offset: t.length);
                        },
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 10),

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

                const SizedBox(height: 30),

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
