import 'dart:async';

import 'package:ballys_reservation_app/components/chat_wallpaper.dart';
import 'package:ballys_reservation_app/components/group_avatar.dart';
import 'package:ballys_reservation_app/components/user_avatar.dart';
import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/data/services/call_api_service.dart';
import 'package:ballys_reservation_app/data/services/call_manager.dart';
import 'package:ballys_reservation_app/models/call_session.dart';
import 'package:ballys_reservation_app/models/chat_group.dart';
import 'package:flutter/material.dart';

/// WhatsApp-style pre-join screen for a call already live in a chat: the
/// chat's name and picture, a mute toggle to pick before going in, and a card
/// of who is already on the call with Ignore / Join.
///
/// Opened from the chat's green "Join" button. Closes by itself if the call
/// ends while it is up.
class JoinCallScreen extends StatefulWidget {
  final CallInfo call;
  final String title;
  final String? avatarUrl;
  final Color avatarColor;
  final bool isGroup;

  /// The group roster, for the faces of those already on the call.
  final List<GroupMember> members;

  /// Left out of the "who's on the call" list.
  final String? currentUserUuid;

  const JoinCallScreen({
    super.key,
    required this.call,
    required this.title,
    required this.avatarColor,
    required this.isGroup,
    this.avatarUrl,
    this.members = const [],
    this.currentUserUuid,
  });

  @override
  State<JoinCallScreen> createState() => _JoinCallScreenState();
}

class _JoinCallScreenState extends State<JoinCallScreen> {
  static const _background = Color(0xFF0B141A);
  static const _doodle = Color(0xFF17232B);
  static const _card = Color(0xFF111B21);
  static const _cardBorder = Color(0xFF2A3942);
  static const _pill = Color(0xFF1F2C34);
  static const _joinGreen = Color(0xFF21C063);

  bool _muted = false;
  List<CallParticipantInfo> _joined = const [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final snap = await CallApiService.status(widget.call.callId);
      if (!mounted) return;
      if (!snap.call.isLive) {
        Navigator.of(context).pop();
        return;
      }
      final me = widget.currentUserUuid?.toLowerCase();
      setState(() {
        _joined = snap.participants
            .where(
              (p) => p.status == 'joined' && p.userUuid.toLowerCase() != me,
            )
            .toList();
      });
    } catch (_) {
      // Keep whatever was shown last; the next poll tries again.
    }
  }

  void _join() {
    Navigator.of(context).pop();
    CallManager.instance.joinExisting(
      call: widget.call,
      title: widget.title,
      avatarUrl: widget.avatarUrl,
      muted: _muted,
    );
  }

  GroupMember? _memberOf(CallParticipantInfo p) {
    final uuid = p.userUuid.toLowerCase();
    for (final m in widget.members) {
      if (m.userUuid.toLowerCase() == uuid && m.appType == p.appType) return m;
    }
    for (final m in widget.members) {
      if (m.userUuid.toLowerCase() == uuid) return m;
    }
    return null;
  }

  String _nameOf(CallParticipantInfo p) {
    if (p.name.trim().isNotEmpty) return p.name.trim();
    if (p.firstName.trim().isNotEmpty) return p.firstName.trim();
    return _memberOf(p)?.name ?? 'Someone';
  }

  String get _whoLabel {
    if (_joined.isEmpty) {
      final caller = widget.call.callerName.trim();
      return caller.isEmpty ? 'Waiting for others' : caller;
    }
    final first = _nameOf(_joined.first);
    final rest = _joined.length - 1;
    if (rest == 0) return first;
    return '$first & $rest ${rest == 1 ? 'other' : 'others'}';
  }

  String get _subtitle {
    final video = widget.call.media == CallMedia.video;
    if (widget.isGroup) return video ? 'Group video call' : 'Group call';
    return video ? 'Video call' : 'Voice call';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: ChatWallpaper(
        background: _background,
        doodle: _doodle,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 96),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.call.media == CallMedia.video
                          ? Icons.videocam_outlined
                          : Icons.call_outlined,
                      size: 18,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                widget.isGroup
                    ? GroupAvatar(
                        avatarUrl: widget.avatarUrl,
                        radius: 96,
                        backgroundColor: widget.avatarColor,
                      )
                    : UserAvatar(
                        avatarUrl: widget.avatarUrl,
                        initials: _initials(widget.title),
                        backgroundColor: widget.avatarColor,
                        radius: 96,
                        fontSize: 56,
                      ),
                const Spacer(),
                _MuteToggle(
                  muted: _muted,
                  onTap: () => setState(() => _muted = !_muted),
                ),
                const SizedBox(height: 16),
                _buildCard(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: ChatColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _whoLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                if (_joined.isNotEmpty) _buildFaces(),
              ],
            ),
          ),
          const Divider(height: 1, color: _cardBorder),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _CardButton(
                    label: 'Ignore',
                    color: _pill,
                    textColor: Colors.white,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CardButton(
                    label: 'Join',
                    color: _joinGreen,
                    textColor: _background,
                    onTap: _join,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Overlapping faces of up to three people already on the call.
  Widget _buildFaces() {
    const radius = 14.0;
    const step = 20.0;
    final shown = _joined.take(3).toList();
    return SizedBox(
      width: radius * 2 + step * (shown.length - 1) + 4,
      height: radius * 2 + 4,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: _card,
                  shape: BoxShape.circle,
                ),
                child: _face(shown[i], radius),
              ),
            ),
        ],
      ),
    );
  }

  Widget _face(CallParticipantInfo p, double radius) {
    final member = _memberOf(p);
    final name = _nameOf(p);
    return UserAvatar(
      avatarUrl: member?.avatarUrl,
      initials: member?.initials ?? _initials(name),
      backgroundColor: member?.avatarColor ?? ChatColors.primary,
      radius: radius,
      fontSize: 10,
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((s) => s[0].toUpperCase()).join();
}

class _MuteToggle extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;
  const _MuteToggle({required this.muted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = muted ? const Color(0xFF0B141A) : Colors.white;
    return Material(
      color: muted ? Colors.white : const Color(0xFF1F2C34),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_off_outlined, color: fg, size: 22),
              const SizedBox(width: 12),
              Text(
                muted ? 'Muted' : 'Mute',
                style: TextStyle(
                  color: fg,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _CardButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
