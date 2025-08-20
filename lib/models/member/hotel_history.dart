class HotelHistory {
  final String resNo;
  final String checkIn;
  final String checkOut;
  final String hotel;
  final String checkInFor;
  final String checkOutFor;
  final String requestBy;
  final String status;
  final String payIns;
  final String extra;
  final String special;
  final String rem;
  final String catName;
  final String roomType;
  final String mealPlan;
  final int rooms;
  final int nights;
  final int adults;

  HotelHistory({
    required this.resNo,
    required this.checkIn,
    required this.checkOut,
    required this.hotel,
    required this.checkInFor,
    required this.checkOutFor,
    required this.requestBy,
    required this.status,
    required this.payIns,
    required this.extra,
    required this.special,
    required this.rem,
    required this.catName,
    required this.roomType,
    required this.mealPlan,
    required this.rooms,
    required this.nights,
    required this.adults,
  });

  factory HotelHistory.fromJson(Map<String, dynamic> json) {
    return HotelHistory(
      resNo: json['Res_No'],
      checkIn: json['CheckIn'],
      checkOut: json['CheckOut'],
      hotel: json['Hotel'],
      checkInFor: json['CheckInFor'],
      checkOutFor: json['CheckOutFor'],
      requestBy: json['RequestBy'],
      status: json['Status'],
      payIns: json['PayIns'],
      extra: json['Extra'],
      special: json['Special'],
      rem: json['Rem'],
      catName: json['CatName'],
      roomType: json['RoomType'],
      mealPlan: json['MealPlan'],
      rooms: json['Rooms'],
      nights: json['Nights'],
      adults: json['Adults'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Res_No': resNo,
      'CheckIn': checkIn,
      'CheckOut': checkOut,
      'Hotel': hotel,
      'CheckInFor': checkInFor,
      'CheckOutFor': checkOutFor,
      'RequestBy': requestBy,
      'Status': status,
      'PayIns': payIns,
      'Extra': extra,
      'Special': special,
      'Rem': rem,
      'CatName': catName,
      'RoomType': roomType,
      'MealPlan': mealPlan,
      'Rooms': rooms,
      'Nights': nights,
      'Adults': adults,
    };
  }
}
