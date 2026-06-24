// guest_reservation_entry.dart
//
// Lightweight model representing ONE guest's full booking slice inside a
// single multi-guest reservation. Several of these share one reservationNo.
//
// Place this file at: lib/models/reservation/guest_reservation_entry.dart
// (adjust the import paths below to match wherever you put it)

import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';

class GuestReservationEntry {
  final String mid;
  final String guestName;
  final List<HotelDescip> hotels;
  final List<FlightBooking> flights;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final String remarks;
  final String airTicketRequisition; // "Yes" / "No"

  GuestReservationEntry({
    required this.mid,
    required this.guestName,
    required this.hotels,
    required this.flights,
    required this.arrivalDate,
    required this.departureDate,
    required this.remarks,
    required this.airTicketRequisition,
  });

  /// Used to build the `guests` array sent to the backend.
  Map<String, dynamic> toJson() {
    return {
      "bmNumber": mid,
      "guestName": guestName,
      "roomDetails": hotels.map((h) => h.toJson()).toList(),
      "airTicketDetails": flights.map((f) => f.toJson()).toList(),
      "arrivalDate": arrivalDate?.toIso8601String(),
      "departureDate": departureDate?.toIso8601String(),
      "remarks": remarks,
      "hasAirTicketReservation": airTicketRequisition == "Yes" ? "1" : "0",
    };
  }

  /// Convenience copy used when "editing" an already-added guest
  /// (pops it back into the form fields).
  GuestReservationEntry copyWith({
    String? mid,
    String? guestName,
    List<HotelDescip>? hotels,
    List<FlightBooking>? flights,
    DateTime? arrivalDate,
    DateTime? departureDate,
    String? remarks,
    String? airTicketRequisition,
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
    );
  }
}