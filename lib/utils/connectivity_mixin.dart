import 'package:flutter/material.dart';
import 'package:ballys_reservation_app/utils/connectivity_service.dart';
import 'package:ballys_reservation_app/utils/no_internet_dialog.dart';

mixin ConnectivityMixin<T extends StatefulWidget> on State<T> {
  void onConnectivityRestored() {}

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.isConnected
        .addListener(_onConnectivityChanged);

    // ← Show dialog on every new screen if offline
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ConnectivityService.instance.isConnected.value) {
        NoInternetDialog.resetDismissed(); // ← reset on every new screen
        NoInternetDialog.show(context);
      }
    });
  }

  @override
  void dispose() {
    ConnectivityService.instance.isConnected
        .removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (!mounted) return;
    if (ConnectivityService.instance.isConnected.value) {
      onConnectivityRestored();
    }
  }
}