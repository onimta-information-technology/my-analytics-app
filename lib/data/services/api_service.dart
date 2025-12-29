import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final FlutterSecureStorage storage;

  ApiService(this.storage);

  /// Get the dynamic base URL from storage, fallback to Constants.baseUrl
  Future<String> _getBaseUrl() async {
    final dynamicUrl = await StorageUtil.getCurrentApiUrl();
    return dynamicUrl ?? '';
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, Object?> body,
  ) async {
    String? accessToken = await storage.read(key: 'access_token');
    final baseUrl = await _getBaseUrl();
  
    try {
      final header = {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        body: jsonEncode(body),
        headers: header,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to load data: ${response.statusCode} - ${response.reasonPhrase}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Client-side error: ${e.message}');
    } catch (e) {
      throw Exception('API request failed with unexpected error: $e');
    }
  }
}