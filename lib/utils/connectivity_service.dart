import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Global singleton that broadcasts internet connectivity changes.
/// Call [ConnectivityService.instance.initialize()] once in main().
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isConnected = ValueNotifier(true);
  StreamSubscription? _subscription;

  /// Call once from main() — before runApp().
  Future<void> initialize() async {
    isConnected.value = await _hasRealInternet();
    _subscription = Connectivity().onConnectivityChanged.listen((_) async {
      isConnected.value = await _hasRealInternet();
    });
  }

  void dispose() {
    _subscription?.cancel();
    isConnected.dispose();
  }

  /// Performs a real HTTP probe (same logic as SplashScreen).
  Future<bool> _hasRealInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) return false;

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      try {
        final req = await client
            .getUrl(Uri.parse('http://clients3.google.com/generate_204'))
            .timeout(const Duration(seconds: 3));
        final res = await req.close().timeout(const Duration(seconds: 3));
        client.close();
        return res.statusCode == 204 || res.statusCode == 200;
      } catch (_) {
        client.close();
        return false;
      }
    } catch (_) {
      return false;
    }
  }
}