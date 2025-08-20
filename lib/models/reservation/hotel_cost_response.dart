class HotelCostResponse {
  final String? idx;
  final String? hotel;
  final String? catName;
  final String? roomType;
  final String? mealPlan;
  final String? checkIn;
  final String? checkOut;
  final int? rooms;
  final int? nights;
  final double? netRate;
  final double? commission;
  final double? ourRate;
  final double? extraBedRate;
  final double? usRate;

  HotelCostResponse({
    this.idx,
    this.hotel,
    this.catName,
    this.roomType,
    this.mealPlan,
    this.checkIn,
    this.checkOut,
    this.rooms,
    this.nights,
    this.netRate,
    this.commission,
    this.ourRate,
    this.extraBedRate,
    this.usRate,
  });

  // Factory constructor to create an instance from JSON
  factory HotelCostResponse.fromJson(Map<String, dynamic> json) {
    return HotelCostResponse(
      idx: json['IDX'] as String?,
      hotel: json['Hotel'] as String?,
      catName: json['CatName'] as String?,
      roomType: json['RoomType'] as String?,
      mealPlan: json['MealPlan'] as String?,
      checkIn: json['CheckIN'] as String,
      checkOut: json['CheckOut'] as String,
      rooms: json['Rooms'] as int?,
      nights: json['Nights'] as int?,
      netRate: (json['netRate'] as num?)?.toDouble(),
      commission: (json['Comm'] as num?)?.toDouble(),
      ourRate: (json['OurRate'] as num?)?.toDouble(),
      extraBedRate: (json['ExtraBedRate'] as num?)?.toDouble(),
      usRate: (json['USRate'] as num?)?.toDouble(),
    );
  }

  // Method to convert an instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'IDX': idx,
      'Hotel': hotel,
      'CatName': catName,
      'RoomType': roomType,
      'MealPlan': mealPlan,
      'CheckIN': checkIn,
      'CheckOut': checkOut,
      'Rooms': rooms,
      'Nights': nights,
      'netRate': netRate,
      'Comm': commission,
      'OurRate': ourRate,
      'ExtraBedRate': extraBedRate,
      'USRate': usRate,
    };
  }
}
