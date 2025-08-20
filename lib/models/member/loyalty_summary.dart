import 'package:intl/intl.dart';

class LoyaltySummary {
  final String mid;
  final String name;
  final int totalPoints;
  final int ballysRuppes;
  final String ballysRuppesExpireMessage;
  final int ballysCoins;
  final String ballysCoinsExpireMessage;
  final String lastUpdateDateTime;
  final String lastRedeemType;
  final int lastRedeemAmount;
  final String lastRedeemDate;
  final String lastRedeemTime;

  LoyaltySummary({
    required this.mid,
    required this.name,
    required this.totalPoints,
    required this.ballysRuppes,
    required this.ballysRuppesExpireMessage,
    required this.ballysCoins,
    required this.ballysCoinsExpireMessage,
    required this.lastUpdateDateTime,
    required this.lastRedeemType,
    required this.lastRedeemAmount,
    required this.lastRedeemDate,
    required this.lastRedeemTime,
  });

  factory LoyaltySummary.fromJson(Map<String, dynamic> json) {
    return LoyaltySummary(
      mid: json['Mid'] as String,
      name: json['Name'] as String,
      totalPoints: json['TotalPoints'] as int,
      ballysRuppes: json['BallysRuppes'] as int,
      ballysRuppesExpireMessage: json['BallysRuppesExpireMessage'] as String,
      ballysCoins: json['BallysCoins'] as int,
      ballysCoinsExpireMessage: json['BallysCoinsExpireMessage'] as String,
      lastUpdateDateTime: json['LastUpdateDateTime'],
      lastRedeemType: json['LastRedeemType'] as String,
      lastRedeemAmount: json['LastRedeemAmount'] as int,
      lastRedeemDate: json['LastRedeemDate'],
      lastRedeemTime: json['LastRedeemTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Mid': mid,
      'Name': name,
      'TotalPoints': _parseNumberFormat(totalPoints),
      'BallysRuppes': _parseNumberFormat(ballysRuppes),
      'BallysRuppesExpireMessage': ballysRuppesExpireMessage,
      'BallysCoins': _parseNumberFormat(ballysCoins),
      'BallysCoinsExpireMessage': ballysCoinsExpireMessage,
      'LastUpdateDateTime': lastUpdateDateTime,
      'LastRedeemType': lastRedeemType,
      'LastRedeemAmount': _parseNumberFormat(lastRedeemAmount),
      'LastRedeemDate': lastRedeemDate,
      'LastRedeemTime': lastRedeemTime,
    };
  }

  String? _parseNumberFormat(int? value) {
    if (value == null || value == "") return "0.00";
    final formatter = NumberFormat('#,##0');
    String formattedNumber = formatter.format(value);
    return formattedNumber;
  }
}
