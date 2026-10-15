// lib/models/unfollow_item.dart

import 'package:ballys_reservation_app/models/follow_up_item.dart';

/// A single unfollow record returned by `GetAllUnfollowup`, together with the
/// original follow-up it closed (the nested `followup` object).
class UnfollowItem {
  final int unfollowupId;
  final int followupId;
  final String memberId;
  final String memberName;
  final String reason;
  final String? remarks;

  /// The user who unfollowed (`Login_By` on the wire).
  final String? loginBy;

  /// When the member was unfollowed. Null when the API sends no date.
  final DateTime? createdDate;

  /// The original follow-up, or null when the API omits it.
  final FollowUpItem? followUp;

  const UnfollowItem({
    required this.unfollowupId,
    required this.followupId,
    required this.memberId,
    required this.memberName,
    required this.reason,
    this.remarks,
    this.loginBy,
    this.createdDate,
    this.followUp,
  });

  static DateTime? _parseDate(Map<String, dynamic> json) {
    for (final key in const ['CreatedDate', 'InsertDate']) {
      final raw = json[key];
      if (raw is String && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  factory UnfollowItem.fromJson(Map<String, dynamic> json) {
    final followUpJson = json['followup'] ?? json['Followup'];
    return UnfollowItem(
      unfollowupId: (json['UnfollowupId'] as num?)?.toInt() ?? 0,
      followupId: (json['FollowupId'] as num?)?.toInt() ?? 0,
      memberId: json['MId'] as String? ?? '',
      memberName: json['MName'] as String? ?? '',
      reason: json['Reason'] as String? ?? '',
      remarks: json['Remarks'] as String?,
      loginBy: (json['Login_By'] ?? json['LoginBy'])?.toString(),
      createdDate: _parseDate(json),
      followUp: followUpJson is Map<String, dynamic>
          ? FollowUpItem.fromJson(followUpJson)
          : null,
    );
  }
}
