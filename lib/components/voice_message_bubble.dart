import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Playback for voice notes, shared by every bubble in the app.
///
/// One [AudioPlayer] is enough — and is what the user expects: starting a
/// second clip stops the first, rather than two people talking at once. The
/// bubble whose [key] matches [playingKey] is the one showing progress; every
/// other one sits idle.
class VoicePlayerHub {
  VoicePlayerHub._();
  static final VoicePlayerHub instance = VoicePlayerHub._();

  final AudioPlayer _player = AudioPlayer();

  /// The clip currently loaded, or null when nothing has been played yet.
  /// Bubbles watch this so the previous one drops back to idle the moment
  /// another is started.
  final ValueNotifier<String?> playingKey = ValueNotifier<String?>(null);

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// The length the decoder reports, which is the fallback for a clip the
  /// backend sent no duration for.
  Duration? get loadedDuration => _player.duration;

  bool get isPlaying => _player.playing;

  /// Starts [key] (loading it first if it is not the current clip), or pauses
  /// it if it is already running. A clip that has played to the end restarts.
  Future<void> toggle(String key, {String? url, String? filePath}) async {
    final source = (url != null && url.isNotEmpty) ? url : filePath;
    if (source == null || source.isEmpty) return;

    if (playingKey.value != key) {
      await _player.stop();
      playingKey.value = key;
      if (url != null && url.isNotEmpty) {
        await _player.setUrl(url);
      } else {
        await _player.setFilePath(filePath!);
      }
      await _player.play();
      return;
    }

    if (_player.playing) {
      await _player.pause();
    } else {
      // Finished clips park at the end; play() there would return at once.
      final duration = _player.duration;
      if (duration != null && _player.position >= duration) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> seek(String key, Duration position) async {
    if (playingKey.value != key) return;
    await _player.seek(position);
  }

  /// Stops whatever is playing — used when the chat screen goes away, so a
  /// clip does not keep talking over the next screen.
  Future<void> stop() async {
    if (playingKey.value == null) return;
    playingKey.value = null;
    await _player.stop();
  }

  /// Whether [key] is the clip that is loaded *and* actually running.
  bool isPlayingKey(String key) => playingKey.value == key && _player.playing;
}

/// A recorded clip inside a chat bubble: play/pause, a waveform that doubles
/// as a scrubber, and the remaining time.
///
/// [duration] is what the sender measured while recording, so the length is
/// known before the audio has been fetched; the decoder's own duration takes
/// over once the clip is loaded.
class VoiceMessageBubble extends StatefulWidget {
  /// Identifies this clip to [VoicePlayerHub] — the message id, which is
  /// unique within the conversation.
  final String messageKey;
  final String? url;
  final String? localPath;
  final Duration? duration;
  final bool isMe;
  final double fontSize;

  /// False while the message list is in selection mode, where a tap belongs to
  /// the selection rather than to playback.
  final bool enabled;

  const VoiceMessageBubble({
    super.key,
    required this.messageKey,
    required this.isMe,
    required this.fontSize,
    this.url,
    this.localPath,
    this.duration,
    this.enabled = true,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final VoicePlayerHub _hub = VoicePlayerHub.instance;

  /// Width of the waveform, which is also what a tap's x position is measured
  /// against when scrubbing.
  static const double _waveWidth = 140;

  /// Set while a clip of ours is being fetched, so the button can say so
  /// instead of looking dead on a slow connection.
  bool _isLoading = false;

  bool get _isCurrent => _hub.playingKey.value == widget.messageKey;

  Future<void> _toggle() async {
    if (!widget.enabled) return;
    setState(() => _isLoading = !_isCurrent);
    try {
      await _hub.toggle(
        widget.messageKey,
        url: widget.url,
        filePath: widget.localPath,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play this voice message')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final onDark = widget.isMe;
    final foreground = onDark ? Colors.white : Colors.black87;
    final played = onDark ? Colors.white : const Color(0xFF2E7D32);
    final unplayed = onDark ? Colors.white38 : Colors.black26;

    return ValueListenableBuilder<String?>(
      valueListenable: _hub.playingKey,
      builder: (context, playingKey, _) {
        final isCurrent = playingKey == widget.messageKey;

        // Only the current clip has a position to report; every other bubble
        // draws its waveform empty and shows its full length.
        return StreamBuilder<Duration>(
          stream: isCurrent ? _hub.positionStream : const Stream.empty(),
          builder: (context, positionSnap) {
            return StreamBuilder<PlayerState>(
              stream: isCurrent ? _hub.playerStateStream : const Stream.empty(),
              builder: (context, stateSnap) {
                final total = (isCurrent ? _hub.loadedDuration : null) ??
                    widget.duration ??
                    Duration.zero;
                final position = isCurrent
                    ? (positionSnap.data ?? Duration.zero)
                    : Duration.zero;
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: (_isLoading || buffering)
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(foreground),
                              ),
                            )
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.enabled ? _toggle : null,
                              child: Icon(
                                playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                size: 32,
                                color: foreground,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: _waveWidth,
                          height: 26,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            // Scrubbing only makes sense on the clip that is
                            // loaded — there is nothing to seek in the others.
                            onTapDown: isCurrent && total > Duration.zero
                                ? (details) => _seekTo(
                                      details.localPosition.dx / _waveWidth,
                                      total,
                                    )
                                : null,
                            onHorizontalDragUpdate:
                                isCurrent && total > Duration.zero
                                    ? (details) => _seekTo(
                                          details.localPosition.dx /
                                              _waveWidth,
                                          total,
                                        )
                                    : null,
                            child: CustomPaint(
                              painter: _WaveformPainter(
                                seed: widget.messageKey,
                                progress: progress,
                                playedColor: played,
                                unplayedColor: unplayed,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic,
                              size: widget.fontSize - 6,
                              color: onDark ? Colors.white70 : Colors.black54,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              // Counts down through the clip and shows the
                              // full length when it is not playing.
                              _format(isCurrent && position > Duration.zero
                                  ? position
                                  : total),
                              style: TextStyle(
                                color:
                                    onDark ? Colors.white70 : Colors.black54,
                                fontSize: widget.fontSize - 5,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  void _seekTo(double fraction, Duration total) {
    final clamped = fraction.clamp(0.0, 1.0);
    _hub.seek(
      widget.messageKey,
      Duration(milliseconds: (total.inMilliseconds * clamped).round()),
    );
  }
}

/// The bars behind the scrubber.
///
/// No real amplitudes are available — the upload carries only the file and its
/// length — so the heights are derived from the message id: stable for a given
/// message (it does not reshuffle as the list rebuilds) and different enough
/// between messages to read as a waveform rather than a progress bar.
class _WaveformPainter extends CustomPainter {
  final String seed;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _WaveformPainter({
    required this.seed,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  static const int _barCount = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed.hashCode);
    final barWidth = size.width / (_barCount * 2 - 1);
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < _barCount; i++) {
      final height = size.height * (0.25 + random.nextDouble() * 0.75);
      final x = i * barWidth * 2;
      final top = (size.height - height) / 2;
      paint.color =
          (i / _barCount) < progress ? playedColor : unplayedColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.seed != seed ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor;
}
