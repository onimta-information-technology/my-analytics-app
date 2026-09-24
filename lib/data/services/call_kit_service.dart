import 'dart:async';
import 'dart:io';

import 'package:ballys_reservation_app/data/services/call_api_service.dart';
import 'package:ballys_reservation_app/data/services/call_manager.dart';
import 'package:ballys_reservation_app/models/call_session.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// The OS's own incoming-call UI — CallKit on iOS, a full-screen
/// ConnectionService call on Android — driven through
/// `flutter_callkit_incoming`.
///
/// Every call push is silent/data-only now, so nothing rings unless the app
/// raises it. This is what does that whenever the in-app call screen can't:
/// the app is backgrounded or killed, and always on iOS, where the server's
/// VoIP push is already reported to CallKit natively (AppDelegate) and a
/// second in-app ring would double up.
///
/// The system call's id is the server's `callId` (a UUID), so a VoIP push and
/// the FCM push for the same call land on the same CallKit entry instead of
/// ringing twice.
class CallKitService {
  const CallKitService._();

  /// callIds this app ended itself (the caller hung up, someone answered on
  /// another device). Ending an unanswered system call reports a *decline*
  /// on both platforms, and that must not be sent to the server as though
  /// the user had tapped it. Kept in prefs because the dismissal and the
  /// event can land in different isolates.
  static const _dismissedKey = 'callkit_dismissed_ids';

  static const _voipSyncedKey = 'VoipTokenSynced';

  static StreamSubscription<CallEvent?>? _eventSub;

  /// Calls rung through the system UI that this isolate is watching, so the
  /// ring stops when the call ends elsewhere even if that push never comes
  /// (iOS gets no FCM push once killed).
  static final Map<String, Timer> _watchers = {};

  // ─── Ringing ──────────────────────────────────────────────────────────────

