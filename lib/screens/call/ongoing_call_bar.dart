import 'dart:async';

import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/data/services/call_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps the whole app: while a call carries on behind the other screens,
/// a green "Tap to return to call" bar sits above them, WhatsApp style, and
/// tapping it brings [CallScreen] back.
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
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: ChatColors.primary,
        child: InkWell(
          onTap: CallManager.instance.showScreen,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    c.isVideo ? Icons.videocam : Icons.call,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap to return to call · ${c.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _label(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
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
