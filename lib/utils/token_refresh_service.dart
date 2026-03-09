import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/auth_repository.dart';

class TokenRefreshService with WidgetsBindingObserver {
  static final TokenRefreshService _instance = TokenRefreshService._internal();
  factory TokenRefreshService() => _instance;
  TokenRefreshService._internal();

  Timer? _midnightTimer;
  AuthRepository? _authRepository;
  bool _isRunning = false;

  static const String _lastRefreshKey = 'last_token_refresh_timestamp';
  static const Duration _refreshThreshold = Duration(hours: 23);

  /// Call this once after a successful login to start the refresh cycle.
  void start(AuthRepository authRepository) {
    if (_isRunning) return;
    _authRepository = authRepository;
    _isRunning = true;

    // Register to listen to app lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Schedule midnight timer (covers app staying open past midnight)
    _scheduleNextMidnightRefresh();
  }

  /// Stop the scheduler (call on logout).
  void stop() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
    _authRepository = null;
    _isRunning = false;

    WidgetsBinding.instance.removeObserver(this);
  }

  bool get isRunning => _isRunning;

  // ─── App Lifecycle Observer ───────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('[TokenRefreshService] App resumed — checking if token refresh needed...');
      _refreshIfNeeded();
    }
  }

  // ─── Resume-Based Refresh ─────────────────────────────────────────────────

  Future<void> _refreshIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      if (!isLoggedIn || _authRepository == null) {
        print('[TokenRefreshService] User not logged in — skipping refresh.');
        stop();
        return;
      }

      final lastRefreshMs = prefs.getInt(_lastRefreshKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = Duration(milliseconds: now - lastRefreshMs);

      if (elapsed >= _refreshThreshold) {
        print('[TokenRefreshService] ${elapsed.inHours}h since last refresh — refreshing now...');
        await _refreshToken();
      } else {
        final remaining = _refreshThreshold - elapsed;
        print(
          '[TokenRefreshService] Token still fresh — next refresh in '
          '${remaining.inHours}h ${remaining.inMinutes % 60}m',
        );
      }
    } catch (e) {
      print('[TokenRefreshService] _refreshIfNeeded error: $e');
    }
  }

  // ─── Midnight Timer ───────────────────────────────────────────────────────

  void _scheduleNextMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final durationUntilMidnight = nextMidnight.difference(now);

    print(
      '[TokenRefreshService] Next midnight refresh in '
      '${durationUntilMidnight.inHours}h '
      '${durationUntilMidnight.inMinutes % 60}m '
      '${durationUntilMidnight.inSeconds % 60}s '
      '(at $nextMidnight)',
    );

    _midnightTimer?.cancel();
    _midnightTimer = Timer(durationUntilMidnight, () async {
      await _refreshToken();
      // Repeat every 24 hours while app stays open
      _midnightTimer = Timer.periodic(const Duration(hours: 24), (_) async {
        await _refreshToken();
      });
    });
  }

  // ─── Core Refresh Logic ───────────────────────────────────────────────────

  Future<void> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      if (!isLoggedIn || _authRepository == null) {
        print('[TokenRefreshService] User not logged in — skipping refresh.');
        stop();
        return;
      }

      print('[TokenRefreshService] Refreshing access token...');
      final token = await _authRepository!.authenticate();

      if (token.isNotEmpty) {
        // ✅ Save timestamp so resume-check knows when we last refreshed
        await prefs.setInt(_lastRefreshKey, DateTime.now().millisecondsSinceEpoch);
        print('[TokenRefreshService] Token refreshed successfully ✅');
      } else {
        print('[TokenRefreshService] Token refresh returned empty — user may need to re-login.');
      }
    } catch (e) {
      print('[TokenRefreshService] Token refresh failed: $e');
    }
  }
}