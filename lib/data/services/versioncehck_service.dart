import 'dart:convert';
import 'dart:io';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';


class VersionCheckService {

  /// Check if app version is latest
  /// Returns Map with keys: isLatest (bool), currentVersion (String)
  static Future<Map<String, dynamic>> checkVersion() async {
    try {
      // Get current app version from package info
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final platformId = Platform.isAndroid 
          ? Constants.androidPlatformId.toString() 
          : Constants.iosPlatformId.toString();

      // Prepare request payload
      final payload = {
        "Iid": platformId,
        "Version": currentVersion,
      };
      print("object");
      print(currentVersion);

      // Make API request
      final response = await http.post(
        Uri.parse(Constants.versionCheckUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Version check timeout');
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        return {
          'isLatest': responseData['isLatest'] ?? true,
          'currentVersion': currentVersion,
          'success': true,
        };
      } else {
        // If API fails, assume version is latest to not block user
        return {
          'isLatest': true,
          'currentVersion': currentVersion,
          'success': false,
          'error': 'Failed to check version: ${response.statusCode}',
        };
      }
    } catch (e) {
      // On error, assume version is latest to not block user
      print('Version check error: $e');
      return {
        'isLatest': true,
        'currentVersion': '0.0.0',
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get the update URL
  static String getUpdateUrl() {
    return Constants.updateUrl;
  }
}