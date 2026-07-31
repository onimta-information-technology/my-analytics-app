import 'package:ballys_reservation_app/models/airport_search_response.dart';
import 'package:intl/intl.dart';

class FlightBookingBallys {
  final int guestCount;

  /// Children travelling on the ticket. Counted separately from [guestCount],
  /// which stays the adult count.
  final int childrenCount;

  /// Infants travelling on the ticket.
  final int infantCount;
  final FlightAirport? airports;
  final int airTicketClass;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final int silkRoute;
  final int airportTransportation;
  final String airTicketClassName;
  final bool isRoundTrip;
  final dynamic selectedCost;

  /// The airline picked from the master list (API 90156) — its name, its code
  /// ("AIR0015") and its IATA code ("TG"). All three are sent on save.
  final String? airLine;
  final String? airLineCode;
  final String? iataCode;
  final String? contactPerson;
  final bool visa;
  final bool meal;
  final bool extraLegroomSeat;
  final bool goldRoute;

  /// Which leg the Silk Route facility applies to — "Arrival" or "Departure".
  /// Only meaningful while [silkRoute] is 1.
  final String? silkRouteType;

  /// Which leg the Gold Route facility applies to — "Arrival" or "Departure".
  /// Only meaningful while [goldRoute] is true.
  final String? goldRouteType;

  /// Free-text meal requirement, captured only when [meal] is true.
  final String? mealRemark;

  /// The guest is not flying direct — the ticket routes through one or more
  /// transit airports. Only meaningful together with [departureSectors] /
  /// [returnSectors].
  final bool isMultiSector;

  /// Transit airports on the outbound leg, in travel order. They sit *between*
  /// `airports.departure.dFrom` and `airports.departure.dTo`, which stay the
  /// origin and the final destination.
  final List<AirportInfo> departureSectors;

  /// Transit airports on the return leg, in travel order, between
  /// `airports.return_.rFrom` and `airports.return_.rTo`.
  final List<AirportInfo> returnSectors;

  FlightBookingBallys({
    required this.guestCount,
    this.childrenCount = 0,
    this.infantCount = 0,
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
    this.airLineCode,
    this.iataCode,
    this.contactPerson,
    this.visa = false,
    this.meal = false,
    this.extraLegroomSeat = false,
    this.goldRoute = false,
    this.silkRouteType,
    this.goldRouteType,
    this.mealRemark,
    this.isMultiSector = false,
    this.departureSectors = const [],
    this.returnSectors = const [],
  });

  /// Outbound airport codes in travel order — origin, every transit stop, then
  /// the final destination. Blank codes are dropped so a partly filled flight
  /// still reads sensibly.
  List<String> get departureRouteCodes {
    final departure = airports?.departure;
    if (departure == null) return const [];
    return [
      departure.dFrom.airportCode,
      ...departureSectors.map((sector) => sector.airportCode),
      departure.dTo.airportCode,
    ].where((code) => code.trim().isNotEmpty).toList();
  }

  /// Return leg codes in travel order. Empty when the flight is one-way.
  List<String> get returnRouteCodes {
    final returnLeg = airports?.returnFlight;
    if (returnLeg == null) return const [];
    return [
      returnLeg.rFrom.airportCode,
      ...returnSectors.map((sector) => sector.airportCode),
      returnLeg.rTo.airportCode,
    ].where((code) => code.trim().isNotEmpty).toList();
  }

  /// e.g. "CMB → DXB → LHR" — the whole outbound leg on one line.
  String get departureRouteText => departureRouteCodes.join(' → ');

  /// e.g. "LHR → DOH → CMB". Empty when the flight is one-way.
  String get returnRouteText => returnRouteCodes.join(' → ');

  factory FlightBookingBallys.fromJson(Map<String, dynamic> json) {
    return FlightBookingBallys(
      guestCount: json['guest_count'] ?? 0,
      childrenCount: _toInt(json['children_count']),
      infantCount: _toInt(json['infant_count']),
      airports: json['airports'] != null
          ? FlightAirport.fromJson(json['airports'])
          : _parseFlatAirports(json),
      airTicketClass: json['air_ticket_class'] ?? 0,
      arrivalDate: _parseCustomDate(json['arrival_date']),
      departureDate: _parseCustomDate(json['departure_date']),
      silkRoute: json['silk_route'] ?? '',
      airportTransportation: json['airport_transportation'] ?? 0,
      airTicketClassName: json['air_ticket_class_name'] ?? '',
      isRoundTrip: json['is_round_trip'] ?? false,
      selectedCost: _parseCost(json['selected_cost']),
      airLine: json['air_line'] as String?,
      airLineCode: json['air_line_code'] as String?,
      iataCode: json['iata_code'] as String?,
      contactPerson: json['contact_person'] as String?,
      visa: json['visa'] as bool? ?? false,
      meal: json['meal'] as bool? ?? false,
      extraLegroomSeat: json['extra_leg_room_seat'] as bool? ?? false,
      goldRoute: json['gold_route'] as bool? ?? false,
      silkRouteType: json['silk_route_type'] as String?,
      goldRouteType: json['gold_route_type'] as String?,
      mealRemark: json['meal_remark'] as String?,
      isMultiSector: _toBool(json['is_multi_sector']),
      departureSectors: _parseSectors(json['departure_sectors']),
      returnSectors: _parseSectors(json['return_sectors']),
    );
  }

