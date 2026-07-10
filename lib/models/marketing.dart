// Robust scalar parsing. The CommonExecute API sometimes returns numeric/text
// columns as the wrong JSON type — e.g. an empty object `{}` (seen on Bellagio
// when a member has no marketing group) or a number-as-string. A bare
// `as num?` cast would throw on those and blank the whole target tab.
double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
  return 0;
}

String _toStr(dynamic v) {
  if (v is String) return v;
  if (v == null || v is Map || v is List) return '';
  return v.toString();
}

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
      gcode: _toStr(json['Gcode']),
      gName: _toStr(json['GName']),
      actualDrop: _toDouble(json['ActualDrop']),
      mTarget: _toDouble(json['M_Target']),
      achievement: _toDouble(json['Achievement']),
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
      idNo: _toDouble(json['Id_No']),
      mid: _toStr(json['MID']),
      mName: _toStr(json['MName']),
      tripNo: _toInt(json['TripNo']),
      arrivalDate: parseDate(json['ArrivalDate']),
      departureDate: parseDate(json['DepartureDate']),
      actualDrop: _toDouble(json['ActualDrop']),
      gcode: _toStr(json['Gcode']),
      gName: _toStr(json['GName']),
      mTarget: _toDouble(json['M_Target']),
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
  // NEW columns — not present on every member row, so both are nullable and
  // parsed defensively. `pkgStatus == 'Y'` drives the package badge in the UI.
  final double? gActDrop;
  final String? pkgStatus;

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
    this.gActDrop,
    this.pkgStatus,
  });

  // True when the member has an active package (PKG_Status == "Y").
  bool get hasPackage => (pkgStatus ?? '').trim().toUpperCase() == 'Y';

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
      // Absent on members without a package — leave null when the key is missing.
      gActDrop: json.containsKey('G_ActDrop')
          ? _toDouble(json['G_ActDrop'])
          : null,
      pkgStatus: json.containsKey('PKG_Status')
          ? _toStr(json['PKG_Status'])
          : null,
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
      if (gActDrop != null) 'G_ActDrop': gActDrop,
      if (pkgStatus != null) 'PKG_Status': pkgStatus,
    };
  }

  @override
  String toString() {
    return 'MarketingDetailedData{memId: $memId, mName: $mName, mDrop: $mDrop, cashOut: $cashOut, comm: $comm, paidComm: $paidComm, balanceComm: $balanceComm, winLost: $winLost, sm: $sm, smName: $smName, gActDrop: $gActDrop, pkgStatus: $pkgStatus}';
  }
}