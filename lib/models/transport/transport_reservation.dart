/// Models for `Transport_Get_Data` (Bellagio only).
///
/// The API returns a master record per transport request, each holding one or
/// more vehicle/hire legs in `transport_details`.
class TransportReservation {
  final String masterId;
  final String mid;
  final String guestName;
  final DateTime? pickupDate;
  final String contactNumber;
  final String reservationStatus;
  final String salesCode;
  final String userName;
  final String deviceId;
  final DateTime? createdDate;
  final String? receivedBy;
  final DateTime? receivedDate;
  final String? taxiPlateNumber;
  final String? driverName;
  final String? driverPhoneNumber;
  final List<TransportDetail> details;

  /// Passport scans uploaded with the request, served as files from the API
  /// host (see [TransportPassportFile.urlFrom]).
  final List<TransportPassportFile> passportFiles;

  /// Amendment notes raised against this request, newest last as returned by
  /// the API.
  final List<TransportAmendment> amendments;

  TransportReservation({
    required this.masterId,
    required this.mid,
    required this.guestName,
    required this.pickupDate,
    required this.contactNumber,
    required this.reservationStatus,
    required this.salesCode,
    required this.userName,
    required this.deviceId,
    required this.createdDate,
    this.receivedBy,
    this.receivedDate,
    this.taxiPlateNumber,
    this.driverName,
    this.driverPhoneNumber,
    required this.details,
    this.passportFiles = const [],
    this.amendments = const [],
  });

  /// True when at least one amendment note was raised against this request.
  bool get hasAmendments => amendments.isNotEmpty;

  /// Most recent amendment by `created_date`, or the last one the API returned
  /// when the dates are missing. Null when there are none.
  TransportAmendment? get latestAmendment {
    if (amendments.isEmpty) return null;
    TransportAmendment latest = amendments.first;
    for (final a in amendments.skip(1)) {
      final current = a.createdDate;
      final best = latest.createdDate;
      if (best == null || (current != null && current.isAfter(best))) {
        latest = a;
      }
    }
    return latest;
  }

  /// Anything the API doesn't recognise falls back to [TransportStatus.requested]
  /// so a request is never dropped from every tab.
  TransportStatus get status {
    switch (reservationStatus.trim().toLowerCase()) {
      case 'transport assigned':
        return TransportStatus.transportAssigned;
      case 'pending transport':
        return TransportStatus.pendingTransport;
      case 'rejected':
        return TransportStatus.rejected;
      default:
        return TransportStatus.requested;
    }
  }

  /// True once transport staff have assigned a taxi/driver to the request.
  bool get isAssigned => status == TransportStatus.transportAssigned;

  factory TransportReservation.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['transport_details'];
    final rawFiles = json['passport_files'];
    final rawAmendments = json['amendments'];

    return TransportReservation(
      masterId: json['master_id']?.toString() ?? '',
      mid: json['mid']?.toString() ?? '',
      guestName: json['guest_name']?.toString() ?? '',
      pickupDate: _parseDate(json['pickup_date']),
      contactNumber: json['contact_number']?.toString() ?? '',
      reservationStatus: json['reservation_status']?.toString() ?? 'Pending',
      salesCode: json['sales_code']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      createdDate: _parseDate(json['created_date']),
      receivedBy: _parseText(json['received_by']),
      receivedDate: _parseDate(json['received_date']),
      taxiPlateNumber: _parseText(json['taxi_plate_number']),
      driverName: _parseText(json['driver_name']),
      driverPhoneNumber: _parseText(json['driver_phone_number']),
      details: rawDetails is List
          ? rawDetails
              .whereType<Map>()
              .map((d) =>
                  TransportDetail.fromJson(Map<String, dynamic>.from(d)))
              .toList()
          : const [],
      passportFiles: rawFiles is List
          ? rawFiles
              .whereType<Map>()
              .map((f) =>
                  TransportPassportFile.fromJson(Map<String, dynamic>.from(f)))
              .toList()
          : const [],
      amendments: rawAmendments is List
          ? rawAmendments
              .whereType<Map>()
              .map((a) =>
                  TransportAmendment.fromJson(Map<String, dynamic>.from(a)))
              .toList()
          : const [],
    );
  }

  /// True when any leg of this request is an airport pickup.
  bool get hasAirportPickup => details.any((d) => d.isAirportPickup);

  /// Airport-pickup progress for the whole request: the least advanced stage
  /// reported across its airport-pickup legs, so the card never claims more
  /// progress than every leg has actually reached. Null when there is no
  /// airport pickup, or when staff haven't reported anything yet.
  AirportPickupStatus? get airportPickupStage {
    AirportPickupStatus? lowest;
    for (final detail in details) {
      final stage = detail.airportPickupStage;
      if (stage == null) continue;
      if (lowest == null || stage.code < lowest.code) lowest = stage;
    }
    return lowest;
  }

  /// Total vehicles across every leg of this request.
  int get totalVehicles =>
      details.fold(0, (sum, d) => sum + d.noOfVehicles);

  /// Total passengers across every leg of this request.
  int get totalPassengers =>
      details.fold(0, (sum, d) => sum + d.noOfPassengers);
}

