class GiftType {
  final String code;


  GiftType({required this.code});

  factory GiftType.fromJson(Map<String, dynamic> json) {
    return GiftType(
      code: json['GIFT_CODE'] ?? ''
    );
  }
}
