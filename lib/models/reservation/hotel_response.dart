class HotelResponse {
  final double hotelId;
  final String hotelName;

  HotelResponse({
    required this.hotelId,
    required this.hotelName,
  });

  factory HotelResponse.fromJson(Map<String, dynamic> json) {
    return HotelResponse(
      hotelId: json['Hotel_IID'],
      hotelName: json['HotelName'],
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'hotel': hotelId,
      'hotel_name': hotelName,
    };
  }
}