  /// The JSON-string payload gives real booleans; the flattened DB response
  /// gives 1/0 or "1"/"0".
  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == '1' || v == 'true' || v == 'yes';
    }
    return false;
  }

  /// Transit airports arrive either as full objects (our own payload) or as a
  /// bare list / comma-separated string of codes if the back office only keeps
  /// the codes.
  static List<AirportInfo> _parseSectors(dynamic value) {
    if (value == null) return const [];

    List<dynamic> items;
    if (value is List) {
      items = value;
    } else if (value is String) {
      if (value.trim().isEmpty) return const [];
      items = value.split(',');
    } else {
      return const [];
    }

    final sectors = <AirportInfo>[];
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        sectors.add(AirportInfo.fromSectorJson(item));
      } else if (item is Map) {
        sectors.add(AirportInfo.fromSectorJson(
            item.map((k, v) => MapEntry(k.toString(), v))));
      } else if (item is String && item.trim().isNotEmpty) {
        sectors.add(AirportInfo(
          airportCode: item.trim(),
          cityName: '',
          airportName: '',
          country: '',
        ));
      }
    }
    return sectors;
  }

  /// Child / infant counts come back as either a number or a string depending
  /// on the endpoint; missing means none.
  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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

  /// Builds a [FlightAirport] from the flattened `DF_/DT_/RF_/RT_` fields used
  /// by the Reservation_GetAllReservations response (which has no nested
  /// `airports` object). Returns null when none of the flat fields are present.
  static FlightAirport? _parseFlatAirports(Map<String, dynamic> json) {
    AirportInfo? mk(String prefix) {
      if (json['${prefix}_AirportCode'] == null) return null;
      return AirportInfo(
        airportCode: json['${prefix}_AirportCode'] as String? ?? '',
        cityName: json['${prefix}_CityName'] as String? ?? '',
        airportName: json['${prefix}_AirportName'] as String? ?? '',
        country: json['${prefix}_Country'] as String? ?? '',
      );
    }

    final dFrom = mk('DF');
    final dTo = mk('DT');
    final rFrom = mk('RF');
    final rTo = mk('RT');

    if (dFrom == null && dTo == null && rFrom == null && rTo == null) {
      return null;
    }

    return FlightAirport(
      departure: (dFrom != null && dTo != null)
          ? Departure(dFrom: dFrom, dTo: dTo)
          : null,
      returnFlight: (rFrom != null && rTo != null)
          ? ReturnFlight(rFrom: rFrom, rTo: rTo)
          : null,
    );
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
      'guest_count': guestCount,
      'children_count': childrenCount,
      'infant_count': infantCount,
      'air_ticket_class': airTicketClass,
      'air_ticket_class_name': airTicketClassName,
      'air_line': airLine,
      'air_line_code': airLineCode,
      'iata_code': iataCode,
      'contact_person': contactPerson,
      'visa': visa,
      'meal': meal,
      'extra_leg_room_seat': extraLegroomSeat,
      'gold_route': goldRoute,
      'is_round_trip': isRoundTrip,
      'silk_route': silkRoute,
      'silk_route_type': silkRoute == 1 ? (silkRouteType ?? '') : '',
      'gold_route_type': goldRoute ? (goldRouteType ?? '') : '',
      'meal_remark': meal ? (mealRemark ?? '') : '',
      'airport_transportation': airportTransportation,
      'arrival_date': arrivalDate?.toIso8601String(),
      'departure_date': departureDate?.toIso8601String(),
      'selected_cost': _parseCostToDouble(selectedCost),
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
      // Transit stops for guests with no direct flight. DF_/DT_ and RF_/RT_
      // above stay the leg endpoints, so anything reading only those keeps
      // working; the stops ride along in order.
      'is_multi_sector': isMultiSector,
      'departure_sectors':
          departureSectors.map((sector) => sector.toSectorJson()).toList(),
      'return_sectors':
          returnSectors.map((sector) => sector.toSectorJson()).toList(),
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

  /// A transit stop, keyed the same way as the flattened `DF_`/`DT_` fields
  /// minus the leg prefix.
  factory AirportInfo.fromSectorJson(Map<String, dynamic> json) {
    // Key casing differs between our payload ("CityName") and the nested
    // airport objects ("Cityname"), so match case-insensitively.
    final byLowerKey = <String, dynamic>{
      for (final entry in json.entries) entry.key.toLowerCase(): entry.value,
    };
    String read(String name) =>
        byLowerKey[name.toLowerCase()]?.toString() ?? '';

    return AirportInfo(
      airportCode: read('AirportCode'),
      cityName: read('CityName'),
      airportName: read('AirportName'),
      country: read('Country'),
    );
  }

  Map<String, dynamic> toSectorJson() {
    return {
      'AirportCode': airportCode,
      'CityName': cityName,
      'AirportName': airportName,
      'Country': country,
    };
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
