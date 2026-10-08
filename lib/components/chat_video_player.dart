import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays one chat video, from a local file (before upload) or its url.
///
/// Tapping the picture toggles playback; a scrubber runs along the bottom.
/// The controller lives and dies with this widget, so a PageView only keeps
/// the video on screen loaded.
class ChatVideoPlayer extends StatefulWidget {
  final String? url;
  final String? localPath;
  final bool autoPlay;

  const ChatVideoPlayer({
    super.key,
    this.url,
    this.localPath,
    this.autoPlay = false,
  });

  @override
  State<ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<ChatVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    final localPath = widget.localPath;
    final url = widget.url;
    final VideoPlayerController controller;
    if (localPath != null && File(localPath).existsSync()) {
      controller = VideoPlayerController.file(File(localPath));
    } else if (url != null && url.isNotEmpty) {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      setState(() => _failed = true);
      return;
    }
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (widget.autoPlay) await controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    controller.addListener(_onTick);
    setState(() {});
  }

  /// Redraws the play/pause overlay as playback starts, stops or finishes.
  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      // Played to the end: start over rather than doing nothing.
      if (controller.value.position >= controller.value.duration) {
        controller.seekTo(Duration.zero);
      }
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.videocam_off, color: Colors.white54, size: 64),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: _togglePlayback,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              if (!controller.value.isPlaying)
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen player for a video in the conversation.
class ChatVideoView extends StatelessWidget {
  final String? url;
  final String? localPath;
  final String? title;

  const ChatVideoView({super.key, this.url, this.localPath, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: title == null ? null : Text(title!, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: ChatVideoPlayer(url: url, localPath: localPath, autoPlay: true),
      ),
    );
  }
}
