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

  /// Marketing person the member belongs to (GCode / GName from the SP).
  /// Only passed on to the profile, not shown on the list.
  final String gCode;
  final String gName;

  const MyInactiveMember({
    required this.mid,
    required this.memberName,
    required this.rating,
    required this.ratingId,
    required this.country,
    required this.lastVisitDate,
    required this.lastVisitRaw,
    required this.gCode,
    required this.gName,
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
      gCode: (getValue(['GCode']) ?? '').trim(),
      gName: (getValue(['GName']) ?? '').trim(),
    );
  }

  /// Guest used to open the member profile, carrying the member's marketing
  /// person ([gCode] / [gName]). The fallbacks fill in when the SP sends them
  /// blank.
  Guest toGuest({String? fallbackMGroup, String? fallbackGName}) => Guest(
        mid: mid,
        memberName: memberName,
        country: country,
        lastVisitDate: lastVisitRaw,
        age: 0,
        gRating: rating.isEmpty ? null : rating,
        mGroup: gCode.isNotEmpty ? gCode : fallbackMGroup,
        gName: gName.isNotEmpty ? gName : fallbackGName,
      );
}
