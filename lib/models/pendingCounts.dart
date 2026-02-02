class PendingCounts {
  final int reservation; // P_Reservation
  final int otpGift; // P_Gift
  final int birthdayGift; // P_BGift

  const PendingCounts({
    this.reservation = 0,
    this.otpGift = 0,
    this.birthdayGift = 0,
  });

  factory PendingCounts.fromJson(Map<String, dynamic> json) {
    return PendingCounts(
      reservation: (json['P_Reservation'] as num?)?.toInt() ?? 0,
      otpGift: (json['P_Gift'] as num?)?.toInt() ?? 0,
      birthdayGift: (json['P_BGift'] as num?)?.toInt() ?? 0,
    );
  }
}