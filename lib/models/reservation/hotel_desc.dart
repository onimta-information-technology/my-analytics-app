import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HotelDescip {
  final dynamic hotel;
  final String? hotelName;
  final int? roomCategoryId;
  final String? roomCategoryName;
  final int? roomTypeId;
  final String? roomTypeName;
  final int? guestCount;
  final dynamic selectedDateRange;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final int? childrenCount;
  final int? roomCount;
  final int? noOfNights;
  final dynamic selectedCost;
  final int? costIndex;
  final String? ecLcoFacility;
  final String? paymentBy;

  HotelDescip({
    this.hotel,
    this.hotelName,
    this.roomCategoryId,
    this.roomCategoryName,
    this.roomTypeId,
    this.roomTypeName,
    this.guestCount,
    this.selectedDateRange,
    this.arrivalDate,
    this.departureDate,
    this.childrenCount,
    this.roomCount,
    this.noOfNights,
    this.selectedCost,
    this.costIndex,
    this.ecLcoFacility,
    this.paymentBy,
  });

  factory HotelDescip.fromJson(Map<String, dynamic> json) {
    return HotelDescip(
      hotel: json['hotel'],
      hotelName: json['hotel_name'] as String?,
      roomCategoryId: _toInt(json['room_category']),
      roomCategoryName: json['room_category_name'] as String?,
      roomTypeId: _toInt(json['room_type']),
      roomTypeName: json['room_type_name'] as String?,
      guestCount: _toInt(json['guest_count']),
      selectedDateRange: _parseDateTimeRange(json['selected_date_range']),
      arrivalDate: _parseCustomDate(json['arrival_date']),
      departureDate: _parseCustomDate(json['departure_date']),
      childrenCount: _toInt(json['children_count']),
      roomCount: _toInt(json['room_count']),
      noOfNights: _toInt(json['no_of_nights']),
      selectedCost: _parseCost(json['selected_cost']),
      costIndex: _toInt(json['cost_index']),
      ecLcoFacility: json['ec_lco_facility'] as String?,
      paymentBy: json['payment_by'] as String?,
    );
  }

// Helper method to safely parse integers
  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
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
    if (dateString == null || dateString.isEmpty) return null;

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

  static DateTimeRange? _parseDateTimeRange(String? range) {
    if (range == null || range.isEmpty) return null;

    try {
      final parts = range.split('~').map((e) => e.trim()).toList();
      if (parts.length != 2) return null;

      final startDate = DateFormat('dd/MM/yyyy').parse(parts[0]);
      final endDate = DateFormat('dd/MM/yyyy').parse(parts[1]);

      return DateTimeRange(start: startDate, end: endDate);
    } catch (e) {
  
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'hotel': hotel,
      'hotel_name': hotelName,
      'room_category': roomCategoryId,
      'room_category_name': roomCategoryName,
      'room_type': roomTypeId,
      'room_type_name': roomTypeName,
      'guest_count': guestCount,
      'children_count': childrenCount,
      'room_count': roomCount,
      'no_of_nights': noOfNights,
      'arrival_date': arrivalDate?.toIso8601String(),
      'departure_date': departureDate?.toIso8601String(),
      'selected_cost': _parseCostToDouble(selectedCost),
      'cost_index': costIndex,
      'ec_lco_facility': ecLcoFacility,
      'payment_by': paymentBy,
    };
  }
}

// extension DateTimeRangeJson on DateTimeRange {
//   Map<String, dynamic> toJson() {
//     return {
//       'start': start.toIso8601String(),
//       'end': end.toIso8601String(),
//     };
//   }
// }
