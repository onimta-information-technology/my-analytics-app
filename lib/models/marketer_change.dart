/// One marketer-change request from `GetAllMarketerChange`.
class MarketerChange {
  final int changeId;
  final String mId;
  final String mName;
  final String prvMPerson;
  final String prvMGroup;
  final String remark;
  final String reqMPerson;
  final String reqSalesCode;
  final String reqMCode;
  final String approvalStatus;
  final DateTime? insertDate;
  final List<MarketerChangeImage> images;

  const MarketerChange({
    required this.changeId,
    required this.mId,
    required this.mName,
    required this.prvMPerson,
    required this.prvMGroup,
    required this.remark,
    required this.reqMPerson,
    required this.reqSalesCode,
    required this.reqMCode,
    required this.approvalStatus,
    required this.insertDate,
    required this.images,
  });

  factory MarketerChange.fromJson(Map<String, dynamic> json) {
    final images = json['Images'];
    return MarketerChange(
      changeId: _parseInt(json['ChangeId']),
      mId: _text(json['MId']),
      mName: _text(json['MName']),
      prvMPerson: _text(json['PrvMPerson']),
      prvMGroup: _text(json['PrvMGroup']),
      remark: _text(json['Remark']),
      reqMPerson: _text(json['ReqMPerson']),
      reqSalesCode: _text(json['ReqSalesCode']),
      reqMCode: _text(json['ReqMCode']),
      approvalStatus: _text(json['ApprovalStatus']),
      insertDate: _parseDate(json['InsertDate'] ?? json['CreatedDate']),
      images: images is List
          ? images
              .whereType<Map>()
              .map((e) =>
                  MarketerChangeImage.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

/// An entry of `Images`. [filePath] is relative to the host root.
class MarketerChangeImage {
  final int id;
  final String fileName;
  final bool isPdf;
  final String filePath;

  const MarketerChangeImage({
    required this.id,
    required this.fileName,
    required this.isPdf,
    required this.filePath,
  });

  factory MarketerChangeImage.fromJson(Map<String, dynamic> json) {
    final filePath = _text(json['FilePath']);
    return MarketerChangeImage(
      id: _parseInt(json['Id']),
      fileName: _text(json['FileName']),
      isPdf: json['IsPdf'] == true || filePath.toLowerCase().endsWith('.pdf'),
      filePath: filePath,
    );
  }
}

String _text(dynamic value) => value?.toString().trim() ?? '';

int _parseInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
