class TripHistory {
  final double consecutiveDates;
  final String arrivalDate;
  final String departureDate;
  final double tripDrop;
  final double tripCashOut;
  final double tripResult;
  final double tripCommission;
  final double tripActDrop;
  final double tripTotalCoupon;
  final double tripHour;
  final double tripMinutes;

  TripHistory({
    required this.consecutiveDates,
    required this.arrivalDate,
    required this.departureDate,
    required this.tripDrop,
    required this.tripCashOut,
    required this.tripResult,
    required this.tripCommission,
    required this.tripActDrop,
    required this.tripTotalCoupon,
    required this.tripHour,
    required this.tripMinutes,
  });

  factory TripHistory.fromJson(Map<String, dynamic> json) {
    return TripHistory(
      consecutiveDates: json['ConsecutiveDates'],
      arrivalDate: json['ArrivalDate'],
      departureDate: json['DepartureDate'],
      tripDrop: json['Trip_Drop'],
      tripCashOut: json['Trip_CashOut'],
      tripResult: json['Trip_Result'],
      tripCommission: json['Trip_Commission'],
      tripActDrop: json['Trip_ActDrop'],
      tripTotalCoupon: json['Trip_TotalCoupon'],
      tripHour: json['Trip_Hour'],
      tripMinutes: json['Trip_Minutes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ConsecutiveDates': consecutiveDates,
      'ArrivalDate': arrivalDate,
      'DepartureDate': departureDate,
      'Trip_Drop': tripDrop,
      'Trip_CashOut': tripCashOut,
      'Trip_Result': tripResult,
      'Trip_Commission': tripCommission,
      'Trip_ActDrop': tripActDrop,
      'Trip_TotalCoupon': tripTotalCoupon,
      'Trip_Hour': tripHour,
      'Trip_Minutes': tripMinutes,
    };
  }
}
