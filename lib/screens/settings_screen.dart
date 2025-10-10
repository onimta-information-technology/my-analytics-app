import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/services/biometric_service.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart'
    hide AppMode;
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final String _selectedFontWeight = 'Normal';
  bool _canShowOverallData = false;
  final _biometricService = BiometricService();

  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
    _initializeBiometrics();
  }

  Future<void> _checkUserPermissions() async {
    final salesCode = await StorageUtil.getSalesCode();

    // Set the sales code in the provider
    if (salesCode != null) {
      ref.read(appmodeSettingsProvider.notifier).setSalesCode(salesCode);
    }

    setState(() {
      _canShowOverallData = salesCode == 'AD001';
    });
  }

  Future<void> _initializeBiometrics() async {
    final isAvailable = await _biometricService.isDeviceSupported();
    final isEnabled = await _biometricService.isBiometricEnabled();
    final biometrics = await _biometricService.getAvailableBiometrics();

    setState(() {
      _isBiometricAvailable = isAvailable;
      _isBiometricEnabled = isEnabled;
      _availableBiometrics = biometrics;
    });
  }

  Future<void> _handleBiometricToggle(bool value) async {
    if (value && _isBiometricAvailable) {
      // Enable biometric - ask for username and password
      await _showBiometricEnableDialog();
    } else if (!value && _isBiometricEnabled) {
      // Disable biometric
      await _disableBiometric();
    }
  }

  Future<void> _showBiometricEnableDialog() async {
    final biometricName = _biometricService.getBiometricTypeName(
      _availableBiometrics,
    );

    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    bool showPassword = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                child: Icon(
                  _availableBiometrics.contains(BiometricType.face)
                      ? Icons.face
                      : Icons.fingerprint,
                  color: Colors.orange[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable $biometricName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your credentials to enable $biometricName for quick login',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          showPassword = !showPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
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
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your credentials will be stored securely',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                    'Cancel',
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
      ),
    );

    usernameController.dispose();
    passwordController.dispose();

    if (result == true) {
      final username = usernameController.text.trim();
      final password = passwordController.text;

      if (username.isNotEmpty && password.isNotEmpty) {
        await _enableBiometric(username, password);
      } else {
        _showErrorSnackBar('Please enter both username and password');
      }
    }
  }

  Future<void> _enableBiometric(String username, String password) async {
    try {
      await _biometricService.saveCredentials(username, password);
      setState(() {
        _isBiometricEnabled = true;
      });
      _showSuccessSnackBar(
        '${_biometricService.getBiometricTypeName(_availableBiometrics)} enabled successfully',
      );
    } catch (e) {
      print('Error enabling biometric: $e');
      _showErrorSnackBar('Failed to enable biometric authentication');
    }
  }

  Future<void> _disableBiometric() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Biometric'),
        content: const Text(
          'Are you sure you want to disable biometric authentication?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _biometricService.disableBiometric();
        setState(() {
          _isBiometricEnabled = false;
        });
        _showSuccessSnackBar('Biometric authentication disabled');
      } catch (e) {
        print('Error disabling biometric: $e');
        _showErrorSnackBar('Failed to disable biometric authentication');
      }
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double selectedFontSize = ref.watch(fontSettingsProvider).fontSize;
    final appModeNotifier = ref.read(appmodeSettingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_canShowOverallData) ...[
                  const Text(
                    'App Mode',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAppModeButton(AppMode.myData, 'Show My Data'),
                      _buildAppModeButton(
                        AppMode.overallData,
                        'Show Overall Data',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  // For regular users, only show My Data option (non-interactive)
                  const Text('App Mode', style: TextStyle(fontSize: 16.0)),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Constants.kSecondaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Show My Data',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                const Text(
                  'Font Size Settings',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFontSizeButton(14.0, 'Small'),
                    _buildFontSizeButton(16.0, 'Medium'),
                    _buildFontSizeButton(18.0, 'Large'),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Font Weight Settings',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFontWeightButton(FontWeight.normal, 'Normal'),
                    _buildFontWeightButton(FontWeight.bold, 'Bold'),
                    _buildFontWeightButton(FontWeight.w900, 'Extra Bold'),
                  ],
                ),
                const SizedBox(height: 20),
                // Biometric Settings
                if (_isBiometricAvailable) ...[
                  const Text(
                    'Biometric Authentication',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _availableBiometrics.contains(BiometricType.face)
                                  ? Icons.face
                                  : Icons.fingerprint,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _biometricService.getBiometricTypeName(
                                    _availableBiometrics,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isBiometricEnabled ? 'Enabled' : 'Disabled',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _isBiometricEnabled
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: _isBiometricEnabled,
                          activeColor: Colors.orange,
                          onChanged: _handleBiometricToggle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
                const Spacer(),
                // Logout Button
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
          //const Watermark(),
        ],
      ),
    );
  }

  Widget _buildFontSizeButton(double size, String name) {
    return ElevatedButton(
      onPressed: () {
        ref.read(fontSettingsProvider.notifier).setFontSize(size);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: ref.watch(fontSettingsProvider).fontSize == size
            ? Constants.kSecondaryColor
            : Colors.grey[300],
        foregroundColor: ref.watch(fontSettingsProvider).fontSize == size
            ? Colors.white
            : Colors.black,
      ),
      child: Text(name),
    );
  }

  Widget _buildFontWeightButton(FontWeight weight, String name) {
    return ElevatedButton(
      onPressed: () {
        ref.read(fontSettingsProvider.notifier).setFontWeight(weight);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: ref.watch(fontSettingsProvider).fontWeight == weight
            ? Constants.kSecondaryColor
            : Colors.grey[300],
        foregroundColor: ref.watch(fontSettingsProvider).fontWeight == weight
            ? Colors.white
            : Colors.black,
      ),
      child: Text(name),
    );
  }

  Widget _buildAppModeButton(AppMode mode, String name) {
    // Only rebuild this widget when appMode changes
    final selectedMode = ref.watch(
      appmodeSettingsProvider.select((s) => s.appMode),
    );

    return ElevatedButton(
      onPressed: () {
        ref.read(appmodeSettingsProvider.notifier).setAppMode(mode);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: selectedMode == mode
            ? Constants.kSecondaryColor
            : Colors.grey[300],
        foregroundColor: selectedMode == mode ? Colors.white : Colors.black,
      ),
      child: Text(name),
    );
  }
}
