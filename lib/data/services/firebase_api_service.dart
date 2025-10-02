import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseApiService {
  static const String domain =
      'https://ballysnotifications.onimtaitsl.com'; // Replace with your actual domain
  static const String fmcDomain = 'https://ballysnotifications.onimtaitsl.com';

  static const Map<String, String> endpoints = {
    'InsertFcmToken': '/api/users/update-fcm-token',
    'InsertChatFMCToken': '/api/users/sync',
    'sendMessage': '/api/chat/send-message-with-notification',
    'deleteMessage':
        '/api/chats', // Base endpoint, chatId and messageId will be appended
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
          'responseBody': response.body,
        };
      }
    } catch (e) {
      print('Error in postRequest: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper for DELETE requests
  static Future<Map<String, dynamic>> deleteRequest(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await getAuthHeaders();
      print('DELETE Request to $url with body: $body');

      final request = http.Request('DELETE', Uri.parse(url))
        ..headers.addAll(headers)
        ..body = jsonEncode(body);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Delete Response status: ${response.statusCode}');
      print('Delete Response body: ${response.body}');

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

  // Set FCM token for user
  static Future<Map<String, dynamic>> setFmcToken(
    String memberId,
    String fcmToken,
  ) async {
    final url = '$domain${endpoints['InsertFcmToken']}';
    return await postRequest(url, {'userId': memberId, 'fcmToken': fcmToken});
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

  // Send message with notification
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

  // Send message with notification and chatId
  static Future<Map<String, dynamic>> sendMessageWithChatId(
    String senderFirstName,
    String recipientFirstName,
    String message,
    String title,
    String body,
    String chatId,
  ) async {
    final url = '$fmcDomain${endpoints['sendMessage']}';
    return await postRequest(url, {
      'senderFirstName': senderFirstName,
      'recipientFirstName': recipientFirstName,
      'message': message,
      'title': title,
      'body': body,
      'chatId': chatId,
    });
  }

  // Soft delete a message
  static Future<Map<String, dynamic>> deleteMessage(
    String chatId,
    String messageId,
  ) async {
    final url =
        '$fmcDomain${endpoints['deleteMessage']}/$chatId/messages/$messageId/soft-delete';
    return await deleteRequest(url, {'userId': 'Mr Anushka'});
  }

  // Delete/leave a chat
  static Future<Map<String, dynamic>> deleteChat(String chatId) async {
    final url = '$fmcDomain/api/chats/$chatId';
    return await deleteRequest(url, {'userId': 'Mr Anushka'});
  }

  // Get user chats
  static Future<Map<String, dynamic>> getUserChats() async {
    try {
      final headers = await getAuthHeaders();
      final url = '$fmcDomain/api/chats';

      final response = await http.get(Uri.parse(url), headers: headers);

      print('Get chats response status: ${response.statusCode}');
      print('Get chats response body: ${response.body}');

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
      print('Error getting user chats: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get all users
  static Future<Map<String, dynamic>> getAllUsers() async {
    try {
      final headers = await getAuthHeaders();
      final url = '$fmcDomain/api/users';

      final response = await http.get(Uri.parse(url), headers: headers);

      print('Get users response status: ${response.statusCode}');
      print('Get users response body: ${response.body}');

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
      print('Error getting all users: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get messages for a specific chat
  static Future<Map<String, dynamic>> getChatMessages(
    String chatId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final headers = await getAuthHeaders();
      final url =
          '$fmcDomain/api/chats/$chatId/messages?page=$page&limit=$limit';

      final response = await http.get(Uri.parse(url), headers: headers);

      print('Get messages response status: ${response.statusCode}');
      print('Get messages response body: ${response.body}');

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
      print('Error getting chat messages: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Mark messages as read
  static Future<Map<String, dynamic>> markMessagesAsRead(
    String chatId,
    List<String> messageIds,
  ) async {
    final url = '$fmcDomain/api/chats/$chatId/messages/mark-read';
    return await postRequest(url, {'messageIds': messageIds});
  }

  // Update user online status
  static Future<Map<String, dynamic>> updateOnlineStatus(bool isOnline) async {
    final url = '$fmcDomain/api/users/status';
    return await postRequest(url, {
      'isOnline': isOnline,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }
}
