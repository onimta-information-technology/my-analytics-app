import 'dart:async';
import 'dart:io';
import 'package:ballys_reservation_app/main.dart';
import 'package:ballys_reservation_app/utils/no_internet_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isConnected = ValueNotifier(true);
  StreamSubscription? _subscription;
  Timer? _debounce; // ← ADD

  Future<void> initialize() async {
    isConnected.value = await _hasRealInternet();

    _subscription = Connectivity().onConnectivityChanged.listen((_) {
      // ← Debounce 1.5 seconds — prevents rapid flicker triggering reset
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1500), () async {
        final wasConnected = isConnected.value;
        final nowConnected = await _hasRealInternet();

        // Only act if state actually changed
        if (nowConnected == isConnected.value && nowConnected == wasConnected) {
          return; // ← nothing changed, ignore
        }
 print('🔴 ConnectivityService: wasConnected=$wasConnected nowConnected=$nowConnected dismissed=${NoInternetDialog.dismissedThisSession} isShowing=${NoInternetDialog.isShowing}');
        isConnected.value = nowConnected;

        final context = navigatorKey.currentContext;
        if (context == null) return;

        if (!nowConnected && !NoInternetDialog.dismissedThisSession) {
          NoInternetDialog.show(context);
        } else if (!nowConnected && NoInternetDialog.dismissedThisSession) {
          // User dismissed — do nothing
        } else if (!wasConnected && nowConnected) {
          // Genuinely came back online
          NoInternetDialog.resetDismissed();
          NoInternetDialog.dismissIfShowing(context);
        }
      });
    });
  }

  Future<bool> checkNow() async {
    final ok = await _hasRealInternet();
    isConnected.value = ok;
    return ok;
  }

  void dispose() {
    _debounce?.cancel(); // ← ADD
    _subscription?.cancel();
    isConnected.dispose();
  }

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