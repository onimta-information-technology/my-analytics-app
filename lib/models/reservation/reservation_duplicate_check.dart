/// What `Reservation_CheckDuplicate` found for a new reservation, sorted by
/// what the screen does about it:
///
/// * [hotelDuplicates] — a guest already has a pending stay at the same hotel
///   on the same dates. The reservation is not saved.
/// * [airTicketDuplicates] — a guest already has a pending ticket on the same
///   dates between the same airports. The reservation is not saved.
/// * [airTicketWarnings] — the backend's `other_air_ticket_overlaps`: tickets
///   in the same date range on other sectors. Informational only — shown to
///   the user, then the reservation is saved. These arrive even when
///   `has_duplicates` is false.
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
    if (duplicates is List) {
      for (final guest in duplicates.whereType<Map<String, dynamic>>()) {
        final bm = guest['bm_number']?.toString() ?? '';
        List<DuplicateMatch> matches(String key) => _rows(guest[key])
            .map((row) => DuplicateMatch(bmNumber: bm, row: row))
            .toList();

        hotels.addAll(matches('hotel_duplicates'));
        tickets.addAll(matches('air_ticket_duplicates'));
        warnings.addAll(matches('other_air_ticket_overlaps'));
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
}

/// One clash against an existing reservation, as the backend sent it.
class DuplicateMatch {
  final String bmNumber;
  final Map<String, dynamic> row;

  const DuplicateMatch({required this.bmNumber, required this.row});

  String field(String key) => row[key]?.toString().trim() ?? '';

  DateTime? date(String key) => DateTime.tryParse(field(key));
}
