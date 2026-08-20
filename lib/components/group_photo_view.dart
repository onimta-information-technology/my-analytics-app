import 'package:flutter/material.dart';

/// Opens a group's avatar full screen, pinch-to-zoom.
///
/// [onEdit] is passed only for admins: the viewer pops itself first so the
/// picker opens over the sheet that owns the upload, not over this route.
Future<void> showGroupPhoto(
  BuildContext context, {
  required String url,
  required String title,
  VoidCallback? onEdit,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _GroupPhotoView(url: url, title: title, onEdit: onEdit),
    ),
  );
}

class _GroupPhotoView extends StatelessWidget {
  final String url;
  final String title;
  final VoidCallback? onEdit;

  const _GroupPhotoView({
    required this.url,
    required this.title,
    this.onEdit,
  });

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
      body: Center(
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
    );
  }
}
