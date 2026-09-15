/// One passport page on a group reservation that was already saved, as
/// `GroupReservation/Get` returns it.
class GroupReservationPassportImage {
  const GroupReservationPassportImage({
    required this.id,
    required this.guestBmNumber,
    required this.fileName,
    required this.isPdf,
    required this.filePath,
    this.createdDate,
  });

  final int id;
  final String guestBmNumber;
  final String fileName;
  final bool isPdf;

  /// Server-relative, e.g. `/UploadedGroupPassports/<master_id>_BM_16510_<guid>.jpg`.
  final String filePath;

  final DateTime? createdDate;

  factory GroupReservationPassportImage.fromJson(Map<String, dynamic> json) {
    return GroupReservationPassportImage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      guestBmNumber: json['guest_bm_number']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      isPdf: json['is_pdf'] == true,
      filePath: json['file_path']?.toString() ?? '',
      createdDate: DateTime.tryParse(json['created_date']?.toString() ?? ''),
    );
  }
}

/// A group reservation that has already been saved — the read side of what
/// [GroupReservationRepository.saveGroupReservation] writes.
class GroupReservationRecord {
  const GroupReservationRecord({
    required this.id,
    required this.masterId,
    required this.bmNumber,
    required this.guestName,
    this.remarks = '',
    this.status = '',
    this.salesCode = '',
    this.userName = '',
    this.deviceId = '',
    this.guestSheetName = '',
    this.guestSheetPath = '',
    this.createdDate,
    this.modifiedDate,
    this.passportImages = const [],
  });

  final int id;

  /// The reference the save sent — what the backend keys the group on.
  final String masterId;

  /// The lead guest.
  final String bmNumber;
  final String guestName;

  final String remarks;

  /// 'Pending' on save; the backend moves it on from there.
  final String status;

  /// Who raised it.
  final String salesCode;
  final String userName;
  final String deviceId;

  /// The uploaded Excel sheet naming the rest of the party.
  final String guestSheetName;
  final String guestSheetPath;

  final DateTime? createdDate;
  final DateTime? modifiedDate;
  final List<GroupReservationPassportImage> passportImages;

  factory GroupReservationRecord.fromJson(Map<String, dynamic> json) {
    final passports = json['passport_images'];
    return GroupReservationRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      masterId: json['master_id']?.toString() ?? '',
      bmNumber: json['bm_number']?.toString() ?? '',
      guestName: json['guest_name']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      salesCode: json['sales_code']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      guestSheetName: json['guest_sheet_name']?.toString() ?? '',
      guestSheetPath: json['guest_sheet_path']?.toString() ?? '',
      createdDate: DateTime.tryParse(json['created_date']?.toString() ?? ''),
      modifiedDate: DateTime.tryParse(json['modified_date']?.toString() ?? ''),
      passportImages: passports is List
          ? passports
              .whereType<Map>()
              .map((p) => GroupReservationPassportImage.fromJson(
                  Map<String, dynamic>.from(p)))
              .toList()
          : const [],
    );
  }
}

/// Turns a server-relative upload path into a full URL on [host] (scheme +
/// authority of the current API URL). Null when there is no path.
String? groupReservationFileUrl(String host, String filePath) {
  if (filePath.isEmpty) return null;
  if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
    return filePath;
  }
  final base = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
  final path = filePath.startsWith('/') ? filePath : '/$filePath';
  return '$base${Uri.encodeFull(path)}';
}
