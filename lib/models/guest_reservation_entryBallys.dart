import 'dart:convert';
import 'dart:io';

import 'package:ballys_reservation_app/models/reservation/flight_bookng_ballys.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc_ballys.dart';
import 'package:ballys_reservation_app/utils/amount_util.dart';

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

/// A second (third, …) member travelling on the SAME package as the guest that
/// owns them: they share that guest's rooms, air tickets and dates, so they
/// carry no hotels/flights of their own — only who they are and whether family
/// members come along with them.
class AccompanyingMember {
  final String mid;
  final String guestName;

  /// Whether family members travel with this member — a plain yes/no tick.
  final bool hasFamilyMembers;

  /// This member's own package amount as displayed in the form, e.g.
  /// `"IND 10,000"`. Members share the owner's rooms, tickets and dates but
  /// each is billed their own package, so the amount is per member.
  final String packageAmount;

  const AccompanyingMember({
    required this.mid,
    required this.guestName,
    this.hasFamilyMembers = false,
    this.packageAmount = '',
  });

  factory AccompanyingMember.fromJson(Map<String, dynamic> json) {
    // Sent as a bare number plus a separate currency, mirroring the
    // reservation-level package_amount / currency_type pair.
    final amount = json['PackageAmount']?.toString().trim() ?? '';
    final currency = json['CurrencyType']?.toString().trim() ?? '';

    return AccompanyingMember(
      mid: json['BMNumber'] as String? ?? '',
      guestName: json['GuestName'] as String? ?? '',
      hasFamilyMembers: json['HasFamilyMembers'] as bool? ?? false,
      packageAmount: amount.isEmpty || currency.isEmpty
          ? amount
          : '$currency $amount',
    );
  }

  AccompanyingMember copyWith({
    String? mid,
    String? guestName,
    bool? hasFamilyMembers,
    String? packageAmount,
  }) {
    return AccompanyingMember(
      mid: mid ?? this.mid,
      guestName: guestName ?? this.guestName,
      hasFamilyMembers: hasFamilyMembers ?? this.hasFamilyMembers,
      packageAmount: packageAmount ?? this.packageAmount,
    );
  }
}

class GuestReservationEntryBallys {
  final String mid;
  final String guestName;
  final List<HotelDescipBallys> hotels;
  final List<FlightBookingBallys> flights;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final String remarks;
  final String airTicketRequisition; // "Yes" / "No"
  final List<PassportImage> passportImages;

  /// Whether family members travel with THIS guest — a plain yes/no tick.
  final bool hasFamilyMembers;

  /// Other members sharing this guest's package.
  final List<AccompanyingMember> accompanyingMembers;

  /// This guest's own package amount as displayed in the form, e.g.
  /// `"IND 10,000"`. Every guest is billed their own package, so the amount
  /// travels per guest inside `guests` rather than on the reservation.
  final String packageAmount;

  GuestReservationEntryBallys({
    required this.mid,
    required this.guestName,
    required this.hotels,
    required this.flights,
    required this.arrivalDate,
    required this.departureDate,
    required this.remarks,
    required this.airTicketRequisition,
    this.passportImages = const [],
    this.hasFamilyMembers = false,
    this.accompanyingMembers = const [],
    this.packageAmount = '',
  });

  /// Simplified guest entry sent inside the `guests` array.
  Map<String, dynamic> toJson() {
    return {
      'BMNumber': mid,
      'GuestName': guestName,
      'ArrivalDate': arrivalDate?.toIso8601String(),
      'DepartureDate': departureDate?.toIso8601String(),
      'HasFamilyMembers': hasFamilyMembers,
      'PackageAmount': packageAmountToInt(packageAmount),
      'CurrencyType': packageAmountCurrency(packageAmount),
    };
  }

  /// This guest plus every member sharing their package, flattened for the
  /// top-level `guests` array. Shared members repeat the owner's dates and
  /// contribute no rooms or air tickets of their own, but each carries its own
  /// package amount.
  List<Map<String, dynamic>> toGuestsJson() {
    return [
      toJson(),
      ...accompanyingMembers.map(
        (m) => {
          'BMNumber': m.mid,
          'GuestName': m.guestName,
          'ArrivalDate': arrivalDate?.toIso8601String(),
          'DepartureDate': departureDate?.toIso8601String(),
          'HasFamilyMembers': m.hasFamilyMembers,
          'PackageAmount': packageAmountToInt(m.packageAmount),
          'CurrencyType': packageAmountCurrency(m.packageAmount),
        },
      ),
    ];
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

  GuestReservationEntryBallys copyWith({
    String? mid,
    String? guestName,
    List<HotelDescipBallys>? hotels,
    List<FlightBookingBallys>? flights,
    DateTime? arrivalDate,
    DateTime? departureDate,
    String? remarks,
    String? airTicketRequisition,
    List<PassportImage>? passportImages,
    bool? hasFamilyMembers,
    List<AccompanyingMember>? accompanyingMembers,
    String? packageAmount,
  }) {
    return GuestReservationEntryBallys(
      mid: mid ?? this.mid,
      guestName: guestName ?? this.guestName,
      hotels: hotels ?? this.hotels,
      flights: flights ?? this.flights,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      departureDate: departureDate ?? this.departureDate,
      remarks: remarks ?? this.remarks,
      airTicketRequisition: airTicketRequisition ?? this.airTicketRequisition,
      passportImages: passportImages ?? this.passportImages,
      hasFamilyMembers: hasFamilyMembers ?? this.hasFamilyMembers,
      accompanyingMembers: accompanyingMembers ?? this.accompanyingMembers,
      packageAmount: packageAmount ?? this.packageAmount,
    );
  }
}