/// The `reservation_status` values the API returns, one per tab.
enum TransportStatus {
  /// Not assigned to a taxi/driver yet.
  requested('Requested'),

  /// Assigned for today.
  transportAssigned('Transport Assigned'),

  /// Assigned for a future date.
  pendingTransport('Pending Transport'),

  /// Turned down by transport staff.
  rejected('Rejected');

  const TransportStatus(this.label);

  /// Full status name, as shown on the tabs and status chips.
  final String label;
}

/// `airport_pickup_status` on a transport leg — how far transport staff have
/// taken an airport pickup.
enum AirportPickupStatus {
  /// Logged by transport staff, not yet taken on.
  noted(1, 'Noted'),

  /// Taken on by transport staff.
  accepted(2, 'Accepted'),

  /// Confirmed back to the requester.
  acknowledged(3, 'Acknowledged');

  const AirportPickupStatus(this.code, this.label);

  /// The numeric value the API sends.
  final int code;

  /// Status name as shown on the cards and chips.
  final String label;

  /// Null for `0` (nothing reported yet) and any code the API adds later.
  static AirportPickupStatus? fromCode(int? code) {
    for (final status in AirportPickupStatus.values) {
      if (status.code == code) return status;
    }
    return null;
  }
}

class TransportDetail {
  final int detailId;
  final String mid;
  final String guestName;
  final DateTime? pickupDate;
  final String pickupTime;
  final String carType;
  final String hireType;
  final String pickupLocation;
  final String pickupPlaceId;
  final String dropLocation;
  final String dropPlaceId;
  final int noOfVehicles;
  final int noOfPassengers;
  final String contactNumber;

  /// `1` when the leg is a Silk Route service, `0` otherwise.
  final int silkRoute;

  /// `1` when the leg is an airport pickup, `0` otherwise.
  final int airportPickup;

  /// Progress transport staff reported for the airport pickup — see
  /// [AirportPickupStatus]. `0` while nothing has been reported yet.
  final int airportPickupStatus;

  final String? receivedBy;
  final DateTime? receivedDate;
  final String? taxiPlateNumber;
  final String? driverName;
  final String? driverPhoneNumber;

  TransportDetail({
    required this.detailId,
    required this.mid,
    required this.guestName,
    required this.pickupDate,
    required this.pickupTime,
    required this.carType,
    required this.hireType,
    required this.pickupLocation,
    required this.pickupPlaceId,
    required this.dropLocation,
    required this.dropPlaceId,
    required this.noOfVehicles,
    required this.noOfPassengers,
    required this.contactNumber,
    this.silkRoute = 0,
    this.airportPickup = 0,
    this.airportPickupStatus = 0,
    this.receivedBy,
    this.receivedDate,
    this.taxiPlateNumber,
    this.driverName,
    this.driverPhoneNumber,
  });

  /// True when this leg was raised as an airport pickup.
  bool get isAirportPickup => airportPickup == 1;

  /// True when this leg was raised as a Silk Route service.
  bool get isSilkRoute => silkRoute == 1;

  /// Airport-pickup progress, or null when this isn't an airport pickup or
  /// staff haven't reported anything yet.
  AirportPickupStatus? get airportPickupStage =>
      isAirportPickup ? AirportPickupStatus.fromCode(airportPickupStatus) : null;

  /// True once transport staff have filled in the taxi/driver assignment.
  bool get hasDriverInfo =>
      taxiPlateNumber != null ||
      driverName != null ||
      driverPhoneNumber != null ||
      receivedBy != null ||
      receivedDate != null;

