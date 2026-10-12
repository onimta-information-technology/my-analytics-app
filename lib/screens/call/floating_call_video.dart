import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/data/services/call_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show RTCVideoViewObjectFit;
import 'package:livekit_client/livekit_client.dart';

/// A minimized video call, WhatsApp style: a small video card floating over
/// whatever screen the user moved on to. Drag it anywhere (it snaps to the
/// nearest corner); tap it to go back to [CallScreen].
///
/// Fills the screen so it can place itself, but only the card takes touches —
/// everything around it reaches the app below.
class FloatingCallVideo extends StatefulWidget {
  final CallController controller;
  const FloatingCallVideo({super.key, required this.controller});

  @override
  State<FloatingCallVideo> createState() => _FloatingCallVideoState();
}

class _FloatingCallVideoState extends State<FloatingCallVideo> {
  static const _size = Size(120, 176);
  static const _margin = 12.0;
  // Keeps the card off the app bar and the bottom navigation bar.
  static const _topInset = 56.0;
  static const _bottomInset = 88.0;

  /// Which corner the card rests in.
  bool _right = true;
  bool _bottom = true;

  /// Card's top-left while a finger is on it; null when resting in a corner.
  Offset? _drag;

  Rect _bounds(Size screen, EdgeInsets safe) => Rect.fromLTRB(
    _margin,
    safe.top + _topInset,
    screen.width - _margin - _size.width,
    screen.height - safe.bottom - _bottomInset - _size.height,
  );

  Offset _cornerOffset(Rect b) =>
      Offset(_right ? b.right : b.left, _bottom ? b.bottom : b.top);

  void _onPanEnd(DragEndDetails d, Rect b) {
    final pos = _drag;
    if (pos == null) return;
    // A fling picks the corner it was thrown towards; otherwise the nearest.
    const flingSpeed = 600.0;
    final v = d.velocity.pixelsPerSecond;
    setState(() {
      _right = v.dx.abs() > flingSpeed ? v.dx > 0 : pos.dx > b.center.dx;
      _bottom = v.dy.abs() > flingSpeed ? v.dy > 0 : pos.dy > b.center.dy;
      _drag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final safe = MediaQuery.paddingOf(context);
        final b = _bounds(box.biggest, safe);
        final pos = _drag ?? _cornerOffset(b);
        return Stack(
          children: [
            AnimatedPositioned(
              duration: _drag == null
                  ? const Duration(milliseconds: 250)
                  : Duration.zero,
              curve: Curves.easeOut,
              left: pos.dx,
              top: pos.dy,
              width: _size.width,
              height: _size.height,
              child: GestureDetector(
                onTap: CallManager.instance.showScreen,
                onPanStart: (_) => setState(() => _drag = pos),
                onPanUpdate: (d) => setState(() {
                  final p = (_drag ?? pos) + d.delta;
                  _drag = Offset(
                    p.dx.clamp(b.left, b.right),
                    p.dy.clamp(b.top, b.bottom),
                  );
                }),
                onPanEnd: (d) => _onPanEnd(d, b),
                onPanCancel: () => setState(() => _drag = null),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2C34),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 10),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _content(widget.controller),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The other side's camera (or screen) when there is one, else our own
  /// camera, else their photo.
  Widget _content(CallController c) {
    final remotes = c.remoteParticipants;
    final speaking = remotes.where((p) => p.isSpeaking);
    VideoTrack? track;
    for (final p in [...speaking, ...remotes]) {
      track =
          _remoteTrack(p, TrackSource.camera) ??
          _remoteTrack(p, TrackSource.screenShareVideo);
      if (track != null) break;
    }
    track ??= _localCamera(c);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (track != null)
          VideoTrackRenderer(
            track,
            key: ObjectKey(track),
            fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            renderMode: VideoRenderMode.texture,
          )
        else
          Center(child: _avatar(c)),
        if (!c.micEnabled)
          const Positioned(
            top: 6,
            left: 6,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black54,
              child: Icon(Icons.mic_off, size: 14, color: Colors.white),
            ),
          ),
        // Back to the full call screen, like WhatsApp's expand corner.
        Positioned(
          top: 4,
          right: 4,
          child: Semantics(
            button: true,
            label: 'Expand call',
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: CallManager.instance.showScreen,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.open_in_full,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(CallController c) {
    final url = c.avatarUrl;
    final parts = c.title
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty);
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((s) => s[0].toUpperCase()).join();
    return CircleAvatar(
      radius: 32,
      backgroundColor: ChatColors.primary,
      foregroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static VideoTrack? _remoteTrack(RemoteParticipant p, TrackSource source) {
    final pub = p.getTrackPublicationBySource(source);
    if (pub == null || !pub.subscribed || pub.muted) return null;
    final track = pub.track;
    return track is VideoTrack ? track as VideoTrack : null;
  }

  static VideoTrack? _localCamera(CallController c) {
    if (!c.cameraEnabled) return null;
    final pub = c.room?.localParticipant?.getTrackPublicationBySource(
      TrackSource.camera,
    );
    if (pub == null || pub.muted) return null;
    final track = pub.track;
    return track is VideoTrack ? track as VideoTrack : null;
  }
}
