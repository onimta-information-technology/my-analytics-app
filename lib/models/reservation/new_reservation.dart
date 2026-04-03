
class NewReservation {
  String? bmNumber;
  String? guestName;
  String? hotelName;
  List<Map<String, dynamic>>? roomDetails;
  int? noOfNights;
  DateTime? arrivalDate;
  DateTime? departureDate;
  String? hasAirTicketReservation;
  String? remarks;
  List<Map<String, dynamic>>? airTicketDetails;
  String? reservationNo;
  String? reservationnewnumber;

  NewReservation({
    this.bmNumber,
    this.guestName,
    this.hotelName,
    this.roomDetails,
    this.noOfNights,
    this.arrivalDate,
    this.departureDate,
    this.hasAirTicketReservation,
    this.remarks,
    this.airTicketDetails,
    this.reservationNo,
    this.reservationnewnumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'bm_number': bmNumber,
      'guest_name': guestName,
      'hotel_name': hotelName,
      'room_details': roomDetails,
      'no_of_nights': noOfNights,
      'arrival_date': arrivalDate?.toIso8601String(),
      'departure_date': departureDate?.toIso8601String(),
      'has_air_ticket_reservation': hasAirTicketReservation!,
      'remarks': remarks,
      'air_ticket_details': airTicketDetails,
      'reservation_no': reservationNo,
      'Manual_Reserv_No': reservationnewnumber,
    };
  }

  factory NewReservation.fromJson(Map<String, dynamic> json) {
    return NewReservation(
      bmNumber: json['bm_number'] ?? '',
      guestName: json['guest_name'] ?? '',
      hotelName: json['hotel_name'] ?? '',
      roomDetails: List<Map<String, dynamic>>.from(json['room_details'] ?? []),
      noOfNights: json['no_of_nights'] ?? 0,
      arrivalDate: json['arrival_date'] ?? '',
      departureDate: json['departure_date'] ?? '',
      hasAirTicketReservation: (json['has_air_ticket_reservation'] ?? '0'),
      remarks: json['remarks'] ?? '',
      airTicketDetails:
          List<Map<String, dynamic>>.from(json['air_ticket_details'] ?? []),
      reservationNo: json['reservNo'] ?? '',
      reservationnewnumber: json['Manual_Reserv_No'] ?? '',

    );
  }

  NewReservation copyWith({
    String? bmNumber,
    String? guestName,
    String? hotelName,
    List<Map<String, dynamic>>? roomDetails,
    int? noOfNights,
    DateTime? arrivalDate,
    DateTime? departureDate,
    String? hasAirTicketReservation,
    String? remarks,
    List<Map<String, dynamic>>? airTicketDetails,
    String? reservationnewnumber,

  }) {
    return NewReservation(
      bmNumber: bmNumber ?? this.bmNumber,
      guestName: guestName ?? this.guestName,
      hotelName: hotelName ?? this.hotelName,
      roomDetails: roomDetails ?? this.roomDetails,
      noOfNights: noOfNights ?? this.noOfNights,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      departureDate: departureDate ?? this.departureDate,
      hasAirTicketReservation:
          hasAirTicketReservation ?? this.hasAirTicketReservation,
      remarks: remarks ?? this.remarks,
      airTicketDetails: airTicketDetails ?? this.airTicketDetails,
      reservationnewnumber: reservationnewnumber ?? this.reservationnewnumber,
    );
  }
}
