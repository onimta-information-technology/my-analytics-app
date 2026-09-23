import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart'
    show AndroidAudioAttributes, AndroidAudioContentType, AndroidAudioUsage;
import 'package:ballys_reservation_app/data/services/call_api_service.dart';
import 'package:ballys_reservation_app/data/services/call_kit_service.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/main.dart' show navigatorKey;
import 'package:ballys_reservation_app/models/call_session.dart';
import 'package:ballys_reservation_app/screens/call/call_screen.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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
  final bool isGroupCall;
  final bool isOutgoing;

  /// Answered from the OS call UI (CallKit / Android's full-screen ring),
  /// which then holds a system call entry that has to be released with it.
  final bool viaSystem;

  CallPhase phase;
  String? endReason;
  DateTime? connectedAt;

  Room? room;
  bool micEnabled = true;
  late bool cameraEnabled = media == CallMedia.video;
  late bool speakerOn = media == CallMedia.video;
  CameraPosition cameraPosition = CameraPosition.front;

  /// LiveKit identity (`<userUuid>|<appType>`) → display name, from the
  /// server's participant list. Covers anyone whose token carried no name.
  final Map<String, String> names = {};

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
  });

  bool get isVideo => media == CallMedia.video;

  List<RemoteParticipant> get remoteParticipants =>
      room?.remoteParticipants.values.toList() ?? const [];

  String nameOf(Participant p) {
    if (p.name.isNotEmpty) return p.name;
    return names[p.identity] ?? (isGroupCall ? 'Participant' : title);
  }

  /// The screen showing this call, removed once it has ended.
  Route<void>? _route;

  void update() => notifyListeners();
}

/// Owns the device's single active call. Every entry point — the chat
/// screen's call buttons, the "ongoing call" banner, call pushes and taps on
/// them — goes through here, so there is never more than one room open.
class CallManager {
  CallManager._();
  static final CallManager instance = CallManager._();

  /// How long an unanswered outgoing call rings before we give up.
  static const _outgoingTimeout = Duration(seconds: 45);

  /// How long an incoming call is offered before the screen closes itself.
  static const _incomingTimeout = Duration(seconds: 60);

  /// The call on this device, if any — including one showing its closing
  /// message. Screens listen to it to hide or refresh an "ongoing call"
  /// banner as calls come and go.
  final ValueNotifier<CallController?> active = ValueNotifier(null);

