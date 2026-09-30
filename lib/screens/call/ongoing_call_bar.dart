import 'dart:async';

import 'package:ballys_reservation_app/data/services/call_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps the whole app: while a call carries on behind the other screens,
/// a WhatsApp-style bar sits above them — mute, the name and timer, hang
/// up — and tapping it brings [CallScreen] back.
class OngoingCallBar extends StatelessWidget {
  final Widget child;
  const OngoingCallBar({super.key, required this.child});

  static bool _isLive(CallController? c) =>
      c != null &&
      (c.phase == CallPhase.outgoing ||
          c.phase == CallPhase.connecting ||
          c.phase == CallPhase.connected);

  @override
  Widget build(BuildContext context) {
    final manager = CallManager.instance;
    return ValueListenableBuilder<CallController?>(
      valueListenable: manager.active,
      builder: (context, call, _) => ValueListenableBuilder<bool>(
        valueListenable: manager.screenShown,
        builder: (context, shown, _) => ListenableBuilder(
          listenable: call ?? const _Never(),
          builder: (context, _) {
            final visible = !shown && _isLive(call);
            // The tree keeps the same shape either way so the app's navigator
            // below is never rebuilt from scratch when the bar comes and goes.
            return Column(
              children: [
                if (visible) _Bar(controller: call!),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: visible,
                    child: child,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Never extends Listenable {
  const _Never();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _Bar extends StatefulWidget {
  final CallController controller;
  const _Bar({required this.controller});

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _label() {
    final c = widget.controller;
    final since = c.connectedAt;
    if (c.phase != CallPhase.connected || since == null) {
      return c.phase == CallPhase.outgoing ? 'Calling…' : 'Connecting…';
    }
    final d = DateTime.now().difference(since);
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:${two(m)}:$s' : '$m:$s';
  }

  static const _background = Color(0xFF1F2C34);
  static const _green = Color(0xFF25D366);
  static const _red = Color(0xFFEA0038);

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final manager = CallManager.instance;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: _background,
        child: InkWell(
          onTap: manager.showScreen,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  _RoundButton(
                    tooltip: c.micEnabled ? 'Mute' : 'Unmute',
                    icon: Icons.mic_off,
                    // Lit up while muted, like the call screen's own button.
                    background:
                        c.micEnabled ? const Color(0xFF2A3942) : Colors.white,
                    iconColor: c.micEnabled ? Colors.white : Colors.black87,
                    onPressed: manager.toggleMic,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            c.isVideo ? Icons.videocam : Icons.call,
                            color: _green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${c.title} - ${_label()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _green,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _RoundButton(
                    tooltip: 'Hang up',
                    icon: Icons.call_end,
                    background: _red,
                    iconColor: Colors.white,
                    onPressed: manager.hangUp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color background;
  final Color iconColor;
  final VoidCallback onPressed;

  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Semantics, not Tooltip: this bar sits above the navigator, where there
    // is no Overlay for a tooltip to show in.
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ),
      ),
    );
  }
}
