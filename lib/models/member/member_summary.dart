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
      descrip: json['Descrip'],
      inAmount: json['In'],
      outAmount: json['Out'],
      tDate: json['TDate'],
      tTime: json['TTime'],
      cur: json['Cur'],
      insertDate: json['InsertDate'],
      rn: json['RN'],
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
