import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart'
    show AndroidAudioAttributes, AndroidAudioContentType, AndroidAudioUsage;
import 'package:ballys_reservation_app/data/services/call_api_service.dart';
import 'package:ballys_reservation_app/data/services/call_audio_router.dart';
import 'package:ballys_reservation_app/data/services/call_kit_service.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/main.dart' show navigatorKey;
import 'package:ballys_reservation_app/models/call_session.dart';
import 'package:ballys_reservation_app/screens/call/call_screen.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallPhase {
  /// Someone is ringing us; nothing is connected yet.
  incoming,

  /// We placed the call and nobody else has joined the room yet.
  outgoing,

  /// Fetching a token / connecting to LiveKit.
  connecting,

  /// In the room with at least one other person (or joining an ongoing call).
  connected,

  /// Over — the screen shows [CallController.endReason] and closes itself.
  ended,
}

/// State of the one call this device is part of. [CallScreen] renders from
/// it; [CallManager] drives it from user actions, pushes, polling and LiveKit
/// room events.
class CallController extends ChangeNotifier {
  String? callId;
  final String chatId;

  /// The other person's name for a 1:1 call, the chat title for a group.
  final String title;
  final String? avatarUrl;
  final CallMedia media;

  /// Not final: adding someone to a 1:1 call turns it into a group call, and
  /// from then on it outlives any one person leaving.
  bool isGroupCall;

  /// How the call began — a 1:1 call later made a group has no group name to
  /// show, so it is titled after the people on it instead.
  final bool startedAsGroup;
  final bool isOutgoing;

  /// Answered from the OS call UI (CallKit / Android's full-screen ring),
  /// which then holds a system call entry that has to be released with it.
  final bool viaSystem;

  CallPhase phase;

  /// Outgoing only: a callee's device confirmed it is showing its ring
  /// (`msg_type` 26). Until then the caller sees "Calling…", not "Ringing…" —
  /// a push that never arrived never rang anything.
  bool remoteRinging = false;
  String? endReason;
  DateTime? connectedAt;

  Room? room;
  bool micEnabled = true;
  late bool cameraEnabled = media == CallMedia.video;
  late bool speakerOn = media == CallMedia.video;

  /// We are showing our screen to the others on the call.
  bool screenSharing = false;

  /// The call's audio outputs and the one it is on, kept current while the
  /// call is live. Null until the platform reports them.
  AudioRoutes? audioRoutes;

  /// The output picked from the speaker button / picker. Until there is one
  /// the call follows [speakerOn], with a connected headset winning.
  AudioRoute? chosenRoute;

  AudioRoute? get audioRoute => audioRoutes?.current;

  /// Audio is at the ear: not the loudspeaker, nor a headset.
  bool get onEarpiece =>
      !speakerOn &&
      (audioRoute == null || audioRoute!.type == AudioRouteType.earpiece);
  CameraPosition cameraPosition = CameraPosition.front;

  /// LiveKit identity (`<userUuid>|<appType>`) → display name, from the
  /// server's participant list. Covers anyone whose token carried no name.
  final Map<String, String> names = {};

  /// LiveKit identity → profile photo URL, looked up once per participant.
  /// The empty string marks a lookup that found no photo.
  final Map<String, String> avatars = {};

  /// Our own profile photo, for the "You" tile.
  String? myAvatarUrl;

  /// People this device added to the call who have not picked up yet, keyed
  /// by LiveKit identity. Cleared as they join, decline, or ring out.
  final Map<String, CallInvitee> invited = {};

  CallController({
    required this.callId,
    required this.chatId,
    required this.title,
    required this.media,
    required this.isGroupCall,
    required this.isOutgoing,
    required this.phase,
    this.avatarUrl,
    this.viaSystem = false,
  }) : startedAsGroup = isGroupCall;

  bool get isVideo => media == CallMedia.video;

  List<RemoteParticipant> get remoteParticipants =>
      room?.remoteParticipants.values.toList() ?? const [];

  /// The call's name on screen: the chat's title, or for a 1:1 call that
  /// became a group, everyone else on it ("Jane, John").
  String get displayTitle {
    if (startedAsGroup || !isGroupCall) return title;
    final names = [
      for (final p in remoteParticipants) nameOf(p),
      for (final i in invited.values) i.name,
    ].where((n) => n.isNotEmpty && n != 'Participant').toSet();
    return names.isEmpty ? title : names.join(', ');
  }

  /// LiveKit identities of everyone already on or ringing into the call,
  /// us included — who "Add person" should not offer.
  Set<String> get identitiesOnCall => {
        ...?room?.remoteParticipants.values.map((p) => p.identity),
        if (room?.localParticipant != null) room!.localParticipant!.identity,
        ...invited.keys,
      };

  String nameOf(Participant p) {
    if (p.name.isNotEmpty) return p.name;
    return names[p.identity] ?? (isGroupCall ? 'Participant' : title);
  }

  String? avatarOf(Participant p) {
    final url = avatars[p.identity];
    return (url == null || url.isEmpty) ? null : url;
  }

  /// The screen showing this call, removed once it has ended.
  Route<void>? _route;

  void update() => notifyListeners();
}

/// Someone added to the call from this device, still ringing.
class CallInvitee {
  final String userUuid;
  final int appType;
  final String name;
  final String? avatarUrl;

  /// Drops the "Ringing…" entry once their ring window is over — an invitee
  /// who lets it ring out is never reported back to us.
  Timer? expiry;

  CallInvitee({
    required this.userUuid,
    required this.appType,
    required this.name,
    this.avatarUrl,
  });

  String get identity => '$userUuid|$appType';
}

/// Owns the device's single active call. Every entry point — the chat
/// screen's call buttons, the "ongoing call" banner, call pushes and taps on
/// them — goes through here, so there is never more than one room open.
class CallManager {
  CallManager._();
  static final CallManager instance = CallManager._();

  /// The server ends an unanswered call itself after 45s and tells the caller
  /// with a `msg_type` 25 push. This is only the backstop for when that push
  /// (and the poll) never make it, so it runs a little past the server's.
  static const _outgoingTimeout = Duration(seconds: 50);

  /// How long an incoming call is offered before the screen closes itself —
  /// the server's ring window, past which the call is already gone.
  static const _incomingTimeout = Duration(seconds: 45);

