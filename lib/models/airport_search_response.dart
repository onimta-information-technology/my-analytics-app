class Airport {
  final String? airportCode;
  final String? cityName;
  final String? airportName;
  final String? country;
  final String? countryAbbr;
  final double? worldAreaCode;

  Airport({
    this.airportCode,
    this.cityName,
    this.airportName,
    this.country,
    this.countryAbbr,
    this.worldAreaCode,
  });

  factory Airport.fromJson(Map<String, dynamic> json) {
    return Airport(
      airportCode: json['AirportCode'] as String?,
      cityName: json['Cityname'] as String?,
      airportName: json['AirportName'] as String?,
      country: json['Country'] as String?,
      countryAbbr: json['CountryAbbr'] as String?,
      worldAreaCode: (json['WorldAreaCode'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'AirportCode': airportCode,
      'Cityname': cityName,
      'AirportName': airportName,
      'Country': country,
      'CountryAbbr': countryAbbr,
      'WorldAreaCode': worldAreaCode,
    };
  }
}
