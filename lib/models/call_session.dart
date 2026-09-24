// Shapes returned by the calling API (`/api/calls`). A call is not a chat: a
// chat can have many calls over its lifetime, each with its own `callId` and
// its own LiveKit room.

/// `msg_type` values the chat server uses for call pushes. Every one of them
/// arrives silent/data-only — even [incoming] carries no FCM `notification`,
/// so the OS never shows anything by itself and ringing is the app's job.
class CallPushType {
  const CallPushType._();

  static const incoming = '20';
  static const answered = '21';
  static const declined = '22';
  static const ended = '23';
  static const participantLeft = '24';

  /// Nobody answered within the server's ring window (45s) — the server has
  /// already ended the call. The caller shows "No answer"/"Unreachable"
  /// rather than a plain "Call ended".
  static const noAnswer = '25';

  /// A callee's device confirmed (`POST /calls/:callId/ringing`) that it is
  /// showing its ringing UI — the caller switches "Calling…" to "Ringing…".
  static const ringing = '26';

  static const all = {
    incoming,
    answered,
    declined,
    ended,
    participantLeft,
    noAnswer,
    ringing,
  };

  static bool isCallPush(Map<String, dynamic> data) =>
      all.contains(data['msg_type']?.toString());
}

/// `"audio"` or `"video"` on the wire.
enum CallMedia {
  audio,
  video;

  static CallMedia parse(Object? raw) =>
      raw?.toString().toLowerCase() == 'video' ? video : audio;

  String get wire => name;
}

/// What `start` and `join` both answer with: everything the LiveKit SDK
/// needs to connect. The token is scoped to this one room and this one
/// participant, so it is never reused across calls.
class CallJoinInfo {
  final String callId;
  final String roomName;
  final String livekitUrl;
  final String token;
  final CallMedia media;
  final bool isGroupCall;

  const CallJoinInfo({
    required this.callId,
    required this.roomName,
    required this.livekitUrl,
    required this.token,
    required this.media,
    required this.isGroupCall,
  });

  factory CallJoinInfo.fromJson(Map<String, dynamic> json) => CallJoinInfo(
    callId: json['callId']?.toString() ?? '',
    roomName: json['roomName']?.toString() ?? '',
    livekitUrl: json['livekitUrl']?.toString() ?? '',
    token: json['token']?.toString() ?? '',
    media: CallMedia.parse(json['callType']),
    isGroupCall: json['isGroupCall'] == true,
  );
}

/// The call row itself, as `GET /calls/:callId` and
/// `GET /chats/:chatId/active-call` return it.
class CallInfo {
  final String callId;
  final String chatId;
  final String roomName;
  final CallMedia media;
  final bool isGroupCall;
  final String callerUuid;
  final String callerName;

