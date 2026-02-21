import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/auth_repository.dart';

class TokenRefreshService {
  static final TokenRefreshService _instance = TokenRefreshService._internal();
  factory TokenRefreshService() => _instance;
  TokenRefreshService._internal();

  Timer? _midnightTimer;
  AuthRepository? _authRepository;
  bool _isRunning = false;

  /// Call this once after a successful login to start the midnight refresh cycle.
  void start(AuthRepository authRepository) {
    if (_isRunning) return; // Already scheduled

    _authRepository = authRepository;
    _isRunning = true;

    _scheduleNextMidnightRefresh();
  }

  /// Stop the scheduler (call on logout).
  void stop() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
    _authRepository = null;
    _isRunning = false;
  }

  bool get isRunning => _isRunning;

  void _scheduleNextMidnightRefresh() {
    final now = DateTime.now();

    // Calculate the next midnight (00:00:00 of the next day)
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final durationUntilMidnight = nextMidnight.difference(now);

    print(
      '[TokenRefreshService] Next token refresh scheduled in '
      '${durationUntilMidnight.inHours}h '
      '${durationUntilMidnight.inMinutes % 60}m '
      '${durationUntilMidnight.inSeconds % 60}s '
      '(at $nextMidnight)',
    );

    _midnightTimer?.cancel();

    _midnightTimer = Timer(durationUntilMidnight, () async {
      await _refreshToken();

      // After the first midnight fires, repeat every 24 hours
      _midnightTimer = Timer.periodic(const Duration(hours: 24), (_) async {
        await _refreshToken();
      });
    });
  }
// void _scheduleNextMidnightRefresh() {
//   // ✅ TEMPORARY TEST — fire after 1 minute
//   final testDuration = const Duration(minutes: 1);

//   print('[TokenRefreshService] TEST MODE — Token refresh in 1 minute...');

//   _midnightTimer?.cancel();
//   _midnightTimer = Timer(testDuration, () async {
//     await _refreshToken();

//     // Then every 2 minutes to keep testing
//     _midnightTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
//       await _refreshToken();
//     });
//   });
// }
  Future<void> _refreshToken() async {
    try {
      // Only refresh if user is still logged in
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      if (!isLoggedIn || _authRepository == null) {
        print('[TokenRefreshService] User not logged in — skipping refresh.');
        stop();
        return;
      }

      print('[TokenRefreshService] Midnight reached — refreshing access token...');
      final token = await _authRepository!.authenticate();

      if (token.isNotEmpty) {
        print('[TokenRefreshService] Token refreshed successfully at midnight.');
      } else {
        print('[TokenRefreshService] Token refresh returned empty — user may need to re-login.');
      }
    } catch (e) {
      print('[TokenRefreshService] Token refresh failed: $e');
    }
  }
}