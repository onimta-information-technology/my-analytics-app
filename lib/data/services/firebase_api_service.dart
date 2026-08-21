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
  // Chat backend host, picked from the logged-in property: Bellagio logins
  // (API url on bty.world) talk to the Bellagio chat server, everything else —
  // including Bally's — stays on the default host.
  static const String ballysDomain = 'https://chat.bcqr.lk';
  static const String bellagioDomain = 'https://chat.bty.world';

  /// Chat host for the currently logged-in property. Every request resolves
  /// this first so a re-login onto another property switches servers.
  static Future<String> resolveDomain() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    return apiUrl.contains('bty.world') ? bellagioDomain : ballysDomain;
  }

  static const Map<String, String> endpoints = {
    'InsertFcmToken': '/api/users/update-fcm-token',
    'InsertChatFMCToken': '/api/users/sync',
    'RemoveFcmToken': '/api/users/remove-fcm-token',
    'sendMessage': '/api/chat/send-message-with-notification',
    'deleteMessage': '/api/chats',
    'createChat': '/api/chats/create',
    'fetchUserChats': '/api/chats/user',
    'fetchAllUsers': '/api/users/contacts',
    'markAsRead': '/api/chats',
    'fetchMessages': '/api/chats',
    'softDeleteMessage': '/api/chats',
    'forwardMessage': '/api/chats', // base; full path: /api/chats/{chatId}/messages/{messageId}/forward
    'reactToMessage': '/api/chats', // base; full path: /api/chats/{chatId}/messages/{messageId}/react
    'uploadFiles': '/api/chats', // base; full path: /api/chats/{chatId}/upload/multiple
    'createGroup': '/api/groups/create',
    'fetchUserGroups': '/api/groups/user',
    'groups': '/api/groups', // base; full path: /api/groups/{groupId}
  };

  /// appType of this app, sent alongside every user id the chat backend needs
  /// to disambiguate (the same user uuid can exist under another app).
  static const int appType = 2;

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
      final domain = await resolveDomain();
     
      final token = await _getToken();
      final deviceId = await DeviceId.get();
      final senderName = await StorageUtil.getUserName() ?? '';

      final url =
          Uri.parse('$domain/api/chats/$chatId/upload/multiple');

      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['senderId'] = deviceId ?? ''
        ..fields['senderName'] = senderName
        ..fields['senderAppType'] = '2'; // Assuming appType is always 2 for this app


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
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['markAsRead']}/$chatId/messages/read';
      return await putRequest(url, {
        'messageIds': messageIds,
        'userId': deviceId,
        'appType': 2, 
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> syncFmcToken(
    String name,
    String fcmToken,
  ) async {
    final domain = await resolveDomain();
    final deviceId = await DeviceId.get();
    final actualSalesCode = await StorageUtil.getSalesCode();
     final phoneNumber = await StorageUtil.getMobileNumber();
    final url = '$domain${endpoints['InsertChatFMCToken']}';
    final timestamp = DateTime.now().toIso8601String();
  final location = await StorageUtil.getCurrentLocation();
  print('Syncing FCM token with deviceId: $deviceId, name: $name, fcmToken: $fcmToken, salesCode: $actualSalesCode, phoneNumber: $phoneNumber, location: ${location?.code ?? "N/A"}');
    final response = await postRequest(url, {
      'id': deviceId,
      'name': name,
      'email': timestamp,
      'fcmToken': fcmToken,
      'appId': 2,
      'salesCode': actualSalesCode,
      'phoneNo':phoneNumber,
      'location': location?.code ?? "",
    });

    final prefs = await SharedPreferences.getInstance();
    final user = response['data']?['user'];
    if (user != null && user['name'] != null) {
      await prefs.setString('name', user['name']);
    }
    print('syncFmcToken response: $response');
    return response;
  }

  /// Detaches this device's FCM token from the backend on logout.
  ///
  /// Called instead of FirebaseMessaging.deleteToken(): dropping the row stops
  /// the pushes without invalidating the device registration, so the next
  /// login cannot pick a just-deleted token out of the SDK cache.
  ///
  /// Must run before StorageUtil.clearUserData() — it needs the auth token and
  /// the property's api url, both of which live in SharedPreferences.
  static Future<Map<String, dynamic>> removeFcmToken() async {
    final domain = await resolveDomain();
    final deviceId = await DeviceId.get();
    final url = '$domain${endpoints['RemoveFcmToken']}';
    final response = await postRequest(url, {
      'userId': deviceId,
      'appType': appType,
    });
    print('removeFcmToken response: $response');
    return response;
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  static Future<String?> createChat(String userUid) async {
    final deviceId = await DeviceId.get();
    try {
      final domain = await resolveDomain();
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

  /// Creates a group with the current user as creator/admin.
  ///
  /// [members] are the other participants — each entry needs the user's uuid
  /// and the appType they belong to, since the same uuid can exist on another
  /// app. Returns the new groupId, or null when the call fails.
  static Future<String?> createGroup({
    required String name,
    required List<ChatContact> members,
    String? avatarPath,
  }) async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final token = await _getToken();
      final url = Uri.parse('$domain${endpoints['createGroup']}');

      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['name'] = name
        ..fields['creatorId'] = deviceId
        ..fields['creatorAppType'] = appType.toString()
        // members travels as a JSON-encoded array inside the form field.
        ..fields['members'] = jsonEncode(
          members
              .map((m) => {'userUuid': m.userUuid, 'appType': m.appType})
              .toList(),
        );

      if (avatarPath != null && avatarPath.isNotEmpty) {
        final file = File(avatarPath);
        if (file.existsSync()) {
          final ext = avatarPath.split('.').last.toLowerCase();
          final mimeParts = _mimeFromExtension(ext).split('/');
          request.files.add(
            await http.MultipartFile.fromPath(
              'avatar',
              avatarPath,
              contentType: MediaType(mimeParts[0], mimeParts[1]),
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      print('createGroup response: ${streamedResponse.statusCode} $responseBody');

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true || data['groupId'] != null) {
          return data['groupId']?.toString();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Groups the current user belongs to.
  static Future<List<Map<String, dynamic>>> fetchUserGroups() async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      if (deviceId.isEmpty) {
        throw Exception('deviceId not found in storage');
      }
      final url =
          '$domain${endpoints['fetchUserGroups']}/$deviceId?appType=$appType';
      final response = await getRequest(url);
      if (response['success'] == true) {
        final groups = response['data']?['groups'];
        if (groups is List) {
          return groups.whereType<Map<String, dynamic>>().toList();
        }
        return [];
      }
      throw Exception(response['error'] ?? 'Failed to fetch groups');
    } catch (e) {
      throw Exception('Failed to fetch groups: $e');
    }
  }

  /// Sends a message to a group. Group messaging reuses the chat message
  /// endpoint with the groupId standing in for the chatId.
  ///
  /// [chatId] is a groupId for a group and a chatId for a 1:1 conversation —
  /// the backend treats them the same, so this one call serves both.
  ///
  /// [replyToMessageId] quotes an existing message — it must belong to this
  /// same chat, or the backend answers 400. The server snapshots the quoted
  /// text and sender name onto the new message, so nothing else is sent.
  ///
  /// [mentionedUserIds] flags the people named with an @ in [text] — each entry
  /// is `{userUuid, appType}`, since the uuid alone does not identify a user
  /// across apps. Mostly a group feature, but the endpoint accepts it for 1:1
  /// chats too.
  static Future<Map<String, dynamic>> sendChatMessage({
    required String chatId,
    required String text,
    String? replyToMessageId,
    List<Map<String, dynamic>>? mentionedUserIds,
  }) async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final senderName =
          await StorageUtil.getUserName() ?? await getName() ?? '';
      final url = '$domain${endpoints['fetchMessages']}/$chatId/messages';
print('sendChatMessage called with chatId: $chatId, text: $text, replyToMessageId: $replyToMessageId, mentionedUserIds: $mentionedUserIds');
      return await postRequest(url, {
        'senderId': deviceId,
        'senderAppType': appType,
        'senderName': senderName,
        'text': text,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        if (mentionedUserIds != null && mentionedUserIds.isNotEmpty)
          'mentionedUserIds': mentionedUserIds,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Renames a group and/or flips admin-only messaging. Admins only — only the
  /// fields passed here are sent, so the rest keep their current values.
  static Future<Map<String, dynamic>> updateGroupSettings({
    required String groupId,
    String? name,
    bool? adminOnlyMessaging,
  }) async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['groups']}/$groupId/settings';
      return await patchRequest(url, {
        'requesterId': deviceId,
        'requesterAppType': appType,
        if (name != null) 'name': name,
        if (adminOnlyMessaging != null)
          'adminOnlyMessaging': adminOnlyMessaging,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Replaces a group's avatar. Admins only.
  ///
  /// The backend uploads the image to Cloud Storage and stores the resulting
  /// public url on the group in one step, so nothing else needs calling after
  /// this. Returns the same {success, data|error} shape as the other group
  /// admin actions, with `avatarUrl` inside `data` on success.
  static Future<Map<String, dynamic>> updateGroupAvatar({
    required String groupId,
    required String avatarPath,
  }) async {
    try {
      print('updateGroupAvatar called with groupId: $groupId, avatarPath: $avatarPath');
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final token = await _getToken();
      final url = Uri.parse('$domain${endpoints['groups']}/$groupId/avatar');

      final file = File(avatarPath);
      if (!file.existsSync()) {
        return {'success': false, 'error': 'Image file not found'};
      }

      final ext = avatarPath.split('.').last.toLowerCase();
      final mimeParts = _mimeFromExtension(ext).split('/');

      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['requesterId'] = deviceId
        ..fields['requesterAppType'] = appType.toString()
        ..files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            avatarPath,
            contentType: MediaType(mimeParts[0], mimeParts[1]),
          ),
        );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(responseBody)};
      }
      return {
        'success': false,
        'error': 'Server returned status code: ${streamedResponse.statusCode}',
        'statusCode': streamedResponse.statusCode,
        'responseBody': responseBody,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Adds members to a group. Admins only. Users already in the group are
  /// silently skipped by the backend.
  static Future<Map<String, dynamic>> addGroupMembers({
    required String groupId,
    required List<Map<String, dynamic>> members,
  }) async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['groups']}/$groupId/members';
      return await postRequest(url, {
        'requesterId': deviceId,
        'requesterAppType': appType,
        'members': members,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Removes someone else from a group. Admins only — leaving is a separate
  /// endpoint and cannot be done through this one.
  static Future<Map<String, dynamic>> removeGroupMember({
    required String groupId,
    required String userUuid,
    required int memberAppType,
  }) async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final url =
          '$domain${endpoints['groups']}/$groupId/members/$userUuid?appType=$memberAppType';
      return await deleteRequestWithBody(url, {
        'requesterId': deviceId,
        'requesterAppType': appType,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Promotes a member to admin. Admins only.
  static Future<Map<String, dynamic>> promoteGroupAdmin({
    required String groupId,
    required String targetUserId,
    required int targetAppType,
  }) async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['groups']}/$groupId/admins';
      return await postRequest(url, {
        'requesterId': deviceId,
        'requesterAppType': appType,
        'targetUserId': targetUserId,
        'targetAppType': targetAppType,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Demotes an admin back to member. Admins only, and the backend rejects
  /// demoting the last remaining admin.
  static Future<Map<String, dynamic>> demoteGroupAdmin({
    required String groupId,
    required String userUuid,
    required int memberAppType,
  }) async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final url =
          '$domain${endpoints['groups']}/$groupId/admins/$userUuid?appType=$memberAppType';
      return await deleteRequestWithBody(url, {
        'requesterId': deviceId,
        'requesterAppType': appType,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Leaves a group. Rejected for the sole admin while other members remain.
  static Future<Map<String, dynamic>> leaveGroup(String groupId) async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['groups']}/$groupId/leave';
      return await postRequest(url, {'userId': deviceId, 'appType': appType});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Deletes a group along with its messages and attachments. Creator only.
  static Future<Map<String, dynamic>> deleteGroup(String groupId) async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['groups']}/$groupId';
      return await deleteRequestWithBody(url, {
        'requesterId': deviceId,
        'requesterAppType': appType,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Full details for one group, including its member list and their roles.
  static Future<Map<String, dynamic>> fetchGroupDetails(String groupId) async {
    try {
      final domain = await resolveDomain();
      final url = '$domain${endpoints['groups']}/$groupId';
      final response = await getRequest(url);
      if (response['success'] == true) {
        final group = response['data']?['group'];
        if (group is Map<String, dynamic>) return group;
        throw Exception('Group not found');
      }
      throw Exception(response['error'] ?? 'Failed to fetch group details');
    } catch (e) {
      throw Exception('Failed to fetch group details: $e');
    }
  }

  static Future<bool> deleteChat(String chatId) async {
    try {
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['deleteMessage']}/$chatId/hide';
      final response = await postRequest(url, {'userId': deviceId, 'appType': 2});
      return response['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> fetchUserChats() async {
    try {
      print('fetchUserChats called');
      final domain = await resolveDomain();
      print('Resolved domain: $domain');
      final deviceId = await DeviceId.get();
      final location = await StorageUtil.getCurrentLocation();
      if (deviceId == null || deviceId.isEmpty) {
        throw Exception('deviceId not found in storage');
      }
      final url = '$domain${endpoints['fetchUserChats']}/$deviceId?location=${location?.code}&appType=2';
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
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final location = await StorageUtil.getCurrentLocation();
      final url = '$domain${endpoints['fetchAllUsers']}/$deviceId?location=${location?.code}&appType=2';
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
      final domain = await resolveDomain();
      final url = '$domain${endpoints['fetchMessages']}/$chatId/messages';
      print("rrrr, $url");
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
    int recipientAppType = 1,
  }) async {
    try {
      print(
          'sendMessage called with recipientUuid: $recipientUuid,recipientUuid: $title, chatId: $chatId, message: $message ,recipientAppType: $recipientAppType');
      final domain = await resolveDomain();
      final deviceId = await DeviceId.get();
      final url = '$domain${endpoints['sendMessage']}';
      print('sendMessage URL: $url');
      final response = await postRequest(url, {
        "senderUuid": deviceId,
        "recipientUuid": recipientUuid,
        "message": message,
        "title": title,
        "body": body,
        "chatId": chatId,
        "senderAppType": 2,
        "recipientAppType": recipientAppType,
      });
      print('sendMessage response: $response');
      return response;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // static Future<Map<String, dynamic>> softDeleteMessage(
  //   String chatId,
  //   String messageId,
  // ) async {
  //   try {
  //     final deviceId = await DeviceId.get();
  //     final url =
  //         '$domain${endpoints['softDeleteMessage']}/$chatId/messages/$messageId';
  //     return await deleteRequestWithBody(url, {'userId': deviceId});
  //   } catch (e) {
  //     return {'success': false, 'error': e.toString()};
  //   }
  // }
  // Delete for ME only (existing - soft delete)
static Future<Map<String, dynamic>> softDeleteMessage(

  String chatId,
  String messageId,
) async {
  try {
    print('softDeleteMessage called with chatId: $chatId, messageId: $messageId');
    final domain = await resolveDomain();
    final deviceId = await DeviceId.get();
    final url = '$domain/api/chats/$chatId/messages/$messageId/soft-delete';
    return await patchRequest(url, {'userId': deviceId,'appType': 2});
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Forwards one message into other chats/groups and/or straight to users.
///
/// [chatId]/[messageId] identify the message being forwarded. Targets are
/// given as either (or both) of:
///  * [targetChatIds] — chats or groups the user is already a participant of.
///  * [targetUsers] — `{userUuid, appType}` pairs; the backend finds or
///    creates the 1:1 chat with that person, so they need not be messaged
///    before.
///
/// Best-effort per target: the response carries a `results` list where each
/// entry reports its own success/error, so one rejected target (not a
/// participant, admin-only group, forwarding back into the source chat) does
/// not stop the rest.
static Future<Map<String, dynamic>> forwardMessage({
  required String chatId,
  required String messageId,
  List<String> targetChatIds = const [],
  List<Map<String, dynamic>> targetUsers = const [],
}) async {
  try {
    final domain = await resolveDomain();
    final deviceId = await DeviceId.get();
    final senderName = await StorageUtil.getUserName() ?? await getName() ?? '';
    final url = '$domain/api/chats/$chatId/messages/$messageId/forward';
    final body = {
      'userId': deviceId,
      'appType': appType,
      'senderName': senderName,
      if (targetChatIds.isNotEmpty) 'targetChatIds': targetChatIds,
      if (targetUsers.isNotEmpty) 'targetUserIds': targetUsers,
    };
    _logLong('forwardMessage ▶ POST $url');
    _logLong('forwardMessage ▶ body: ${jsonEncode(body)}');

    final result = await postRequest(url, body);

    _logLong('forwardMessage ◀ response: ${jsonEncode(result)}');
    return result;
  } catch (e) {
    print('forwardMessage ✖ exception: $e');
    return {'success': false, 'error': e.toString()};
  }
}

/// print() drops very long lines on some platforms, so long payloads are
/// emitted in chunks that survive the terminal.
static void _logLong(String message, {int chunkSize = 800}) {
  for (var i = 0; i < message.length; i += chunkSize) {
    final end = (i + chunkSize < message.length) ? i + chunkSize : message.length;
    print(message.substring(i, end));
  }
}

// Delete for EVERYONE (hard delete)
static Future<Map<String, dynamic>> deleteMessageForEveryone(
  String chatId,
  String messageId,
) async {
  try {
    print('deleteMessageForEveryone called with chatId: $chatId, messageId: $messageId');
    final domain = await resolveDomain();
    final deviceId = await DeviceId.get();
    final url = '$domain/api/chats/$chatId/messages/$messageId';
    return await deleteRequestWithBody(url, {'userId': deviceId,'appType': 2});
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}
/// Adds, changes or removes this user's emoji reaction on a message.
///
/// The backend keeps at most one reaction per user per message, so this one
/// endpoint covers all three cases: sending the emoji they already have
/// removes it, a different one replaces it. The response carries
/// `reacted: true` when a reaction was added or changed and `reacted: false`
/// when it was removed. Reacting to a deleted message is rejected with 400.
static Future<Map<String, dynamic>> reactToMessage({
  required String chatId,
  required String messageId,
  required String emoji,
}) async {
  try {
    final domain = await resolveDomain();
    final deviceId = await DeviceId.get();
    final url = '$domain/api/chats/$chatId/messages/$messageId/react';
    final body = {
      'userId': deviceId,
      'appType': appType,
      'emoji': emoji,
    };
    _logLong('reactToMessage ▶ POST $url');
    _logLong('reactToMessage ▶ body: ${jsonEncode(body)}');

    final result = await postRequest(url, body);

    _logLong('reactToMessage ◀ response: ${jsonEncode(result)}');
    return result;
  } catch (e) {
    print('reactToMessage ✖ exception: $e');
    return {'success': false, 'error': e.toString()};
  }
}

static Future<Map<String, dynamic>> patchRequest(
  String url,
  Map<String, dynamic> body,
) async {
  try {
    final headers = await getAuthHeaders();
    final response = await http.patch(
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
}