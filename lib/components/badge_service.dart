import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class BadgeService {
  // Singleton pattern
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  static const String _badgeCountKey = 'app_badge_count';
  int _currentBadgeCount = 0;

  /// Initialize badge service
  Future<void> initialize() async {
    try {
      // Load saved badge count
      final prefs = await SharedPreferences.getInstance();
      _currentBadgeCount = prefs.getInt(_badgeCountKey) ?? 0;

      // Set initial badge for both iOS and Android
      await _setBadgeInNotification(_currentBadgeCount);
      await _setIOSBadge(_currentBadgeCount);
    } catch (e) {
      print('Error initializing badge service: $e');
    }
  }

  /// Update badge count
  Future<void> updateBadge(int count) async {
    try {
      _currentBadgeCount = count.clamp(0, 9999);

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_badgeCountKey, _currentBadgeCount);

      // Update badge for both platforms
      await _setBadgeInNotification(_currentBadgeCount);
      await _setIOSBadge(_currentBadgeCount);
    } catch (e) {
      print('Error updating badge: $e');
    }
  }

  /// Set badge using Awesome Notifications (Android)
  Future<void> _setBadgeInNotification(int count) async {
    try {
      if (count > 0) {
        await AwesomeNotifications().setGlobalBadgeCounter(count);
      } else {
        await AwesomeNotifications().resetGlobalBadge();
      }
    } catch (e) {
      print('Error setting Awesome Notifications badge: $e');
    }
  }

  /// Set badge for iOS as well by using AwesomeNotifications global counter.
  /// Using AwesomeNotifications ensures we update the system badge number
  /// instead of relying only on the APNs payload which may overwrite counts.
  Future<void> _setIOSBadge(int count) async {
    try {
      if (count > 0) {
        await AwesomeNotifications().setGlobalBadgeCounter(count);
      } else {
        await AwesomeNotifications().resetGlobalBadge();
      }

      // Ensure iOS presents badges when app is foregrounded
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(badge: true);
    } catch (e) {
      print('Error setting iOS badge: $e');
    }
  }

  /// Returns the system/global badge counter if available. Falls back to
  /// the locally persisted count if the plugin call fails.
  Future<int> getSystemBadgeCount() async {
    try {
      final counter = await AwesomeNotifications().getGlobalBadgeCounter();
      return counter;
    } catch (e) {
      // ignore and fallback to stored value
    }
    return await getSavedBadgeCount();
  }

  /// Clear badge
  Future<void> clearBadge() async {
    await updateBadge(0);
  }

  /// Add to badge count
  Future<void> addBadge(int increment) async {
    try {
      // Try to read the system badge counter first to avoid overwriting
      // a value set by the OS (APNs payload). Fall back to local value.
      final systemCount = await getSystemBadgeCount();
      final base = systemCount > _currentBadgeCount
          ? systemCount
          : _currentBadgeCount;
      await updateBadge(base + increment);
    } catch (e) {
      await updateBadge(_currentBadgeCount + increment);
    }
  }

  /// Subtract from badge count
  Future<void> subtractBadge(int decrement) async {
    await updateBadge(_currentBadgeCount - decrement);
  }

  /// Get current badge count
  int get currentBadgeCount => _currentBadgeCount;

  /// Get badge count from storage
  Future<int> getSavedBadgeCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_badgeCountKey) ?? 0;
    } catch (e) {
      print('Error getting saved badge count: $e');
      return 0;
    }
  }
}