  /// The call on this device, if any — including one showing its closing
  /// message. Screens listen to it to hide or refresh an "ongoing call"
  /// banner as calls come and go.
  final ValueNotifier<CallController?> active = ValueNotifier(null);

  /// Whether [CallScreen] is up. False while the call carries on behind the
  /// app's other screens, WhatsApp style, with the "return to call" bar
  /// offering the way back.
  final ValueNotifier<bool> screenShown = ValueNotifier(false);

  CallController? get _current => active.value;
  set _current(CallController? c) => active.value = c;
  EventsListener<RoomEvent>? _roomListener;

  /// Keeps the call screen on screen while the app is still starting up.
  Timer? _screenWatchdog;
  Timer? _pollTimer;
  Timer? _timeoutTimer;
  Timer? _lostTimer;
  Timer? _routeTimer;

  /// Right after a switch the platform still reports the old route for a
  /// moment; polls until then are ignored so the button doesn't flick back.
  DateTime _routeSettleAt = DateTime(0);
  bool _ringing = false;

  /// How long the other side of a 1:1 call may stay unreachable before the
  /// call is given up on. An iPhone swiped out of the app switcher dies
  /// without hanging up, and LiveKit can keep it in the room long after — its
  /// connection quality going `lost` is the first sign.
  static const _lostTimeout = Duration(seconds: 15);

  /// Plays the ringback tone to whoever placed the call. Null when nothing is
  /// ringing out.
  AudioPlayer? _ringback;
  StreamSubscription<PlayerState>? _ringbackWatch;

  CallController? get current => _current;

  /// A call that has ended but is still showing its closing message does not
  /// count — a new call can start over it.
  bool get isBusy => _current != null && _current!.phase != CallPhase.ended;

  // ─── Placing and joining ─────────────────────────────────────────────────

  /// Rings everyone else in [chatId]. If the chat already has a live call the
  /// server answers 409 with its id, and we join that one instead.
  Future<void> startCall({
    required String chatId,
    required String title,
    required CallMedia media,
    required bool isGroup,
    String? avatarUrl,
  }) async {
    if (isBusy) {
      _toast('You are already on a call');
      return;
    }
    final c = CallController(
      callId: null,
      chatId: chatId,
      title: title,
      avatarUrl: avatarUrl,
      media: media,
      isGroupCall: isGroup,
      isOutgoing: true,
      phase: CallPhase.outgoing,
    );
    _open(c);

    if (!await _ensurePermissions(media)) {
      return _finish(c, 'Microphone${media == CallMedia.video ? ' and camera' : ''} permission is required');
    }

    CallJoinInfo info;
    try {
      info = await CallApiService.start(chatId: chatId, media: media);
    } on CallApiException catch (e) {
      if (e.isAlreadyActive && e.existingCallId != null) {
        try {
          c.phase = CallPhase.connecting;
          c.update();
          info = await CallApiService.join(e.existingCallId!);
        } on CallApiException catch (e2) {
          return _finish(c, _describe(e2));
        }
      } else {
        return _finish(c, _describe(e));
      }
    }
    if (!_isLive(c)) {
      // Hung up while the request was in flight.
      unawaited(_safeEnd(info.callId, 'cancelled'));
      return;
    }
    c.callId = info.callId;
    await CallKitService.showOngoing(
      callId: info.callId,
      title: c.title,
      media: c.media,
    );
    if (!_isLive(c)) {
      unawaited(CallKitService.release(info.callId));
      return;
    }
    // "Calling…" from here. The ringback tone waits for the callee's device
    // to confirm it is ringing (msg_type 26) — see [_markRemoteRinging].
    await _connect(c, info);
    if (c.phase == CallPhase.outgoing) {
      _startPolling(c);
      _timeoutTimer = Timer(_outgoingTimeout, () {
        if (_isLive(c) && c.phase == CallPhase.outgoing) {
          _hangUp(c, reason: 'no_answer', message: _noAnswerText(c));
        }
      });
    }
  }

  /// Joins a call already in progress — the chat screen's "Join" banner.
  Future<void> joinExisting({
    required CallInfo call,
    required String title,
    String? avatarUrl,
  }) async {
    if (isBusy) {
      if (_current!.callId == call.callId) return showScreen();
      _toast('You are already on a call');
      return;
    }
    final c = CallController(
      callId: call.callId,
      chatId: call.chatId,
      title: title,
      avatarUrl: avatarUrl,
      media: call.media,
      isGroupCall: call.isGroupCall,
      isOutgoing: false,
      phase: CallPhase.connecting,
    );
    _open(c);
    await _acceptInto(c, answeringRing: false);
  }

  /// The user tapped Accept on the system incoming-call UI. The app may have
  /// been launched just for this, so the call is opened straight into
  /// connecting — there is nothing left to ring.
  Future<void> acceptFromSystem(IncomingCallPush push) async {
    final current = _current;
    if (current != null && current.callId == push.callId) {
      if (current.phase == CallPhase.incoming) return accept();
      if (current.phase != CallPhase.ended) return showScreen();
    }
    if (isBusy) {
      _toast('You are already on a call');
      unawaited(CallKitService.dismiss(push.callId));
      return;
    }
    final c = CallController(
      callId: push.callId,
      chatId: push.chatId,
      title: push.displayTitle,
      avatarUrl: push.callerImageUrl,
      media: push.media,
      isGroupCall: push.isGroupCall,
      isOutgoing: false,
      phase: CallPhase.connecting,
      viaSystem: true,
    );
    _open(c);
    await _acceptInto(c);
  }

  /// Hung up from the system UI (iOS call bar, lock screen, Android's
  /// ongoing-call notification).
  Future<void> hangUpFromSystem(String callId) async {
    final c = _current;
    if (c == null || c.callId != callId || c.phase == CallPhase.ended) return;
    if (c.phase == CallPhase.incoming) return decline();
    final nobodyAnswered = c.phase == CallPhase.outgoing;
    await _hangUp(c, reason: nobodyAnswered ? 'cancelled' : 'hangup');
  }

  // ─── User actions from the call screen ───────────────────────────────────

