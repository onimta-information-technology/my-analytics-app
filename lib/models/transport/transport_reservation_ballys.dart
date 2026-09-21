/// Models for Bally's `TransportReservation/Get`.
///
/// The API returns a master record per transport request, each holding one or
/// more hire legs in `transport_details`; every leg carries its own vehicles
/// and accompanying guests.
class TransportReservationBallys {
  final int id;
  final String masterId;
  final String salesCode;
  final String userName;
  final String marketingCode;
  final String deviceId;
  final String mid;
  final String guestName;
  final DateTime? pickupDate;
  final String contactNumber;
  final TransportApproverBallys? approvePerson;
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
  final List<TransportDetailBallys> details;

  TransportReservationBallys({
    required this.id,
    required this.masterId,
    required this.salesCode,
    required this.userName,
    required this.marketingCode,
    required this.deviceId,
    required this.mid,
    required this.guestName,
    required this.pickupDate,
    required this.contactNumber,
    required this.approvePerson,
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
    required this.details,
  });

  factory TransportReservationBallys.fromJson(Map<String, dynamic> json) {
    final rawApprover = json['approve_person'];
    final rawDetails = json['transport_details'];

    return TransportReservationBallys(
      id: _parseInt(json['id']),
      masterId: json['master_id']?.toString() ?? '',
      salesCode: json['sales_code']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      marketingCode: json['marketing_code']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      mid: json['MID']?.toString() ?? '',
      guestName: json['guest_name']?.toString() ?? '',
      pickupDate: _parseDate(json['pickup_date']),
      contactNumber: json['contact_number']?.toString() ?? '',
      approvePerson: rawApprover is Map
          ? TransportApproverBallys.fromJson(
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
      details: rawDetails is List
          ? rawDetails
              .whereType<Map>()
              .map((d) => TransportDetailBallys.fromJson(
                  Map<String, dynamic>.from(d)))
              .toList()
          : const [],
    );
  }

  /// Anything the API doesn't recognise falls back to
  /// [TransportStatusBallys.pending] so a request is never dropped from every
  /// tab.
  TransportStatusBallys get status {
    switch (reservationStatus.trim().toLowerCase()) {
      case 'checked':
        return TransportStatusBallys.checked;
      case 'approved':
        return TransportStatusBallys.approved;
      case 'rejected':
        return TransportStatusBallys.rejected;
      default:
        return TransportStatusBallys.pending;
    }
  }

  /// Total vehicles across every leg of this request.
  int get totalVehicles => details.fold(0, (sum, d) => sum + d.noOfVehicles);

  /// Total passengers across every vehicle of every leg.
  int get totalPassengers =>
      details.fold(0, (sum, d) => sum + d.totalPassengers);
}

/// The `reservation_status` values, one per tab.
enum TransportStatusBallys {
  /// Raised, waiting to be checked.
  pending('Pending Check'),

  /// Checked, waiting for the approver.
  checked('Pending Approval'),
  approved('Approved'),
  rejected('Rejected');

  const TransportStatusBallys(this.label);

  final String label;
}

/// `approve_person` — who was asked to authorise the request.
class TransportApproverBallys {
  final int authorizationId;
  final String authorizationPerson;
  final int authorizationLevel;
  final String authorizationCategory;

  TransportApproverBallys({
    required this.authorizationId,
    required this.authorizationPerson,
    required this.authorizationLevel,
    required this.authorizationCategory,
  });

  factory TransportApproverBallys.fromJson(Map<String, dynamic> json) {
    return TransportApproverBallys(
      authorizationId: _parseInt(json['authorization_id']),
      authorizationPerson: json['authorization_person']?.toString() ?? '',
      authorizationLevel: _parseInt(json['authorization_level']),
      authorizationCategory: json['authorization_category']?.toString() ?? '',
    );
  }
}

/// One hire leg in `transport_details`.
class TransportDetailBallys {
  final int id;
  final int rowId;
  final String mid;
  final String guestName;
  final DateTime? pickupDate;
  final String pickupTime;
  final String hireType;
  final String gate;
  final String flightNo;
  final String pickupLocation;
  final String pickupPlaceId;
  final String dropLocation;
  final String dropPlaceId;
  final int noOfVehicles;
  final String contactNumber;
  final List<TransportGuestBallys> accompanyingMembers;
  final List<TransportVehicleBallys> vehicles;

  TransportDetailBallys({
    required this.id,
    required this.rowId,
    required this.mid,
    required this.guestName,
    required this.pickupDate,
    required this.pickupTime,
    required this.hireType,
    required this.gate,
    required this.flightNo,
    required this.pickupLocation,
    required this.pickupPlaceId,
    required this.dropLocation,
    required this.dropPlaceId,
    required this.noOfVehicles,
    required this.contactNumber,
    required this.accompanyingMembers,
    required this.vehicles,
  });

  factory TransportDetailBallys.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['accompanying_members'];
    final rawVehicles = json['vehicle_details'];

    return TransportDetailBallys(
      id: _parseInt(json['id']),
      rowId: _parseInt(json['row_id']),
      mid: json['MID']?.toString() ?? '',
      guestName: json['guest_name']?.toString() ?? '',
      pickupDate: _parseDate(json['pickup_date']),
      pickupTime: json['pickup_time']?.toString() ?? '',
      hireType: json['hire_type']?.toString() ?? '',
      gate: json['gate']?.toString() ?? '',
      flightNo: json['flight_no']?.toString() ?? '',
      pickupLocation: json['pickup_location']?.toString() ?? '',
      pickupPlaceId: json['pickup_place_id']?.toString() ?? '',
      dropLocation: json['drop_location']?.toString() ?? '',
      dropPlaceId: json['drop_place_id']?.toString() ?? '',
      noOfVehicles: _parseInt(json['no_of_vehicles']),
      contactNumber: json['contact_number']?.toString() ?? '',
      accompanyingMembers: rawMembers is List
          ? rawMembers
              .whereType<Map>()
              .map((m) =>
                  TransportGuestBallys.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      vehicles: rawVehicles is List
          ? rawVehicles
              .whereType<Map>()
              .map((v) =>
                  TransportVehicleBallys.fromJson(Map<String, dynamic>.from(v)))
              .toList()
          : const [],
    );
  }

  int get totalPassengers =>
      vehicles.fold(0, (sum, v) => sum + v.noOfPassengers);
}

/// An entry of `accompanying_members`.
class TransportGuestBallys {
  final int id;
  final String mid;
  final String guestName;

  TransportGuestBallys({
    required this.id,
    required this.mid,
    required this.guestName,
  });

  factory TransportGuestBallys.fromJson(Map<String, dynamic> json) {
    return TransportGuestBallys(
      id: _parseInt(json['id']),
      mid: json['MID']?.toString() ?? '',
      guestName: json['guest_name']?.toString() ?? '',
    );
  }
}

/// An entry of `vehicle_details`.
class TransportVehicleBallys {
  final int id;
  final String carType;
  final int noOfPassengers;

  TransportVehicleBallys({
    required this.id,
    required this.carType,
    required this.noOfPassengers,
  });

  factory TransportVehicleBallys.fromJson(Map<String, dynamic> json) {
    return TransportVehicleBallys(
      id: _parseInt(json['id']),
      carType: json['car_type']?.toString() ?? '',
      noOfPassengers: _parseInt(json['no_of_passengers']),
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
