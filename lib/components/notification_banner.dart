import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_settings/app_settings.dart';

class NotificationBanner extends StatefulWidget {
  const NotificationBanner({super.key});

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner> {
  bool _showBanner = false;
  bool _notificationsEnabled = false;
  bool _isLoading = false; // New: For button loading state

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final isEnabled =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus ==
            AuthorizationStatus.provisional; // Handle provisional on iOS

    if (mounted) {
      setState(() {
        _notificationsEnabled = isEnabled;
        _showBanner = !isEnabled;
      });
    }
  }

  Future<void> _dismissBanner() async {
    print('Dismiss button tapped'); // Debug log
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
      await _checkNotificationStatus();

      if (_notificationsEnabled) {
        // Already enabled
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
        // Not enabled → open app settings
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable notifications in app settings'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        AppSettings.openAppSettings(type: AppSettingsType.notification);
      }
    } catch (e) {
      print('Error checking permissions: $e');
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
              onTap: _isLoading
                  ? null
                  : () => _enableNotifications(), // Disable during loading
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
              onTap: () {
                print('Close tapped');
                _dismissBanner();
              },
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
