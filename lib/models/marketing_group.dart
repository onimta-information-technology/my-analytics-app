class MarketingGroup {
  final String gCode;
  final String gName;
  final int rc;

  MarketingGroup({
    required this.gCode,
    required this.gName,
    required this.rc,
  });

  factory MarketingGroup.fromJson(Map<String, dynamic> json) {
    return MarketingGroup(
      gCode: json['GCode']?.toString() ?? '',
      gName: json['GName']?.toString() ?? '',
      rc: int.tryParse(json['rc']?.toString() ?? '0') ?? 0,
    );
  }
}