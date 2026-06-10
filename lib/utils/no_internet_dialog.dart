import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ballys_reservation_app/utils/connectivity_service.dart';

class NoInternetDialog {
  NoInternetDialog._();

  static bool _isShowing = false;
  static bool _dismissedThisSession = false;
static bool get isShowing => _isShowing;
  static void resetDismissed() => _dismissedThisSession = false;
static bool get dismissedThisSession => _dismissedThisSession;
  static void dismissIfShowing(BuildContext context) {
    if (_isShowing && context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  static void show(BuildContext context, {VoidCallback? onRetry}) {
    if (_isShowing || _dismissedThisSession) return;
    _isShowing = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.red, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'No Internet Connection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 24, color: Color.fromARGB(255, 0, 0, 0)),
                tooltip: 'Dismiss',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _dismissedThisSession = true; // ← won't show again this offline session
                  if (ctx.mounted && Navigator.of(ctx).canPop()) {
                    Navigator.of(ctx).pop();
                  }
                },
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
                final ok = await ConnectivityService.instance.checkNow();
                if (!ok) {
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
                  _dismissedThisSession = false;
                  if (ctx.mounted && Navigator.of(ctx).canPop()) {
                    Navigator.of(ctx).pop();
                  }
                  onRetry?.call();
                }
              },
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Color(0xFFDAB066),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => exit(0),
              child: const Text(
                'Exit',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _isShowing = false;
    });
  }
}