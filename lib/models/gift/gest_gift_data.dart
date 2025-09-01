class GestGiftData {
  final double guestDrop;
  final double guestCoupon;
  final double tmpCashout;
  final double res;
  final double actD;
  final double tmpCommpaid;
  final double tmpAvgBet;
  final double tmphh;
  final String grt;
  final double tmpPoint;
  final String mktP;
  final String gRating;
  final double flushCoupon;
  final double flushActDrop;

  GestGiftData({
    required this.guestDrop,
    required this.guestCoupon,
    required this.tmpCashout,
    required this.res,
    required this.actD,
    required this.tmpCommpaid,
    required this.tmpAvgBet,
    required this.tmphh,
    required this.grt,
    required this.tmpPoint,
    required this.mktP,
    required this.gRating,
    required this.flushCoupon,
    required this.flushActDrop,
  });

  factory GestGiftData.fromJson(Map<String, dynamic> json) {
    return GestGiftData(
      guestDrop: (json['Guest_Drop'] ?? 0).toDouble(),
      guestCoupon: (json['Guest_Coupon']?? 0).toDouble(),
      tmpCashout: (json['tmpCashOut']?? 0).toDouble(),
      res: (json['Res']?? 0).toDouble(),
      actD: (json['Act_D']?? 0).toDouble(),
      tmpCommpaid: (json['tmpCommPaid']?? 0).toDouble(),
      tmpAvgBet: (json['tmpAvgBet']?? 0).toDouble(),
      tmphh: (json['tmpHH']?? 0).toDouble(),
      grt: json['G_RT']?? '',
      tmpPoint: (json['tmpPoints'] ?? 0).toDouble(),
      mktP: json['Mkt_P']?? '',
      gRating: json['G_Rating'] ?? '',
       flushCoupon: (json['Flush_Coupon'] ?? 0).toDouble(),
        flushActDrop: (json['FlushAct_Drop'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Guest_Drop': guestDrop,
      'Guest_Coupon': guestCoupon,
      'tmpCashOut': tmpCashout,
      'Res': res,
      'Act_D': actD,
      'tmpCommPaid': tmpCommpaid,
      'tmpAvgBet': tmpAvgBet,
      'tmpHH': tmphh,
      'G_RT': grt,
      'tmpPoints': tmpPoint,
      'Mkt_P': mktP,
      'G_Rating': gRating,
      'Flush_Coupon': flushCoupon,
      'FlushAct_Drop': flushActDrop,
    };
  }
}