  Future<void> accept() async {
    final c = _current;
    if (c == null || c.phase != CallPhase.incoming) return;
    _stopRinging();
    _timeoutTimer?.cancel();
    c.phase = CallPhase.connecting;
    c.update();
    await _acceptInto(c);
  }

  Future<void> decline() async {
    final c = _current;
    if (c == null) return;
    final id = c.callId;
    _finish(c, 'Call declined');
    if (id != null) {
      try {
        await CallApiService.decline(id);
      } catch (e) {
        print('call decline failed: $e');
      }
    }
  }

  Future<void> hangUp() async {
    final c = _current;
    if (c == null) return;
    if (c.phase == CallPhase.incoming) return decline();
    final nobodyAnswered = c.phase == CallPhase.outgoing;
    await _hangUp(c, reason: nobodyAnswered ? 'cancelled' : 'hangup');
  }

  Future<void> toggleMic() async {
    final c = _current;
    final lp = c?.room?.localParticipant;
    if (c == null || lp == null) return;
    c.micEnabled = !c.micEnabled;
    c.update();
    try {
      await lp.setMicrophoneEnabled(c.micEnabled);
    } catch (e) {
      print('mic toggle failed: $e');
      c.micEnabled = !c.micEnabled;
      c.update();
    }
  }

  Future<void> toggleCamera() async {
    final c = _current;
    final lp = c?.room?.localParticipant;
    if (c == null || lp == null) return;
    if (!c.cameraEnabled && !await Permission.camera.request().isGranted) {
      _toast('Camera permission is required');
      return;
    }
    c.cameraEnabled = !c.cameraEnabled;
    c.update();
    try {
      await lp.setCameraEnabled(c.cameraEnabled);
    } catch (e) {
      print('camera toggle failed: $e');
      c.cameraEnabled = !c.cameraEnabled;
      c.update();
    }
  }

  /// Speaker on/off — for when no headset is connected; with one, the call
  /// screen offers the full list through [selectAudioRoute] instead.
  Future<void> toggleSpeaker() async {
    final c = _current;
    if (c == null) return;
    await selectAudioRoute(AudioRoute(
      c.speakerOn ? AudioRouteType.earpiece : AudioRouteType.speaker,
    ));
  }

  /// Plays the call through [route]: the earpiece, the loudspeaker, or a
  /// Bluetooth / wired headset.
  Future<void> selectAudioRoute(AudioRoute route) async {
    final c = _current;
    if (c == null) return;
    c.chosenRoute = route;
    c.speakerOn = route.type == AudioRouteType.speaker;
    final routes = c.audioRoutes;
    if (routes != null) c.audioRoutes = AudioRoutes(route, routes.available);
    _routeSettleAt = DateTime.now().add(const Duration(seconds: 2));
    c.update();
    if (!_isLive(c) || c.room == null) return;
    await CallAudioRouter.select(route);
  }

  /// Puts call audio where it belongs: the output the user picked, or else a
  /// connected Bluetooth headset (AirPods etc.), a wired one, and failing
  /// those the loudspeaker or earpiece per [CallController.speakerOn].
  ///
  /// LiveKit ignores a speaker switch (it only logs) until a local audio
  /// track is published, and Android can move audio back to the earpiece
  /// once remote audio starts — so this is re-run after connecting and
  /// whenever a remote audio track arrives.
  Future<void> _applySpeaker(CallController c) async {
    if (!_isLive(c) || c.room == null) return;
    var route = c.chosenRoute;
    if (route == null) {
      final routes = await CallAudioRouter.fetch();
      if (!_isLive(c)) return;
      if (routes != null) c.audioRoutes = routes;
      final available = routes?.available ?? const <AudioRoute>[];
      route = available
              .where((r) => r.type == AudioRouteType.bluetooth)
              .firstOrNull ??
          available.where((r) => r.type == AudioRouteType.wired).firstOrNull ??
          AudioRoute(
            c.speakerOn ? AudioRouteType.speaker : AudioRouteType.earpiece,
          );
      c.speakerOn = route.type == AudioRouteType.speaker;
      c.update();
    }
    await CallAudioRouter.select(route);
  }

