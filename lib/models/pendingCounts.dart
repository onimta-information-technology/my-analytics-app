class PendingCounts {
  final int reservation; // P_Reservation, or StatusCounts totals.pending on Ballys
  final int otpGift; // P_Gift
  final int birthdayGift; // P_BGift

  /// Pending count per reservation type from `StatusCounts/Get`, keyed by the
  /// API's `feature` (`reservation`, `group_reservation`, `visa_request`,
  /// `airport_service`, `transport`). Empty when that API was not called.
  final Map<String, int> featurePending;

  const PendingCounts({
    this.reservation = 0,
    this.otpGift = 0,
    this.birthdayGift = 0,
    this.featurePending = const {},
  });

  factory PendingCounts.fromJson(Map<String, dynamic> json) {
    return PendingCounts(
      reservation: (json['P_Reservation'] as num?)?.toInt() ?? 0,
      otpGift: (json['P_Gift'] as num?)?.toInt() ?? 0,
      birthdayGift: (json['P_BGift'] as num?)?.toInt() ?? 0,
    );
  }

  int pendingFor(String feature) => featurePending[feature] ?? 0;

  PendingCounts copyWith({int? reservation, Map<String, int>? featurePending}) {
    return PendingCounts(
      reservation: reservation ?? this.reservation,
      otpGift: otpGift,
      birthdayGift: birthdayGift,
      featurePending: featurePending ?? this.featurePending,
    );
  }
}
