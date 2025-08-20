class GuestGift {
  final String mid;
  final String memberName;
  final String expireDate;
  final double amount;
  final String categoryCode;

  GuestGift({
    required this.mid,
    required this.memberName,
    required this.expireDate,
    required this.amount,
    required this.categoryCode,
  });

  factory GuestGift.fromJson(Map<String, dynamic> json) {
    return GuestGift(
      mid: json['MID'],
      memberName: json['MNAME'],
      expireDate: json['D_EXP_DATE'],
      amount: json['AMT'],
      categoryCode: json['CatCode'],
    );
  }
}
