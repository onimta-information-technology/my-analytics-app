// Shapes returned by the calling API (`/api/calls`). A call is not a chat: a
// chat can have many calls over its lifetime, each with its own `callId` and
// its own LiveKit room.

/// `msg_type` values the chat server uses for call pushes. Only [incoming] is
/// a visible alert; the rest arrive silent/data-only.
class CallPushType {
  const CallPushType._();

  static const incoming = '20';
  static const answered = '21';
  static const declined = '22';
  static const ended = '23';
  static const participantLeft = '24';
  static const participantMissing = '25';

  static const all = {
    incoming,
    answered,
    declined,
    ended,
    participantLeft,
    participantMissing,
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

DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();
