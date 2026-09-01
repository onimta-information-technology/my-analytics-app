import 'package:flutter/material.dart';

/// Opens an avatar — a person's profile picture or a group's photo — full
/// screen, pinch-to-zoom.
///
/// Does nothing when there is no picture, so callers can wire it straight to a
/// tap without null-checking first.
///
/// [onEdit] is passed only where the viewer may change the picture (a group
/// admin): the viewer pops itself first so the picker opens over the sheet
/// that owns the upload, not over this route.
Future<void> showAvatarPhoto(
  BuildContext context, {
  required String? url,
  required String title,
  VoidCallback? onEdit,
}) async {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return;

  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          _AvatarPhotoView(url: trimmed, title: title, onEdit: onEdit),
    ),
  );
}

class _AvatarPhotoView extends StatelessWidget {
  final String url;
  final String title;
  final VoidCallback? onEdit;

  const _AvatarPhotoView({required this.url, required this.title, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.camera_alt),
              tooltip: 'Change photo',
              onPressed: () {
                Navigator.of(context).pop();
                onEdit!();
              },
            ),
        ],
      ),
      // Tapping the picture closes it, the way every other chat app does it.
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 48,
                      width: 48,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    ),
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 80,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
