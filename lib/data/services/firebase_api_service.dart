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
    

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );


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
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> putRequest(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

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
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper for GET requests
  static Future<Map<String, dynamic>> getRequest(String url) async {
    try {
      final headers = await getAuthHeaders();
  

      final response = await http.get(Uri.parse(url), headers: headers);

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
   
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper for DELETE requests
  static Future<Map<String, dynamic>> deleteRequest(String url) async {
    try {
      final headers = await getAuthHeaders();
   

      final response = await http.delete(Uri.parse(url), headers: headers);


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
   
      final url = '$domain${endpoints['markAsRead']}/$chatId/messages/read';
     

      final response = await putRequest(url, {
        'messageIds': messageIds,
        'userId': deviceId,
      });

     
      return response;
    } catch (e) {
 
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
      final response = await postRequest(url, {
        "participants": [userUid, deviceId],
      });

      if (response['success'] == true && response['data']?['chatId'] != null) {
        return response['data']['chatId'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Delete a chat
  static Future<bool> deleteChat(String chatId) async {
    try {
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['deleteMessage']}/$chatId/hide';

      final response = await postRequest(url, {'userId': deviceId});


      return response['success'] == true;
    } catch (e) {
    
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
     
      throw Exception('Failed to fetch users: $e');
    }
  }

  // Fetch messages for a specific chat
  static Future<Map<String, dynamic>> fetchMessages(String chatId) async {
    try {
      final url = '$domain${endpoints['fetchMessages']}/$chatId/messages';
  
      final response = await getRequest(
        url,
      ).timeout(const Duration(seconds: 10));

   
      return response;
    } catch (e) {
    
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

      final url = '$domain${endpoints['sendMessage']}';
      final response = await postRequest(url, {
        "senderUuid": deviceId,
        "recipientUuid": recipientUuid,
        "message": message,
        "title": title,
        "body": body,
        "chatId": chatId,
      });

   
      return response;
    } catch (e) {
   
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteRequestWithBody(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

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
   

      final response = await deleteRequestWithBody(url, {'userId': deviceId});

  
      return response;
    } catch (e) {
    
      return {'success': false, 'error': e.toString()};
    }
  }
}
