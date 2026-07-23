import 'package:ballys_reservation_app/models/guest_modal.dart';

/// One marketing-group summary row from Table1 of the inactive-members call.
/// Only Ballys (iid 1059006) returns this table; Bellagio (iid 9006) does not.
class InactiveMemberGroup {
  final String mGroup;
  final String gName;
  final int count;

  InactiveMemberGroup({
    required this.mGroup,
    required this.gName,
    required this.count,
  });

  factory InactiveMemberGroup.fromJson(Map<String, dynamic> json) {
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

    return InactiveMemberGroup(
      mGroup: getValue(['mGroup', 'MGROUP']) ?? '',
      gName: getValue(['GName', 'GNAME']) ?? '',
      count: int.tryParse(getValue(['rc', 'RC']) ?? '0') ?? 0,
    );
  }
}

/// Both tables of the inactive-members response: the member rows (Table) and,
/// for Ballys, the marketing-group counts (Table1).
class InactiveMembersResult {
  final List<Guest> members;
  final List<InactiveMemberGroup> groups;

  InactiveMembersResult({required this.members, required this.groups});

  /// Members belonging to [mGroup], used when a group is tapped on the
  /// Ballys group list.
  List<Guest> membersOfGroup(String mGroup) =>
      members.where((g) => (g.mGroup ?? '') == mGroup).toList();
}
