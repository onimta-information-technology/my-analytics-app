class GuestGift {
  final String mid;
  final String memberName;
  final String expireDate;
  final double amount;
  final String categoryCode;
  final String gName;
  final String? lvd;
  final String? gRating;
  final String mobile;
  final String? mGroup;

  GuestGift({
    required this.mid,
    required this.memberName,
    required this.expireDate,
    required this.amount,
    required this.categoryCode,
    required this.gName,
     this.lvd,
     this.gRating,
     this.mobile = "",
      this.mGroup,
  });

  factory GuestGift.fromJson(Map<String, dynamic> json) {
    return GuestGift(
      mid: json['MID'],
      memberName: json['MNAME'],
      expireDate: json['D_EXP_DATE'],
      amount: json['AMT'],
      categoryCode: json['CatCode'],
      gName: json['GName'],
      lvd: json['LVD'],
      gRating: json['G_Rating'],
      mobile: json['Mobile'] ?? "",
      mGroup: json['MGroup'],

    );
  }
}
