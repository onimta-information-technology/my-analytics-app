import 'dart:convert';
import 'package:ballys_reservation_app/core/exceptions.dart';
import 'package:ballys_reservation_app/data/services/token_manager.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Global logout callback — injected once from main.dart
// ---------------------------------------------------------------------------

void Function() _onForceLogout = () {};

/// Register a logout callback to be triggered on unrecoverable auth failure.
/// Call this once from main.dart after ProviderScope is set up.
void registerLogoutCallback(void Function() callback) {
  _onForceLogout = callback;
}

// ---------------------------------------------------------------------------
// ApiService
// ---------------------------------------------------------------------------

/// Thin HTTP client with a single-retry token-refresh interceptor.
///
/// Flow:
///   1. Attach current access token and make the request.
///   2. If the response signals an expired/invalid token (401 / 406):
///      a. Ask [TokenManager] for a fresh token (handles concurrent-refresh lock).
///      b. Retry the original request once with the new token.
///      c. If the retry still fails auth → force logout and throw [UnauthorizedException].
///   3. Any non-200 terminal response throws a typed exception.
class ApiService {
  final TokenManager _tokenManager;

  /// Accepts [FlutterSecureStorage] directly — matches all existing call sites:
  ///   ApiService(const FlutterSecureStorage())
  ///   ApiService(storage)
  ///
  /// [TokenManager] is built internally, so no call sites need to change.
  ApiService(FlutterSecureStorage storage)
      : _tokenManager = TokenManager(storage);

  /// Named constructor for callers that already hold a [TokenManager]
  /// (e.g. a Riverpod provider that manages the singleton).
  ApiService.withManager(this._tokenManager);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Performs an authenticated POST to [endpoint] with [body].
  ///
  /// Throws:
  ///   [UnauthorizedException]  — session expired and refresh failed.
  ///   [ServerException]        — 5xx from the server.
  ///   [ApiException]           — any other non-200 status.
  ///   [NetworkException]       — connectivity / socket error.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, Object?> body,
  ) async {
    try {
      final token = await _tokenManager.getAccessToken();
      var response = await _execute(endpoint, body, token);

      // ── Token expired / invalid — attempt refresh then retry ─────────────
      if (_isAuthFailure(response)) {
        await _tokenManager.clearAccessToken();

        final newToken = await _tokenManager.refreshToken();

        if (newToken == null || newToken.isEmpty) {
          await _forceLogout();
          throw UnauthorizedException();
        }

        // One retry with the fresh token
        response = await _execute(endpoint, body, newToken);

        if (_isAuthFailure(response)) {
          await _forceLogout();
          throw UnauthorizedException();
        }
      }

      // ── Success ───────────────────────────────────────────────────────────
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      // ── Server error ──────────────────────────────────────────────────────
      if (response.statusCode >= 500) {
        throw ServerException(
          response.reasonPhrase ?? 'Server error',
          response.statusCode,
        );
      }

      // ── Other HTTP error ──────────────────────────────────────────────────
      throw ApiException(
        'Request failed: ${response.statusCode} ${response.reasonPhrase}',
        statusCode: response.statusCode,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on ApiException {
      rethrow; // Let typed exceptions propagate as-is
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Executes the HTTP POST and returns the raw response.
  Future<http.Response> _execute(
    String endpoint,
    Map<String, Object?> body,
    String? token,
  ) async {
    final baseUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    return http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  /// Returns true when the response indicates an expired or invalid token.
  ///
  /// Handles:
  ///   - HTTP 401 Unauthorized
  ///   - HTTP 406 with `{ "status": "erorr"/"error", "statusMsg": "...invalid token..." }`
  bool _isAuthFailure(http.Response response) {
    if (response.statusCode == 401) return true;

    if (response.statusCode == 406) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final status = (body['status'] as String? ?? '').toLowerCase();
        final msg = (body['statusMsg'] as String? ?? '').toLowerCase();
        // Tolerate the API's "Erorr" typo alongside the correct spelling
        return (status == 'erorr' || status == 'error') &&
            msg.contains('invalid token');
      } catch (_) {
        return false;
      }
    }

    return false;
  }

  /// Clears all stored credentials and triggers the app-wide logout callback.
  Future<void> _forceLogout() async {
    try {
      await _tokenManager.clearAll();
      _onForceLogout();
    } catch (_) {}
  }
}