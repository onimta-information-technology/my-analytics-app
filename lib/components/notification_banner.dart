import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationBanner extends StatefulWidget {
  const NotificationBanner({super.key});

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner> {
  bool _showBanner = false;
  bool _notificationsEnabled = false;
  bool _isLoading = false;
  bool _hasRequestedPermission = false; // Track if we've already asked

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    // Check if user has permanently dismissed the banner
    final prefs = await SharedPreferences.getInstance();
    final isDismissed = prefs.getBool('notification_banner_dismissed') ?? false;
    
    if (isDismissed) {
      setState(() {
        _showBanner = false;
      });
      return;
    }

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final isEnabled =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (mounted) {
      setState(() {
        _notificationsEnabled = isEnabled;
        _showBanner = !isEnabled;
      });
    }
  }

  Future<void> _dismissBanner() async {
    // Save dismiss state permanently
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_banner_dismissed', true);
    
    if (mounted) {
      setState(() {
        _showBanner = false;
      });
    }
  }

  Future<void> _enableNotifications() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First, try requesting permission programmatically (only works if not permanently denied)
      if (!_hasRequestedPermission) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        _hasRequestedPermission = true;

        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          // Permission granted!
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications enabled successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            await _dismissBanner();
          }
          return;
        }
      }

      // If we reach here, permission was denied or already denied
      // Check current status before opening settings
      await _checkNotificationStatus();

      if (_notificationsEnabled) {
        // Already enabled (edge case)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications already enabled!'),
              backgroundColor: Colors.green,
            ),
          );
          await _dismissBanner();
        }
      } else {
        // Permission denied - only open settings if user explicitly taps again
        if (mounted) {
          // Show dialog to confirm before opening settings
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Enable Notifications'),
              content: const Text(
                'Notifications are currently disabled. Would you like to open settings to enable them?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await AppSettings.openAppSettings(type: AppSettingsType.notification);
          }
        }
      }
    } catch (e) {
      print('Error enabling notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to enable notifications'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showBanner) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.orange.shade100,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          border: Border(
            bottom: BorderSide(color: Colors.orange.shade300, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_off,
              color: Colors.orange.shade800,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enable notifications to never miss a message',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _isLoading ? null : _enableNotifications,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isLoading ? Colors.grey : Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Enable',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _dismissBanner,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  color: Colors.orange.shade800,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}