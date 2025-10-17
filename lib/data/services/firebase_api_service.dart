import 'dart:convert';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
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
    'fetchAllUsers': '/api/users/contacts',
    'markAsRead': '/api/chats',
    'fetchMessages': '/api/chats',
    'softDeleteMessage': '/api/chats',
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

  static Future<Map<String, dynamic>> putRequest(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await getAuthHeaders();
      print('PUT Request to $url with body: $body');

      final response = await http.put(
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
      print('Error in putRequest: $e');
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

  // Mark messages as read
  static Future<Map<String, dynamic>> markMessagesAsRead(
    String chatId,
    List<String> messageIds,
  ) async {
    try {
      final deviceId = await DeviceId.get();
      print('User ID for marking as read: $deviceId');
      print('Message IDs to mark as read: $messageIds');
      final url = '$domain${endpoints['markAsRead']}/$chatId/messages/read';
      print(
        'Marking messages as read: chatId=$chatId, messageIds=$messageIds, userId=$deviceId',
      );

      final response = await putRequest(url, {
        'messageIds': messageIds,
        'userId': deviceId,
      });

      print('Mark as read response: $response');
      return response;
    } catch (e) {
      print('Error marking messages as read: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Sync FCM token with chat service
  static Future<Map<String, dynamic>> syncFmcToken(
    String name,
    String fcmToken,
  ) async {
    final deviceId = await DeviceId.get();
    final url = '$fmcDomain${endpoints['InsertChatFMCToken']}';
    final timestamp = DateTime.now().toIso8601String();
    final response = await postRequest(url, {
      'id': deviceId,
      'name': name,
      'email': timestamp,
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

  // Get user name from storage
  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  // Create a new chat
  static Future<String?> createChat(String userUid) async {
    final deviceId = await DeviceId.get();
    try {
      final url = '$domain${endpoints['createChat']}';
      print('Creating chat with receiver: $userUid');
      print('Creating chat with deviceId: $deviceId');

      final response = await postRequest(url, {
        "participants": [userUid, deviceId],
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
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['deleteMessage']}/$chatId/hide';
      print('Hiding chat (deleteChat): chatId=$chatId, userId=$deviceId');

      final response = await postRequest(url, {'userId': deviceId});

      print('Hide chat response: $response');
      return response['success'] == true;
    } catch (e) {
      print('Error hiding chat: $e');
      return false;
    }
  }

  // Fetch user chats
  static Future<Map<String, dynamic>> fetchUserChats() async {
    try {
      final deviceId = await DeviceId.get();
      if (deviceId == null || deviceId.isEmpty) {
        throw Exception('deviceId not found in storage');
      }
      final url = '$domain${endpoints['fetchUserChats']}/$deviceId';
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
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['fetchAllUsers']}/$deviceId';
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

  // Fetch messages for a specific chat
  static Future<Map<String, dynamic>> fetchMessages(String chatId) async {
    try {
      final url = '$domain${endpoints['fetchMessages']}/$chatId/messages';
      print('Fetching messages for chat: $chatId');

      final response = await getRequest(
        url,
      ).timeout(const Duration(seconds: 10));

      print('Fetch messages response: $response');
      return response;
    } catch (e) {
      print('Error fetching messages: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Send a message with notification
  static Future<Map<String, dynamic>> sendMessage({
    required String recipientUuid,
    required String message,
    required String title,
    required String body,
    required String chatId,
  }) async {
    try {
      final deviceId = await DeviceId.get();
      print('Sending message from deviceId: $deviceId');

      final url = '$domain${endpoints['sendMessage']}';
      final response = await postRequest(url, {
        "senderUuid": deviceId,
        "recipientUuid": recipientUuid,
        "message": message,
        "title": title,
        "body": body,
        "chatId": chatId,
      });

      print('Send message response: $response');
      return response;
    } catch (e) {
      print('Error sending message: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteRequestWithBody(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await getAuthHeaders();
      print('DELETE Request to $url with body: $body');

      final response = await http.delete(
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
      print('Error in deleteRequestWithBody: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Soft delete a message
  static Future<Map<String, dynamic>> softDeleteMessage(
    String chatId,
    String messageId,
  ) async {
    try {
      final deviceId = await DeviceId.get();
      final url =
          '$domain${endpoints['softDeleteMessage']}/$chatId/messages/$messageId';
      print(
        'Soft deleting message: chatId=$chatId, messageId=$messageId, userId=$deviceId',
      );

      final response = await deleteRequestWithBody(url, {'userId': deviceId});

      print('Soft delete message response: $response');
      return response;
    } catch (e) {
      print('Error soft deleting message: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
