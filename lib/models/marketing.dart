class MarketingPerformance {
  final String sm;
  final String smName;
  final double winLost;
  final bool isPositive;
  final double displayValue;

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

// NEW: Summary row from Table1 — one entry per SM/group
class MarketingTarget {
  final String gcode;
  final String gName;
  final double actualDrop;
  final double mTarget;
  final double achievement; // percentage

  MarketingTarget({
    required this.gcode,
    required this.gName,
    required this.actualDrop,
    required this.mTarget,
    required this.achievement,
  });

  factory MarketingTarget.fromJson(Map<String, dynamic> json) {
    return MarketingTarget(
      gcode: json['Gcode']?.toString() ?? '',
      gName: json['GName']?.toString() ?? '',
      actualDrop: (json['ActualDrop'] as num?)?.toDouble() ?? 0.0,
      mTarget: (json['M_Target'] as num?)?.toDouble() ?? 0.0,
      achievement: (json['Achievement'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'Gcode': gcode,
        'GName': gName,
        'ActualDrop': actualDrop,
        'M_Target': mTarget,
        'Achievement': achievement,
      };

  @override
  String toString() =>
      'MarketingTarget{gcode: $gcode, gName: $gName, actualDrop: $actualDrop, mTarget: $mTarget, achievement: $achievement}';
}

// NEW: Detail row from Table (individual member trips)
class MarketingTargetDetail {
  final double idNo;
  final String mid;
  final String mName;
  final int tripNo;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final double actualDrop;
  final String gcode;
  final String gName;
  final double mTarget;

  MarketingTargetDetail({
    required this.idNo,
    required this.mid,
    required this.mName,
    required this.tripNo,
    this.arrivalDate,
    this.departureDate,
    required this.actualDrop,
    required this.gcode,
    required this.gName,
    required this.mTarget,
  });

  factory MarketingTargetDetail.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return MarketingTargetDetail(
      idNo: (json['Id_No'] as num?)?.toDouble() ?? 0.0,
      mid: json['MID']?.toString() ?? '',
      mName: json['MName']?.toString() ?? '',
      tripNo: (json['TripNo'] as num?)?.toInt() ?? 0,
      arrivalDate: parseDate(json['ArrivalDate']),
      departureDate: parseDate(json['DepartureDate']),
      actualDrop: (json['ActualDrop'] as num?)?.toDouble() ?? 0.0,
      gcode: json['Gcode']?.toString() ?? '',
      gName: json['GName']?.toString() ?? '',
      mTarget: (json['M_Target'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'Id_No': idNo,
        'MID': mid,
        'MName': mName,
        'TripNo': tripNo,
        'ArrivalDate': arrivalDate?.toIso8601String(),
        'DepartureDate': departureDate?.toIso8601String(),
        'ActualDrop': actualDrop,
        'Gcode': gcode,
        'GName': gName,
        'M_Target': mTarget,
      };

  @override
  String toString() =>
      'MarketingTargetDetail{mid: $mid, mName: $mName, tripNo: $tripNo, actualDrop: $actualDrop}';
}

class MarketingDetailedData {
  final String memId;
  final String mName;
  final double mDrop;
  final double cashOut;
  final double comm;
  final double paidComm;
  final double balanceComm;
  final double winLost;
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