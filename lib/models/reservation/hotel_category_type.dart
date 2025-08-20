class Hotel {
  final double hotelIID;
  final String hotelName;

  Hotel({required this.hotelIID, required this.hotelName});
}

class HotelCategory {
  final int catCode;
  final String catName;

  HotelCategory({required this.catCode, required this.catName});
}

class HotelType {
  final int roomTypeID;
  final String roomType;
  final String mealPlan;

  HotelType(
      {required this.roomTypeID,
      required this.roomType,
      required this.mealPlan});
}
