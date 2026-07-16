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
  });

  /// True once transport staff have assigned a taxi/driver to the request.
  bool get isAssigned =>
      reservationStatus.toLowerCase() == 'transport assigned';

  factory TransportReservation.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['transport_details'];

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
    );
  }

  /// Total vehicles across every leg of this request.
  int get totalVehicles =>
      details.fold(0, (sum, d) => sum + d.noOfVehicles);

  /// Total passengers across every leg of this request.
  int get totalPassengers =>
      details.fold(0, (sum, d) => sum + d.noOfPassengers);
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
    this.receivedBy,
    this.receivedDate,
    this.taxiPlateNumber,
    this.driverName,
    this.driverPhoneNumber,
  });

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
      receivedBy: _parseText(json['received_by']),
      receivedDate: _parseDate(json['received_date']),
      taxiPlateNumber: _parseText(json['taxi_plate_number']),
      driverName: _parseText(json['driver_name']),
      driverPhoneNumber: _parseText(json['driver_phone_number']),
    );
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
