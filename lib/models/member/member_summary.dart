class MemberSummary {
  final String descrip;
  final String inAmount;
  final String outAmount;
  final String tDate;
  final String tTime;
  final String cur;
  final String insertDate;
  final int rn;

  MemberSummary({
    required this.descrip,
    required this.inAmount,
    required this.outAmount,
    required this.tDate,
    required this.tTime,
    required this.cur,
    required this.insertDate,
    required this.rn,
  });

  factory MemberSummary.fromJson(Map<String, dynamic> json) {
    return MemberSummary(
      descrip: json['Descrip'] ?? '',
      inAmount: json['In'] ?? '',
      outAmount: json['Out'] ?? '',
      tDate: json['TDate'] ?? '',
      tTime: json['TTime'] ?? '',
      cur: json['Cur'] ?? '',
      insertDate: json['InsertDate'] ?? '',
      rn: json['RN'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Descrip': descrip,
      'In': inAmount,
      'Out': outAmount,
      'TDate': tDate,
      'TTime': tTime,
      'Cur': cur,
      'InsertDate': insertDate,
      'RN': rn,
    };
  }
}

class MemberSummaryTable1 {
  final double mDrop;
  final double cashOut;
  final double res;

  MemberSummaryTable1({
    required this.mDrop,
    required this.cashOut,
    required this.res,
  });

  factory MemberSummaryTable1.fromJson(Map<String, dynamic> json) {
    return MemberSummaryTable1(
      mDrop: (json['M_Drop'] ?? 0).toDouble(),
      cashOut: (json['Cash_Out'] ?? 0).toDouble(),
      res: (json['Res'] ?? 0).toDouble(),
    );
  }
}

class MemberSummaryResult {
  final List<MemberSummary> table;
  final MemberSummaryTable1? table1;

  MemberSummaryResult({
    required this.table,
    this.table1,
  });
}