  CallController? get _current => active.value;
  set _current(CallController? c) => active.value = c;
  EventsListener<RoomEvent>? _roomListener;
  Timer? _pollTimer;
  Timer? _timeoutTimer;
  bool _ringing = false;

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
    // It is really ringing on the other side now, so the caller hears the
    // tone. It carries on through the LiveKit connect below, and stops the
    // moment somebody picks up.
    unawaited(_startRingback());
    await _connect(c, info);
    if (c.phase == CallPhase.outgoing) {
      _startPolling(c);
      _timeoutTimer = Timer(_outgoingTimeout, () {
        if (_isLive(c) && c.phase == CallPhase.outgoing) {
          _hangUp(c, reason: 'no_answer', message: 'No answer');
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
      if (_current!.callId == call.callId) return _bringToFront();
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
    await _acceptInto(c);
  }

  /// The user tapped Accept on the system incoming-call UI. The app may have
  /// been launched just for this, so the call is opened straight into
  /// connecting — there is nothing left to ring.
  Future<void> acceptFromSystem(IncomingCallPush push) async {
    final current = _current;
    if (current != null && current.callId == push.callId) {
      if (current.phase == CallPhase.incoming) return accept();
      if (current.phase != CallPhase.ended) return _bringToFront();
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
    await _hangUp(c, reason: 'hangup');
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
    await lp.setMicrophoneEnabled(c.micEnabled);
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
    await lp.setCameraEnabled(c.cameraEnabled);
  }

  Future<void> toggleSpeaker() async {
    final c = _current;
    if (c == null) return;
    c.speakerOn = !c.speakerOn;
    c.update();
    await Hardware.instance.setSpeakerphoneOn(c.speakerOn);
  }

  Future<void> switchCamera() async {
    final c = _current;
    final pub = c?.room?.localParticipant?.videoTrackPublications.firstOrNull;
    final track = pub?.track;
    if (c == null || track == null) return;
    c.cameraPosition = c.cameraPosition == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    c.update();
    await track.setCameraPosition(c.cameraPosition);
  }

  // ─── Pushes ──────────────────────────────────────────────────────────────

  /// A call push that arrived while the app was in the foreground.
  Future<void> handleForegroundPush(RemoteMessage message) async {
    final type = message.data['msg_type']?.toString();
    final details = _details(message.data);
    final callId = details['callId']?.toString() ?? '';
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
        return CallKitService.showIncoming(push);
      }
      return _offerIncoming(push);
    }

    // A ring still showing in the system UI rather than in-app stops once the
    // call is answered elsewhere (1:1), declined, or over.
    final systemRingOver = switch (type) {
      CallPushType.answered => details['isGroupCall']?.toString() != 'true',
      CallPushType.declined || CallPushType.ended => true,
      _ => false,
    };
    final c = _current;
    if (c == null || c.callId != callId) {
      if (systemRingOver) unawaited(CallKitService.dismiss(callId));
      return;
    }
    switch (type) {
      case CallPushType.answered:
        // For a 1:1 callee still ringing, someone answering means it was
        // picked up on another of our devices.
        if (c.phase == CallPhase.incoming && !c.isGroupCall) {
          _finish(c, 'Answered on another device');
        }
      case CallPushType.declined:
        _finish(c, 'Call declined');
      case CallPushType.ended:
        _finish(c, 'Call ended');
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
      media: push.media,
      isGroupCall: push.isGroupCall,
      isOutgoing: false,
      phase: CallPhase.incoming,
    );
    _open(c);
    _startRinging();
    _startPolling(c);
    _timeoutTimer = Timer(_incomingTimeout, () {
      if (_isLive(c) && c.phase == CallPhase.incoming) {
        _finish(c, 'Missed call');
      }
    });
  }

  // ─── Internals ───────────────────────────────────────────────────────────

  Future<void> _acceptInto(CallController c) async {
    if (!await _ensurePermissions(c.media)) {
      return _finish(c, 'Microphone${c.isVideo ? ' and camera' : ''} permission is required');
    }
    try {
      final info = await CallApiService.join(c.callId!);
      if (!_isLive(c)) return;
      await _connect(c, info);
    } on CallApiException catch (e) {
      _finish(c, _describe(e));
    }
  }

  Future<void> _connect(CallController c, CallJoinInfo info) async {
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
        c.update();
        unawaited(_refreshNames(c));
      })
      ..on<ParticipantDisconnectedEvent>((_) {
        // A 1:1 call is over the moment the other side leaves; a group call
        // carries on for whoever is left.
        if (!c.isGroupCall && c.phase == CallPhase.connected) {
          _hangUp(c, reason: 'hangup', message: 'Call ended');
        } else {
          c.update();
        }
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
      await Hardware.instance.setSpeakerphoneOn(c.speakerOn);
      // Joining a call someone is already in: no ParticipantConnectedEvent
      // fires for them, so the call counts as connected straight away.
      if (c.phase == CallPhase.connecting ||
          (c.phase == CallPhase.outgoing &&
              room.remoteParticipants.isNotEmpty)) {
        _stopRingback();
        c.phase = CallPhase.connected;
        c.connectedAt = DateTime.now();
      }
      if (c.viaSystem) unawaited(CallKitService.markConnected(info.callId));
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

    _stopRinging();
    _stopRingback();
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    final callId = c.callId;
    if (c.viaSystem && callId != null) {
      unawaited(CallKitService.release(callId));
    }

    final listener = _roomListener;
    final room = c.room;
    _roomListener = null;
    c.room = null;
    unawaited(() async {
      await listener?.dispose();
      room?.removeListener(c.update);
      await room?.disconnect();
      await room?.dispose();
      Hardware.instance.setSpeakerphoneOn(false).ignore();
    }());

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (identical(_current, c)) _current = null;
      final route = c._route;
      c._route = null;
      if (route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
    });
  }

  void _open(CallController c) {
    _current = c;
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: CallScreen.routeName),
      fullscreenDialog: true,
      builder: (_) => CallScreen(controller: c),
    );
    c._route = route;
    navigatorKey.currentState?.push(route);
  }

  /// Rejoining the call we are already in just surfaces its screen again.
  void _bringToFront() {
    final nav = navigatorKey.currentState;
    nav?.popUntil((r) => r.settings.name == CallScreen.routeName || r.isFirst);
  }

  /// Still the call on this device, and not yet hung up.
  bool _isLive(CallController c) =>
      identical(_current, c) && c.phase != CallPhase.ended;

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
        if (!snap.call.isLive) return _finish(c, 'Call ended');
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
      if (_isLive(c)) c.update();
    } catch (_) {}
  }

  Future<bool> _ensurePermissions(CallMedia media) async {
    final perms = [
      Permission.microphone,
      if (media == CallMedia.video) Permission.camera,
    ];
    final results = await perms.request();
    return results.values.every((s) => s.isGranted || s.isLimited);
  }

  void _startRinging() {
    if (_ringing) return;
    _ringing = true;
    FlutterRingtonePlayer().playRingtone(looping: true).ignore();
  }

  void _stopRinging() {
    if (!_ringing) return;
    _ringing = false;
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
