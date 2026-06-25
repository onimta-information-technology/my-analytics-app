import 'package:ballys_reservation_app/models/airport_search_response.dart';
import 'package:intl/intl.dart';

class FlightBooking {
  final int guestCount;
  final FlightAirport? airports;
  final int airTicketClass;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final int silkRoute;
  final int airportTransportation;
  final String airTicketClassName;
  final bool isRoundTrip;
  final dynamic selectedCost;
  final String? airLine;
  final String? contactPerson;
  final bool visa;

  FlightBooking({
    required this.guestCount,
    required this.airports,
    required this.airTicketClass,
    required this.arrivalDate,
    required this.departureDate,
    required this.silkRoute,
    required this.airportTransportation,
    required this.airTicketClassName,
    required this.isRoundTrip,
    required this.selectedCost,
    this.airLine,
    this.contactPerson,
    this.visa = false,
  });

  factory FlightBooking.fromJson(Map<String, dynamic> json) {
    return FlightBooking(
      guestCount: json['guest_count'] ?? 0,
      airports: json['airports'] != null
          ? FlightAirport.fromJson(json['airports'])
          : null,
      airTicketClass: json['air_ticket_class'] ?? 0,
      arrivalDate: _parseCustomDate(json['arrival_date']),
      departureDate: _parseCustomDate(json['departure_date']),
      silkRoute: json['silk_route'] ?? '',
      airportTransportation: json['airport_transportation'] ?? 0,
      airTicketClassName: json['air_ticket_class_name'] ?? '',
      isRoundTrip: json['is_round_trip'] ?? false,
      selectedCost: _parseCost(json['selected_cost']),
      airLine: json['air_line'] as String?,
      contactPerson: json['contact_person'] as String?,
      visa: json['visa'] as bool? ?? false,
    );
  }

  static String? _parseCost(dynamic cost) {
    if (cost == null) return null;
    if (cost is num) {
      return NumberFormat("#,##0")
          .format(cost)
          .toString(); // return cost.toDouble();
    }
    // if (cost is String) return double.tryParse(cost);
    return "";
  }

  static double? _parseCostToDouble(dynamic cost) {
    if (cost is num) return cost.toDouble();
    if (cost is String) {
      return double.tryParse(cost.replaceAll(',', ''));
    }
    return null;
  }

  static DateTime? _parseCustomDate(String? dateString) {
    if (dateString == null) return null;

    try {
      return DateFormat('dd/MM/yyyy').parse(dateString);
    } catch (e) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
       
        return null;
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'GuestCount': guestCount,
      'AirTicketClass': airTicketClass,
      'AirTicketClassName': airTicketClassName,
      'AirLine': airLine,
      'ContactPerson': contactPerson,
      'Visa': visa,
      'IsRoundTrip': isRoundTrip,
      'SilkRoute': silkRoute,
      'AirportTransportation': airportTransportation,
      'ArrivalDate': arrivalDate?.toIso8601String(),
      'DepartureDate': departureDate?.toIso8601String(),
      'SelectedCost': _parseCostToDouble(selectedCost),
      // Departure leg — flattened
      'DF_AirportCode': airports?.departure?.dFrom.airportCode,
      'DF_CityName': airports?.departure?.dFrom.cityName,
      'DF_AirportName': airports?.departure?.dFrom.airportName,
      'DF_Country': airports?.departure?.dFrom.country,
      'DT_AirportCode': airports?.departure?.dTo.airportCode,
      'DT_CityName': airports?.departure?.dTo.cityName,
      'DT_AirportName': airports?.departure?.dTo.airportName,
      'DT_Country': airports?.departure?.dTo.country,
      // Return leg — flattened (null when one-way)
      'RF_AirportCode': airports?.returnFlight?.rFrom.airportCode,
      'RF_CityName': airports?.returnFlight?.rFrom.cityName,
      'RF_AirportName': airports?.returnFlight?.rFrom.airportName,
      'RF_Country': airports?.returnFlight?.rFrom.country,
      'RT_AirportCode': airports?.returnFlight?.rTo.airportCode,
      'RT_CityName': airports?.returnFlight?.rTo.cityName,
      'RT_AirportName': airports?.returnFlight?.rTo.airportName,
      'RT_Country': airports?.returnFlight?.rTo.country,
    };
  }
}

class FlightAirport {
  Departure? departure;
  ReturnFlight? returnFlight;

  FlightAirport({
    this.departure,
    this.returnFlight,
  });

  factory FlightAirport.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? safeParse(dynamic value) {
      return value is Map<String, dynamic> ? value : null;
    }

 

    return FlightAirport(
      departure: safeParse(json['departure']) != null
          ? Departure.fromJson(json['departure'])
          : null,
      returnFlight: safeParse(json['return_']) != null
          ? ReturnFlight.fromJson(json['return_'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'departure': departure?.toJson(),
      'return_': returnFlight?.toJson(),
    };
  }
}

class Departure {
  AirportInfo dFrom;
  AirportInfo dTo;

  Departure({
    required this.dFrom,
    required this.dTo,
  });

  factory Departure.fromJson(Map<String, dynamic> json) {
    return Departure(
      dFrom: AirportInfo.fromJson(json['d_from'], prefix: 'df_'),
      dTo: AirportInfo.fromJson(json['d_to'], prefix: 'dt_'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'd_from': dFrom.toCustomJson('df_'),
      'd_to': dTo.toCustomJson('dt_'),
    };
  }
}

class ReturnFlight {
  AirportInfo rFrom;
  AirportInfo rTo;

  ReturnFlight({
    required this.rFrom,
    required this.rTo,
  });

  factory ReturnFlight.fromJson(Map<String, dynamic> json) {
    return ReturnFlight(
      rFrom: AirportInfo.fromJson(json['r_from'], prefix: 'rf_'),
      rTo: AirportInfo.fromJson(json['r_to'], prefix: 'rt_'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'r_from': rFrom.toCustomJson('rf_'),
      'r_to': rTo.toCustomJson('rt_'),
    };
  }
}

class AirportInfo {
  String airportCode;
  String cityName;
  String airportName;
  String country;

  AirportInfo({
    required this.airportCode,
    required this.cityName,
    required this.airportName,
    required this.country,
  });

  factory AirportInfo.fromJson(Map<String, dynamic> json,
      {String prefix = ''}) {
    return AirportInfo(
      airportCode: json['${prefix}AirportCode'] ?? '',
      cityName: json['${prefix}Cityname'] ?? '',
      airportName: json['${prefix}AirportName'] ?? '',
      country: json['${prefix}Country'] ?? '',
    );
  }

  Airport toAirport() {
    return Airport(
      airportCode: airportCode,
      cityName: cityName,
      airportName: airportName,
      country: country,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'airportCode': airportCode,
      'cityName': cityName,
      'airportName': airportName,
      'country': country,
    };
  }

  Map<String, dynamic> toCustomJson(String prefix) {
    return {
      '${prefix}AirportCode': airportCode,
      '${prefix}Cityname': cityName,
      '${prefix}AirportName': airportName,
      '${prefix}Country': country,
    };
  }
}
