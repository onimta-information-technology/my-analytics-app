import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pushes that end the session on this device wherever the app happens to be.
///
/// `msg_type` 40 is sent when the user's account has been deleted: the app
/// signs out straight away instead of waiting for the next request to fail.
class ForcedLogoutPush {
  ForcedLogoutPush._();

  static const String accountDeleted = '40';

  static const String _pendingKey = 'forced_logout_pending';

  static bool isForcedLogout(Map<String, dynamic> data) =>
      data['msg_type']?.toString() == accountDeleted;

  /// The running app's full logout, set while it is up.
  ///
  /// On iOS a `content-available` push reaches the background handler in the
  /// app's own isolate, so this is set there and the logout happens at once,
  /// even with the app in the background. Android runs that handler in a
  /// separate isolate with no app in it, where this stays null and
  /// [recordFromBackground] is used instead.
  static Future<void> Function()? appHandler;

  /// Called from the FCM background handler for a forced-logout push.
  static Future<void> handleInBackground() async {
    final logOutNow = appHandler;
    if (logOutNow != null) {
      await logOutNow();
    } else {
      await recordFromBackground();
    }
  }

  /// Background isolate: there is no ProviderContainer or navigator here, so
  /// this wipes the stored session — a cold start then lands on /login by
  /// itself — and leaves a flag for the main isolate to finish the logout
  /// when the app comes back to the foreground.
  static Future<void> recordFromBackground() async {
    final prefs = await SharedPreferences.getInstance();
    // This isolate can outlive a logout/login in the main one; read what is
    // on disk, not what was cached when it started.
    await prefs.reload();

    final hadSession = (prefs.getBool('is_logged_in') ?? false) ||
        await StorageUtil.getExpiry() != null;
    if (!hadSession) return;

    await StorageUtil.clearUserData();
    await prefs.setBool('is_logged_in', false);
    await prefs.setBool(_pendingKey, true);
  }

  /// Main isolate: true once after the background isolate recorded a forced
  /// logout, and clears the flag so it is acted on only once.
  static Future<bool> takePending() async {
    final prefs = await SharedPreferences.getInstance();
    // The background isolate wrote through its own instance; this one still
    // holds the values it cached before that ran.
    await prefs.reload();
    if (!(prefs.getBool(_pendingKey) ?? false)) return false;
    await prefs.remove(_pendingKey);
    return true;
  }
}
