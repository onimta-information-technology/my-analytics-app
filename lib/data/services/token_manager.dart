import 'dart:async';
import 'dart:convert';
import 'package:ballys_reservation_app/core/exceptions.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Manages access token storage, retrieval, and refresh.
class TokenManager {
  final FlutterSecureStorage _storage;

  /// The refresh currently in flight, shared by every [TokenManager].
  ///
  /// Static on purpose: each repository builds its own ApiService (and so its
  /// own TokenManager). With a per-instance lock, the burst of requests a
  /// screen fires after the token expires each called /Login on their own —
  /// every new login invalidated the token the previous one had just stored,
  /// the retries failed with it, and the user was logged out.
  static Future<String?>? _inFlight;

  static const _accessTokenKey = 'access_token';

  TokenManager(this._storage);

  /// Returns the stored access token, or null if absent.
  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  /// Clears the stored access token.
  Future<void> clearAccessToken() => _storage.delete(key: _accessTokenKey);

  /// Clears all stored credentials (used on force logout).
  Future<void> clearAll() => _storage.deleteAll();

  /// Returns a token to retry with after [failedToken] was rejected.
  ///
  /// If another request already replaced [failedToken] while this one was in
  /// flight, that newer token is reused instead of logging in again.
  Future<String?> refreshAfterFailure(String? failedToken) async {
    final current = await getAccessToken();
    if (current != null && current.isNotEmpty && current != failedToken) {
      return current;
    }
    return refreshToken();
  }

  /// Obtains a fresh access token from the auth endpoint, stores it in place
  /// of the old one and returns it. Concurrent callers share one request.
  ///
  /// Returns null only when the server rejected the credentials — the caller
  /// should log out. A network or server failure throws [NetworkException] /
  /// [ServerException] instead, so a blip does not end the session.
  Future<String?> refreshToken() {
    return _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);
  }

  Future<String?> _doRefresh() async {
    final baseUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    // The device config is gone — the splash re-fetches it on next launch.
    if (baseUrl.isEmpty) throw MissingApiUrlException();

    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/Login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'UserName': 'BaLlY\$#Crm619',
          'PassWord': 'cRm_0987_@bL',
        }),
      );
    } catch (e) {
      throw NetworkException('Could not refresh session: $e');
    }

    if (response.statusCode >= 500) {
      throw ServerException(
        response.reasonPhrase ?? 'Server error',
        response.statusCode,
      );
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['Token']?['access_token'] as String?;
        if (token != null && token.isNotEmpty) {
          await _storage.write(key: _accessTokenKey, value: token);
          return token;
        }
      } catch (_) {}
    }

    return null;
  }
}
