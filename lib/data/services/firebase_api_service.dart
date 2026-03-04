import 'dart:convert';
import 'dart:io';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // needed for MediaType
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseApiService {
  //   static const String domain = 'https://ballysnotifications.onimtaitsl.com';
  //  static const String fmcDomain = 'https://ballysnotifications.onimtaitsl.com';
  static const String domain = 'https://chat.bcqr.lk';
  static const String fmcDomain = 'https://chat.bcqr.lk';
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
    'uploadFiles': '/api/chats', // base; full path: /api/chats/{chatId}/upload/multiple
  };

  // ---------------------------------------------------------------------------
  // Auth helpers
  // ---------------------------------------------------------------------------

  static Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('Token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('Token') ?? '';
  }

  // ---------------------------------------------------------------------------
  // Generic HTTP helpers
  // ---------------------------------------------------------------------------

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
        return {'success': true, 'data': jsonDecode(response.body)};
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
        return {'success': true, 'data': jsonDecode(response.body)};
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

  static Future<Map<String, dynamic>> getRequest(String url) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
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

  static Future<Map<String, dynamic>> deleteRequest(String url) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.delete(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
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
        return {'success': true, 'data': jsonDecode(response.body)};
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

  // ---------------------------------------------------------------------------
  // Upload files  (POST /api/chats/{chatId}/upload/multiple)
  // Accepts one or more local file paths. Returns list of uploaded file info:
  // [{ messageId, attachmentId, url, filename, size, type }, ...]
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> uploadFiles({
    required String chatId,
    required List<String> filePaths,
  }) async {
    try {
      final token = await _getToken();
      final deviceId = await DeviceId.get();
      final senderName = await StorageUtil.getUserName() ?? '';

      final url =
          Uri.parse('$domain/api/chats/$chatId/upload/multiple');

      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['senderId'] = deviceId ?? ''
        ..fields['senderName'] = senderName;

      for (final path in filePaths) {
        final file = File(path);
        if (!file.existsSync()) continue;

        // Determine MIME type from extension and pass it explicitly.
        // Without this the http package defaults to application/octet-stream
        // which the server rejects.
        final ext = path.split('.').last.toLowerCase();
        final mimeString = _mimeFromExtension(ext);
        final mimeParts = mimeString.split('/');
        final contentType = MediaType(mimeParts[0], mimeParts[1]);

        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            path,
            contentType: contentType,
          ),
        );
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error':
              'Upload failed with status: ${streamedResponse.statusCode}',
          'statusCode': streamedResponse.statusCode,
          'responseBody': responseBody,
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static String _mimeFromExtension(String ext) {
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // ---------------------------------------------------------------------------
  // Chat operations
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> markMessagesAsRead(
    String chatId,
    List<String> messageIds,
  ) async {
    try {
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['markAsRead']}/$chatId/messages/read';
      return await putRequest(url, {
        'messageIds': messageIds,
        'userId': deviceId,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> syncFmcToken(
    String name,
    String fcmToken,
  ) async {
    final deviceId = await DeviceId.get();
    final actualSalesCode = await StorageUtil.getSalesCode();
    final url = '$fmcDomain${endpoints['InsertChatFMCToken']}';
    final timestamp = DateTime.now().toIso8601String();
    final response = await postRequest(url, {
      'id': deviceId,
      'name': name,
      'email': timestamp,
      'fcmToken': fcmToken,
      'appId': 2,
      'salesCode': actualSalesCode,
    });

    final prefs = await SharedPreferences.getInstance();
    final user = response['data']?['user'];
    if (user != null && user['name'] != null) {
      await prefs.setString('name', user['name']);
    }
    print('syncFmcToken response: $response');
    return response;
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

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

  static Future<Map<String, dynamic>> fetchUserChats() async {
    try {
      final deviceId = await DeviceId.get();
      if (deviceId == null || deviceId.isEmpty) {
        throw Exception('deviceId not found in storage');
      }
      final url = '$domain${endpoints['fetchUserChats']}/$deviceId';
      print('Fetching chats for deviceId: $url');
      final response = await getRequest(url);
      if (response['success'] == true) {
        print('Fetch chats response: ${response['data']}');
        return response['data'] ?? {};
      } else {
        throw Exception(response['error'] ?? 'Failed to fetch chats');
      }
    } catch (e) {
      throw Exception('Failed to fetch chats: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchAllUsers() async {
    try {
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['fetchAllUsers']}/$deviceId';
      print('Fetching users from URL: $url');
      final response = await getRequest(url);
      print('Fetch users response: $response');
      if (response['success'] == true) {
        return response['data'] ?? {};
      } else {
        throw Exception(response['error'] ?? 'Failed to fetch users');
      }
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchMessages(String chatId) async {
    try {
      final url = '$domain${endpoints['fetchMessages']}/$chatId/messages';
      final response =
          await getRequest(url).timeout(const Duration(seconds: 10));
      return response;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String recipientUuid,
    required String message,
    required String title,
    required String body,
    required String chatId,
  }) async {
    try {
      print(
          'sendMessage called with recipientUuid: $recipientUuid, chatId: $chatId, message: $message');
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
      print('sendMessage response: $response');
      return response;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> softDeleteMessage(
    String chatId,
    String messageId,
  ) async {
    try {
      final deviceId = await DeviceId.get();
      final url =
          '$domain${endpoints['softDeleteMessage']}/$chatId/messages/$messageId';
      return await deleteRequestWithBody(url, {'userId': deviceId});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}