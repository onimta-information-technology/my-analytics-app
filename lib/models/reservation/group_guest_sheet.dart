import 'dart:convert';
import 'dart:io';

/// The Excel sheet listing everybody travelling on a group reservation.
///
/// A group booking can carry dozens of guests, so instead of typing each one
/// into the form the marketing person attaches the sheet the guest sent and the
/// backend expands it into individual guests. Only the lead guest's BM number
/// and name are keyed in by hand.
class GroupGuestSheet {
  /// Location on disk, inside app storage — the picker's cache copy is not
  /// kept, so this path is still readable at save time.
  final String path;
  final String fileName;
  final int sizeBytes;

  const GroupGuestSheet({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
  });

  /// "24.5 KB" / "1.2 MB", for the attachment card.
  String get readableSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Base64 of the file on disk, or null when it has gone missing since it was
  /// picked. Read at save time rather than at pick time so a large sheet is not
  /// held in memory for the whole session.
  Future<String?> toBase64() async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return base64Encode(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }
}
