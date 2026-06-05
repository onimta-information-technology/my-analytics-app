import 'package:flutter/material.dart';
import 'connectivity_service.dart';
import 'no_internet_dialog.dart';

/// Add this mixin to any [State] to get automatic No-Internet dialogs.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ConnectivityMixin {
///   @override
///   void onConnectivityRestored() {
///     // optional: reload data when back online
///   }
/// }
/// ```
mixin ConnectivityMixin<T extends StatefulWidget> on State<T> {
  /// Override to react when connectivity is restored (e.g. reload data).
  void onConnectivityRestored() {}

  @override
  void initState() {
    super.initState();
    // Check immediately when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowIfOffline();
    });

    // Listen for future changes
    ConnectivityService.instance.isConnected.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    ConnectivityService.instance.isConnected.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (!mounted) return;
    if (!ConnectivityService.instance.isConnected.value) {
      NoInternetDialog.show(context, onRetry: onConnectivityRestored);
    } else {
      onConnectivityRestored();
    }
  }

  void _checkAndShowIfOffline() {
    if (!mounted) return;
    if (!ConnectivityService.instance.isConnected.value) {
      NoInternetDialog.show(context, onRetry: onConnectivityRestored);
    }
  }
}