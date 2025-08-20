class RoomTypeResponse {
  final int? id;
  final String? roomType;
  final String? mealPlan;

  RoomTypeResponse({
    this.id,
    this.roomType,
    this.mealPlan,
  });

  factory RoomTypeResponse.fromJson(Map<String, dynamic> json) {
    return RoomTypeResponse(
      id: json['ID'],
      roomType: json['RoomType'] as String?,
      mealPlan: json['MealPlan'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': id,
      'RoomType': roomType,
      'MealPlan': mealPlan,
    };
  }
}
