// models/birthday_gift_model.dart

class BirthdayGiftResponse {
  final String mid;
  final String gift;
  final String mobile;

  BirthdayGiftResponse({
    required this.mid,
    required this.gift,
    required this.mobile,
  });

  factory BirthdayGiftResponse.fromJson(Map<String, dynamic> json) {
    return BirthdayGiftResponse(
      mid: json['MID'] ?? '',
      gift: json['GIFT'] ?? '',
      mobile: json['Mobile'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'MID': mid,
      'GIFT': gift,
      'Mobile': mobile,
    };
  }
}