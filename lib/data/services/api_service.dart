import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/core/exceptions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Injected once from main.dart to avoid circular imports
void Function() _triggerGlobalLogout = () {};

void registerLogoutCallback(void Function() callback) {
  _triggerGlobalLogout = callback;
}

class ApiService {
  final FlutterSecureStorage storage;

  ApiService(this.storage);

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, Object?> body,
  ) async {
String? accessToken = await storage.read(key: 'access_token');
  
    try {
      var response = await _makeRequest(endpoint, body, accessToken);
print(response.statusCode);
      // ── 401: refresh token once, then retry ───────────────────────────────
      if (response.statusCode == 401) {
        await storage.delete(key: 'access_token');
        final newToken = await _reAuthenticate();

        if (newToken != null && newToken.isNotEmpty) {
          response = await _makeRequest(endpoint, body, newToken);
print(response.statusCode);
          if (response.statusCode == 200) {
            return jsonDecode(response.body);
          }
        }

        // Still unauthorized or re-auth failed → force logout
        await _forceLogout();
        throw UnauthorizedException();
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      if (response.statusCode >= 500) {
        throw ServerException(
          response.reasonPhrase ?? 'Server error',
          response.statusCode,
        );
      }

      throw ApiException(
        'Failed to load data: ${response.statusCode} - ${response.reasonPhrase}',
        statusCode: response.statusCode,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<http.Response> _makeRequest(
    String endpoint,
    Map<String, Object?> body,
    String? accessToken,
  ) {
    return http.post(
      Uri.parse('${Constants.baseUrl}/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
  }

  Future<String?> _reAuthenticate() async {
    try {
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/Login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "UserName": "BaLlY\$#Crm619",
          "PassWord": "cRm_0987_@bL",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['Token']?['access_token'] as String?;
        if (token != null) {
          await storage.write(key: 'access_token', value: token);
          return token;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _forceLogout() async {
    try {
      await storage.deleteAll();
      _triggerGlobalLogout();
    } catch (_) {}
  }
}