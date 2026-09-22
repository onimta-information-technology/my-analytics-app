/// Models for Bally's `VisaRequest/Get`.
///
/// The API returns a master record per visa request, each holding its guests
/// and the passport scans uploaded for them.
class VisaRequestBallys {
  final int id;
  final String masterId;
  final String salesCode;
  final String userName;
  final String deviceId;
  final String marketingCode;
  final DateTime? arrivalDate;
  final int noOfGuests;
  final String reservationStatus;

  final String? checkedBy;
  final String? checkedRemark;
  final DateTime? checkedDate;
  final String? approvedBy;
  final String? approvedRemark;
  final DateTime? approvedDate;
  final String? rejectedBy;
  final String? rejectedRemark;
  final DateTime? rejectedDate;

  final DateTime? createdDate;
  final DateTime? modifiedDate;
  final List<VisaGuestBallys> guests;
  final List<VisaPassportImageBallys> passportImages;

  VisaRequestBallys({
    required this.id,
    required this.masterId,
    required this.salesCode,
    required this.userName,
    required this.deviceId,
    required this.marketingCode,
    required this.arrivalDate,
    required this.noOfGuests,
    required this.reservationStatus,
    this.checkedBy,
    this.checkedRemark,
    this.checkedDate,
    this.approvedBy,
    this.approvedRemark,
    this.approvedDate,
    this.rejectedBy,
    this.rejectedRemark,
    this.rejectedDate,
    required this.createdDate,
    this.modifiedDate,
    required this.guests,
    required this.passportImages,
  });

  factory VisaRequestBallys.fromJson(Map<String, dynamic> json) {
    final rawGuests = json['guests'];
    final rawImages = json['passport_images'];

    return VisaRequestBallys(
      id: _parseInt(json['id']),
      masterId: json['master_id']?.toString() ?? '',
      salesCode: json['sales_code']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      marketingCode: json['marketing_code']?.toString() ?? '',
      arrivalDate: _parseDate(json['arrival_date']),
      noOfGuests: _parseInt(json['no_of_guests']),
      reservationStatus: json['reservation_status']?.toString() ?? 'Pending',
      checkedBy: _parseText(json['checked_by']),
      checkedRemark: _parseText(json['checked_remark']),
      checkedDate: _parseDate(json['checked_date']),
      approvedBy: _parseText(json['approved_by']),
      approvedRemark: _parseText(json['approved_remark']),
      approvedDate: _parseDate(json['approved_date']),
      rejectedBy: _parseText(json['rejected_by']),
      rejectedRemark: _parseText(json['rejected_remark']),
      rejectedDate: _parseDate(json['rejected_date']),
      createdDate: _parseDate(json['created_date']),
      modifiedDate: _parseDate(json['modified_date']),
      guests: rawGuests is List
          ? rawGuests
              .whereType<Map>()
              .map((g) =>
                  VisaGuestBallys.fromJson(Map<String, dynamic>.from(g)))
              .toList()
          : const [],
      passportImages: rawImages is List
          ? rawImages
              .whereType<Map>()
              .map((p) => VisaPassportImageBallys.fromJson(
                  Map<String, dynamic>.from(p)))
              .toList()
          : const [],
    );
  }

  /// Anything the API doesn't recognise falls back to
  /// [VisaStatusBallys.pending] so a request is never dropped from every tab.
  VisaStatusBallys get status {
    switch (reservationStatus.trim().toLowerCase()) {
      case 'checked':
        return VisaStatusBallys.checked;
      case 'approved':
        return VisaStatusBallys.approved;
      case 'rejected':
        return VisaStatusBallys.rejected;
      default:
        return VisaStatusBallys.pending;
    }
  }

  /// First guest, used as the request's headline in the list.
  VisaGuestBallys? get leadGuest => guests.isEmpty ? null : guests.first;

  /// Passport scans uploaded for [guest].
  List<VisaPassportImageBallys> imagesFor(VisaGuestBallys guest) =>
      passportImages.where((p) => p.guestBmNumber == guest.bmNumber).toList();
}

/// The `reservation_status` values, one per tab.
enum VisaStatusBallys {
  /// Raised, waiting to be checked.
  pending('Pending Check'),

  /// Checked, waiting for the approver.
  checked('Pending Approval'),
  approved('Approved'),
  rejected('Rejected');

  const VisaStatusBallys(this.label);

  final String label;
}

/// An entry of `guests`.
class VisaGuestBallys {
  final int id;
  final String bmNumber;
  final String guestName;
  final DateTime? arrivalDate;

  VisaGuestBallys({
    required this.id,
    required this.bmNumber,
    required this.guestName,
    required this.arrivalDate,
  });

  factory VisaGuestBallys.fromJson(Map<String, dynamic> json) {
    return VisaGuestBallys(
      id: _parseInt(json['id']),
      bmNumber: json['BMNumber']?.toString() ?? '',
      guestName: json['GuestName']?.toString() ?? '',
      arrivalDate: _parseDate(json['ArrivalDate']),
    );
  }
}

/// An entry of `passport_images`. [filePath] is relative to the host root.
class VisaPassportImageBallys {
  final int id;
  final String guestBmNumber;
  final String fileName;
  final bool isPdf;
  final String filePath;
  final DateTime? createdDate;

  VisaPassportImageBallys({
    required this.id,
    required this.guestBmNumber,
    required this.fileName,
    required this.isPdf,
    required this.filePath,
    required this.createdDate,
  });

  factory VisaPassportImageBallys.fromJson(Map<String, dynamic> json) {
    final filePath = json['FilePath']?.toString() ?? '';
    return VisaPassportImageBallys(
      id: _parseInt(json['id']),
      guestBmNumber: json['GuestBMNumber']?.toString() ?? '',
      fileName: json['FileName']?.toString() ?? '',
      isPdf: json['IsPdf'] == true ||
          filePath.toLowerCase().endsWith('.pdf'),
      filePath: filePath,
      createdDate: _parseDate(json['CreatedDate']),
    );
  }
}

/// Returns null for absent/blank values.
String? _parseText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
