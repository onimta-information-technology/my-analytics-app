import 'dart:io';

import 'package:ballys_reservation_app/components/chat_video_player.dart';
import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/models/chat_message.dart';
import 'package:ballys_reservation_app/providers/chat_font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the user decided to send from [MediaPreviewScreen].
class MediaPreviewResult {
  final List<String> filePaths;

  /// Trimmed; null when nothing was typed.
  final String? caption;

  const MediaPreviewResult({required this.filePaths, this.caption});
}

/// Shown between picking photos/videos and uploading them: the picked media
/// full size, a thumbnail strip with a remove button per item, and a caption
/// field. Nothing is uploaded here — the screen pops a [MediaPreviewResult]
/// on Send, or null when the user backs out or removes everything.
class MediaPreviewScreen extends ConsumerStatefulWidget {
  final List<String> filePaths;

  /// Who the media is going to, shown in the app bar.
  final String? recipientName;

  const MediaPreviewScreen({
    super.key,
    required this.filePaths,
    this.recipientName,
  });

  @override
  ConsumerState<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends ConsumerState<MediaPreviewScreen> {
  late final List<String> _paths = List.of(widget.filePaths);
  final _captionController = TextEditingController();
  final _pageController = PageController();
  int _current = 0;

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideo(String path) => AttachmentItem.isVideoPath(path);

  void _remove(int index) {
    if (_paths.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _paths.removeAt(index);
      if (_current >= _paths.length) _current = _paths.length - 1;
    });
    // The page under the removed one slid into its slot; keep the view and
    // the highlighted thumbnail on the same item.
    if (_pageController.hasClients) _pageController.jumpToPage(_current);
  }

  void _send() {
    final caption = _captionController.text.trim();
    Navigator.pop(
      context,
      MediaPreviewResult(
        filePaths: List.of(_paths),
        caption: caption.isEmpty ? null : caption,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(chatFontSettingsProvider);

    return ChatFontScope(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.recipientName == null
                ? '${_current + 1} / ${_paths.length}'
                : 'Send to ${widget.recipientName}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove',
              onPressed: () => _remove(_current),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _paths.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (ctx, i) {
                    final path = _paths[i];
                    if (_isVideo(path)) {
                      return ChatVideoPlayer(
                        key: ValueKey(path),
                        localPath: path,
                      );
                    }
                    return InteractiveViewer(
                      child: Center(
                        child: Image.file(File(path), fit: BoxFit.contain),
                      ),
                    );
                  },
                ),
              ),
              if (_paths.length > 1) _buildThumbnailStrip(),
              _buildCaptionBar(fontSettings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    const size = 64.0;
    return SizedBox(
      height: size + 16,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final path = _paths[i];
          final selected = i == _current;
          final thumb = _isVideo(path)
              ? Container(
                  width: size,
                  height: size,
                  color: Colors.grey[850],
                  child: const Icon(Icons.videocam, color: Colors.white70),
                )
              : Image.file(
                  File(path),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                );

          return GestureDetector(
            onTap: () => _pageController.jumpToPage(i),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? ChatColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: thumb,
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => _remove(i),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaptionBar(FontSettings fontSettings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _captionController,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSettings.fontSize,
              ),
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: ChatColors.primary,
            foregroundColor: Colors.white,
            onPressed: _send,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
