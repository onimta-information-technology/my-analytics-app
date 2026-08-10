import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/services/biometric_service.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart' hide AppMode;
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  bool _canShowOverallData = false;
  bool _isOverallDataOnly = false;
  final _biometricService = BiometricService();

  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];

  // ─── NOTIFICATIONS ────────────────────────────────────────────────────────
  bool _isNotificationsEnabled = false;
  bool _isNotificationLoading = false;
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // To re-check when returning from app settings
    _checkUserPermissions();
    _initializeBiometrics();
    _loadNotificationSetting();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check notification status when user returns from system settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotificationSetting();
    }
  }

  // ─── NOTIFICATION METHODS ─────────────────────────────────────────────────

  Future<void> _loadNotificationSetting() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final isEnabled =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (mounted) {
      setState(() {
        _isNotificationsEnabled = isEnabled;
      });
    }
  }

  Future<void> _handleNotificationToggle(bool value) async {
    if (_isNotificationLoading) return;
    setState(() => _isNotificationLoading = true);

    try {
      if (value) {
        // ── ENABLE: request Firebase permission ──────────────────────────
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        final granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

        if (granted) {
          // Clear dismissed flag so the banner can show again if needed
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('notification_banner_dismissed');

          if (mounted) {
            setState(() => _isNotificationsEnabled = true);
            _showSuccessSnackBar('Notifications enabled');
          }
        } else {
          // System denied — send user to app settings
          if (mounted) {
            final shouldOpen = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(Icons.notifications_active,
                        color: Colors.orange[700], size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Enable Notifications',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                content: const Text(
                  'Notification permission was denied. Please open app settings to enable notifications manually.',
                  style: TextStyle(fontSize: 15),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Open Settings',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );

            if (shouldOpen == true) {
              await AppSettings.openAppSettings(
                  type: AppSettingsType.notification);
            }
          }
        }
      } else {
        // ── DISABLE: can only be done via system settings on mobile ─────
        if (mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.notifications_off,
                      color: Colors.orange[700], size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Disable Notifications',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: const Text(
                'To disable notifications, please turn them off in your device\'s app settings.',
                style: TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Open Settings',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );

          if (shouldOpen == true) {
            await AppSettings.openAppSettings(
                type: AppSettingsType.notification);
            // Status will re-sync in didChangeAppLifecycleState when user returns
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update notification settings');
    } finally {
      if (mounted) setState(() => _isNotificationLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _checkUserPermissions() async {
    final salesCode = await StorageUtil.getSalesCode();
    if (salesCode != null) {
      ref.read(appmodeSettingsProvider.notifier).setSalesCode(salesCode);
    }
    // Marketing_Code 0 means no marketing group, so overall data is the only
    // mode that makes sense — no switch. Otherwise only MArketing_P users may
    // switch between their own and overall data.
    final hasMarketingPermission = await StorageUtil.getMarketingP();
    final hasOwnMarketingGroup = await StorageUtil.hasOwnMarketingGroup();
    if (!mounted) return;
    setState(() {
      _canShowOverallData = hasMarketingPermission && hasOwnMarketingGroup;
      _isOverallDataOnly = !hasOwnMarketingGroup;
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
      await _enableBiometricDirectly();
    } else if (!value && _isBiometricEnabled) {
      await _disableBiometric();
    }
  }

  Future<void> _enableBiometricDirectly() async {
    try {
      final biometricName =
          _biometricService.getBiometricTypeName(_availableBiometrics);
      final username = await _getStoredUsename();
      final password = await _getStoredPassword();
      if (username == null || username.isEmpty) {
        _showErrorSnackBar('User credentials not found. Please login first.');
        return;
      }
      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to enable $biometricName for login',
      );
      if (authenticated) {
        if (password != null) {
          await _biometricService.saveCredentials(username, password);
          setState(() => _isBiometricEnabled = true);
          _showSuccessSnackBar('$biometricName enabled successfully');
        } else {
          _showErrorSnackBar('Password not found. Please login again.');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to enable biometric authentication');
    }
  }

  Future<String?> _getStoredPassword() async {
    try {
      final sessionPassword =
          ref.read(authProvider.notifier).getCurrentSessionPassword();
      if (sessionPassword != null && sessionPassword.isNotEmpty) {
        return sessionPassword;
      }
      final credentials = await _biometricService.getCredentials();
      return credentials?['password'];
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getStoredUsename() async {
    try {
      final sessionUsername =
          ref.read(authProvider.notifier).getCurrentSessionUsername();
      if (sessionUsername != null && sessionUsername.isNotEmpty) {
        return sessionUsername;
      }
      final credentials = await _biometricService.getCredentials();
      return credentials?['username'];
    } catch (e) {
      return null;
    }
  }

  Future<void> _disableBiometric() async {
    final biometricName =
        _biometricService.getBiometricTypeName(_availableBiometrics);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[700], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Disable Biometric',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Disable',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _biometricService.disableBiometric();
        setState(() => _isBiometricEnabled = false);
        _showSuccessSnackBar('$biometricName authentication disabled');
      } catch (e) {
        _showErrorSnackBar('Failed to disable biometric authentication');
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Delete Account',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This action cannot be undone!',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red)),
            SizedBox(height: 12),
            Text(
                'Are you sure you want to delete your account? All your data will be permanently removed.',
                style: TextStyle(fontSize: 15)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
      try {
        final success =
            await ref.read(authProvider.notifier).deleteAccount();
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account deleted successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) context.go('/login');
          } else {
            _showErrorSnackBar(
                'Failed to delete account. Please try again.');
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _showErrorSnackBar('Failed to delete account: ${e.toString()}');
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appModeNotifier = ref.read(appmodeSettingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Stack(
        children: [
           SingleChildScrollView(
        
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── App Mode ──────────────────────────────────────────────
                if (_canShowOverallData) ...[
                  const Text('App Mode',
                      style: TextStyle(
                          fontSize: 16.0, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAppModeButton(AppMode.myData, 'Show My Data'),
                      _buildAppModeButton(
                          AppMode.overallData, 'Show Overall Data'),
                    ],
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  const Text('App Mode',
                      style: TextStyle(fontSize: 16.0)),
                  const SizedBox(height: 20),
                  // Marketing_Code 0 puts the user in no group, so overall
                  // data is the only mode they can be in.
                  _buildFixedAppModeBox(_isOverallDataOnly
                      ? 'Show Overall Data'
                      : 'Show My Data'),
                  const SizedBox(height: 30),
                ],

                // ── Font Size ─────────────────────────────────────────────
                const Text('Font Size Settings',
                    style: TextStyle(
                        fontSize: 16.0, fontWeight: FontWeight.bold)),
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

                // ── Font Weight ───────────────────────────────────────────
                const Text('Font Weight Settings',
                    style: TextStyle(
                        fontSize: 16.0, fontWeight: FontWeight.bold)),
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

                // ── Notifications ─────────────────────────────────────────
                const Text(
                  'Notifications',
                  style: TextStyle(
                      fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
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
                            _isNotificationsEnabled
                                ? Icons.notifications_active
                                : Icons.notifications_off,
                            color: _isNotificationsEnabled
                                ? Colors.orange
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notifications',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isNotificationsEnabled
                                    ? 'Enabled'
                                    : 'Disabled',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isNotificationsEnabled
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _isNotificationLoading
                          ? const SizedBox(
                              width: 36,
                              height: 36,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange,
                                ),
                              ),
                            )
                          : Switch(
                              value: _isNotificationsEnabled,
                              activeColor: Colors.orange,
                              onChanged: _handleNotificationToggle,
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ──────────────────────────────────────────────────────────

                // ── Biometric ─────────────────────────────────────────────
                if (_isBiometricAvailable) ...[
                  const Text('Biometric Authentication',
                      style: TextStyle(
                          fontSize: 16.0, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                              _availableBiometrics
                                      .contains(BiometricType.face)
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
                                      _availableBiometrics),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isBiometricEnabled
                                      ? 'Enabled'
                                      : 'Disabled',
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

               const SizedBox(height: 10),

                // ── Delete Account ────────────────────────────────────────
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _handleDeleteAccount,
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('Delete Account',
                        style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[700]!, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeButton(double size, String name) {
    return ElevatedButton(
      onPressed: () =>
          ref.read(fontSettingsProvider.notifier).setFontSize(size),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            ref.watch(fontSettingsProvider).fontSize == size
                ? Constants.kSecondaryColor
                : Colors.grey[300],
        foregroundColor:
            ref.watch(fontSettingsProvider).fontSize == size
                ? Colors.white
                : Colors.black,
      ),
      child: Text(name),
    );
  }

  Widget _buildFontWeightButton(FontWeight weight, String name) {
    return ElevatedButton(
      onPressed: () =>
          ref.read(fontSettingsProvider.notifier).setFontWeight(weight),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            ref.watch(fontSettingsProvider).fontWeight == weight
                ? Constants.kSecondaryColor
                : Colors.grey[300],
        foregroundColor:
            ref.watch(fontSettingsProvider).fontWeight == weight
                ? Colors.white
                : Colors.black,
      ),
      child: Text(name),
    );
  }

  Widget _buildAppModeButton(AppMode mode, String name) {
    final selectedMode =
        ref.watch(appmodeSettingsProvider.select((s) => s.appMode));
    return ElevatedButton(
      onPressed: () =>
          ref.read(appmodeSettingsProvider.notifier).setAppMode(mode),
      style: ElevatedButton.styleFrom(
        backgroundColor: selectedMode == mode
            ? Constants.kSecondaryColor
            : Colors.grey[300],
        foregroundColor:
            selectedMode == mode ? Colors.white : Colors.black,
      ),
      child: Text(name),
    );
  }

  // Shown to users who have only one mode available — there is nothing to
  // switch between, so the current mode is stated rather than offered.
  Widget _buildFixedAppModeBox(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Constants.kSecondaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(name,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500)),
    );
  }
}