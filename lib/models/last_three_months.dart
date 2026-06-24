/// Model for the SM-wise performance summary returned in `Table`
/// from `sp_CRM_Common_API` when called with `@Iid = 778899`.
class LastThreeMonthsPerformance {
  final String sm;
  final String smName;
  final double winLost;

  const LastThreeMonthsPerformance({
    required this.sm,
    required this.smName,
    required this.winLost,
  });

  bool get isPositive => winLost >= 0;

  /// Kept as its own getter (mirrors MarketingPerformance.displayValue)
  /// so the widget's sort logic doesn't need to know the underlying field.
  double get displayValue => winLost;

  factory LastThreeMonthsPerformance.fromJson(Map<String, dynamic> json) {
    return LastThreeMonthsPerformance(
      sm: json['SM']?.toString() ?? '',
      smName: json['SM_Name']?.toString() ?? '',
      winLost: _toDouble(json['WinLost']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
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
  });

  bool get isPositive => winLost >= 0;

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
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}