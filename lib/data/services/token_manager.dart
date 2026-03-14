import 'dart:async';
import 'dart:convert';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Manages access token storage, retrieval, and refresh.
/// Uses a lock [Completer] to prevent concurrent refresh calls.
class TokenManager {
  final FlutterSecureStorage _storage;

  // Prevents multiple simultaneous refresh requests (race condition guard)
  Completer<String?>? _refreshCompleter;

  static const _accessTokenKey = 'access_token';

  TokenManager(this._storage);

  /// Returns the stored access token, or null if absent.
   Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
// Future<String?> getAccessToken() async {
//   // TEMP: force expired token to test refresh flow
//   return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0IiwiZXhwIjoxfQ.fake';
// }
  /// Clears the stored access token.
  Future<void> clearAccessToken() => _storage.delete(key: _accessTokenKey);

  /// Clears all stored credentials (used on force logout).
  Future<void> clearAll() => _storage.deleteAll();

  /// Attempts to obtain a fresh access token from the auth endpoint.
  ///
  /// If a refresh is already in flight, the caller awaits the same [Completer]
  /// instead of issuing a duplicate request — this is the token refresh lock.
  ///
  /// Returns the new token string, or null if refresh failed.
  Future<String?> refreshToken() async {
    // If refresh is already in progress, wait for it
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final baseUrl = await StorageUtil.getCurrentApiUrl() ?? '';
      final response = await http.post(
        Uri.parse('$baseUrl/Login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'UserName': 'BaLlY\$#Crm619',
          'PassWord': 'cRm_0987_@bL',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['Token']?['access_token'] as String?;

        if (token != null && token.isNotEmpty) {
          await _storage.write(key: _accessTokenKey, value: token);
          _refreshCompleter!.complete(token);
          return token;
        }
      }

      _refreshCompleter!.complete(null);
      return null;
    } catch (_) {
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      // Reset so future refreshes can proceed
      _refreshCompleter = null;
    }
  }
}