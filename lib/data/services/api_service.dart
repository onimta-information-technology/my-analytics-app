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
///      a. Ask [TokenManager] for a fresh token (one shared refresh for all
///         concurrent requests; the new token replaces the old in storage).
///      b. Retry the original request once with the new token.
///      c. If the server won't issue a token, or rejects the new one → force
///         logout and throw [UnauthorizedException]. A network/server error
///         during refresh is thrown as-is and does not log out.
///   3. Any non-200 terminal response throws a typed exception.
class ApiService {
  final TokenManager _tokenManager;

  /// Accepts [FlutterSecureStorage] directly — matches all existing call sites,
  /// which pass the app-wide instance:
  ///   ApiService(SecureStorage.instance)
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
      final response = await _sendWithAuthRetry(
        (token) => _execute(endpoint, body, token),
      );
print('API response for $endpoint: ${response.body}');
      // ── Success ───────────────────────────────────────────────────────────
  if (response.statusCode == 200) {
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final bodyStatusCode = decoded['statusCode'];

  if (bodyStatusCode == null || bodyStatusCode == 200) {
    return decoded;
  }

  throw ApiException(
    'Request failed: $bodyStatusCode ${decoded['statusMsg']}',
    statusCode: bodyStatusCode as int,
  );
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

  /// Performs an authenticated GET to [endpoint].
  ///
  /// Mirrors [post]'s token-refresh/retry flow but sends no body.
  ///
  /// Throws:
  ///   [UnauthorizedException]  — session expired and refresh failed.
  ///   [ServerException]        — 5xx from the server.
  ///   [ApiException]           — any other non-200 status.
  ///   [NetworkException]       — connectivity / socket error.
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await _sendWithAuthRetry(
        (token) => _executeGet(endpoint, token),
      );
      print('API response for $endpoint: ${response.body}');

      // ── Success ───────────────────────────────────────────────────────────
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final bodyStatusCode = decoded['statusCode'];

        if (bodyStatusCode == null || bodyStatusCode == 200) {
          return decoded;
        }

        throw ApiException(
          'Request failed: $bodyStatusCode ${decoded['statusMsg']}',
          statusCode: bodyStatusCode as int,
        );
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

  /// Authenticated GET that returns the raw response, for endpoints whose body
  /// isn't a JSON object (e.g. a top-level list). Gets the same token
  /// refresh/retry as [get]; status and body parsing are left to the caller.
  Future<http.Response> getResponse(String endpoint) =>
      _sendWithAuthRetry((token) => _executeGet(endpoint, token));

  /// Authenticated POST that returns the raw response. See [getResponse].
  Future<http.Response> postResponse(
    String endpoint,
    Map<String, Object?> body,
  ) =>
      _sendWithAuthRetry((token) => _execute(endpoint, body, token));

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Sends a request with the stored token. If the token is expired/invalid,
  /// fetches a new one (replacing the old one in storage) and retries once.
  /// Logs out only when the server refuses to issue a token, or rejects the
  /// fresh one — a network or server failure during refresh just throws.
  Future<http.Response> _sendWithAuthRetry(
    Future<http.Response> Function(String? token) send,
  ) async {
    final token = await _tokenManager.getAccessToken();
    final response = await send(token);
    if (!_isAuthFailure(response)) return response;

    final newToken = await _tokenManager.refreshAfterFailure(token);
    if (newToken == null || newToken.isEmpty) {
      await _forceLogout();
      throw UnauthorizedException();
    }

    final retried = await send(newToken);
    if (_isAuthFailure(retried)) {
      await _forceLogout();
      throw UnauthorizedException();
    }
    return retried;
  }

  /// Executes the HTTP GET and returns the raw response.
  Future<http.Response> _executeGet(
    String endpoint,
    String? token,
  ) async {
    final baseUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    if (baseUrl.isEmpty) throw MissingApiUrlException();
    return http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  /// Executes the HTTP POST and returns the raw response.
  Future<http.Response> _execute(
    String endpoint,
    Map<String, Object?> body,
    String? token,
  ) async {
    final baseUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    if (baseUrl.isEmpty) throw MissingApiUrlException();
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

  try {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final bodyStatusCode = body['statusCode'];
    
    if (bodyStatusCode == 406) {
      final status = (body['status'] as String? ?? '').toLowerCase();
      final msg = (body['statusMsg'] as String? ?? '').toLowerCase();
      return (status == 'erorr' || status == 'error') &&
          msg.contains('invalid token');
    }
  } catch (_) {
    return false;
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