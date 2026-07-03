import 'dart:convert';
import 'dart:typed_data';

/// A passport image/PDF returned by `Reservation_GetAllReservations`.
///
/// Unlike the upload-side `PassportImage` (which points at a local file), this
/// carries the base64 payload straight from the API so it can be rendered with
/// `Image.memory` or handed to a PDF viewer. Each image is tagged with the
/// owning guest's BM number via [guestBmNumber].
class ReservationPassportImage {
  final String guestBmNumber;
  final String fileName;
  final bool isPdf;
  final String base64Data;

  ReservationPassportImage({
    required this.guestBmNumber,
    required this.fileName,
    required this.isPdf,
    required this.base64Data,
  });

  factory ReservationPassportImage.fromJson(Map<String, dynamic> json) {
    return ReservationPassportImage(
      guestBmNumber: json['GuestBMNumber'] as String? ?? '',
      fileName: json['FileName'] as String? ?? '',
      isPdf: json['IsPdf'] as bool? ?? false,
      base64Data: json['Base64Data'] as String? ?? '',
    );
  }

  /// Decoded bytes, or null when the payload is empty / not valid base64.
  Uint8List? get bytes {
    if (base64Data.isEmpty) return null;
    try {
      return base64Decode(base64Data);
    } catch (_) {
      return null;
    }
  }
}
