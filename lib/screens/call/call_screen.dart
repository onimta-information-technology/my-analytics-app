import 'dart:async';

import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/data/services/call_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show RTCVideoViewObjectFit;
import 'package:livekit_client/livekit_client.dart';

/// Full-screen UI for the device's one call: ringing (either direction),
/// connecting, in-call and the brief "call ended" state before it closes.
/// Everything it shows comes from [CallController]; every button goes back
/// through [CallManager].
class CallScreen extends StatelessWidget {
  static const routeName = '/call';

  final CallController controller;

  const CallScreen({super.key, required this.controller});

  static const _background = Color(0xFF0B141A);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return PopScope(
          // Leaving the screen would strand the call with no way back to its
          // controls; hanging up is how you leave.
          canPop: c.phase == CallPhase.ended,
          child: Scaffold(
            backgroundColor: _background,
            body: Stack(
              fit: StackFit.expand,
              children: [
                _Stage(controller: c),
                SafeArea(
                  child: Column(
                    children: [
                      if (_showsVideoStage(c)) _TopBar(controller: c),
                      const Spacer(),
                      c.phase == CallPhase.incoming
                          ? const _IncomingActions()
                          : _Controls(controller: c),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Video is drawn once the call is live and somebody actually has a camera
/// on; until then (and for audio calls) the avatar layout is shown.
bool _showsVideoStage(CallController c) {
  if (c.phase != CallPhase.connected && c.phase != CallPhase.outgoing) {
    return false;
  }
  if (!c.isVideo) return false;
  return _localVideo(c) != null ||
      c.remoteParticipants.any((p) => _remoteVideo(p) != null);
}

VideoTrack? _remoteVideo(RemoteParticipant p) => p.videoTrackPublications
    .where((pub) => pub.subscribed && !pub.muted)
    .map((pub) => pub.track)
    .whereType<VideoTrack>()
    .firstOrNull;

VideoTrack? _localVideo(CallController c) {
  if (!c.cameraEnabled) return null;
  final pub = c.room?.localParticipant?.videoTrackPublications.firstOrNull;
  if (pub == null || pub.muted) return null;
  return pub.track;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((s) => s[0].toUpperCase()).join();
}

String _statusText(CallController c) {
  switch (c.phase) {
    case CallPhase.incoming:
      final kind = c.isVideo ? 'video' : 'voice';
      return c.isGroupCall ? 'Incoming group $kind call' : 'Incoming $kind call';
    case CallPhase.outgoing:
      // Only the callee's own confirmation (msg_type 26) earns "Ringing…".
      return c.remoteRinging ? 'Ringing…' : 'Calling…';
    case CallPhase.connecting:
      return 'Connecting…';
    case CallPhase.connected:
      return '';
    case CallPhase.ended:
      return c.endReason ?? 'Call ended';
  }
}

// ─── Stage ───────────────────────────────────────────────────────────────────

class _Stage extends StatelessWidget {
  final CallController controller;
  const _Stage({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!_showsVideoStage(c)) return _AvatarStage(controller: c);

    final remotes = c.remoteParticipants;
    // 1:1 (or nobody else here yet): the other side fills the screen and we
    // float in a corner, the usual video-call layout.
    if (remotes.length <= 1) return _OneToOneStage(controller: c);

    // Group: everyone, us included, in an even grid.
    final local = c.room?.localParticipant;
    final tiles = <Widget>[
      for (final p in remotes)
        _ParticipantTile(
          name: c.nameOf(p),
          track: _remoteVideo(p),
          muted: p.isMuted,
          speaking: p.isSpeaking,
        ),
      if (local != null)
        _ParticipantTile(
          name: 'You',
          track: _localVideo(c),
          muted: !c.micEnabled,
          speaking: local.isSpeaking,
        ),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 56, 8, 120),
        child: LayoutBuilder(
          builder: (context, box) {
            final columns = tiles.length <= 2 ? 1 : 2;
            final rows = (tiles.length / columns).ceil();
            final ratio = (box.maxWidth / columns) /
                (box.maxHeight / rows).clamp(1, double.infinity);
            return GridView.count(
              crossAxisCount: columns,
              childAspectRatio: ratio,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: tiles,
            );
          },
        ),
      ),
    );
  }
}

/// 1:1 video, WhatsApp style: one side fills the screen, the other floats in
/// a small card that can be dragged (it snaps to the nearest corner) and
/// tapped to swap which side is big.
class _OneToOneStage extends StatefulWidget {
  final CallController controller;
  const _OneToOneStage({required this.controller});

  @override
  State<_OneToOneStage> createState() => _OneToOneStageState();
}

class _OneToOneStageState extends State<_OneToOneStage> {
  static const _pipSize = Size(110, 160);
  static const _margin = 16.0;
  // Room kept clear for the top bar and the controls bar.
  static const _topInset = 64.0;
  static const _bottomInset = 120.0;

  /// Which corner the card rests in.
  bool _right = true;
  bool _bottom = true;

  /// Card's top-left while a finger is on it; null when resting in a corner.
  Offset? _drag;

  /// True when our own camera is the big picture.
  bool _swapped = false;

  Rect _bounds(Size screen, EdgeInsets safe) => Rect.fromLTRB(
        _margin,
        safe.top + _topInset,
        screen.width - _margin - _pipSize.width,
        screen.height - safe.bottom - _bottomInset - _pipSize.height,
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
    final c = widget.controller;
    final remote = c.remoteParticipants.firstOrNull;
    final remoteTrack = remote == null ? null : _remoteVideo(remote);
    final localTrack = _localVideo(c);
    final hasPip = remote != null && localTrack != null;
    final swapped = _swapped && hasPip;

    final Widget main;
    if (swapped) {
      main = _video(localTrack);
    } else if (remoteTrack != null) {
      main = _video(remoteTrack);
    } else if (remote == null && localTrack != null) {
      main = _video(localTrack);
    } else {
      main = _AvatarStage(controller: c, showStatus: false);
    }

    return LayoutBuilder(
      builder: (context, box) {
        final safe = MediaQuery.paddingOf(context);
        final b = _bounds(box.biggest, safe);
        final pos = _drag ?? _cornerOffset(b);
        return Stack(
          fit: StackFit.expand,
          children: [
            main,
            if (hasPip)
              AnimatedPositioned(
                duration: _drag == null
                    ? const Duration(milliseconds: 250)
                    : Duration.zero,
                curve: Curves.easeOut,
                left: pos.dx,
                top: pos.dy,
                width: _pipSize.width,
                height: _pipSize.height,
                child: GestureDetector(
                  onTap: () => setState(() => _swapped = !_swapped),
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
                        BoxShadow(color: Colors.black45, blurRadius: 8),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: swapped
                        ? (remoteTrack != null
                            ? _video(remoteTrack)
                            : Center(
                                child: _Avatar(
                                  name: c.title,
                                  url: c.avatarUrl,
                                  radius: 32,
                                ),
                              ))
                        : _video(localTrack),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _video(VideoTrack track) => VideoTrackRenderer(
        track,
        key: ObjectKey(track),
        fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
}

/// Audio calls, ringing and anything without video: a big avatar, the name
/// and the call's state, WhatsApp style.
class _AvatarStage extends StatelessWidget {
  final CallController controller;
  final bool showStatus;
  const _AvatarStage({required this.controller, this.showStatus = true});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final others = c.remoteParticipants;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 12, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  c.isVideo ? 'Video call' : 'Voice call',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              c.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (showStatus)
              c.phase == CallPhase.connected
                  ? _Duration(since: c.connectedAt)
                  : Text(
                      _statusText(c),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
            const SizedBox(height: 40),
            _Avatar(
              name: c.title,
              url: c.avatarUrl,
              radius: 64,
              pulsing: c.phase == CallPhase.incoming ||
                  c.phase == CallPhase.outgoing,
            ),
            if (c.isGroupCall && others.isNotEmpty) ...[
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final p in others)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Avatar(
                          name: c.nameOf(p),
                          radius: 22,
                          highlight: p.isSpeaking,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 64,
                          child: Text(
                            c.nameOf(p),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final CallController controller;
  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          Text(
            c.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          c.phase == CallPhase.connected
              ? _Duration(since: c.connectedAt)
              : Text(
                  _statusText(c),
                  style: const TextStyle(color: Colors.white70),
                ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final String name;
  final VideoTrack? track;
  final bool muted;
  final bool speaking;

  const _ParticipantTile({
    required this.name,
    required this.track,
    required this.muted,
    required this.speaking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: speaking ? ChatColors.accent : Colors.transparent,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (track != null)
            VideoTrackRenderer(
              track!,
              fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            Center(child: _Avatar(name: name, radius: 32)),
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                if (muted)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.mic_off, size: 16, color: Colors.white),
                  ),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  final bool pulsing;
  final bool highlight;

  const _Avatar({
    required this.name,
    required this.radius,
    this.url,
    this.pulsing = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: highlight ? ChatColors.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: ChatColors.primary,
        foregroundImage: url == null || url!.isEmpty ? null : NetworkImage(url!),
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return pulsing ? _Pulse(child: avatar) : avatar;
  }
}

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = _anim.value;
        return Container(
          padding: EdgeInsets.all(12 * t),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12 * (1 - t)),
          ),
          child: child,
        );
      },
      child: Padding(padding: const EdgeInsets.all(0), child: widget.child),
    );
  }
}

class _Duration extends StatefulWidget {
  final DateTime? since;
  const _Duration({required this.since});

  @override
  State<_Duration> createState() => _DurationState();
}

class _DurationState extends State<_Duration> {
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.since == null
        ? Duration.zero
        : DateTime.now().difference(widget.since!);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      h > 0 ? '$h:$m:$s' : '$m:$s',
      style: const TextStyle(color: Colors.white70, fontSize: 15),
    );
  }
}

// ─── Buttons ─────────────────────────────────────────────────────────────────

class _IncomingActions extends StatelessWidget {
  const _IncomingActions();

  @override
  Widget build(BuildContext context) {
    final manager = CallManager.instance;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          icon: Icons.call_end,
          label: 'Decline',
          color: Colors.redAccent,
          onTap: manager.decline,
        ),
        _RoundButton(
          icon: manager.current?.isVideo == true ? Icons.videocam : Icons.call,
          label: 'Accept',
          color: ChatColors.accent,
          onTap: manager.accept,
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  final CallController controller;
  const _Controls({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final manager = CallManager.instance;
    final ended = c.phase == CallPhase.ended;
    final live = c.room != null && !ended;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C34),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToggleButton(
            icon: c.speakerOn ? Icons.volume_up : Icons.volume_down,
            active: c.speakerOn,
            tooltip: 'Speaker',
            onTap: live ? manager.toggleSpeaker : null,
          ),
          if (c.isVideo) ...[
            _ToggleButton(
              icon: c.cameraEnabled ? Icons.videocam : Icons.videocam_off,
              active: !c.cameraEnabled,
              tooltip: 'Camera',
              onTap: live ? manager.toggleCamera : null,
            ),
            _ToggleButton(
              icon: Icons.cameraswitch,
              active: false,
              tooltip: 'Switch camera',
              onTap: live && c.cameraEnabled ? manager.switchCamera : null,
            ),
          ],
          _ToggleButton(
            icon: c.micEnabled ? Icons.mic : Icons.mic_off,
            active: !c.micEnabled,
            tooltip: 'Mute',
            onTap: live ? manager.toggleMic : null,
          ),
          _RoundButton(
            icon: Icons.call_end,
            color: Colors.redAccent,
            size: 56,
            onTap: ended ? null : manager.hangUp,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;

  const _ToggleButton({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? Colors.white : Colors.white12,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: onTap == null
                  ? Colors.white30
                  : (active ? Colors.black87 : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final double size;
  final VoidCallback? onTap;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
    this.size = 68,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: onTap == null ? color.withValues(alpha: 0.4) : color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.45),
        ),
      ),
    );
    if (label == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 8),
        Text(label!, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
