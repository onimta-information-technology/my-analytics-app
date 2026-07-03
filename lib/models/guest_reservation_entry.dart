import 'dart:convert';
import 'dart:io';

import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';

class PassportImage {
  final String path;
  final String fileName;
  final bool isPdf;

  PassportImage({
    required this.path,
    required this.fileName,
    required this.isPdf,
  });

  Map<String, dynamic> toJsonWithGuest(String guestBmNumber) {
    final bytes = File(path).readAsBytesSync();
    return {
      'GuestBMNumber': guestBmNumber,
      'FileName': fileName,
      'IsPdf': isPdf,
      'Base64Data': base64Encode(bytes),
    };
  }
}

class GuestReservationEntry {
  final String mid;
  final String guestName;
  final List<HotelDescip> hotels;
  final List<FlightBooking> flights;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final String remarks;
  final String airTicketRequisition; // "Yes" / "No"
  final List<PassportImage> passportImages;

  GuestReservationEntry({
    required this.mid,
    required this.guestName,
    required this.hotels,
    required this.flights,
    required this.arrivalDate,
    required this.departureDate,
    required this.remarks,
    required this.airTicketRequisition,
    this.passportImages = const [],
  });

  /// Simplified guest entry sent inside the `guests` array.
  Map<String, dynamic> toJson() {
    return {
      'BMNumber': mid,
      'GuestName': guestName,
      'ArrivalDate': arrivalDate?.toIso8601String(),
      'DepartureDate': departureDate?.toIso8601String(),
      'HasAirTicketReservation': airTicketRequisition == 'Yes',
      'Remarks': remarks,
    };
  }

  /// Returns passport images for this guest to be added to the top-level
  /// `passport_images` array, each tagged with this guest's BM number.
  List<Map<String, dynamic>> toPassportImagesJson() {
    return passportImages.map((p) => p.toJsonWithGuest(mid)).toList();
  }

  /// Room details for this guest for the top-level `room_details` array,
  /// each tagged with this guest's BM number.
  List<Map<String, dynamic>> toRoomDetailsJson() {
    return hotels
        .map((h) => {
              ...h.toJson(),
              'BMNumber': mid,
            })
        .toList();
  }

  /// Air-ticket details for this guest for the top-level `air_ticket_details`
  /// array, each tagged with this guest's BM number.
  List<Map<String, dynamic>> toAirTicketDetailsJson() {
    return flights
        .map((f) => {
              ...f.toJson(),
              'BMNumber': mid,
            })
        .toList();
  }

  GuestReservationEntry copyWith({
    String? mid,
    String? guestName,
    List<HotelDescip>? hotels,
    List<FlightBooking>? flights,
    DateTime? arrivalDate,
    DateTime? departureDate,
    String? remarks,
    String? airTicketRequisition,
    List<PassportImage>? passportImages,
  }) {
    return GuestReservationEntry(
      mid: mid ?? this.mid,
      guestName: guestName ?? this.guestName,
      hotels: hotels ?? this.hotels,
      flights: flights ?? this.flights,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      departureDate: departureDate ?? this.departureDate,
      remarks: remarks ?? this.remarks,
      airTicketRequisition: airTicketRequisition ?? this.airTicketRequisition,
      passportImages: passportImages ?? this.passportImages,
    );
  }
}
