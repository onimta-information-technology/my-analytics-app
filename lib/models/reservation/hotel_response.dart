class HotelResponse {
  final double hotelId;
  final String hotelName;

  HotelResponse({
    required this.hotelId,
    required this.hotelName,
  });

  factory HotelResponse.fromJson(Map<String, dynamic> json) {
    return HotelResponse(
      hotelId: _toDouble(json['Hotel_IID']),
      hotelName: json['HotelName']?.toString() ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'hotel': hotelId,
      'hotel_name': hotelName,
    };
  }
}