class AirportCostResponse {
  final String? airLine;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final String? travelClass;
  final double? cost;
  final String? sector;
  final String? route01;
  final String? route02;
  final String? route03;
  final double? usRate;

  AirportCostResponse({
    this.airLine,
    this.arrivalDate,
    this.departureDate,
    this.travelClass,
    this.cost,
    this.sector,
    this.route01,
    this.route02,
    this.route03,
    this.usRate,
  });

  factory AirportCostResponse.fromJson(Map<String, dynamic> json) {
    return AirportCostResponse(
      airLine: json['AirLine'] as String?,
      arrivalDate: json['ArrivalDate'] != null
          ? DateTime.tryParse(json['ArrivalDate'])
          : null,
      departureDate: json['DepartureDate'] != null
          ? DateTime.tryParse(json['DepartureDate'])
          : null,
      travelClass: json['Class'] as String?,
      cost: json['Cost'] != null ? (json['Cost'] as num).toDouble() : null,
      sector: json['Sector'] as String?,
      route01: json['Route01'] as String?,
      route02: json['Route02'] as String?,
      route03: json['Route03'] as String?,
      usRate: json['USRate'] != null ? (json['USRate'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'AirLine': airLine,
      'ArrivalDate': arrivalDate?.toIso8601String(),
      'DepartureDate': departureDate?.toIso8601String(),
      'Class': travelClass,
      'Cost': cost,
      'Sector': sector,
      'Route01': route01,
      'Route02': route02,
      'Route03': route03,
      'USRate': usRate,
    };
  }
}