  /// Keeps [CallController.audioRoutes] in step with the device while the
  /// call is on — headsets come and go, and the system can move the audio
  /// itself (AirPods connecting mid-call take it over, like on any call).
  void _watchAudioRoutes(CallController c) {
    _routeTimer?.cancel();
    _routeTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isLive(c) || c.room == null) return;
      final routes = await CallAudioRouter.fetch();
      if (routes == null || !_isLive(c)) return;
      if (DateTime.now().isBefore(_routeSettleAt)) return;
      final before = c.audioRoutes;
      final chosen = c.chosenRoute;
      if (chosen != null) {
        final stillThere = routes.available.any(chosen.sameAs);
        // A headset that just connected takes the audio over; the pick made
        // before it no longer says where audio should go.
        final newHeadset = routes.available.any((r) =>
            r.type == AudioRouteType.bluetooth &&
            !(before?.available.any(r.sameAs) ?? true));
        if (!stillThere || newHeadset) c.chosenRoute = null;
      }
      final current = routes.current;
      final speakerOn =
          current == null ? c.speakerOn : current.type == AudioRouteType.speaker;
      if (routes == before && speakerOn == c.speakerOn) return;
      c.audioRoutes = routes;
      c.speakerOn = speakerOn;
      c.update();
    });
  }

  /// Native side of screen sharing. Android: the foreground service that
  /// Android 10+ requires while the screen is captured (`CallScreenShare.kt`).
  /// iOS: the system broadcast picker and the ScreenShare extension's
  /// start/stop signals (`AppDelegate.registerScreenShareChannel`).
  static const _screenShareChannel = MethodChannel('call_screen_share');
  bool _screenShareChannelReady = false;

  static bool get screenShareSupported => Platform.isAndroid || Platform.isIOS;

  /// Starts or stops showing our screen to everyone on the call, WhatsApp
  /// style: the system asks the user first, and while it is on there is a
  /// way out from outside the app too — a notification with "Stop sharing"
  /// on Android, the red status-bar pill on iOS.
  Future<void> toggleScreenShare() async {
    final c = _current;
    final lp = c?.room?.localParticipant;
    if (c == null || lp == null || !screenShareSupported) return;
    if (c.screenSharing) return _stopScreenShare(c);

    _listenForScreenShareStop();
    if (Platform.isIOS) {
      // Sharing starts when the extension says the broadcast has —
      // see [_startIOSScreenShare]. Cancelling the sheet leaves nothing to
      // undo.
      try {
        await _screenShareChannel.invokeMethod('showPicker');
      } catch (e) {
        print('screen share picker failed: $e');
        _toast('Could not share your screen');
      }
      return;
    }
    try {
      // The system "start recording or casting?" prompt.
      if (!await Helper.requestCapturePermission()) return;
      if (!_isLive(c)) return;
      await _screenShareChannel.invokeMethod('start');
      if (!_isLive(c)) {
        _screenShareChannel.invokeMethod('stop').ignore();
        return;
      }
      await lp.setScreenShareEnabled(true);
      c.screenSharing = true;
      c.update();
    } catch (e) {
      print('screen share failed: $e');
      _screenShareChannel.invokeMethod('stop').ignore();
      _toast('Could not share your screen');
    }
  }

  /// iOS: the user tapped Start Broadcast and the extension is up. Our
  /// screen track opens the socket the extension is waiting to send to.
  Future<void> _startIOSScreenShare() async {
    final c = _current;
    final lp = c?.room?.localParticipant;
    if (c == null || lp == null || !_isLive(c) || c.screenSharing) {
      // Not on a call (any more): the broadcast has nowhere to go.
      _screenShareChannel.invokeMethod('stop').ignore();
      return;
    }
    try {
      final track = await LocalVideoTrack.createScreenShareTrack(
        const _IOSBroadcastCaptureOptions(),
      );
      if (!_isLive(c)) {
        await track.stop();
        _screenShareChannel.invokeMethod('stop').ignore();
        return;
      }
      await lp.publishVideoTrack(track);
      c.screenSharing = true;
      c.update();
    } catch (e) {
      print('screen share failed: $e');
      _screenShareChannel.invokeMethod('stop').ignore();
      _toast('Could not share your screen');
    }
  }

  Future<void> _stopScreenShare(CallController c) async {
    c.screenSharing = false;
    c.update();
    try {
      await c.room?.localParticipant?.setScreenShareEnabled(false);
    } catch (e) {
      print('screen share stop failed: $e');
    }
    _screenShareChannel.invokeMethod('stop').ignore();
  }

  /// Sharing stopped from outside the app — Android's notification action,
  /// iOS's status bar — and, on iOS, the broadcast starting.
  void _listenForScreenShareStop() {
    if (_screenShareChannelReady) return;
    _screenShareChannelReady = true;
    _screenShareChannel.setMethodCallHandler((call) async {
      final c = _current;
      switch (call.method) {
        case 'broadcastStarted':
          await _startIOSScreenShare();
        case 'stopRequested':
          if (c != null && c.screenSharing) await _stopScreenShare(c);
      }
    });
  }

  Future<void> switchCamera() async {
    final c = _current;
    final pub = c?.room?.localParticipant
        ?.getTrackPublicationBySource(TrackSource.camera);
    final track = pub?.track;
    if (c == null || track is! LocalVideoTrack) return;
    c.cameraPosition = c.cameraPosition == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    c.update();
    await track.setCameraPosition(c.cameraPosition);
  }

  /// How long a person added to the call shows as "Ringing…" — the same ring
  /// window every other ring gets.
  static const _inviteTimeout = Duration(seconds: 45);

  /// Rings [userUuid] into the call we are on, WhatsApp's "Add participant".
  /// Works on a 1:1 call too, which becomes a group call from here on — the
  /// invitee joins only the call, never the chat behind it.
  Future<void> addParticipant({
    required String userUuid,
    required int appType,
    required String name,
    String? avatarUrl,
  }) async {
    final c = _current;
    final id = c?.callId;
    if (c == null || id == null || !_isLive(c) ||
        c.phase != CallPhase.connected) {
      return;
    }
    final invitee = CallInvitee(
      userUuid: userUuid,
      appType: appType,
      name: name,
      avatarUrl: avatarUrl,
    );
    if (c.identitiesOnCall.contains(invitee.identity)) {
      _toast('$name is already on the call');
      return;
    }
    // Shown as ringing straight away; taken back if the server refuses.
    final wasGroup = c.isGroupCall;
    c.invited[invitee.identity] = invitee;
    c.isGroupCall = true;
    c.update();
    try {
      await CallApiService.invite(
        id,
        inviteeUserId: userUuid,
        inviteeAppType: appType,
      );
    } on CallApiException catch (e) {
      if (!_isLive(c)) return;
      c.invited.remove(invitee.identity);
      c.isGroupCall = wasGroup || c.remoteParticipants.length > 1;
      c.update();
      _toast(switch (e.statusCode) {
        409 => '$name is already on the call',
        403 => 'Only people on the call can add someone',
        _ => e.isOver ? 'This call has already ended' : 'Could not add $name',
      });
      return;
    }
    if (!_isLive(c)) return;
    invitee.expiry = Timer(_inviteTimeout, () {
      if (identical(c.invited[invitee.identity], invitee)) {
        c.invited.remove(invitee.identity);
        c.update();
        _endIfAlone(c);
      }
    });
    _toast('Ringing $name…');
  }

  /// A 1:1 call that people were added to is over once everyone else has
  /// left and nobody is still ringing in — there is no group to stay in. A
  /// call that began in a group chat keeps the existing behaviour.
  void _endIfAlone(CallController c) {
    if (c.startedAsGroup ||
        !c.isGroupCall ||
        !_isLive(c) ||
        c.phase != CallPhase.connected) {
      return;
    }
    if (c.remoteParticipants.isNotEmpty || c.invited.isNotEmpty) return;
    _hangUp(c, reason: 'hangup', message: 'Call ended');
  }

  /// [CallController.invited] minus whoever has since joined the room, or
  /// turned down / missed the ring according to the server.
  void _settleInvites(CallController c, [List<CallParticipantInfo>? snapshot]) {
    if (c.invited.isEmpty) return;
    final inRoom = c.remoteParticipants.map((p) => p.identity).toSet();
    final settled = {
      for (final p in snapshot ?? const <CallParticipantInfo>[])
        if (p.status != 'ringing') p.identity,
    };
    c.invited.removeWhere((identity, invitee) {
      final done = inRoom.contains(identity) || settled.contains(identity);
      if (done) invitee.expiry?.cancel();
      return done;
    });
  }

  // ─── Pushes ──────────────────────────────────────────────────────────────

  /// A call push that arrived while the app was in the foreground.
  Future<void> handleForegroundPush(RemoteMessage message) async {
    final type = message.data['msg_type']?.toString();
    final details = _details(message.data);
    var callId = details['callId']?.toString() ?? '';
    // Pushes aimed at the caller's own call are applied to it even if a
    // payload ever turns up without the id.
    if (callId.isEmpty &&
        (type == CallPushType.ringing || type == CallPushType.noAnswer)) {
      callId = _current?.callId ?? '';
    }
    if (callId.isEmpty) return;
    print('call push $type for $callId');

    if (type == CallPushType.incoming) {
      final push = IncomingCallPush.fromMap(details);
      if (push == null) return;
      // iOS rings through CallKit in every app state: the server's VoIP push
      // is reported there natively, and both land on the same CallKit entry
      // (keyed by callId), so ringing in-app as well would double up.
      if (Platform.isIOS) {
        if (isBusy && _current!.callId != callId) {
          unawaited(
            CallApiService.decline(callId)
                .catchError((e) => print('busy decline: $e')),
          );
          return;
        }
        await CallKitService.showIncoming(push);
        return;
      }
      return _offerIncoming(push);
    }

    // A ring still showing in the system UI rather than in-app stops once the
    // call is answered elsewhere (1:1), declined, or over.
    final systemRingOver = switch (type) {
      CallPushType.answered => details['isGroupCall']?.toString() != 'true',
      CallPushType.declined ||
      CallPushType.ended ||
      CallPushType.noAnswer => true,
      _ => false,
    };
    final c = _current;
    // The callee can confirm its ring before our own `start` has even
    // returned the callId.
    final ownPendingCall = c != null &&
        c.callId == null &&
        c.isOutgoing &&
        type == CallPushType.ringing;
    if (c == null || (c.callId != callId && !ownPendingCall)) {
      if (systemRingOver) unawaited(CallKitService.dismiss(callId));
      return;
    }
    switch (type) {
      case CallPushType.answered:
        // For a 1:1 callee still ringing, someone answering means it was
        // picked up on another of our devices.
        if (c.phase == CallPhase.incoming && !c.isGroupCall) {
          _finish(c, 'Answered on another device');
        } else if (c.phase == CallPhase.connected) {
          // Someone added to the call picked up.
          if (details['isGroupCall']?.toString() == 'true') {
            c.isGroupCall = true;
          }
          unawaited(_refreshNames(c));
        }
      case CallPushType.declined:
        _finish(c, 'Call declined');
      case CallPushType.ended:
        _finish(c, 'Call ended');
      case CallPushType.noAnswer:
        // The server has already ended the call — nothing to send back.
        _finish(c, c.isOutgoing ? _noAnswerText(c) : 'Missed call');
      case CallPushType.ringing:
        _markRemoteRinging(c);
      case CallPushType.participantLeft:
        unawaited(_refreshNames(c));
    }
  }

  /// The user tapped the incoming-call notification while the app was in
  /// the background or closed. The ring may be long over by now, so the call
  /// is looked up before anything is shown.
  Future<void> handleNotificationTap(RemoteMessage message) async {
    if (message.data['msg_type']?.toString() != CallPushType.incoming) return;
    final details = _details(message.data);
    final callId = details['callId']?.toString() ?? '';
    if (callId.isEmpty || isBusy) return;

    try {
      final snap = await CallApiService.status(callId);
      final me = await _myIdentity();
      final mine = snap.participants
          .where((p) => p.identity == me)
          .firstOrNull;
      final stillForMe =
          snap.call.isLive && (mine == null || mine.status == 'ringing' ||
              (snap.call.isGroupCall && mine.status != 'joined'));
      if (!stillForMe) {
        _toast('Missed call from ${snap.call.callerName}');
        return;
      }
      final push = IncomingCallPush.fromMap({
        ...details,
        'callType': snap.call.media.wire,
        'isGroupCall': snap.call.isGroupCall,
        'callerName': snap.call.callerName,
        'chatId': snap.call.chatId,
      });
      if (push != null) await _offerIncoming(push);
    } catch (e) {
      print('call tap lookup failed: $e');
    }
  }

  /// Rings in-app — Android with the app in the foreground. Background and
  /// killed states ring through [CallKitService] instead.
  Future<void> _offerIncoming(IncomingCallPush push) async {
    final callId = push.callId;
    if (isBusy) {
      if (_current!.callId == callId) return;
      // Already on another call: treat it as busy rather than ringing over
      // the top of the conversation.
      unawaited(
        CallApiService.decline(callId).catchError((e) => print('busy decline: $e')),
      );
      return;
    }

    final c = CallController(
      callId: callId,
      chatId: push.chatId,
      title: push.displayTitle,
      avatarUrl: push.callerImageUrl,
      media: push.media,
      isGroupCall: push.isGroupCall,
      isOutgoing: false,
      phase: CallPhase.incoming,
    );
    _open(c);
    _startRinging();
    // Our ring is on screen — the caller's UI can say "Ringing…" now.
    unawaited(CallApiService.confirmRinging(callId));
    _startPolling(c);
    _timeoutTimer = Timer(_incomingTimeout, () {
      if (_isLive(c) && c.phase == CallPhase.incoming) {
        _finish(c, 'Missed call');
      }
    });
  }

  // ─── Internals ───────────────────────────────────────────────────────────

  /// [answeringRing] is true when this answers a ring rather than joining a
  /// call already in progress: if the call can't be taken, the caller is
  /// told so rather than left ringing until the timeout.
  Future<void> _acceptInto(CallController c, {bool answeringRing = true}) async {
    if (!await _ensurePermissions(c.media)) {
      final id = c.callId;
      _finish(c, 'Microphone${c.isVideo ? ' and camera' : ''} permission is required');
      if (answeringRing && id != null) {
        unawaited(
          CallApiService.decline(id).catchError((e) => print('call decline failed: $e')),
        );
      }
      return;
    }
    // Answered from the system ring, the call already has its ongoing-call
    // notification.
    if (!c.viaSystem) {
      await CallKitService.showOngoing(
        callId: c.callId!,
        title: c.title,
        media: c.media,
      );
      if (!_isLive(c)) {
        unawaited(CallKitService.release(c.callId!));
        return;
      }
    }
    try {
      final info = await CallApiService.join(c.callId!);
      if (!_isLive(c)) {
        // Hung up while the join was in flight — the server now counts us as
        // joined, and the end sent at hang-up may have landed before it.
        unawaited(_safeEnd(info.callId, 'cancelled'));
        return;
      }
      await _connect(c, info);
    } on CallApiException catch (e) {
      _finish(c, _describe(e));
    }
  }

  Future<void> _connect(CallController c, CallJoinInfo info) async {
    unawaited(CallKitService.armTerminateHangUp(info.callId));
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
          params: VideoParametersPresets.h720_169,
        ),
      ),
    );
    c.room = room;
    room.addListener(c.update);
    // LiveKit prefers the loudspeaker on iOS by default, and while it does,
    // setSpeakerphoneOn is a no-op — the speaker button could never switch
    // to the earpiece. Routing is driven by [CallController.speakerOn].
    if (Platform.isIOS) {
      await Hardware.instance.setPreferSpeakerOutput(false);
    }
    final listener = room.createListener();
    _roomListener = listener;
    listener
      ..on<ParticipantConnectedEvent>((_) {
        if (c.phase == CallPhase.outgoing) {
          _stopRingback();
          c.phase = CallPhase.connected;
          c.connectedAt = DateTime.now();
          _timeoutTimer?.cancel();
          _pollTimer?.cancel();
        }
        // A third person in the room: someone was added to what began as a
        // 1:1 call — by us or by the other side — so it is a group call now.
        if (room.remoteParticipants.length > 1) c.isGroupCall = true;
        _settleInvites(c);
        c.update();
        unawaited(_refreshNames(c));
      })
      ..on<TrackSubscribedEvent>((e) {
        if (e.track is RemoteAudioTrack) unawaited(_applySpeaker(c));
      })
      ..on<ParticipantDisconnectedEvent>((_) {
        // A 1:1 call is over the moment the other side leaves; a group call
        // carries on for whoever is left.
        if (!c.isGroupCall && c.phase == CallPhase.connected) {
          _hangUp(c, reason: 'hangup', message: 'Call ended');
        } else {
          c.update();
          _endIfAlone(c);
        }
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((e) {
        if (c.isGroupCall || e.participant is! RemoteParticipant) return;
        if (e.connectionQuality != ConnectionQuality.lost) {
          _lostTimer?.cancel();
          _lostTimer = null;
          return;
        }
        _lostTimer ??= Timer(_lostTimeout, () {
          _lostTimer = null;
          if (_isLive(c) && c.phase == CallPhase.connected) {
            print('call: other side unreachable, ending');
            _hangUp(c, reason: 'disconnected', message: 'Call ended');
          }
        });
      })
      ..on<RoomDisconnectedEvent>((e) {
        // Our own hang-up disconnects too, by which point we are ended.
        if (_isLive(c)) {
          print('call room disconnected: ${e.reason}');
          _hangUp(c, reason: 'disconnected', message: 'Call ended');
        }
      })
      ..listen((_) => c.update());

    try {
      await room.connect(info.livekitUrl, info.token);
      if (!_isLive(c)) return;
      await room.localParticipant?.setMicrophoneEnabled(c.micEnabled);
      if (c.isVideo) {
        await room.localParticipant?.setCameraEnabled(true);
      }
      await _applySpeaker(c);
      _watchAudioRoutes(c);
      // Joining a call someone is already in: no ParticipantConnectedEvent
      // fires for them, so the call counts as connected straight away.
      if (c.phase == CallPhase.connecting ||
          (c.phase == CallPhase.outgoing &&
              room.remoteParticipants.isNotEmpty)) {
        _stopRingback();
        c.phase = CallPhase.connected;
        c.connectedAt = DateTime.now();
      }
      // Starts the timer on the system entry: the system ring's, or on
      // Android the ongoing-call notification [CallKitService.showOngoing]
      // raised. A no-op when there is none.
      unawaited(CallKitService.markConnected(info.callId));
      c.update();
      unawaited(_refreshNames(c));
    } catch (e) {
      print('call connect failed: $e');
      await _hangUp(c, reason: 'connect_failed', message: 'Could not connect the call');
    }
  }

  Future<void> _hangUp(
    CallController c, {
    required String reason,
    String message = 'Call ended',
  }) async {
    final id = c.callId;
    _finish(c, message);
    if (id != null) await _safeEnd(id, reason);
  }

  Future<void> _safeEnd(String callId, String reason) async {
    try {
      await CallApiService.end(callId, reason: reason);
    } catch (e) {
      print('call end failed: $e');
    }
  }

  /// Tears the call down locally and closes the screen shortly after, so the
  /// user sees why it ended. Safe to call more than once.
  void _finish(CallController c, String reason) {
    if (c.phase == CallPhase.ended) return;
    c.phase = CallPhase.ended;
    c.endReason = reason;
    c.update();

    _screenWatchdog?.cancel();
    _stopRinging();
    _stopRingback();
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    _lostTimer?.cancel();
    _lostTimer = null;
    _routeTimer?.cancel();
    _routeTimer = null;
    for (final invitee in c.invited.values) {
      invitee.expiry?.cancel();
    }
    c.invited.clear();
    if (c.screenSharing) {
      c.screenSharing = false;
      _screenShareChannel.invokeMethod('stop').ignore();
    }
    final callId = c.callId;
    if (callId != null) unawaited(CallKitService.release(callId));
    unawaited(CallKitService.disarmTerminateHangUp());

    final listener = _roomListener;
    final room = c.room;
    _roomListener = null;
    c.room = null;
    unawaited(() async {
      await listener?.dispose();
      room?.removeListener(c.update);
      await room?.disconnect();
      await room?.dispose();
      // A new call may have started while this one was tearing down — its
      // speaker setting is not ours to reset.
      if (_current == null || identical(_current, c)) {
        Hardware.instance.setSpeakerphoneOn(false).ignore();
      }
    }());

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (identical(_current, c)) {
        _current = null;
        screenShown.value = false;
        unawaited(CallKitService.setKeepAlive(false));
      }
      final route = c._route;
      c._route = null;
      if (route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
    });
  }

  void _open(CallController c) {
    _current = c;
    unawaited(CallKitService.setKeepAlive(true));
    _showScreen(c);
    // A call answered from the system UI starts the app: for a moment there
    // is no navigator to push onto, and the routing that follows the splash
    // screen throws away whatever was pushed before it ran. Both are covered
    // by putting the screen back until it sticks.
    _screenWatchdog?.cancel();
    var tries = 0;
    _screenWatchdog = Timer.periodic(const Duration(milliseconds: 250), (t) {
      final stale = !identical(_current, c) || c.phase == CallPhase.ended;
      if (stale || ++tries > 24) return t.cancel();
      if (c._route?.isActive == true) return;
      _showScreen(c);
    });
  }

  void _showScreen(CallController c) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: CallScreen.routeName),
      fullscreenDialog: true,
      builder: (_) => CallScreen(controller: c),
    );
    c._route = route;
    screenShown.value = true;
    navigator.push(route).whenComplete(() {
      if (!identical(c._route, route)) return;
      c._route = null;
      if (identical(_current, c)) screenShown.value = false;
    });
  }

  /// Brings the call's screen back — from the "return to call" bar, or when
  /// rejoining the call we are already in.
  void showScreen() {
    final c = _current;
    if (c == null || c.phase == CallPhase.ended) return;
    if (c._route?.isActive == true) {
      final nav = navigatorKey.currentState;
      nav?.popUntil((r) => r.settings.name == CallScreen.routeName || r.isFirst);
      return;
    }
    _showScreen(c);
  }

  /// The user backed out of [CallScreen] to use the rest of the app while the
  /// call carries on. The startup watchdog must not push it straight back.
  void screenMinimized(CallController c) {
    if (!identical(_current, c)) return;
    _screenWatchdog?.cancel();
    c._route = null;
    screenShown.value = false;
  }

  /// Still the call on this device, and not yet hung up.
  bool _isLive(CallController c) =>
      identical(_current, c) && c.phase != CallPhase.ended;

  /// A callee confirmed its ring (msg_type 26): the caller's screen switches
  /// to "Ringing…" and the ringback tone starts. It carries on through to the
  /// answer, and stops the moment somebody picks up.
  void _markRemoteRinging(CallController c) {
    if (!c.isOutgoing || c.phase != CallPhase.outgoing || c.remoteRinging) {
      return;
    }
    c.remoteRinging = true;
    c.update();
    unawaited(_startRingback());
  }

  /// Why an outgoing call nobody answered is over: it rang and was ignored,
  /// or it never reached a device at all.
  static String _noAnswerText(CallController c) =>
      c.remoteRinging ? 'No answer' : 'Unreachable';

  /// Backstop for missed pushes while a call is ringing on either side.
  void _startPolling(CallController c) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final id = c.callId;
      if (!_isLive(c) || id == null) return;
      if (c.phase != CallPhase.incoming && c.phase != CallPhase.outgoing) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final snap = await CallApiService.status(id);
        if (!_isLive(c)) return;
        if (snap.call.status == 'declined') {
          return _finish(c, 'Call declined');
        }
        if (!snap.call.isLive) {
          // Still outgoing means nobody ever joined: the server rang it out.
          return _finish(
            c,
            c.phase == CallPhase.outgoing ? _noAnswerText(c) : 'Call ended',
          );
        }
        if (c.phase == CallPhase.incoming) {
          final me = await _myIdentity();
          final mine =
              snap.participants.where((p) => p.identity == me).firstOrNull;
          if (mine != null && mine.status != 'ringing') {
            _finish(c, 'Call ended');
          }
        }
      } on CallApiException catch (e) {
        if (e.statusCode == 404 || e.isOver) _finish(c, 'Call ended');
      }
    });
  }

  Future<void> _refreshNames(CallController c) async {
    final id = c.callId;
    if (id == null) return;
    try {
      final snap = await CallApiService.status(id);
      for (final p in snap.participants) {
        final name = p.name.isNotEmpty ? p.name : p.firstName;
        if (name.isNotEmpty) c.names[p.identity] = name;
      }
      // The other side of our 1:1 call may have added someone.
      if (snap.call.isGroupCall) c.isGroupCall = true;
      _settleInvites(c, snap.participants);
      if (_isLive(c)) c.update();
      // The last person we added turned the ring down.
      _endIfAlone(c);
      if (c.isGroupCall) await _refreshAvatars(c, snap.participants);
    } catch (_) {}
  }

  /// Profile photos for the group call's tiles. Each participant is looked
  /// up once; a failed lookup is retried on the next refresh.
  Future<void> _refreshAvatars(
    CallController c,
    List<CallParticipantInfo> participants,
  ) async {
    final me = await _myIdentity();
    final lookups = <Future<void>>[
      for (final p in participants)
        if (p.userUuid.isNotEmpty && !c.avatars.containsKey(p.identity))
          FirebaseApiService.fetchUserProfile(userUuid: p.userUuid).then((
            profile,
          ) {
            if (profile == null) return;
            final url = profile['profileImageUrl']?.toString() ?? '';
            c.avatars[p.identity] = url;
            if (p.identity == me && url.isNotEmpty) c.myAvatarUrl = url;
          }),
      if (c.myAvatarUrl == null &&
          !c.avatars.containsKey(me) &&
          !participants.any((p) => p.identity == me))
        FirebaseApiService.fetchUserProfile().then((profile) {
          if (profile == null) return;
          final url = profile['profileImageUrl']?.toString() ?? '';
          c.avatars[me] = url;
          if (url.isNotEmpty) c.myAvatarUrl = url;
        }),
    ];
    if (lookups.isEmpty) return;
    await Future.wait(lookups);
    if (_isLive(c)) c.update();
  }

  Future<bool> _ensurePermissions(CallMedia media) async {
    final perms = [
      Permission.microphone,
      if (media == CallMedia.video) Permission.camera,
    ];
    final results = await perms.request();
    // Android 12+: without it WebRTC can't see a Bluetooth headset and routes
    // the call past AirPods & co. Not required to make the call.
    if (Platform.isAndroid) await Permission.bluetoothConnect.request();
    return results.values.every((s) => s.isGranted || s.isLimited);
  }

  /// Android rings through `CallRingtone.kt`: flutter_ringtone_player reads
  /// the stored ringtone setting, which on Xiaomi can still be the factory
  /// tone after the user picked another one per SIM.
  static const _ringtoneChannel = MethodChannel('call_ringtone');

  void _startRinging() {
    if (_ringing) return;
    _ringing = true;
    if (!Platform.isAndroid) {
      FlutterRingtonePlayer().playRingtone(looping: true).ignore();
      return;
    }
    unawaited(() async {
      try {
        await _ringtoneChannel.invokeMethod('play');
      } catch (e) {
        print('call ringtone failed, using the plugin: $e');
        if (_ringing) {
          FlutterRingtonePlayer().playRingtone(looping: true).ignore();
        }
      }
    }());
  }

  void _stopRinging() {
    if (!_ringing) return;
    _ringing = false;
    if (Platform.isAndroid) {
      _ringtoneChannel.invokeMethod('stop').ignore();
    }
    FlutterRingtonePlayer().stop().ignore();
  }

  /// The tone the caller hears while the other side rings — 440+480 Hz, two
  /// seconds on and four off, the cadence a phone line uses. Played from the
  /// app rather than left to the system: neither LiveKit nor the ring push
  /// makes any sound on this side, so without it placing a call is silent.
  ///
  /// It has to keep going until the call is answered or dropped, which is why
  /// the asset itself holds a full minute of that cadence rather than one
  /// six-second round: loop mode is asked for as well, but it is not honoured
  /// on every platform, and a tone that rings once and goes quiet sounds like
  /// the call failed. A minute outlasts [_outgoingTimeout]; [_ringbackWatch]
  /// restarts or resumes it in the case it stops anyway.
  ///
  /// The player is told to keep out of the audio session because the call owns
  /// it: on Android WebRTC takes audio focus while the room connects, and
  /// just_audio's default is to pause whatever it is playing when focus is
  /// lost. iOS is the other way round: there the session has to be activated
  /// or the tone plays silently, so only interruption handling is turned off.
  ///
  /// Android also needs the tone on the *voice call* stream
  /// ([AndroidAudioUsage.voiceCommunicationSignalling]) rather than the media
  /// one. The caller is in the LiveKit room from the moment the call is placed,
  /// so the device is already in `MODE_IN_COMMUNICATION` by the second ring —
  /// and in that mode media output is what a phone routes away or drops, which
  /// is why the tone was heard once and no more. On the call stream it follows
  /// the call's own routing (earpiece, or speaker once that is on) and lasts as
  /// long as the ringing does.
  ///
  /// Deliberately not [FlutterRingtonePlayer]: that plays the phone's own
  /// ringtone at ring volume, which is the sound of a call coming *in*.
  Future<void> _startRingback() async {
    if (_ringback != null) return;
    final player = AudioPlayer(
      handleInterruptions: false,
      androidApplyAudioAttributes: false,
      handleAudioSessionActivation: !Platform.isAndroid,
    );
    _ringback = player;
    try {
      if (Platform.isAndroid) {
        await player.setAndroidAudioAttributes(
          const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.voiceCommunicationSignalling,
          ),
        );
      }
      await player.setAsset(_ringbackAsset);
      await player.setLoopMode(LoopMode.one);
      // The call stream carries its own volume setting, so the tone is not
      // held back on Android the way it is against media volume on iOS.
      await player.setVolume(Platform.isAndroid ? 1.0 : 0.5);
      // Answered (or hung up) while the asset was loading.
      if (!identical(_ringback, player)) return;
      // Anything that stops the tone while the call is still ringing — the
      // asset running out, or something pausing the player from underneath —
      // starts it again.
      _ringbackWatch = player.playerStateStream.listen((state) {
        if (state.playing) return;
        if (state.processingState != ProcessingState.ready &&
            state.processingState != ProcessingState.completed) {
          return;
        }
        if (!identical(_ringback, player)) return;
        unawaited(() async {
          try {
            if (state.processingState == ProcessingState.completed) {
              await player.seek(Duration.zero);
            }
            player.play().ignore();
          } catch (e) {
            print('ringback restart failed: $e');
          }
        }());
      });
      player.play().ignore();
    } catch (e) {
      print('ringback failed: $e');
    }
  }

  void _stopRingback() {
    final player = _ringback;
    if (player == null) return;
    _ringback = null;
    final watch = _ringbackWatch;
    _ringbackWatch = null;
    unawaited(() async {
      await watch?.cancel();
      try {
        await player.stop();
      } catch (e) {
        print('ringback stop failed: $e');
      }
      await player.dispose();
    }());
  }

  static const _ringbackAsset = 'assets/sounds/callRingback.wav';

  static Future<String> _myIdentity() async =>
      '${await DeviceId.get()}|${FirebaseApiService.appType}';

  static Map<String, dynamic> _details(Map<String, dynamic> data) {
    final raw = data['Details'];
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    // Fall back to flat keys, the way 1:1 chat pushes are sent.
    return data;
  }

  static String _describe(CallApiException e) {
    if (e.isNotConfigured) return 'Calling is not available yet';
    if (e.isOver) return 'This call has already ended';
    if (e.statusCode == 404) return 'Call not found';
    if (e.statusCode == 403) return 'You are not part of this call';
    return 'Call failed';
  }

  static void _toast(String text) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }
}

/// Screen capture through the ScreenShare broadcast extension. LiveKit's own
/// iOS broadcast option also opens the system picker as the track is
/// created; the `-manual` device id tells flutter_webrtc not to, because the
/// picker has already been shown and the broadcast is already running.
class _IOSBroadcastCaptureOptions extends ScreenShareCaptureOptions {
  const _IOSBroadcastCaptureOptions() : super(useiOSBroadcastExtension: true);

  @override
  Map<String, dynamic> toMediaConstraintsMap() => {
        ...super.toMediaConstraintsMap(),
        'deviceId': 'broadcast-manual',
      };
}
