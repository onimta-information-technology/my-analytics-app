import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      
      // Set initial badge
      await _setBadgeInNotification(_currentBadgeCount);
      
      print('Badge service initialized with count: $_currentBadgeCount');
    } catch (e) {
      print('Error initializing badge service: $e');
    }
  }

  /// Update badge count
  Future<void> updateBadge(int count) async {
    try {
      _currentBadgeCount = count.clamp(0, 9999); // Limit to reasonable number
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_badgeCountKey, _currentBadgeCount);
      
      // Update badge via Awesome Notifications
      await _setBadgeInNotification(_currentBadgeCount);
      
      print('✅ Badge updated to: $_currentBadgeCount');
    } catch (e) {
      print('❌ Error updating badge: $e');
    }
  }

  /// Set badge using Awesome Notifications
  Future<void> _setBadgeInNotification(int count) async {
    try {
      if (count > 0) {
        // Use Awesome Notifications global badge
        await AwesomeNotifications().setGlobalBadgeCounter(count);
      } else {
        // Reset badge
        await AwesomeNotifications().resetGlobalBadge();
      }
    } catch (e) {
      print('Error setting badge in notification: $e');
    }
  }

  /// Clear badge
  Future<void> clearBadge() async {
    await updateBadge(0);
  }

  /// Add to badge count
  Future<void> addBadge(int increment) async {
    await updateBadge(_currentBadgeCount + increment);
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