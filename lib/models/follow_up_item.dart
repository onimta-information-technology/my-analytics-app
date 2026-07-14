// lib/models/follow_up_item.dart

import 'dart:convert';
import 'dart:typed_data';

/// A single follow-up record returned by `GetAllFollowup`.
class FollowUpItem {
  final int followupId;
  final String memberId;
  final String memberName;
  final String description;
  final String contactStatus;
  final String? responseType;
  final String? customerResponse;
  final String? remarks;
  final List<String> checklistItems;
  final String? positiveStatus;

  /// The user who requested/saved the follow-up (`Login_By` on the wire).
  final String? loginBy;

  /// When the follow-up was saved. Null when the API sends no date.
  final DateTime? createdDate;

  /// Raw base64 photo. Decoded lazily via [photoBytes] — a follow-up list can
  /// hold dozens of these, so we only pay for the ones that get rendered.
  final String? photoBase64;

  Uint8List? _photoBytes;
  bool _photoDecoded = false;

  FollowUpItem({
    required this.followupId,
    required this.memberId,
    required this.memberName,
    required this.description,
    required this.contactStatus,
    this.responseType,
    this.customerResponse,
    this.remarks,
    this.checklistItems = const <String>[],
    this.positiveStatus,
    this.loginBy,
    this.createdDate,
    this.photoBase64,
  });

  bool get isPositive => responseType?.toLowerCase() == 'positive';
  bool get isNegative => responseType?.toLowerCase() == 'negative';

  /// Decoded photo, or null when there is none or the base64 is malformed.
  Uint8List? get photoBytes {
    if (_photoDecoded) return _photoBytes;
    _photoDecoded = true;
    final raw = photoBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      _photoBytes = base64Decode(raw);
    } catch (_) {
      _photoBytes = null;
    }
    return _photoBytes;
  }

  /// The insert posts `CreatedDate`, but the read endpoint has been seen to
  /// name it differently — try each known key and give up quietly if the date
  /// is missing or unparseable.
  static DateTime? _parseCreatedDate(Map<String, dynamic> json) {
    const keys = <String>[
      'CreatedDate',
      'InsertDate',
      'CreatedOn',
      'FollowupDate',
      'FollowUpDate',
    ];
    for (final key in keys) {
      final raw = json[key];
      if (raw is String && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  factory FollowUpItem.fromJson(Map<String, dynamic> json) {
    return FollowUpItem(
      followupId: (json['FollowupId'] as num?)?.toInt() ?? 0,
      memberId: json['MId'] as String? ?? '',
      memberName: json['MName'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      contactStatus: json['ContactStatus'] as String? ?? '',
      responseType: json['ResponseType'] as String?,
      customerResponse: json['CustomerResponse'] as String?,
      remarks: json['Remarks'] as String?,
      checklistItems: (json['ChecklistItems'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      positiveStatus: json['PositiveStatus'] as String?,
      loginBy: (json['Login_By'] ?? json['LoginBy'])?.toString(),
      createdDate: _parseCreatedDate(json),
      photoBase64: json['Photo'] as String?,
    );
  }
}
