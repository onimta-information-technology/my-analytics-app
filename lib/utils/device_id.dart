import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_udid/flutter_udid.dart';

class DeviceId {
  static Future<String> get() async {
    try {
      final udid = await FlutterUdid.udid;
      if (udid.isNotEmpty) return udid;
    } catch (_) {}

    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return android.id;
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return ios.identifierForVendor ?? 'unknown';
    }
    return 'unknown';
  }
}
