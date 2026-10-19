import 'package:ballys_reservation_app/models/guest_modal.dart';

/// One row of the logged-in user's own inactive members (Ballys, iid 885263).
class MyInactiveMember {
  final String mid;
  final String memberName;
  final String rating;
  final int ratingId;
  final String country;

  /// Last visit date. Null when the API sends no / an unparsable date.
  final DateTime? lastVisitDate;
  final String lastVisitRaw;

  const MyInactiveMember({
    required this.mid,
    required this.memberName,
    required this.rating,
    required this.ratingId,
    required this.country,
    required this.lastVisitDate,
    required this.lastVisitRaw,
  });

  factory MyInactiveMember.fromJson(Map<String, dynamic> json) {
    final lowerJson = {
      for (final e in json.entries) e.key.toLowerCase(): e.value,
    };

    String? getValue(List<String> keys) {
      for (final key in keys) {
        final v = lowerJson[key.toLowerCase()];
        if (v != null) return v.toString();
      }
      return null;
    }

    final lvd = getValue(['LVD']) ?? '';
    return MyInactiveMember(
      mid: (getValue(['MID']) ?? '').trim(),
      memberName: (getValue(['MName', 'MNAME']) ?? '').trim(),
      // The SP spells the column "G_Raing"; accept the correct spelling too.
      rating: (getValue(['G_Raing', 'G_Rating']) ?? '').trim().toUpperCase(),
      ratingId:
          num.tryParse(getValue(['G_RatingID']) ?? '')?.toInt() ?? 0,
      country: (getValue(['Country']) ?? '').trim(),
      lastVisitDate: DateTime.tryParse(lvd),
      lastVisitRaw: lvd,
    );
  }

  /// Guest used to open the member profile.
  Guest toGuest() => Guest(
        mid: mid,
        memberName: memberName,
        country: country,
        lastVisitDate: lastVisitRaw,
        age: 0,
        gRating: rating.isEmpty ? null : rating,
        mGroup: null,
        gName: null,
      );
}
