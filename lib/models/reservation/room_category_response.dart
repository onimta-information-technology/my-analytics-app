class RoomCategoryResponse {
  final int? catCode;
  final String? catName;

  RoomCategoryResponse({
    this.catCode,
    this.catName,
  });

  factory RoomCategoryResponse.fromJson(Map<String, dynamic> json) {
    return RoomCategoryResponse(
      catCode: json['CatCode'],
      catName: json['CatName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'CatCode': catCode,
      'CatName': catName,
    };
  }
}
