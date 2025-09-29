// lib/developer_mode_util.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class DeveloperModeUtil {
  static const MethodChannel _channel = MethodChannel('developer_mode');

  /// Returns true if the native side reports developer mode ON.
  /// In release builds we return false to avoid AppStore/runtime risks.
static Future<bool> isDeveloperModeEnabled() async {
  try {
    final result = await _channel.invokeMethod('isDeveloperMode');
    return result == true;
  } catch (e) {
    debugPrint('DeveloperMode check failed: $e');
    return false;
  }
}

}
