class PrevGiftSummary {
  final String mid;
  final String chipType;
  final double amount;

  PrevGiftSummary({
    required this.mid,
    required this.chipType,
    required this.amount,
  });

  factory PrevGiftSummary.fromJson(Map<String, dynamic> json) {
    return PrevGiftSummary(
      mid: json['MID'] ?? '',
      chipType: json['Chip_Type'] ?? '',
      amount: (json['Amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}