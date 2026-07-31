/// One airline from the master list (API 90156). Only the name is shown to the
/// user; the codes ride along for whoever needs them later.
class AirlineResponse {
  final int? idNo;
  final String? airlineCode;
  final String airlineName;
  final String? iataCode;
  final bool isActive;

  AirlineResponse({
    this.idNo,
    this.airlineCode,
    required this.airlineName,
    this.iataCode,
    this.isActive = true,
  });

  factory AirlineResponse.fromJson(Map<String, dynamic> json) {
    return AirlineResponse(
      idNo: json['Id_No'] is num ? (json['Id_No'] as num).toInt() : null,
      airlineCode: json['AirlineCode'] as String?,
      airlineName: (json['AirlineName'] ?? '').toString(),
      iataCode: json['IATACode'] as String?,
      // Comes back as "1" / "0", but a numeric 1 / 0 reads the same way.
      isActive: json['IsActive']?.toString().trim() == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id_No': idNo,
      'AirlineCode': airlineCode,
      'AirlineName': airlineName,
      'IATACode': iataCode,
      'IsActive': isActive ? '1' : '0',
    };
  }
}
