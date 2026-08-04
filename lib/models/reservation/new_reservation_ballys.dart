
class NewReservationBallys {
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
  String? packageAmount;

  /// The "Shared" tick beside the package amount: the reservation is on a
  /// shared package. Sent in its own right so an empty [packageAmount] no
  /// longer has to stand in for it — a shared package may still carry one.
  bool isSharedAmount;
  String? selectedMarketingPerson;
  List<Map<String, dynamic>>? guests;
  List<Map<String, dynamic>>? passportImages;

  NewReservationBallys({
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
    this.packageAmount,
    this.isSharedAmount = false,
    this.selectedMarketingPerson,
    this.guests,
    this.passportImages,
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
      'manual_reserv_no': reservationnewnumber,
      'package_amount': packageAmount,
      'is_shared_amount': isSharedAmount,
      'selected_marketing_person': selectedMarketingPerson,
      'guests': guests,
      'passport_images': passportImages,
    };
  }

  factory NewReservationBallys.fromJson(Map<String, dynamic> json) {
    return NewReservationBallys(
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

  NewReservationBallys copyWith({
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
    return NewReservationBallys(
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