  factory TransportDetail.fromJson(Map<String, dynamic> json) {
    return TransportDetail(
      detailId: _parseInt(json['detail_id']),
      mid: json['mid']?.toString() ?? '',
      guestName: json['guest_name']?.toString() ?? '',
      pickupDate: _parseDate(json['pickup_date']),
      pickupTime: json['pickup_time']?.toString() ?? '',
      carType: json['car_type']?.toString() ?? '',
      hireType: json['hire_type']?.toString() ?? '',
      pickupLocation: json['pickup_location']?.toString() ?? '',
      pickupPlaceId: json['pickup_place_id']?.toString() ?? '',
      dropLocation: json['drop_location']?.toString() ?? '',
      dropPlaceId: json['drop_place_id']?.toString() ?? '',
      noOfVehicles: _parseInt(json['no_of_vehicles']),
      noOfPassengers: _parseInt(json['no_of_passengers']),
      contactNumber: json['contact_number']?.toString() ?? '',
      silkRoute: _parseInt(json['silk_route']),
      airportPickup: _parseInt(json['airport_pickup']),
      airportPickupStatus: _parseInt(json['airport_pickup_status']),
      receivedBy: _parseText(json['received_by']),
      receivedDate: _parseDate(json['received_date']),
      taxiPlateNumber: _parseText(json['taxi_plate_number']),
      driverName: _parseText(json['driver_name']),
      driverPhoneNumber: _parseText(json['driver_phone_number']),
    );
  }
}

/// A free-text amendment note raised against a transport request, as posted by
/// `Transport_Amendment_Insert` and returned under `amendments`.
class TransportAmendment {
  final int amendmentId;
  final String masterId;
  final String mid;
  final String guestName;
  final String amendment;
  final String userName;
  final String deviceId;
  final DateTime? createdDate;

  TransportAmendment({
    required this.amendmentId,
    required this.masterId,
    required this.mid,
    required this.guestName,
    required this.amendment,
    required this.userName,
    required this.deviceId,
    this.createdDate,
  });

  factory TransportAmendment.fromJson(Map<String, dynamic> json) {
    return TransportAmendment(
      amendmentId: _parseInt(json['amendment_id']),
      masterId: json['master_id']?.toString() ?? '',
      mid: json['mid']?.toString() ?? '',
      guestName: json['guest_name']?.toString() ?? '',
      amendment: json['amendment']?.toString().trim() ?? '',
      userName: json['user_name']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      createdDate: _parseDate(json['created_date']),
    );
  }
}

/// A passport scan uploaded with a transport request.
///
/// The API only returns a server-relative `file_path` (e.g.
/// `/Uploads/TransportPassports/…jpg`); the file itself is served from the
/// API host, so [urlFrom] joins the two.
class TransportPassportFile {
  final int id;
  final String masterId;
  final String fileName;
  final String filePath;
  final String fileType;
  final bool isPdf;
  final DateTime? createdDate;

  TransportPassportFile({
    required this.id,
    required this.masterId,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.isPdf,
    this.createdDate,
  });

  factory TransportPassportFile.fromJson(Map<String, dynamic> json) {
    final path = json['file_path']?.toString() ?? '';
    final name = json['file_name']?.toString() ?? '';
    final flagged = json['is_pdf'];

    return TransportPassportFile(
      id: _parseInt(json['id']),
      masterId: json['master_id']?.toString() ?? '',
      fileName: name,
      filePath: path,
      fileType: json['file_type']?.toString() ?? '',
      // `is_pdf` is authoritative, but fall back to the extension in case the
      // flag is missing on older rows.
      isPdf: flagged is bool
          ? flagged
          : (name.toLowerCase().endsWith('.pdf') ||
              path.toLowerCase().endsWith('.pdf')),
      createdDate: _parseDate(json['created_date']),
    );
  }

  /// Absolute URL of the file on [host] (e.g. `https://bty.world`), or null
  /// when the API returned no path.
  String? urlFrom(String host) {
    if (filePath.isEmpty) return null;
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    final base = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    final path = filePath.startsWith('/') ? filePath : '/$filePath';
    return '$base${Uri.encodeFull(path)}';
  }
}

/// Returns null for absent/blank values so callers can distinguish
/// "not assigned yet" from an empty string.
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
