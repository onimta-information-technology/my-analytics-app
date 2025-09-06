import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseApiService {
  static const String domain =
      'https://yourdomain.com'; // Replace with your actual domain
  static const String fmcDomain = 'https://ballysnotifications.onimtaitsl.com';

  static const Map<String, String> endpoints = {
    'InsertFcmToken': '/api/users/update-fcm-token',
    'InsertChatFMCToken': '/api/users/sync',
    'sendMessage': '/api/chat/send-message-with-notification',
  };

  // Helper to get Bearer token header
  static Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('Token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Helper for POST requests - now returns both success status and response
  static Future<Map<String, dynamic>> postRequest(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await getAuthHeaders();
      print('POST Request to $url with body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'error': 'Server returned status code: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('Error in postRequest: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> setFmcToken(
    String memberId,
    String fcmToken,
  ) async {
    final url = '$domain${endpoints['InsertFcmToken']}';
    return await postRequest(url, {'userId': memberId, 'fcmToken': fcmToken});
  }

  static Future<Map<String, dynamic>> syncFmcToken(
    String name,
    String fcmToken,
  ) async {
    final url = '$fmcDomain${endpoints['InsertChatFMCToken']}';
    return await postRequest(url, {
      'id': name,
      'name': name,
      'email': 'email',
      'fcmToken': fcmToken,
    });
  }

  static Future<Map<String, dynamic>> sendMessage(
    String memberId,
    String hostName,
    String message,
  ) async {
    final url = '$fmcDomain${endpoints['sendMessage']}';
    return await postRequest(url, {
      'senderFirstName': memberId.replaceAll(' ', ''),
      'recipientFirstName': hostName,
      'message': message,
      'title': message,
      'body': message,
      'chatId': '',
    });
  }
}
