/// A guest a hotel room or an air ticket is booked for.
///
/// One room / ticket can be assigned to several guests of the same reservation,
/// so the assignment travels with the room / ticket rather than being implied by
/// whichever guest was on screen when it was picked. On save each assigned guest
/// gets their own row in `room_details` / `air_ticket_details`, tagged with their
/// BM number; the first assigned guest owns the row.
class AssignedGuest {
  final String mid;
  final String guestName;

  const AssignedGuest({required this.mid, this.guestName = ''});

  /// "BM0012 — John Doe", falling back to whichever half is filled in.
  String get label => [
        if (mid.trim().isNotEmpty) mid.trim(),
        if (guestName.trim().isNotEmpty) guestName.trim(),
      ].join(" — ");

  factory AssignedGuest.fromJson(Map<String, dynamic> json) {
    return AssignedGuest(
      mid: json['BMNumber']?.toString() ?? '',
      guestName: json['GuestName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'BMNumber': mid,
        'GuestName': guestName,
      };

  /// Reads an assignment list back off a saved row. Rows saved before the
  /// assignment existed — and rows the back office returns without it — come
  /// back empty, which callers read as "belongs to its BMNumber alone".
  static List<AssignedGuest> listFrom(dynamic value) {
    if (value is! List) return const [];
    final guests = <AssignedGuest>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        guests.add(AssignedGuest.fromJson(item));
      } else if (item is Map) {
        guests.add(AssignedGuest.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v))));
      } else if (item is String && item.trim().isNotEmpty) {
        // Only the BM numbers survived — enough to keep the assignment.
        guests.add(AssignedGuest(mid: item.trim()));
      }
    }
    return guests;
  }

  /// The BM numbers a row is assigned to, in tick order and without blanks.
  static List<String> bmNumbersOf(List<AssignedGuest> guests) {
    final seen = <String>{};
    for (final guest in guests) {
      final mid = guest.mid.trim();
      if (mid.isNotEmpty) seen.add(mid);
    }
    return seen.toList();
  }

  /// Which guest a saved room / ticket row hangs off: the first guest it is
  /// assigned to, falling back to the `BMNumber` rows carried before the
  /// assignment existed.
  static String ownerBmOf(Map<String, dynamic> row) {
    final bmNumbers = bmNumbersOf(listFrom(row['assigned_guests']));
    if (bmNumbers.isNotEmpty) return bmNumbers.first;
    return row['BMNumber']?.toString().trim() ?? '';
  }

  /// Whether this is the copy of the row to read.
  ///
  /// Rows are sent once, with their guests named inside them. Reservations
  /// saved while a shared room was instead repeated per guest — one copy per
  /// `BMNumber` — still come back that way, so only the copy belonging to the
  /// first assigned guest is taken and the room isn't counted, shown or
  /// re-saved twice.
  static bool isOwnerRow(Map<String, dynamic> row) {
    final bmNumbers = bmNumbersOf(listFrom(row['assigned_guests']));
    if (bmNumbers.isEmpty) return true;
    final rowBm = row['BMNumber']?.toString().trim() ?? '';
    // No BM number on the row means there are no copies to tell apart.
    if (rowBm.isEmpty) return true;
    return bmNumbers.first == rowBm;
  }
}
