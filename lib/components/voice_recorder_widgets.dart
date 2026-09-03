import 'package:ballys_reservation_app/components/voice_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// The waveform the composer draws while a voice note is being recorded and
/// while it is being reviewed.
///
/// Unlike the one in a sent bubble — which has nothing but a message id to go
/// on and fakes the bars from it — this one is drawn from the amplitudes the
/// recorder reported, so it is the shape of what was actually said.
///
/// [live] picks how the samples are laid out: while recording only the newest
/// [barCount] of them are shown, newest at the right, so the bars scroll past
/// the way a level meter does; on review the whole clip is averaged down to
/// [barCount] buckets so the entire recording is visible at once.
class VoiceWaveform extends StatelessWidget {
  /// Normalised 0..1 levels, oldest first.
  final List<double> amplitudes;
  final bool live;
  final int barCount;

  /// How far through the clip playback is, 0..1 — the bars before it are drawn
  /// in [playedColor]. Always 0 while recording.
  final double progress;

  final Color playedColor;
  final Color unplayedColor;

  const VoiceWaveform({
    super.key,
    required this.amplitudes,
    required this.playedColor,
    required this.unplayedColor,
    this.live = false,
    this.barCount = 34,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _VoiceWaveformPainter(
        bars: _bars(),
        progress: progress,
        playedColor: playedColor,
        unplayedColor: unplayedColor,
      ),
    );
  }

  /// Reduces the samples to exactly [barCount] values, padding with silence so
  /// a recording that has only just started draws from the right instead of
  /// stretching two samples across the whole strip.
  List<double> _bars() {
    if (amplitudes.isEmpty) return List<double>.filled(barCount, 0);

    if (live) {
      final start =
          amplitudes.length > barCount ? amplitudes.length - barCount : 0;
      final tail = amplitudes.sublist(start);
      if (tail.length == barCount) return tail;
      return [...List<double>.filled(barCount - tail.length, 0), ...tail];
    }

    if (amplitudes.length <= barCount) {
      return [
        ...amplitudes,
        ...List<double>.filled(barCount - amplitudes.length, 0),
      ];
    }

    // Average each bucket rather than sampling one value out of it, so a
    // single loud spike cannot stand in for a quiet second of audio.
    final bars = <double>[];
    final bucket = amplitudes.length / barCount;
    for (int i = 0; i < barCount; i++) {
      final start = (i * bucket).floor();
      final end = ((i + 1) * bucket).ceil().clamp(start + 1, amplitudes.length);
      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += amplitudes[j];
      }
      bars.add(sum / (end - start));
    }
    return bars;
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _VoiceWaveformPainter({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0) return;

    // Bars take two thirds of their slot, the gap the rest.
    final slot = size.width / bars.length;
    final barWidth = (slot * 0.62).clamp(1.5, 6.0);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < bars.length; i++) {
      // A floor of 0.12 keeps silence as a row of dots rather than a gap, so
      // the strip still reads as a waveform when nobody is talking.
      final level = bars[i].clamp(0.0, 1.0);
      final height = (size.height * (0.12 + level * 0.88)).clamp(2.0, size.height);
      final left = i * slot + (slot - barWidth) / 2;
      final top = (size.height - height) / 2;

      paint.color =
          (i / bars.length) < progress ? playedColor : unplayedColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceWaveformPainter old) =>
      old.progress != progress ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor ||
      !identical(old.bars, bars);
}

/// Plays back a clip that has been recorded but not sent yet: the review step
/// between stopping a locked recording and pressing send.
///
/// Playback goes through [VoicePlayerHub] like every other clip in the app, so
/// starting the preview stops whatever bubble was talking, and vice versa.
class VoicePreviewPlayer extends StatefulWidget {
  /// The recorded file. Doubles as the hub key — it carries a timestamp, so a
  /// second recording is never mistaken for the one already loaded.
  final String path;

  /// Levels captured while recording, used to draw the real waveform.
  final List<double> amplitudes;

  /// Length as measured while recording; the decoder's own figure takes over
  /// once the file is loaded.
  final Duration duration;
  final double fontSize;

  const VoicePreviewPlayer({
    super.key,
    required this.path,
    required this.amplitudes,
    required this.duration,
    required this.fontSize,
  });

  @override
  State<VoicePreviewPlayer> createState() => _VoicePreviewPlayerState();
}

class _VoicePreviewPlayerState extends State<VoicePreviewPlayer> {
  final VoicePlayerHub _hub = VoicePlayerHub.instance;
  bool _isLoading = false;

  String get _key => 'composer_preview:${widget.path}';

  @override
  void dispose() {
    // The clip is about to stop existing — either sent or thrown away — so it
    // must not keep playing over whatever replaces the bar.
    if (_hub.playingKey.value == _key) _hub.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    setState(() => _isLoading = _hub.playingKey.value != _key);
    try {
      await _hub.toggle(_key, filePath: widget.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play this recording')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _hub.playingKey,
      builder: (context, playingKey, _) {
        final isCurrent = playingKey == _key;

        return StreamBuilder<Duration>(
          stream: isCurrent ? _hub.positionStream : const Stream.empty(),
          builder: (context, positionSnap) {
            return StreamBuilder<PlayerState>(
              stream: isCurrent ? _hub.playerStateStream : const Stream.empty(),
              builder: (context, stateSnap) {
                final total = (isCurrent ? _hub.loadedDuration : null) ??
                    widget.duration;
                final position =
                    isCurrent ? (positionSnap.data ?? Duration.zero) : Duration.zero;
                final progress = total.inMilliseconds == 0
                    ? 0.0
                    : (position.inMilliseconds / total.inMilliseconds)
                        .clamp(0.0, 1.0);

                final processing = stateSnap.data?.processingState;
                final buffering = isCurrent &&
                    (processing == ProcessingState.loading ||
                        processing == ProcessingState.buffering);
                final playing = isCurrent && (stateSnap.data?.playing ?? false);

                return Row(
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: (_isLoading || buffering)
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 30,
                              icon: Icon(
                                playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                color: Colors.green[700],
                              ),
                              onPressed: _toggle,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: isCurrent && total > Duration.zero
                                ? (d) => _seek(
                                      d.localPosition.dx / constraints.maxWidth,
                                      total,
                                    )
                                : null,
                            onHorizontalDragUpdate:
                                isCurrent && total > Duration.zero
                                    ? (d) => _seek(
                                          d.localPosition.dx /
                                              constraints.maxWidth,
                                          total,
                                        )
                                    : null,
                            child: SizedBox(
                              height: 28,
                              child: VoiceWaveform(
                                amplitudes: widget.amplitudes,
                                progress: progress,
                                playedColor: Colors.green.shade600,
                                unplayedColor: Colors.grey.shade400,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      // Counts up while playing, shows the full length at rest
                      // — the same reading as a sent voice note.
                      _format(isCurrent && position > Duration.zero
                          ? position
                          : total),
                      style: TextStyle(
                        fontSize: widget.fontSize - 4,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _seek(double fraction, Duration total) {
    _hub.seek(
      _key,
      Duration(
        milliseconds:
            (total.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
      ),
    );
  }
}
