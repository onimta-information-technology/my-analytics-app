import 'dart:convert';
import 'dart:typed_data';

import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../utils/download_helper.dart';

/// What the bubble shows about a file once it has been fetched: its size, and
/// for a PDF the page count and a picture of the first page.
class _DocumentInfo {
  final int sizeBytes;
  final int? pageCount;
  final Uint8List? firstPagePng;

  const _DocumentInfo({
    required this.sizeBytes,
    this.pageCount,
    this.firstPagePng,
  });
}

/// A document in the thread, laid out like WhatsApp's: for a PDF a preview of
/// the top of the first page, then the file name with a download button, then
/// "1 page • 282 kB • PDF".
///
/// The file is fetched into the app cache the first time the bubble is built,
/// the same cache [DownloadHelper.openForViewing] reads, so opening it later
/// is instant.
class DocumentMessageBubble extends StatefulWidget {
  final String? url;
  final String? localPath;
  final String fileName;
  final bool isMe;
  final double fontSize;
  final double width;

  /// Tapping the card opens the file for viewing.
  final VoidCallback onTap;

  /// Tapping the download icon saves a copy to the device.
  final VoidCallback onDownload;

  const DocumentMessageBubble({
    super.key,
    required this.fileName,
    required this.isMe,
    required this.fontSize,
    required this.width,
    required this.onTap,
    required this.onDownload,
    this.url,
    this.localPath,
  });

  @override
  State<DocumentMessageBubble> createState() => _DocumentMessageBubbleState();
}

class _DocumentMessageBubbleState extends State<DocumentMessageBubble> {
  /// Kept across rebuilds and scrolls, so a bubble that leaves the screen and
  /// comes back does not rasterise its PDF again.
  static final Map<String, Future<_DocumentInfo?>> _cache = {};

  static const double _previewHeight = 130;

  Future<_DocumentInfo?>? _info;

  String get _extension {
    final dot = widget.fileName.lastIndexOf('.');
    if (dot < 0 || dot == widget.fileName.length - 1) return '';
    return widget.fileName.substring(dot + 1).toUpperCase();
  }

  bool get _isPdf => _extension == 'PDF';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DocumentMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An upload finishing swaps the local path for the server URL.
    if (oldWidget.url != widget.url ||
        oldWidget.localPath != widget.localPath) {
      _load();
    }
  }

  void _load() {
    final key = widget.url ?? widget.localPath;
    if (key == null) {
      _info = null;
      return;
    }
    _info = _cache.putIfAbsent(key, () => _fetch(isPdf: _isPdf));
  }

  Future<_DocumentInfo?> _fetch({required bool isPdf}) async {
    try {
      final file = await DownloadHelper.cachedCopy(
        url: widget.url,
        localPath: widget.localPath,
        fileName: widget.fileName,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (!isPdf) return _DocumentInfo(sizeBytes: bytes.length);

      Uint8List? png;
      try {
        await for (final page in Printing.raster(bytes, pages: [0], dpi: 72)) {
          png = await page.toPng();
          break;
        }
      } catch (_) {
        // Not renderable (damaged or encrypted): show the card without it.
      }
      return _DocumentInfo(
        sizeBytes: bytes.length,
        pageCount: await _countPages(bytes),
        firstPagePng: png,
      );
    } catch (_) {
      // Leave the entry out, so the next build tries the download again.
      _cache.remove(widget.url ?? widget.localPath);
      return null;
    }
  }

  /// Counts the page objects in the file. Cheap, and right for most PDFs; one
  /// that packs its objects into compressed streams hides them from the scan,
  /// so that case falls back to rendering every page at a tiny resolution.
  static Future<int?> _countPages(Uint8List bytes) async {
    final text = latin1.decode(bytes, allowInvalid: true);
    final scanned = RegExp(r'/Type\s*/Page(?![a-zA-Z])').allMatches(text).length;
    if (scanned > 0) return scanned;
    try {
      var count = 0;
      await for (final _ in Printing.raster(bytes, dpi: 1)) {
        count++;
      }
      return count > 0 ? count : null;
    } catch (_) {
      return null;
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1000) return '$bytes B';
    if (bytes < 1000 * 1000) return '${(bytes / 1000).round()} kB';
    return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DocumentInfo?>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        return GestureDetector(
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: widget.width,
              color: widget.isMe
                  ? ChatColors.attachmentOnOutgoing
                  : ChatColors.attachmentOnIncoming,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isPdf) _buildPreview(info, loading),
                  _buildDetails(info),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreview(_DocumentInfo? info, bool loading) {
    final png = info?.firstPagePng;
    return Container(
      height: _previewHeight,
      color: Colors.white,
      child: png != null
          // The top of the page, as WhatsApp crops it.
          ? Image.memory(
              png,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
            )
          : Center(
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ChatColors.primary,
                      ),
                    )
                  : Icon(
                      Icons.picture_as_pdf,
                      size: 44,
                      color: Colors.red.shade400,
                    ),
            ),
    );
  }

  Widget _buildDetails(_DocumentInfo? info) {
    final meta = <String>[
      if (info?.pageCount != null)
        '${info!.pageCount} ${info.pageCount == 1 ? 'page' : 'pages'}',
      if (info != null) _formatSize(info.sizeBytes),
      if (_extension.isNotEmpty) _extension,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      child: Row(
        children: [
          // Without a preview, the file type's icon stands in for it.
          if (!_isPdf) ...[
            Icon(
              Icons.insert_drive_file,
              color: ChatColors.bubbleMeta,
              size: 32,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ChatColors.bubbleText,
                    fontSize: widget.fontSize - 1,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: TextStyle(
                      color: ChatColors.bubbleMeta,
                      fontSize: widget.fontSize - 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDownload,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.file_download_outlined,
                color: ChatColors.bubbleMeta,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
