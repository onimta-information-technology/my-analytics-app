import 'dart:convert';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseApiService {
  static const String domain = 'https://ballysnotifications.onimtaitsl.com';
  static const String fmcDomain = 'https://ballysnotifications.onimtaitsl.com';

  static const Map<String, String> endpoints = {
    'InsertFcmToken': '/api/users/update-fcm-token',
    'InsertChatFMCToken': '/api/users/sync',
    'sendMessage': '/api/chat/send-message-with-notification',
    'deleteMessage': '/api/chats',
    'createChat': '/api/chats/create',
    'fetchUserChats': '/api/chats/user',
    'fetchAllUsers': '/api/users',
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

  // Helper for POST requests
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
          'responseBody': response.body,
        };
      }
    } catch (e) {
      print('Error in postRequest: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper for GET requests
  static Future<Map<String, dynamic>> getRequest(String url) async {
    try {
      final headers = await getAuthHeaders();
      print('GET Request to $url');

      final response = await http.get(Uri.parse(url), headers: headers);

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
          'responseBody': response.body,
        };
      }
    } catch (e) {
      print('Error in getRequest: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper for DELETE requests
  static Future<Map<String, dynamic>> deleteRequest(String url) async {
    try {
      final headers = await getAuthHeaders();
      print('DELETE Request to $url');

      final response = await http.delete(Uri.parse(url), headers: headers);

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
          'responseBody': response.body,
        };
      }
    } catch (e) {
      print('Error in deleteRequest: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Sync FCM token with chat service
  static Future<Map<String, dynamic>> syncFmcToken(
    String name,
    String fcmToken,
  ) async {
    final url = '$fmcDomain${endpoints['InsertChatFMCToken']}';
    final response = await postRequest(url, {
      'id': name,
      'name': name,
      'email': 'email',
      'fcmToken': fcmToken,
    });
    print('syncFmcToken response: $response');

    // Save user name to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final user = response['data']?['user'];
    if (user != null && user['name'] != null) {
      await prefs.setString('name', user['name']);
    }

    return response;
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  // Create a new chat
  static Future<String?> createChat(String receiverName) async {
    final currentUserName = await getName();
    if (currentUserName == null) {
      print('Current user name is null');
      return null;
    }

    try {
      final url = '$domain${endpoints['createChat']}';
      print('Creating chat with receiver: $receiverName');
      print('Creating chat with currentUserName: $currentUserName');

      final response = await postRequest(url, {
        "participants": [receiverName, currentUserName],
      });

      print('Create chat response: $response');

      if (response['success'] == true && response['data']?['chatId'] != null) {
        return response['data']['chatId'];
      }

      print('Failed to create chat');
      return null;
    } catch (e) {
      print('Error creating chat: $e');
      return null;
    }
  }

  // Delete a chat
  static Future<bool> deleteChat(String chatId) async {
    try {
      final url = '$domain${endpoints['deleteMessage']}/$chatId';
      final response = await deleteRequest(url);

      print('Delete chat response: $response');
      return response['success'] == true;
    } catch (e) {
      print('Error deleting chat: $e');
      return false;
    }
  }

  // Fetch user chats
  static Future<Map<String, dynamic>> fetchUserChats() async {
    try {
      final userId = await StorageUtil.getUserName();

      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found in storage');
      }
      final url = '$domain${endpoints['fetchUserChats']}/$userId';
      final response = await getRequest(url);

      if (response['success'] == true) {
        return response['data'] ?? {};
      } else {
        throw Exception(response['error'] ?? 'Failed to fetch chats');
      }
    } catch (e) {
      print('Error fetching user chats: $e');
      throw Exception('Failed to fetch chats: $e');
    }
  }

  // Fetch all users
  static Future<Map<String, dynamic>> fetchAllUsers() async {
    try {
      final url = '$domain${endpoints['fetchAllUsers']}';
      final response = await getRequest(url);

      if (response['success'] == true) {
        return response['data'] ?? {};
      } else {
        throw Exception(response['error'] ?? 'Failed to fetch users');
      }
    } catch (e) {
      print('Error fetching all users: $e');
      throw Exception('Failed to fetch users: $e');
    }
  }
}