  /// `ringing`, `ongoing`, `ended` or `declined`.
  final String status;
  final DateTime? createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  const CallInfo({
    required this.callId,
    required this.chatId,
    required this.roomName,
    required this.media,
    required this.isGroupCall,
    required this.callerUuid,
    required this.callerName,
    required this.status,
    this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  bool get isLive => status == 'ringing' || status == 'ongoing';

  factory CallInfo.fromJson(Map<String, dynamic> json) => CallInfo(
    callId: json['callId']?.toString() ?? '',
    chatId: json['chatId']?.toString() ?? '',
    roomName: json['roomName']?.toString() ?? '',
    media: CallMedia.parse(json['callType']),
    isGroupCall: json['isGroupCall'] == true,
    callerUuid: json['callerUuid']?.toString() ?? '',
    callerName: json['callerName']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
    createdAt: _date(json['createdAt']),
    answeredAt: _date(json['answeredAt']),
    endedAt: _date(json['endedAt']),
  );
}

/// One invited chat member of a call. Its [status] is independent of the
/// call's: `ringing`, `joined`, `declined`, `left` or `missed`.
class CallParticipantInfo {
  final String userUuid;
  final int appType;
  final String name;
  final String firstName;
  final String status;

  const CallParticipantInfo({
    required this.userUuid,
    required this.appType,
    required this.name,
    required this.firstName,
    required this.status,
  });

  /// Matches the LiveKit identity the server mints tokens with.
  String get identity => '$userUuid|$appType';

  factory CallParticipantInfo.fromJson(Map<String, dynamic> json) =>
      CallParticipantInfo(
        userUuid: json['userUuid']?.toString() ?? '',
        appType: int.tryParse(json['appType']?.toString() ?? '') ?? 0,
        name: json['name']?.toString() ?? '',
        firstName: json['firstName']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
      );
}

class CallSnapshot {
  final CallInfo call;
  final List<CallParticipantInfo> participants;

  const CallSnapshot({required this.call, required this.participants});

  factory CallSnapshot.fromJson(Map<String, dynamic> json) => CallSnapshot(
    call: CallInfo.fromJson(
      (json['call'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    participants: ((json['participants'] as List?) ?? const [])
        .whereType<Map>()
        .map((p) => CallParticipantInfo.fromJson(p.cast<String, dynamic>()))
        .toList(),
  );
}

/// The fields of an incoming-call push (`msg_type` 20). FCM data payloads
/// are string-only, so `isGroupCall` arrives as `"true"`/`"false"`. The iOS
/// VoIP push carries the same names with real JSON types, which [fromMap]
/// accepts too.
class IncomingCallPush {
  final String callId;
  final String callerId;
  final String callerName;
  final CallMedia media;
  final bool isGroupCall;

  /// Group name; empty for a 1:1 call.
  final String chatTitle;

  /// Ready-to-display title and body the server composed for the ring.
  final String alertTitle;
  final String alertBody;

  /// Not in the ring payload today — filled in when a lookup supplies it.
  final String chatId;

  const IncomingCallPush({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.media,
    required this.isGroupCall,
    required this.chatTitle,
    required this.alertTitle,
    required this.alertBody,
    this.chatId = '',
  });

  /// Who is calling, as the ringing UI should name it: the group for a group
  /// call, the caller otherwise.
  String get displayTitle {
    if (isGroupCall && chatTitle.isNotEmpty) return chatTitle;
    if (alertTitle.isNotEmpty) return alertTitle;
    if (callerName.isNotEmpty) return callerName;
    return 'Incoming call';
  }

  String get displayBody {
    if (alertBody.isNotEmpty) return alertBody;
    final kind = media == CallMedia.video ? 'video' : 'voice';
    return isGroupCall
        ? '${callerName.isEmpty ? 'Someone' : callerName} · group $kind call'
        : 'Incoming $kind call';
  }

  static IncomingCallPush? fromMap(Map<dynamic, dynamic> raw) {
    final data = raw.map((k, v) => MapEntry(k.toString(), v));
    final callId = data['callId']?.toString() ?? '';
    if (callId.isEmpty) return null;
    String str(String key) => data[key]?.toString() ?? '';
    return IncomingCallPush(
      callId: callId,
      callerId: str('callerId'),
      callerName: str('callerName'),
      media: CallMedia.parse(data['callType']),
      isGroupCall:
          data['isGroupCall'] == true || str('isGroupCall') == 'true',
      chatTitle: str('chatTitle'),
      alertTitle: str('alertTitle'),
      alertBody: str('alertBody'),
      chatId: str('chatId'),
    );
  }

  /// Flat string map — what the CallKit plugin carries in `extra` and hands
  /// back on accept/decline, so [fromMap] rebuilds this on the other side.
  Map<String, String> toMap() => {
    'callId': callId,
    'callerId': callerId,
    'callerName': callerName,
    'callType': media.wire,
    'isGroupCall': isGroupCall.toString(),
    'chatTitle': chatTitle,
    'alertTitle': alertTitle,
    'alertBody': alertBody,
    'chatId': chatId,
  };
}

/// One row of `GET /calls/history/:userId` — the cross-chat "Recents" list.
class CallHistoryEntry {
  final String callId;
  final String chatId;
  final CallMedia media;
  final bool isGroupCall;

  /// `outgoing` when this user started the call, `incoming` otherwise.
  final bool isOutgoing;

  /// `completed`, `missed`, `declined`, or — for a call still in progress —
  /// `ringing`/`ongoing`.
  final String status;
  final DateTime? createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  /// Set for a 1:1 call.
  final CallHistoryPeer? otherParticipant;

  /// Set for a group call.
  final String groupName;
  final String groupAvatarUrl;

  const CallHistoryEntry({
    required this.callId,
    required this.chatId,
    required this.media,
    required this.isGroupCall,
    required this.isOutgoing,
    required this.status,
    this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.otherParticipant,
    this.groupName = '',
    this.groupAvatarUrl = '',
  });

  bool get isMissed => status == 'missed';
  bool get isDeclined => status == 'declined';
  bool get isLive => status == 'ringing' || status == 'ongoing';

  String get title {
    if (isGroupCall) return groupName.isNotEmpty ? groupName : 'Group call';
    final peer = otherParticipant;
    if (peer == null) return 'Unknown';
    if (peer.name.isNotEmpty) return peer.name;
    return peer.firstName.isNotEmpty ? peer.firstName : 'Unknown';
  }

  String? get avatarUrl {
    final url = isGroupCall ? groupAvatarUrl : otherParticipant?.profileImageUrl;
    return (url == null || url.isEmpty) ? null : url;
  }

  /// Talk time, for a call someone answered.
  Duration? get duration {
    final from = answeredAt;
    final to = endedAt;
    if (from == null || to == null || to.isBefore(from)) return null;
    return to.difference(from);
  }

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) {
    final peer = (json['otherParticipant'] as Map?)?.cast<String, dynamic>();
    return CallHistoryEntry(
      callId: json['callId']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      media: CallMedia.parse(json['callType']),
      isGroupCall: json['isGroupCall'] == true,
      isOutgoing: json['direction']?.toString() == 'outgoing',
      status: json['status']?.toString() ?? '',
      createdAt: _date(json['createdAt']),
      answeredAt: _date(json['answeredAt']),
      endedAt: _date(json['endedAt']),
      otherParticipant: peer == null ? null : CallHistoryPeer.fromJson(peer),
      groupName: json['groupName']?.toString() ?? '',
      groupAvatarUrl: json['groupAvatarUrl']?.toString() ?? '',
    );
  }
}

class CallHistoryPeer {
  final String userUuid;
  final int appType;
  final String name;
  final String firstName;
  final String profileImageUrl;

  const CallHistoryPeer({
    required this.userUuid,
    required this.appType,
    required this.name,
    required this.firstName,
    required this.profileImageUrl,
  });

  factory CallHistoryPeer.fromJson(Map<String, dynamic> json) =>
      CallHistoryPeer(
        userUuid: json['userUuid']?.toString() ?? '',
        appType: int.tryParse(json['appType']?.toString() ?? '') ?? 0,
        name: json['name']?.toString() ?? '',
        firstName: json['firstName']?.toString() ?? '',
        profileImageUrl: json['profileImageUrl']?.toString() ?? '',
      );
}

class CallHistoryPage {
  final List<CallHistoryEntry> calls;
  final bool hasMore;

  /// Pass back as `before` for the next page.
  final int? nextCursor;

  const CallHistoryPage({
    required this.calls,
    required this.hasMore,
    this.nextCursor,
  });

  factory CallHistoryPage.fromJson(Map<String, dynamic> json) =>
      CallHistoryPage(
        calls: ((json['calls'] as List?) ?? const [])
            .whereType<Map>()
            .map((c) => CallHistoryEntry.fromJson(c.cast<String, dynamic>()))
            .toList(),
        hasMore: json['hasMore'] == true,
        nextCursor: int.tryParse(json['nextCursor']?.toString() ?? ''),
      );
}

DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();
