class RedeemLocation {
  final int idNo;
  final String location;
  final String commLoca;

  RedeemLocation({
    required this.idNo,
    required this.location,
    required this.commLoca,
  });

  factory RedeemLocation.fromJson(Map<String, dynamic> json) {
    final lowerJson = {
      for (final e in json.entries) e.key.toLowerCase(): e.value
    };

    String? getValue(List<String> keys) {
      for (final key in keys) {
        final v = lowerJson[key.toLowerCase()];
        if (v != null) return v.toString();
      }
      return null;
    }

    return RedeemLocation(
      idNo: num.tryParse(getValue(['ID_NO', 'IDNO']) ?? '')?.toInt() ?? 0,
      location: getValue(['Loca', 'LOCATION']) ?? '',
      commLoca: getValue(['CommLoca', 'COMM_LOCA']) ?? '',
    );
  }
}
