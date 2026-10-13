/// What `Reservation_CheckDuplicate` found for a new reservation, sorted by
/// what the screen does about it:
///
/// * [hotelDuplicates] — a guest already has a pending stay at the same hotel
///   on the same dates. The reservation is not saved.
/// * [airTicketDuplicates] — a guest already has a pending ticket on the same
///   dates between the same airports. The reservation is not saved.
/// * [airTicketWarnings] — a pending ticket on the same dates but between
///   different airports. Shown to the user, then the reservation is saved.
class ReservationDuplicateCheck {
  final bool status;
  final String message;
  final List<DuplicateMatch> hotelDuplicates;
  final List<DuplicateMatch> airTicketDuplicates;
  final List<DuplicateMatch> airTicketWarnings;

  const ReservationDuplicateCheck({
    required this.status,
    required this.message,
    this.hotelDuplicates = const [],
    this.airTicketDuplicates = const [],
    this.airTicketWarnings = const [],
  });

  bool get isBlocked =>
      hotelDuplicates.isNotEmpty || airTicketDuplicates.isNotEmpty;

  factory ReservationDuplicateCheck.fromJson(Map<String, dynamic> json) {
    final hotels = <DuplicateMatch>[];
    final tickets = <DuplicateMatch>[];
    final warnings = <DuplicateMatch>[];

    final duplicates = json['duplicates'];
    if (json['has_duplicates'] == true && duplicates is List) {
      for (final guest in duplicates.whereType<Map<String, dynamic>>()) {
        final bm = guest['bm_number']?.toString() ?? '';

        for (final row in _rows(guest['hotel_duplicates'])) {
          hotels.add(DuplicateMatch(bmNumber: bm, row: row));
        }
        for (final row in _rows(guest['air_ticket_duplicates'])) {
          final match = DuplicateMatch(bmNumber: bm, row: row);
          (_sameAirports(row) ? tickets : warnings).add(match);
        }
      }
    }

    return ReservationDuplicateCheck(
      status: json['Status'] as bool? ?? false,
      message: (json['message'] ?? json['Message'])?.toString() ?? '',
      hotelDuplicates: hotels,
      airTicketDuplicates: tickets,
      airTicketWarnings: warnings,
    );
  }

  static Iterable<Map<String, dynamic>> _rows(dynamic value) =>
      value is List ? value.whereType<Map<String, dynamic>>() : const [];

  /// The backend matches tickets on dates; whether the airports match too is
  /// what decides between stopping the save and only warning about it.
  static bool _sameAirports(Map<String, dynamic> row) {
    String code(String key) => row[key]?.toString().trim().toUpperCase() ?? '';
    return code('requested_departure_from') == code('matched_df_airport_code') &&
        code('requested_departure_to') == code('matched_dt_airport_code') &&
        code('requested_return_from') == code('matched_rf_airport_code') &&
        code('requested_return_to') == code('matched_rt_airport_code');
  }
}

/// One clash against an existing pending reservation, as the backend sent it.
class DuplicateMatch {
  final String bmNumber;
  final Map<String, dynamic> row;

  const DuplicateMatch({required this.bmNumber, required this.row});

  String field(String key) => row[key]?.toString().trim() ?? '';

  DateTime? date(String key) => DateTime.tryParse(field(key));
}
