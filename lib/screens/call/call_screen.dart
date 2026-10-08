import 'dart:async';
import 'dart:math' as math;

import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/data/services/call_audio_router.dart';
import 'package:ballys_reservation_app/data/services/call_manager.dart';
import 'package:ballys_reservation_app/screens/call/add_call_participant_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show RTCVideoViewObjectFit;
import 'package:livekit_client/livekit_client.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Full-screen UI for the device's one call: ringing (either direction),
/// connecting, in-call and the brief "call ended" state before it closes.
/// Everything it shows comes from [CallController]; every button goes back
/// through [CallManager].
class CallScreen extends StatefulWidget {
  static const routeName = '/call';

  final CallController controller;

  const CallScreen({super.key, required this.controller});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static const _background = Color(0xFF0B141A);

  static const _proximity = MethodChannel('call_proximity');

  /// Whether the proximity sensor is currently allowed to blank the screen.
  bool _proximityOn = false;

  @override
  void initState() {
    super.initState();
    // Keep the display from timing out for as long as the call screen is up.
    WakelockPlus.enable();
    widget.controller.addListener(_syncProximity);
    _syncProximity();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncProximity);
    _setProximity(false);
    WakelockPlus.disable();
    super.dispose();
  }

  /// Like WhatsApp: the screen goes dark at the ear only while the call is
  /// being held there — on the earpiece, with no camera of ours to look at.
  /// Ringing, speaker, headset and video calls keep the screen live.
  void _syncProximity() {
    final c = widget.controller;
    final atEar = (c.phase == CallPhase.outgoing ||
            c.phase == CallPhase.connecting ||
            c.phase == CallPhase.connected) &&
        c.onEarpiece &&
        !c.cameraEnabled &&
        !c.screenSharing &&
        _remoteScreenSharer(c) == null;
    _setProximity(atEar);
  }

  void _setProximity(bool enabled) {
    if (enabled == _proximityOn) return;
    _proximityOn = enabled;
    _proximity.invokeMethod('setEnabled', enabled).catchError((Object e) {
      print('proximity switch failed: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return PopScope(
          // Like WhatsApp, backing out keeps the call going and hands over to
          // the "return to call" bar. Only a ringing incoming call holds the
          // screen — it has to be answered or declined.
          canPop: c.phase != CallPhase.incoming,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop && c.phase != CallPhase.ended) {
              CallManager.instance.screenMinimized(c);
            }
          },
          child: Scaffold(
            backgroundColor: _background,
            body: Stack(
              fit: StackFit.expand,
              children: [
                _Stage(controller: c),
                SafeArea(
                  child: Column(
                    children: [
                      if (_showsVideoStage(c) || _showsScreenShareStage(c))
                        _TopBar(controller: c),
                      const Spacer(),
                      c.phase == CallPhase.incoming
                          ? const _IncomingActions()
                          : _Controls(controller: c),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                if (c.phase != CallPhase.incoming &&
                    c.phase != CallPhase.ended)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        tooltip: 'Back to app',
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                // Add person and flip camera sit up top, WhatsApp style,
                // leaving the controls bar room for screen sharing. The group
                // voice layout has its own header there, with add person in
                // its participants sheet.
                if (c.room != null && c.phase != CallPhase.ended)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.phase == CallPhase.connected &&
                              !_showsGroupAudioStage(c))
                            IconButton(
                              tooltip: 'Add person',
                              icon: const Icon(
                                Icons.person_add_alt_1,
                                color: Colors.white,
                                size: 26,
                              ),
                              onPressed: () =>
                                  showAddCallParticipantSheet(context, c),
                            ),
                          if (c.isVideo && c.cameraEnabled)
                            IconButton(
                              tooltip: 'Switch camera',
                              icon: const Icon(
                                Icons.cameraswitch,
                                color: Colors.white,
                                size: 26,
                              ),
                              onPressed: CallManager.instance.switchCamera,
                            ),
                        ],
                      ),
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

/// Someone's screen is being shared, ours included: that takes over the
/// stage, whatever kind of call it is.
bool _showsScreenShareStage(CallController c) =>
    c.phase == CallPhase.connected &&
    (c.screenSharing || _remoteScreenSharer(c) != null);

/// The first other person showing their screen, if any.
RemoteParticipant? _remoteScreenSharer(CallController c) =>
    c.remoteParticipants.where((p) => _remoteScreen(p) != null).firstOrNull;

VideoTrack? _remoteScreen(RemoteParticipant p) {
  final pub = p.getTrackPublicationBySource(TrackSource.screenShareVideo);
  if (pub == null || !pub.subscribed || pub.muted) return null;
  final track = pub.track;
  return track is VideoTrack ? track as VideoTrack : null;
}

/// A group call with no cameras on: everyone gets a tile, WhatsApp style,
/// rather than the single big avatar — straight away while it is placed or
/// joined, not only once it is live. Only the incoming ring keeps the avatar.
bool _showsGroupAudioStage(CallController c) =>
    c.isGroupCall &&
    (c.phase == CallPhase.outgoing ||
        c.phase == CallPhase.connecting ||
        c.phase == CallPhase.connected) &&
    !_showsVideoStage(c);

VideoTrack? _remoteVideo(RemoteParticipant p) => p.videoTrackPublications
    .where((pub) =>
        pub.source == TrackSource.camera && pub.subscribed && !pub.muted)
    .map((pub) => pub.track)
    .whereType<VideoTrack>()
    .firstOrNull;

VideoTrack? _localVideo(CallController c) {
  if (!c.cameraEnabled) return null;
  final pub =
      c.room?.localParticipant?.getTrackPublicationBySource(TrackSource.camera);
  if (pub == null || pub.muted) return null;
  final track = pub.track;
  return track is VideoTrack ? track as VideoTrack : null;
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
    if (c.phase == CallPhase.connected && c.screenSharing) {
      return const _SharingOwnScreenStage();
    }
    final sharer = c.phase == CallPhase.connected ? _remoteScreenSharer(c) : null;
    if (sharer != null) {
      return _RemoteScreenStage(controller: c, sharer: sharer);
    }
    if (_showsGroupAudioStage(c)) return _GroupAudioStage(controller: c);
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

/// What the sharer sees while their screen is out, WhatsApp style — not a
/// mirror of the screen itself, which would just repeat into itself.
class _SharingOwnScreenStage extends StatelessWidget {
  const _SharingOwnScreenStage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.screen_share, color: Colors.white70, size: 72),
            const SizedBox(height: 20),
            const Text(
              "You're sharing your screen",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Everyone on the call can see what is on your screen, '
              'including notifications.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.stop_screen_share),
              label: const Text('Stop sharing'),
              onPressed: CallManager.instance.toggleScreenShare,
            ),
          ],
        ),
      ),
    );
  }
}

