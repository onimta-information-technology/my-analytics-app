import 'dart:convert';

import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/call_session.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:http/http.dart' as http;

/// A calling request the server refused. [statusCode] carries the meaning:
/// 403 not a participant, 404 no such call, 409 the chat already has a live
/// call ([existingCallId] names it), 410 the call is over, 503 calling is not
/// configured on this server.
class CallApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? existingCallId;

  const CallApiException(this.message, {this.statusCode, this.existingCallId});

  bool get isAlreadyActive => statusCode == 409;
  bool get isOver => statusCode == 410;
  bool get isNotConfigured => statusCode == 503;

  @override
  String toString() => message;
}

/// The LiveKit calling endpoints (`/api/calls`). The server only hands out
/// join tokens — media goes straight between the device and LiveKit.
///
/// Lives on the same chat host as [FirebaseApiService], and identifies the
/// user the same way: device id + [FirebaseApiService.appType].
class CallApiService {
  const CallApiService._();

  static Future<CallJoinInfo> start({
    required String chatId,
    required CallMedia media,
  }) async {
    final body = await _send('POST', '/api/calls/start', {
      'chatId': chatId,
      ...await _identity(withName: true),
      'callType': media.wire,
    });
    return CallJoinInfo.fromJson(body);
  }

  /// Accepting a ringing call and joining (or rejoining) an ongoing one are
  /// the same operation.
  static Future<CallJoinInfo> join(String callId) async {
    final body = await _send(
      'POST',
      '/api/calls/$callId/join',
      await _identity(withName: true),
    );
    return CallJoinInfo.fromJson(body);
  }

  static Future<void> decline(String callId) async {
    await _send('POST', '/api/calls/$callId/decline', await _identity());
  }

  /// Leaves the call. Returns true when this closed out the whole call.
  /// Already ended is not an error, so this is safe to send twice.
  static Future<bool> end(String callId, {String reason = 'hangup'}) async {
    final body = await _send('POST', '/api/calls/$callId/end', {
      ...await _identity(),
      'reason': reason,
    });
    return body['ended'] == true || body['alreadyEnded'] == true;
  }

  static Future<CallSnapshot> status(String callId) async {
    final body = await _send('GET', '/api/calls/$callId');
    return CallSnapshot.fromJson(body);
  }

  /// The chat's live call, if any. Carries no token — [join] it for one.
  static Future<CallInfo?> activeCall(String chatId) async {
    final body = await _send('GET', '/api/chats/$chatId/active-call');
    if (body['active'] != true) return null;
    final call = (body['call'] as Map?)?.cast<String, dynamic>();
    return call == null ? null : CallInfo.fromJson({...call, 'chatId': chatId});
  }

  /// Every call this user was invited to, across all chats, newest first.
  /// [before] is the previous page's [CallHistoryPage.nextCursor].
  static Future<CallHistoryPage> history({int limit = 30, int? before}) async {
    final userId = await DeviceId.get();
    final query = {
      'appType': '${FirebaseApiService.appType}',
      'limit': '$limit',
      if (before != null) 'before': '$before',
    };
    final body = await _send(
      'GET',
      '/api/calls/history/$userId?${Uri(queryParameters: query).query}',
    );
    return CallHistoryPage.fromJson(body);
  }

  /// iOS only: the PushKit token — not the FCM token — that the server sends
  /// VoIP pushes to, so a call rings even when the app has been killed.
  static Future<void> updateVoipToken(String voipToken) async {
    await _send('POST', '/api/users/update-voip-token', {
      ...await _identity(),
      'voipToken': voipToken,
    });
  }

  static Future<void> removeVoipToken() async {
    await _send('POST', '/api/users/remove-voip-token', await _identity());
  }

  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _identity({bool withName = false}) async {
    return {
      'userId': await DeviceId.get(),
      'appType': FirebaseApiService.appType,
      if (withName) 'userName': await StorageUtil.getChatUserName() ?? '',
    };
  }

  /// Unlike [FirebaseApiService.postRequest], the error body matters here —
  /// a 409 carries the call to join instead — so it is decoded either way.
  static Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final domain = await FirebaseApiService.resolveDomain();
    final uri = Uri.parse('$domain$path');
    final headers = await FirebaseApiService.getAuthHeaders();
    print('call ▶ $method $uri ${body == null ? '' : jsonEncode(body)}');

    final http.Response response;
    try {
      response = method == 'GET'
          ? await http.get(uri, headers: headers)
          : await http.post(uri, headers: headers, body: jsonEncode(body));
    } catch (e) {
      throw CallApiException('Could not reach the server: $e');
    }
    print('call ◀ ${response.statusCode} ${response.body}');

    Map<String, dynamic> decoded = const {};
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok && decoded['success'] != false) return decoded;

    throw CallApiException(
      decoded['error']?.toString() ??
          'Server returned status code: ${response.statusCode}',
      statusCode: response.statusCode,
      existingCallId: decoded['callId']?.toString(),
    );
  }
}
