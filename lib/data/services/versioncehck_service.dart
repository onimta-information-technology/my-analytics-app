import 'dart:convert';
import 'dart:io';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/services/token_manager.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';


class VersionCheckService {

  /// Version-check endpoint for the currently selected property. Bellagio
  /// logins (bty.world) hit the Bellagio endpoint; everything else — including
  /// a fresh install with no property selected yet — hits Ballys.
  static Future<String> _versionCheckUrl() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    return apiUrl.contains('bty.world')
        ? Constants.bellagioVersionCheckUrl
        : Constants.versionCheckUrl;
  }

  /// POSTs [payload] to [url] with the stored access token. On a 401 it gets a
  /// fresh token from [TokenManager] (same shared refresh ApiService uses) and
  /// retries once. Never logs out — the version check must not block startup.
  static Future<http.Response> _postWithAuthRetry(
    String url,
    Map<String, Object?> payload,
  ) async {
    final tokenManager = TokenManager(SecureStorage.instance);

    Future<http.Response> send(String? token) => http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          body: json.encode(payload),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Version check timeout'),
        );

    final token = await tokenManager.getAccessToken();
    final response = await send(token);
    if (response.statusCode != 401) return response;

    final newToken = await tokenManager.refreshAfterFailure(token);
    if (newToken == null || newToken.isEmpty) return response;
    return send(newToken);
  }

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
      final url = await _versionCheckUrl();
print("verstiocheck $url");
      print("object");
      print(currentVersion);
print(payload);
print('Version check url $url');
      // Make API request
      
      final response = await _postWithAuthRetry(url, payload);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Version check data: $responseData');
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
    if (Platform.isAndroid) {
      return Constants.androidUpdateUrl;
    } else if (Platform.isIOS) {
      return Constants.iosUpdateUrl;
    } else {
      // Fallback to iOS URL for other platforms
      return Constants.iosUpdateUrl;
    }
  }
}