/// Somebody else's screen, fitted whole (not cropped) so nothing on it is
/// cut off; pinch to zoom in on the detail.
class _RemoteScreenStage extends StatelessWidget {
  final CallController controller;
  final RemoteParticipant sharer;
  const _RemoteScreenStage({required this.controller, required this.sharer});

  @override
  Widget build(BuildContext context) {
    final track = _remoteScreen(sharer)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 56, 0, 112),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.screen_share,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${controller.nameOf(sharer)} is sharing their screen',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                maxScale: 4,
                child: VideoTrackRenderer(
                  track,
                  key: ObjectKey(track),
                  fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

/// Group voice call: the call's name and timer on top, then one tile per
/// person — photo, name, a coloured border and wave while they talk, and a
/// mic-off badge when they are muted.
class _GroupAudioStage extends StatelessWidget {
  final CallController controller;
  const _GroupAudioStage({required this.controller});

  /// Per-person colours, the way a group chat colours sender names.
  static const _palette = [
    Color(0xFF53BDEB),
    Color(0xFFFFD279),
    Color(0xFF25D366),
    Color(0xFFA791FF),
    Color(0xFFFC9775),
    Color(0xFF42C7B8),
    Color(0xFF8EBFFF),
  ];
  static const _youColor = Color(0xFFFF72A1);

  static Color colorOf(String identity) {
    final hash = identity.codeUnits.fold<int>(
      0,
      (h, u) => (h * 31 + u) & 0x7fffffff,
    );
    return _palette[hash % _palette.length];
  }

  static List<_GroupMember> membersOf(CallController c) {
    final local = c.room?.localParticipant;
    return [
      for (final p in c.remoteParticipants)
        _GroupMember(
          name: c.nameOf(p),
          avatarUrl: c.avatarOf(p),
          color: colorOf(p.identity),
          muted: p.isMuted,
          speaking: p.isSpeaking,
        ),
      _GroupMember(
        name: 'You',
        avatarUrl: c.myAvatarUrl,
        color: _youColor,
        muted: !c.micEnabled,
        speaking: c.micEnabled && (local?.isSpeaking ?? false),
      ),
      // Added to the call and not picked up yet.
      for (final i in c.invited.values)
        _GroupMember(
          name: i.name,
          avatarUrl: i.avatarUrl,
          color: colorOf(i.identity),
          muted: false,
          speaking: false,
          ringing: true,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final members = membersOf(c);
    return SafeArea(
      child: Column(
        children: [
          _GroupHeader(controller: c),
          Expanded(
            child: Padding(
              // Room at the bottom for the controls bar floating over it.
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 112),
              child: LayoutBuilder(
                builder: (context, box) {
                  const gap = 10.0;
                  final columns = members.length <= 2 ? 1 : 2;
                  final rows = (members.length / columns).ceil();
                  // Fill the screen, but past a handful of people scroll
                  // rather than squash the tiles.
                  final height = ((box.maxHeight - gap * (rows - 1)) / rows)
                      .clamp(150.0, double.infinity);
                  final width = (box.maxWidth - gap * (columns - 1)) / columns;
                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final m in members)
                          SizedBox(
                            width: width,
                            height: height,
                            child: _GroupTile(member: m),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupMember {
  final String name;
  final String? avatarUrl;
  final Color color;
  final bool muted;
  final bool speaking;

  /// Added to the call, still being rung.
  final bool ringing;

  const _GroupMember({
    required this.name,
    required this.avatarUrl,
    required this.color,
    required this.muted,
    required this.speaking,
    this.ringing = false,
  });
}

class _GroupHeader extends StatelessWidget {
  final CallController controller;
  const _GroupHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
      child: Row(
        children: [
          // Balances the participants button so the title stays centred.
          const SizedBox(width: 56),
          Expanded(
            child: Column(
              children: [
                Text(
                  c.displayTitle,
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
              ],
            ),
          ),
          Material(
            color: Colors.white12,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _showParticipants(context),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.people, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showParticipants(BuildContext context) {
    // The call screen's own context — the sheet's is gone once it closes.
    final screenContext = context;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final members = _GroupAudioStage.membersOf(controller);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    '${members.where((m) => !m.ringing).length} in call',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Someone can only be added once the call is live.
                      if (controller.phase == CallPhase.connected)
                        ListTile(
                          leading: const CircleAvatar(
                            radius: 20,
                            backgroundColor: ChatColors.accent,
                            child: Icon(
                              Icons.person_add_alt_1,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Add person',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            showAddCallParticipantSheet(
                                screenContext, controller);
                          },
                        ),
                      for (final m in members)
                        ListTile(
                          leading: _Avatar(
                            name: m.name,
                            url: m.avatarUrl,
                            radius: 20,
                          ),
                          title: Text(
                            m.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: m.ringing
                              ? const Text(
                                  'Ringing…',
                                  style: TextStyle(color: Colors.white54),
                                )
                              : Icon(
                                  m.muted ? Icons.mic_off : Icons.mic,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final _GroupMember member;
  const _GroupTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final m = member;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF111B21),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: m.speaking ? m.color : Colors.transparent,
          width: 3,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: m.ringing ? 0.5 : 1,
                    child: _Avatar(name: m.name, url: m.avatarUrl, radius: 46),
                  ),
                  SizedBox(
                    height: 22,
                    child: m.speaking
                        ? _SpeakingWave(color: m.color)
                        : const SizedBox.shrink(),
                  ),
                  Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: m.color,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (m.ringing)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Ringing…',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (m.muted)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_off,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The little moving bars under a speaker's photo.
class _SpeakingWave extends StatefulWidget {
  final Color color;
  const _SpeakingWave({required this.color});

  @override
  State<_SpeakingWave> createState() => _SpeakingWaveState();
}

class _SpeakingWaveState extends State<_SpeakingWave>
    with SingleTickerProviderStateMixin {
  static const _bars = 7;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
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
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _bars; i++)
              Container(
                width: 3,
                // Each bar rides the same wave a little out of phase, taller
                // towards the middle.
                height:
                    4 +
                    12 *
                        (1 - (i - _bars ~/ 2).abs() / _bars) *
                        (0.5 +
                            0.5 *
                                math.sin(
                                  2 * math.pi * (_anim.value + i / _bars),
                                )),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        );
      },
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
            c.displayTitle,
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
          _AudioButton(controller: c, live: live),
          if (c.isVideo) ...[
            _ToggleButton(
              icon: c.cameraEnabled ? Icons.videocam : Icons.videocam_off,
              active: !c.cameraEnabled,
              tooltip: 'Camera',
              onTap: live ? manager.toggleCamera : null,
            ),
          ],
          if (CallManager.screenShareSupported)
            _ToggleButton(
              icon: c.screenSharing
                  ? Icons.stop_screen_share
                  : Icons.screen_share,
              active: c.screenSharing,
              tooltip: c.screenSharing ? 'Stop sharing' : 'Share screen',
              onTap: live && c.phase == CallPhase.connected
                  ? manager.toggleScreenShare
                  : null,
            ),
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

/// Speaker on/off while the phone is all there is. With a Bluetooth or
/// wired headset connected it shows where the audio is going and opens a
/// list of outputs — Phone, Speaker, AirPods… — the way WhatsApp does.
class _AudioButton extends StatelessWidget {
  final CallController controller;
  final bool live;
  const _AudioButton({required this.controller, required this.live});

  static IconData iconFor(AudioRouteType? type) => switch (type) {
        AudioRouteType.speaker => Icons.volume_up,
        AudioRouteType.bluetooth => Icons.bluetooth_audio,
        AudioRouteType.wired => Icons.headset,
        AudioRouteType.earpiece || null => Icons.phone_in_talk,
      };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final routes = c.audioRoutes;
    if (routes == null || !routes.hasHeadset) {
      return _ToggleButton(
        icon: c.speakerOn ? Icons.volume_up : Icons.volume_down,
        active: c.speakerOn,
        tooltip: 'Speaker',
        onTap: live ? CallManager.instance.toggleSpeaker : null,
      );
    }
    final type = c.audioRoute?.type;
    return _ToggleButton(
      icon: iconFor(type),
      active: type != null && type != AudioRouteType.earpiece,
      tooltip: 'Audio',
      onTap: live ? () => _pick(context) : null,
    );
  }

  void _pick(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final routes = controller.audioRoutes;
          final current = controller.audioRoute;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final route in routes?.available ?? const <AudioRoute>[])
                    ListTile(
                      leading: Icon(iconFor(route.type), color: Colors.white),
                      title: Text(
                        route.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: route.sameAs(current)
                          ? const Icon(Icons.check, color: Color(0xFF25D366))
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        CallManager.instance.selectAudioRoute(route);
                      },
                    ),
                ],
              ),
            ),
          );
        },
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