  /// Raises the system incoming-call UI. Safe from a background isolate.
  /// Returns null once the system UI is up, or the failure text when the
  /// platform refused to show it — [debugCallPushStep] reports that on the
  /// phone while the Android ringing problem is being tracked down.
  static Future<String?> showIncoming(IncomingCallPush push) async {
    final params = CallKitParams(
      id: systemId(push.callId),
      nameCaller: push.displayTitle,
      appName: 'My Analytics',
      handle: push.displayBody,
      type: push.media == CallMedia.video ? 1 : 0,
      // The server gives up on an unanswered call after 45s (and the push
      // itself expires then), so ringing any longer only rings a dead call.
      duration: 45000,
      extra: push.toMap(),
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
      ),
      callingNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Ongoing call',
        callbackText: 'Hang up',
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#075E54',
        actionColor: '#25D366',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming calls',
        missedCallNotificationChannelName: 'Missed calls',
        isShowCallID: false,
        isShowFullLockedScreen: true,
        textAccept: 'Accept',
        textDecline: 'Decline',
      ),
      ios: IOSParams(
        handleType: 'generic',
        supportsVideo: push.media == CallMedia.video,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        includesCallsInRecents: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );
    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e) {
      debugPrint('callkit show failed: $e');
      return 'showCallkitIncoming failed: $e';
    }
    // It is on screen now — let the caller's UI say "Ringing…".
    await CallApiService.confirmRinging(push.callId);
    return null;
  }

  /// Takes a still-ringing system call down without it counting as the user
  /// declining — the call was answered elsewhere, or is over.
  static Future<void> dismiss(String callId) async {
    _stopWatching(callId);
    final id = await _activeSystemIdFor(callId);
    if (id == null) return;
    await _markDismissed(callId);
    try {
      await FlutterCallkitIncoming.endCall(id);
    } catch (e) {
      debugPrint('callkit dismiss failed: $e');
    }
  }

  /// The accepted call is connected — starts the system call timer.
  static Future<void> markConnected(String callId) async {
    final id = await _activeSystemIdFor(callId);
    if (id == null) return;
    try {
      await FlutterCallkitIncoming.setCallConnected(id);
    } catch (_) {}
  }

  /// Ends the system entry for a call the app has finished with, so iOS drops
  /// its green call bar and Android its ongoing-call notification.
  static Future<void> release(String callId) => dismiss(callId);

  // ─── Main-isolate wiring ──────────────────────────────────────────────────

  /// Hooks the system call UI up to [CallManager]. Call once from `main`.
  static Future<void> init() async {
    _eventSub ??= FlutterCallkitIncoming.onEvent.listen(
      _onEvent,
      onError: (e) => debugPrint('callkit event error: $e'),
    );
    if (Platform.isAndroid) {
      try {
        await FlutterCallkitIncoming.onBackgroundMessage(
          callKitBackgroundHandler,
        );
      } catch (e) {
        debugPrint('callkit background handler registration failed: $e');
      }
    }
  }

  /// A call accepted from the lock screen or while the app was killed can be
  /// answered before this isolate was listening. Picks it up and joins it.
  /// Run once the navigator exists.
  static Future<void> resumeAcceptedCall() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      for (final call in calls) {
        final push = IncomingCallPush.fromMap(call.extra ?? const {});
        if (push == null) continue;
        if (call.isAccepted) {
          // Already on it — this runs on every resume too.
          final current = CallManager.instance.current;
          if (current?.callId == push.callId &&
              current?.phase != CallPhase.ended) {
            return;
          }
          await CallManager.instance.acceptFromSystem(push);
          return;
        }
        // Still ringing: keep an eye on it so it stops with the call. A ring
        // AppDelegate raised from a VoIP push while the app was killed was
        // never confirmed to the caller either, so that happens here.
        _watch(push.callId);
        unawaited(CallApiService.confirmRinging(push.callId));
      }
    } catch (e) {
      debugPrint('callkit resume failed: $e');
    }
  }

  static Future<void> _onEvent(CallEvent? event) async {
    switch (event) {
      case CallEventActionCallIncoming(:final callKitParams):
        final push = IncomingCallPush.fromMap(callKitParams.extra ?? const {});
        if (push == null) return;
        _watch(push.callId);
        await CallApiService.confirmRinging(push.callId);
      case CallEventActionCallAccept(:final callKitParams):
        final push = IncomingCallPush.fromMap(callKitParams.extra ?? const {});
        if (push == null) return;
        _stopWatching(push.callId);
        await CallManager.instance.acceptFromSystem(push);
      case CallEventActionCallDecline(:final callKitParams):
        final callId = _callIdOf(callKitParams);
        if (callId == null) return;
        _stopWatching(callId);
        await _declineUnlessDismissed(callId);
      case CallEventActionCallEnded(:final callKitParams):
        // The user hung up from the system UI (iOS call bar, Android
        // ongoing-call notification) after answering.
        final callId = _callIdOf(callKitParams);
        if (callId == null) return;
        _stopWatching(callId);
        if (await _consumeDismissed(callId)) return;
        await CallManager.instance.hangUpFromSystem(callId);
      case CallEventActionCallTimeout():
        // Rang out unanswered — the watcher for it stops with the next poll,
        // when the call no longer shows up in the system list.
        break;
      case CallEventActionDidUpdateDevicePushTokenVoip():
        await syncVoipToken(force: true);
      default:
        break;
    }
  }

  static void _watch(String callId) {
    if (_watchers.containsKey(callId)) return;
    _watchers[callId] = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final snap = await CallApiService.status(callId);
        final me = '${await DeviceId.get()}|${FirebaseApiService.appType}';
        final mine =
            snap.participants.where((p) => p.identity == me).firstOrNull;
        final stillRingingMe =
            snap.call.isLive && (mine == null || mine.status == 'ringing');
        if (!stillRingingMe) await dismiss(callId);
      } on CallApiException catch (e) {
        if (e.statusCode == 404 || e.isOver) await dismiss(callId);
      } catch (_) {}
    });
  }

  static void _stopWatching(String callId) =>
      _watchers.remove(callId)?.cancel();

  /// Android 14+ gates full-screen intents behind a user setting; without it
  /// a killed-app ring degrades to a heads-up notification. Asked once, after
  /// login, alongside the notification permission.
  static Future<void> requestAndroidPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      if (!await FlutterCallkitIncoming.canUseFullScreenIntent()) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (e) {
      debugPrint('full-screen intent permission request failed: $e');
    }
  }

  // ─── VoIP token (iOS) ─────────────────────────────────────────────────────

  /// Sends the PushKit token to the server when it differs from the one the
  /// server last confirmed. The token only exists once AppDelegate's
  /// PKPushRegistry has handed it to the plugin, so an empty answer just
  /// means the DidUpdateDevicePushTokenVoip event will bring it later.
  static Future<void> syncVoipToken({bool force = false}) async {
    if (!Platform.isIOS) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('is_logged_in') ?? false)) return;
      final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      if (token == null || token.isEmpty) return;
      if (!force && token == prefs.getString(_voipSyncedKey)) return;
      await CallApiService.updateVoipToken(token);
      await prefs.setString(_voipSyncedKey, token);
    } catch (e) {
      debugPrint('VoIP token sync failed: $e');
    }
  }

  /// Logout: stop VoIP pushes to this device. Must run before the auth token
  /// and property url are cleared from prefs.
  static Future<void> clearVoipToken() async {
    if (!Platform.isIOS) return;
    try {
      await CallApiService.removeVoipToken();
    } catch (e) {
      debugPrint('VoIP token removal failed: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_voipSyncedKey);
    } catch (_) {}
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// CallKit needs a UUID. The server's callId is one; anything else maps
  /// onto a stable v5 UUID so the same call always gets the same entry.
  static String systemId(String callId) {
    if (Uuid.isValidUUID(fromString: callId)) return callId;
    return const Uuid().v5(Namespace.url.value, 'call:$callId');
  }

  static String? _callIdOf(CallKitParams params) {
    final fromExtra = params.extra?['callId']?.toString();
    if (fromExtra != null && fromExtra.isNotEmpty) return fromExtra;
    return params.id.isEmpty ? null : params.id;
  }

  /// The system entry currently showing [callId], or null when there is
  /// none. Looked up rather than derived so an entry AppDelegate raised from
  /// a VoIP push is found too.
  static Future<String?> _activeSystemIdFor(String callId) async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      for (final call in calls) {
        if (_callIdOf(call) == callId || call.id == systemId(callId)) {
          return call.id;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _declineUnlessDismissed(String callId) async {
    if (await _consumeDismissed(callId)) return;
    // Declining the call this device is already on means hanging up.
    if (CallManager.instance.current?.callId == callId) {
      await CallManager.instance.hangUpFromSystem(callId);
      return;
    }
    try {
      await CallApiService.decline(callId);
    } catch (e) {
      debugPrint('callkit decline failed: $e');
    }
  }

  static Future<void> _markDismissed(String callId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final ids = prefs.getStringList(_dismissedKey) ?? <String>[];
      if (!ids.contains(callId)) ids.add(callId);
      // Only the latest few matter; the event follows within moments.
      await prefs.setStringList(
        _dismissedKey,
        ids.length > 20 ? ids.sublist(ids.length - 20) : ids,
      );
    } catch (_) {}
  }

  static Future<bool> _consumeDismissed(String callId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final ids = prefs.getStringList(_dismissedKey) ?? <String>[];
      if (!ids.remove(callId)) return false;
      await prefs.setStringList(_dismissedKey, ids);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Android: a system-call event while no Flutter UI is listening — the user
/// declined the full-screen ring while the app was killed. Accept needs no
/// handling here: the plugin launches the app, and
/// [CallKitService.resumeAcceptedCall] joins the call from there.
@pragma('vm:entry-point')
Future<void> callKitBackgroundHandler(CallEvent event) async {
  if (event is CallEventActionCallDecline) {
    final callId = CallKitService._callIdOf(event.callKitParams);
    if (callId == null) return;
    if (await CallKitService._consumeDismissed(callId)) return;
    try {
      await CallApiService.decline(callId);
    } catch (e) {
      debugPrint('callkit background decline failed: $e');
    }
  } else if (event is CallEventActionCallEnded) {
    final callId = CallKitService._callIdOf(event.callKitParams);
    if (callId == null) return;
    if (await CallKitService._consumeDismissed(callId)) return;
    try {
      await CallApiService.end(callId);
    } catch (e) {
      debugPrint('callkit background end failed: $e');
    }
  }
}
