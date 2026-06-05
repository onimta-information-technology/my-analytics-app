import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'connectivity_service.dart';

/// Shows the same No-Internet dialog used on the SplashScreen.
/// Automatically dismisses itself when connectivity is restored.
class NoInternetDialog {
  NoInternetDialog._();

  static bool _isShowing = false;

  static void show(BuildContext context, {VoidCallback? onRetry}) {
    if (_isShowing) return;
    _isShowing = true;

    // Listener that auto-dismisses when back online
    void listener() {
      if (ConnectivityService.instance.isConnected.value) {
        _dismissIfShowing(context);
      }
    }

    ConnectivityService.instance.isConnected.addListener(listener);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text(
                'No Internet Connection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Please check your internet connection and try again. '
            'This app requires an active internet connection to function properly.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Re-probe manually when user taps Retry
                final ok = await ConnectivityService.instance
                    ._hasRealInternet();
                ConnectivityService.instance.isConnected.value = ok;

                if (!ok) {
                  // Give visual feedback that we checked but still offline
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Still no internet. Please try again.'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  _dismissIfShowing(ctx);
                  onRetry?.call();
                }
              },
              child: Text(
                'Retry',
                style: TextStyle(
                  color: const Color(0xFFDAB066), // customGoldColor
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => exit(0),
              child: const Text(
                'Exit',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Clean up listener once dialog is gone
      ConnectivityService.instance.isConnected.removeListener(listener);
      _isShowing = false;
    });
  }

  static void _dismissIfShowing(BuildContext context) {
    if (_isShowing && context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

// Expose the private method for the retry probe above
extension _ConnectivityProbe on ConnectivityService {
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