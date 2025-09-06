import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  ConsumerState<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(5, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(5, (index) => FocusNode());
  
  Timer? _timer;
  int _resendSeconds = 47;
  bool _isVerifying = false;
  String _currentOTP = '';

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    
    // Auto-focus first input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNodes[0].requestFocus();
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
      // Since you don't have SMS gateway yet, simulate verification
      // Replace this with your actual OTP verification logic
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate OTP verification
      bool isValid = await _simulateOTPVerification(_currentOTP);
      
      if (isValid) {
        // OTP is valid, proceed with actual login
        await _performActualLogin();
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
    // For now, accept any 5-digit OTP for testing
    return otp.length == 5 && otp.contains(RegExp(r'^\d+$'));
  }

  Future<void> _performActualLogin() async {
    try {
      // Here you would perform the actual login with username/password
      // and then navigate to home screen
      
      // For now, just navigate to home
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      _showErrorMessage('Login failed after OTP verification');
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
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resendOTP() async {
    if (_resendSeconds > 0) return;

    try {
      // Simulate resending OTP
      await Future.delayed(const Duration(seconds: 1));
      
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
    } catch (e) {
      _showErrorMessage('Failed to resend OTP');
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
                const SizedBox(height: 60),
                
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange, width: 3),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 8,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(2),
                                  topRight: Radius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 8,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(2),
                                  topRight: Radius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 8,
                              height: 35,
                              decoration: const BoxDecoration(
                                color: Colors.yellow,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(2),
                                  topRight: Radius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
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
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 2,
                        ),
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
                          _otpControllers[index].selection = TextSelection.fromPosition(
                            TextPosition(offset: _otpControllers[index].text.length),
                          );
                        },
                        onEditingComplete: () {
                          if (_otpControllers[index].text.isEmpty && index > 0) {
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
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
        ],
      ),
    );
  }
}