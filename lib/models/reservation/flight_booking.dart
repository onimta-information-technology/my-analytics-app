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
        print('Error parsing date: $e');
        return null;
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'guest_count': guestCount,
      'airports': airports?.toJson(),
      'air_ticket_class': airTicketClass,
      'arrival_date': arrivalDate?.toIso8601String(),
      'departure_date': departureDate?.toIso8601String(),
      'silk_route': silkRoute,
      'airport_transportation': airportTransportation,
      'air_ticket_class_name': airTicketClassName,
      'is_round_trip': isRoundTrip,
      'selected_cost': _parseCostToDouble(selectedCost),
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

    // print("################ json['departure'] ##################");
    // print(json['departure']);

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
