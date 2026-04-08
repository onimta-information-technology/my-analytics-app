// lib/models/cdd/cdd_history_item.dart

class CddHistoryItem {
  final int idNo;
  final String text1; // Passport/NIC type
  final String text2; // ID number
  final String text3; // Source of funds
  final String text4; // Client type
  final String text5; // Nature of business
  final String text6; // Submitted by
  final String text30; // Device ID
  final String insertDate;

  const CddHistoryItem({
    required this.idNo,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.text5,
    required this.text6,
    required this.text30,
    required this.insertDate,
  });

  factory CddHistoryItem.fromJson(Map<String, dynamic> json) {
    return CddHistoryItem(
      idNo: json['Id_No'] as int,
      text1: json['Text_1'] as String? ?? '',
      text2: json['Text_2'] as String? ?? '',
      text3: json['Text_3'] as String? ?? '',
      text4: json['Text_4'] as String? ?? '',
      text5: json['Text_5'] as String? ?? '',
      text6: json['Text_6'] as String? ?? '',
      text30: json['Text_30'] as String? ?? '',
      insertDate: json['InsertDate'] as String? ?? '',
    );
  }
}