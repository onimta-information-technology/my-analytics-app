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
      // Enable biometric - directly prompt for biometric authentication
      await _enableBiometricDirectly();
    } else if (!value && _isBiometricEnabled) {
      // Disable biometric
      await _disableBiometric();
    }
  }

  Future<void> _enableBiometricDirectly() async {
    try {
      final biometricName = _biometricService.getBiometricTypeName(
        _availableBiometrics,
      );

      // Get current user credentials from storage
      final username = await _getStoredUsename();
      final password = await _getStoredPassword();

      if (username == null || username.isEmpty) {
        _showErrorSnackBar('User credentials not found. Please login first.');
        return;
      }

      print('🔐 Requesting $biometricName authentication to enable...');

      // Authenticate with biometric
      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to enable $biometricName for login',
      );

      if (authenticated) {
        // Save credentials and enable biometric
        if (password != null) {
          await _biometricService.saveCredentials(username, password);
          setState(() {
            _isBiometricEnabled = true;
          });
          _showSuccessSnackBar('$biometricName enabled successfully');
          print('✅ $biometricName enabled successfully');
        } else {
          _showErrorSnackBar('Password not found. Please login again.');
        }
      } else {
        print('❌ Biometric authentication cancelled or failed');
      }
    } catch (e) {
      print('❌ Error enabling biometric: $e');
      _showErrorSnackBar('Failed to enable biometric authentication');
    }
  }

  // Helper method to get stored password from auth provider or secure storage
  Future<String?> _getStoredPassword() async {
    try {
      // First try to get password from current session (in memory)
      final sessionPassword = ref
          .read(authProvider.notifier)
          .getCurrentSessionPassword();
      if (sessionPassword != null && sessionPassword.isNotEmpty) {
        print('✅ Retrieved password from current session');
        return sessionPassword;
      }

      // If not in session, check if we have stored biometric credentials
      final credentials = await _biometricService.getCredentials();
      if (credentials != null && credentials['password'] != null) {
        print('✅ Retrieved password from biometric storage');
        return credentials['password'];
      }

      print('⚠️ No password found in session or storage');
      return null;
    } catch (e) {
      print('Error getting stored password: $e');
      return null;
    }
  }

  Future<String?> _getStoredUsename() async {
    try {
      // First try to get password from current session (in memory)
      final sessionUsername = ref
          .read(authProvider.notifier)
          .getCurrentSessionUsername();
      if (sessionUsername != null && sessionUsername.isNotEmpty) {
        print('✅ Retrieved Username from current session');
        return sessionUsername;
      }

      // If not in session, check if we have stored biometric credentials
      final credentials = await _biometricService.getCredentials();
      if (credentials != null && credentials['username'] != null) {
        print('✅ Retrieved username from biometric storage');
        return credentials['username'];
      }

      print('⚠️ No username found in session or storage');
      return null;
    } catch (e) {
      print('Error getting stored username: $e');
      return null;
    }
  }

  Future<void> _disableBiometric() async {
    final biometricName = _biometricService.getBiometricTypeName(
      _availableBiometrics,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Disable Biometric',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to disable $biometricName authentication?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Disable',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
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
        _showSuccessSnackBar('$biometricName authentication disabled');
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
