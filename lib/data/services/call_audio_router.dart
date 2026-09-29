import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:livekit_client/livekit_client.dart' show Hardware;

enum AudioRouteType { earpiece, speaker, bluetooth, wired }

/// One place call audio can play: the phone's earpiece, the loudspeaker, a
/// Bluetooth headset (AirPods and the like — [id] tells several apart) or a
/// wired one.
@immutable
class AudioRoute {
  final AudioRouteType type;
  final String? id;
  final String? name;

  const AudioRoute(this.type, {this.id, this.name});

  static AudioRoute? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final type = AudioRouteType.values
        .where((t) => t.name == raw['type'])
        .firstOrNull;
    if (type == null) return null;
    return AudioRoute(
      type,
      id: raw['id']?.toString(),
      name: raw['name']?.toString(),
    );
  }

  /// Whether this is the same output as [other]. iOS names one Bluetooth
  /// device by different ids as an input and as an output, so a name match
  /// counts too.
  bool sameAs(AudioRoute? other) {
    if (other == null || other.type != type) return false;
    if (type != AudioRouteType.bluetooth && type != AudioRouteType.wired) {
      return true;
    }
    return (id != null && id == other.id) ||
        (name != null && name == other.name);
  }

  String get label => switch (type) {
        AudioRouteType.earpiece => 'Phone',
        AudioRouteType.speaker => 'Speaker',
        AudioRouteType.bluetooth =>
          (name?.isNotEmpty ?? false) ? name! : 'Bluetooth',
        AudioRouteType.wired =>
          (name?.isNotEmpty ?? false) ? name! : 'Headphones',
      };

  @override
  bool operator ==(Object other) =>
      other is AudioRoute &&
      other.type == type &&
      other.id == id &&
      other.name == name;

  @override
  int get hashCode => Object.hash(type, id, name);
}

/// The call's outputs and the one it is playing through.
@immutable
class AudioRoutes {
  final AudioRoute? current;
  final List<AudioRoute> available;

  const AudioRoutes(this.current, this.available);

  static AudioRoutes? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final list = raw['available'];
    return AudioRoutes(
      AudioRoute.fromMap(raw['current']),
      list is List
          ? list.map(AudioRoute.fromMap).whereType<AudioRoute>().toList()
          : const [],
    );
  }

  /// A headset is connected, so there is more to choose from than
  /// speaker on/off — the button opens the picker, like WhatsApp.
  bool get hasHeadset => available.any((r) =>
      r.type == AudioRouteType.bluetooth || r.type == AudioRouteType.wired);

  @override
  bool operator ==(Object other) =>
      other is AudioRoutes &&
      other.current == current &&
      listEquals(other.available, available);

  @override
  int get hashCode => Object.hash(current, Object.hashAll(available));
}

/// Lists and switches the call's audio output.
///
/// Android: every call is a Telecom call, and Telecom owns its route — a
/// switch made through AudioManager (WebRTC's speakerphone toggle) is just
/// put back — so both go through the callkit plugin's Telecom connection.
/// iOS: AVAudioSession through `AppDelegate`'s `call_audio_route` channel.
class CallAudioRouter {
  const CallAudioRouter._();

  static const _ios = MethodChannel('call_audio_route');

  /// Null when the platform has nothing to report — no Telecom call yet on
  /// Android — in which case the speaker button stays a plain toggle.
  static Future<AudioRoutes?> fetch() async {
    try {
      if (Platform.isAndroid) {
        return AudioRoutes.fromMap(await FlutterCallkitIncoming.getAudioRoutes());
      }
      if (Platform.isIOS) {
        return AudioRoutes.fromMap(await _ios.invokeMethod<Map>('getRoutes'));
      }
    } catch (e) {
      debugPrint('audio routes lookup failed: $e');
    }
    return null;
  }

  static Future<void> select(AudioRoute route) async {
    final speaker = route.type == AudioRouteType.speaker;
    try {
      if (Platform.isAndroid) {
        final handled = await FlutterCallkitIncoming.setAudioRoute(
          route.type.name,
          id: route.id,
        );
        // No Telecom call to route — WebRTC's own switch is all there is.
        if (!handled) await Hardware.instance.setSpeakerphoneOn(speaker);
        return;
      }
      // LiveKit re-applies its remembered speaker setting whenever the
      // tracks change, so it has to agree with the route picked here.
      await Hardware.instance.setSpeakerphoneOn(speaker);
      if (Platform.isIOS) {
        await _ios.invokeMethod('setRoute', {
          'type': route.type.name,
          'id': route.id,
        });
      }
    } catch (e) {
      debugPrint('audio route switch failed: $e');
    }
  }
}
