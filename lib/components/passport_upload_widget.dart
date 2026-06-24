import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// Model representing a single uploaded passport file.
class PassportFile {
  final String path;
  final String fileName;
  final bool isPdf;

  PassportFile({
    required this.path,
    required this.fileName,
    required this.isPdf,
  });
}

/// A reusable widget for uploading one or more passport bio data pages.
/// Supports JPEG/PNG images (camera or gallery) and PDF files.
/// Shows thumbnails for images and a PDF icon card for PDF files.
class PassportUploadWidget extends StatefulWidget {
  /// Called whenever the list of uploaded files changes.
  final ValueChanged<List<PassportFile>>? onFilesChanged;

  /// Pre-populate with existing files (e.g. when editing a flight booking).
  final List<PassportFile>? initialFiles;

  const PassportUploadWidget({
    super.key,
    this.onFilesChanged,
    this.initialFiles,
  });

  @override
  State<PassportUploadWidget> createState() => _PassportUploadWidgetState();
}

class _PassportUploadWidgetState extends State<PassportUploadWidget> {
  final List<PassportFile> _files = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles != null) {
      _files.addAll(widget.initialFiles!);
    }
  }

  // ── Source chooser ────────────────────────────────────────────────────────

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  "Upload Passport Bio Page",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text("Take Photo"),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text("Choose from Gallery"),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                title: const Text("Upload PDF"),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPdf();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickFromCamera() async {
    try {
      final XFile? photo =
          await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo != null) _addFile(photo.path, false);
    } catch (e) {
      _showError("Could not open camera: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      // Allow multiple image selection from gallery.
      final List<XFile> photos = await _imagePicker.pickMultiImage();
      for (final photo in photos) {
        _addFile(photo.path, false);
      }
    } catch (e) {
      _showError("Could not open gallery: $e");
    }
  }

  Future<void> _pickPdf() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      if (result != null) {
        for (final file in result.files) {
          if (file.path != null) _addFile(file.path!, true);
        }
      }
    } catch (e) {
      _showError("Could not pick PDF: $e");
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _addFile(String path, bool isPdf) {
    setState(() {
      _files.add(PassportFile(
        path: path,
        fileName: path.split('/').last,
        isPdf: isPdf,
      ));
    });
    widget.onFilesChanged?.call(List.unmodifiable(_files));
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
    widget.onFilesChanged?.call(List.unmodifiable(_files));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Passport Bio Data Page",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showSourcePicker,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add"),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // ── File list / empty state ───────────────────────────────────────
        if (_files.isEmpty)
          GestureDetector(
            onTap: _showSourcePicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.upload_file,
                      size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    "Tap to upload passport bio page",
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                  Text(
                    "Image (JPG/PNG) or PDF",
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._files.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return _FilePreviewCard(
                  file: file,
                  onRemove: () => _removeFile(index),
                );
              }),
              // "Add more" tile
              _AddMoreTile(onTap: _showSourcePicker),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview card for a single file
// ─────────────────────────────────────────────────────────────────────────────

class _FilePreviewCard extends StatelessWidget {
  final PassportFile file;
  final VoidCallback onRemove;

  const _FilePreviewCard({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    const double size = 90;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Thumbnail or PDF icon ─────────────────────────────────────────
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: file.isPdf ? Colors.red.shade50 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: file.isPdf
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf,
                        size: 36, color: Colors.red.shade400),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        file.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(file.path),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.grey),
                  ),
                ),
        ),

        // ── Remove button ─────────────────────────────────────────────────
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Add more" tile shown after at least one file is uploaded
// ─────────────────────────────────────────────────────────────────────────────

class _AddMoreTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMoreTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                size: 30, color: Colors.blue.shade400),
            const SizedBox(height: 4),
            Text(
              "Add more",
              style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
            ),
          ],
        ),
      ),
    );
  }
}