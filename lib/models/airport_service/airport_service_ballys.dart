/// Models for Bally's `AirportService/Get`.
///
/// The API returns a master record per airport service request, each holding
/// its guests and the person nominated to approve it.
class AirportServiceBallys {
  final int id;
  final String masterId;
  final String salesCode;
  final String userName;
  final String deviceId;
  final String marketingCode;
  final String? remarks;
  final AirportServiceApprovePersonBallys? approvePerson;
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
  final List<AirportServiceGuestBallys> guests;

  AirportServiceBallys({
    required this.id,
    required this.masterId,
    required this.salesCode,
    required this.userName,
    required this.deviceId,
    required this.marketingCode,
    this.remarks,
    this.approvePerson,
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
  });

  factory AirportServiceBallys.fromJson(Map<String, dynamic> json) {
    final rawGuests = json['guests'];
    final rawApprover = json['approve_person'];

    return AirportServiceBallys(
      id: _parseInt(json['id']),
      masterId: json['master_id']?.toString() ?? '',
      salesCode: json['sales_code']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      marketingCode: json['marketing_code']?.toString() ?? '',
      remarks: _parseText(json['remarks']),
      approvePerson: rawApprover is Map
          ? AirportServiceApprovePersonBallys.fromJson(
              Map<String, dynamic>.from(rawApprover))
          : null,
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
              .map((g) => AirportServiceGuestBallys.fromJson(
                  Map<String, dynamic>.from(g)))
              .toList()
          : const [],
    );
  }

  /// Anything the API doesn't recognise falls back to
  /// [AirportServiceStatusBallys.pending] so a request is never dropped from
  /// every tab.
  AirportServiceStatusBallys get status {
    switch (reservationStatus.trim().toLowerCase()) {
      case 'checked':
        return AirportServiceStatusBallys.checked;
      case 'approved':
        return AirportServiceStatusBallys.approved;
      case 'rejected':
        return AirportServiceStatusBallys.rejected;
      default:
        return AirportServiceStatusBallys.pending;
    }
  }

  /// First guest, used as the request's headline in the list.
  AirportServiceGuestBallys? get leadGuest =>
      guests.isEmpty ? null : guests.first;

  /// Sum of every guest's pax.
  int get totalPax => guests.fold(0, (sum, g) => sum + g.noOfPax);
}

/// The `reservation_status` values, one per tab.
enum AirportServiceStatusBallys {
  /// Raised, waiting to be checked.
  pending('Pending Check'),

  /// Checked, waiting for the approver.
  checked('Pending Approval'),
  approved('Approved'),
  rejected('Rejected');

  const AirportServiceStatusBallys(this.label);

  final String label;
}

/// The `approve_person` object.
class AirportServiceApprovePersonBallys {
  final int authorizationId;
  final String authorizationPerson;
  final int authorizationLevel;
  final String authorizationCategory;

  AirportServiceApprovePersonBallys({
    required this.authorizationId,
    required this.authorizationPerson,
    required this.authorizationLevel,
    required this.authorizationCategory,
  });

  factory AirportServiceApprovePersonBallys.fromJson(
      Map<String, dynamic> json) {
    return AirportServiceApprovePersonBallys(
      authorizationId: _parseInt(json['authorization_id']),
      authorizationPerson: json['authorization_person']?.toString() ?? '',
      authorizationLevel: _parseInt(json['authorization_level']),
      authorizationCategory: json['authorization_category']?.toString() ?? '',
    );
  }
}

/// An entry of `guests`.
class AirportServiceGuestBallys {
  final int id;
  final String mid;
  final String guestName;
  final double packageAmount;
  final String currencyType;
  final String serviceType;
  final bool hasAccompanyingMembers;
  final bool hasWife;
  final int noOfChildren;
  final int noOfFriends;
  final int noOfPax;

  AirportServiceGuestBallys({
    required this.id,
    required this.mid,
    required this.guestName,
    required this.packageAmount,
    required this.currencyType,
    required this.serviceType,
    required this.hasAccompanyingMembers,
    required this.hasWife,
    required this.noOfChildren,
    required this.noOfFriends,
    required this.noOfPax,
  });

  factory AirportServiceGuestBallys.fromJson(Map<String, dynamic> json) {
    return AirportServiceGuestBallys(
      id: _parseInt(json['id']),
      mid: json['MID']?.toString() ?? '',
      guestName: json['guest_name']?.toString() ?? '',
      packageAmount: _parseDouble(json['package_amount']),
      currencyType: json['currency_type']?.toString() ?? '',
      serviceType: json['service_type']?.toString() ?? '',
      hasAccompanyingMembers: _parseBool(json['has_accompanying_members']),
      hasWife: _parseBool(json['has_wife']),
      noOfChildren: _parseInt(json['no_of_children']),
      noOfFriends: _parseInt(json['no_of_friends']),
      noOfPax: _parseInt(json['no_of_pax']),
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
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1';
}
