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
    required this.details,
  });

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
  });

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
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
