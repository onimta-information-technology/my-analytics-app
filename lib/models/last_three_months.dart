/// Model for the SM-wise performance summary returned in `Table`
/// from `sp_CRM_Common_API` when called with `@Iid = 778899`.
class LastThreeMonthsPerformance {
  final String sm;
  final String smName;
  final double winLost;

  /// New registrations (new guest count) for this SM, straight from
  /// `N_Reg` in the API response — no longer derived from the detail rows.
  final int newReg;

  /// Old / existing registrations (old guest count) for this SM, from
  /// `O_Reg` in the API response.
  final int oldReg;

  const LastThreeMonthsPerformance({
    required this.sm,
    required this.smName,
    required this.winLost,
    this.newReg = 0,
    this.oldReg = 0,
  });

  /// Same sign convention as [MarketingPerformance] and the detail page:
  /// a NEGATIVE `WinLost` is a win for us (green bar, sorted to the top);
  /// a positive value is a loss (red bar).
  bool get isPositive => winLost < 0;

  /// Total guests for this SM = new + old registrations.
  int get totalReg => newReg + oldReg;

  /// Magnitude used for sorting/labels — mirrors
  /// MarketingPerformance.displayValue (absolute value, scaled by 100) so the
  /// widget's sort logic doesn't need to know the underlying field or sign.
  double get displayValue => winLost.abs() / 100;

  factory LastThreeMonthsPerformance.fromJson(Map<String, dynamic> json) {
    return LastThreeMonthsPerformance(
      sm: json['SM']?.toString() ?? '',
      smName: json['SM_Name']?.toString() ?? '',
      winLost: _toDouble(json['WinLost']),
      newReg: _toInt(json['N_Reg']),
      oldReg: _toInt(json['O_Reg']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

/// Model for the member-level breakdown returned in `Table1` from the
/// same call (Mem_Id / MDrop / CashOut / Comm / SM / SM_Name / M_Name /
/// PaidComm / BalanceComm / WinLost).
class LastThreeMonthsDetailedData {
  final String memId;
  final double mDrop;
  final double cashOut;
  final double comm;
  final String sm;
  final String smName;
  final String mName;
  final double paidComm;
  final double balanceComm;
  final double winLost;

  /// Guest status from `G_Status`: 1 means this member is a new member
  /// (show a "NEW" badge on the detail page); 0 is an existing member.
  final int gStatus;

  /// NEW columns — not present on every member row, so both are nullable and
  /// parsed defensively. `pkgStatus == 'Y'` drives the package badge in the UI.
  final double? gActDrop;
  final String? pkgStatus;

  /// Membership tier from `G_Rating` (GOLD / PLATINUM / DIAMOND / INFINITY / …).
  final String? gRating;

  const LastThreeMonthsDetailedData({
    required this.memId,
    required this.mDrop,
    required this.cashOut,
    required this.comm,
    required this.sm,
    required this.smName,
    required this.mName,
    required this.paidComm,
    required this.balanceComm,
    required this.winLost,
    this.gStatus = 0,
    this.gActDrop,
    this.pkgStatus,
    this.gRating,
  });

  /// Negative `WinLost` = win (green), matching the detail page's
  /// `_getAmountColor` and the SM-level row above.
  bool get isPositive => winLost < 0;

  /// True when this member is flagged as a new member (`G_Status == 1`).
  bool get isNewMember => gStatus == 1;

  /// True when the member has an active package (`PKG_Status == "Y"`).
  bool get hasPackage => (pkgStatus ?? '').trim().toUpperCase() == 'Y';

  /// Rating tier text ready for display. Null when the column is missing or
  /// blank so the UI can skip the badge.
  String? get ratingDisplay {
    final raw = (gRating ?? '').trim();
    return raw.isEmpty ? null : raw.toUpperCase();
  }

  factory LastThreeMonthsDetailedData.fromJson(Map<String, dynamic> json) {
    return LastThreeMonthsDetailedData(
      memId: json['Mem_Id']?.toString() ?? '',
      mDrop: _toDouble(json['MDrop']),
      cashOut: _toDouble(json['CashOut']),
      comm: _toDouble(json['Comm']),
      sm: json['SM']?.toString() ?? '',
      smName: json['SM_Name']?.toString() ?? '',
      mName: json['M_Name']?.toString() ?? '',
      paidComm: _toDouble(json['PaidComm']),
      balanceComm: _toDouble(json['BalanceComm']),
      winLost: _toDouble(json['WinLost']),
      gStatus: _toInt(json['G_Status']),
      // Absent on members without a package — leave null when the key is missing.
      gActDrop:
          json.containsKey('G_ActDrop') ? _toDouble(json['G_ActDrop']) : null,
      pkgStatus:
          json.containsKey('PKG_Status') ? json['PKG_Status']?.toString() : null,
      gRating:
          json.containsKey('G_Rating') ? json['G_Rating']?.toString() : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}