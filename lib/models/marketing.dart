class MarketingPerformance {
  final String sm;
  final String smName;
  final double winLost;
  final bool isPositive;
  final double displayValue; // Value in K format

  MarketingPerformance({
    required this.sm,
    required this.smName,
    required this.winLost,
    required this.isPositive,
    required this.displayValue,
  });

  factory MarketingPerformance.fromJson(Map<String, dynamic> json) {
    final winLostValue = (json['WinLost'] as num?)?.toDouble() ?? 0.0;
    final isPositiveValue = winLostValue < 0;
    final displayValueK = winLostValue.abs() / 100;

    return MarketingPerformance(
      sm: json['SM']?.toString() ?? '',
      smName: json['SM_Name']?.toString() ?? '',
      winLost: winLostValue,
      isPositive: isPositiveValue,
      displayValue: displayValueK,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SM': sm,
      'SM_Name': smName,
      'WinLost': winLost,
      'isPositive': isPositive,
      'displayValue': displayValue,
    };
  }

  @override
  String toString() {
    return 'MarketingPerformance{sm: $sm, smName: $smName, winLost: $winLost, isPositive: $isPositive, displayValue: $displayValue}';
  }
}

// NEW: Model for Table2 (Result data)
class MarketingResult {
  final String sm;
  final String smName;
  final double mDrop;
  final double cashOut;
  final double winLost;
  final bool isPositive;
  final double displayValue;

  MarketingResult({
    required this.sm,
    required this.smName,
    required this.mDrop,
    required this.cashOut,
    required this.winLost,
    required this.isPositive,
    required this.displayValue,
  });

  factory MarketingResult.fromJson(Map<String, dynamic> json) {
    final winLostValue = (json['WinLost'] as num?)?.toDouble() ?? 0.0;
    final isPositiveValue = winLostValue < 0;
    final displayValueK = winLostValue.abs() / 100;

    return MarketingResult(
      sm: json['SM']?.toString() ?? '',
      smName: json['SM_Name']?.toString() ?? '',
      mDrop: (json['MDrop'] as num?)?.toDouble() ?? 0.0,
      cashOut: (json['CashOut'] as num?)?.toDouble() ?? 0.0,
      winLost: winLostValue,
      isPositive: isPositiveValue,
      displayValue: displayValueK,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SM': sm,
      'SM_Name': smName,
      'MDrop': mDrop,
      'CashOut': cashOut,
      'WinLost': winLost,
      'isPositive': isPositive,
      'displayValue': displayValue,
    };
  }

  @override
  String toString() {
    return 'MarketingResult{sm: $sm, smName: $smName, mDrop: $mDrop, cashOut: $cashOut, winLost: $winLost, isPositive: $isPositive, displayValue: $displayValue}';
  }
}

// Complete detailed marketing data model with all fields from Table1
class MarketingDetailedData {
  final String memId;
  final String mName; // Member name
  final double mDrop;
  final double cashOut;
  final double comm;
  final double paidComm; // Paid commission
  final double balanceComm; // Balance commission
  final double winLost; // Actual win/lost value from Table1
  final String sm;
  final String smName;

  MarketingDetailedData({
    required this.memId,
    required this.mName,
    required this.mDrop,
    required this.cashOut,
    required this.comm,
    required this.paidComm,
    required this.balanceComm,
    required this.winLost,
    required this.sm,
    required this.smName,
  });

  factory MarketingDetailedData.fromJson(Map<String, dynamic> json) {
    return MarketingDetailedData(
      memId: json['Mem_Id']?.toString() ?? '',
      mName: json['M_Name']?.toString() ?? '',
      mDrop: (json['MDrop'] as num?)?.toDouble() ?? 0.0,
      cashOut: (json['CashOut'] as num?)?.toDouble() ?? 0.0,
      comm: (json['Comm'] as num?)?.toDouble() ?? 0.0,
      paidComm: (json['PaidComm'] as num?)?.toDouble() ?? 0.0,
      balanceComm: (json['BalanceComm'] as num?)?.toDouble() ?? 0.0,
      winLost: (json['WinLost'] as num?)?.toDouble() ?? 0.0,
      sm: json['SM']?.toString() ?? '',
      smName: json['SM_Name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Mem_Id': memId,
      'M_Name': mName,
      'MDrop': mDrop,
      'CashOut': cashOut,
      'Comm': comm,
      'PaidComm': paidComm,
      'BalanceComm': balanceComm,
      'WinLost': winLost,
      'SM': sm,
      'SM_Name': smName,
    };
  }

  @override
  String toString() {
    return 'MarketingDetailedData{memId: $memId, mName: $mName, mDrop: $mDrop, cashOut: $cashOut, comm: $comm, paidComm: $paidComm, balanceComm: $balanceComm, winLost: $winLost, sm: $sm, smName: $smName}';
  }
}