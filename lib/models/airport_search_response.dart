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
      airportCode: _asString(json['AirportCode']),
      cityName: _asString(json['Cityname']),
      airportName: _asString(json['AirportName']),
      country: _asString(json['Country']),
      countryAbbr: _asString(json['CountryAbbr']),
      worldAreaCode: _asDouble(json['WorldAreaCode']),
    );
  }

  /// Coerces any JSON value to a nullable String without throwing on
  /// unexpected types (some rows in the airport feed send numbers/nulls).
  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Coerces any JSON value to a nullable double, tolerating numbers sent as
  /// strings. Returns null instead of throwing on unparseable values.
  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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
