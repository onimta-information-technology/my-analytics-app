class GuestGift {
  final String mid;
  final String memberName;
  final String expireDate;
  final String? issueDate;
  final double amount;
  final String categoryCode;
  final String gName;
  final String? lvd;
  final String? gRating;
  final String mobile;
  final String? mGroup;
  final int? rcNo;
  final String? srNo;

  GuestGift({
    required this.mid,
    required this.memberName,
    required this.expireDate,
    this.issueDate,
    required this.amount,
    required this.categoryCode,
    required this.gName,
     this.lvd,
     this.gRating,
     this.mobile = "",
      this.mGroup,
      this.rcNo,
      this.srNo,
  });

  factory GuestGift.fromJson(Map<String, dynamic> json) {
    // The SP returns the same column with different casing/types between calls
    // (e.g. AMT as 500 one time and 500.00 the next, RC_NO as int or decimal),
    // so look keys up case-insensitively and never cast the raw value directly.
    final lowerJson = {
      for (final e in json.entries) e.key.toLowerCase(): e.value
    };

    String? getValue(List<String> keys) {
      for (final key in keys) {
        final v = lowerJson[key.toLowerCase()];
        if (v != null) return v.toString();
      }
      return null;
    }

    /// Handles int, double and String ("500", "500.00", "1,500.00") payloads.
    double toDouble(String? raw) {
      if (raw == null || raw.isEmpty) return 0.0;
      return double.tryParse(raw.replaceAll(',', '')) ?? 0.0;
    }

    /// Same as [toDouble] but truncates, so "5.0" no longer parses to null.
    int? toInt(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      return num.tryParse(raw.replaceAll(',', ''))?.toInt();
    }

    return GuestGift(
      mid: getValue(['MID']) ?? '',
      memberName: getValue(['MNAME', 'MName']) ?? '',
      expireDate: getValue(['D_EXP_DATE']) ?? '',
      issueDate: getValue(['D_ISS_DATE', 'DISSDATE']),
      amount: toDouble(getValue(['AMT'])),
      categoryCode: getValue(['CatCode', 'CATCODE']) ?? '',
      gName: getValue(['GName', 'GNAME']) ?? '',
      lvd: getValue(['LVD']),
      gRating: getValue(['G_Rating', 'G_RATING']),
      mobile: getValue(['Mobile', 'MOBILE']) ?? '',
      mGroup: getValue(['MGroup', 'MGROUP', 'mGroup']),
      rcNo: toInt(getValue(['RC_NO', 'RCNO', 'RC'])),
      srNo: getValue(['Sr_No', 'SRNO', 'SR_NO']),
    );
  }
}
