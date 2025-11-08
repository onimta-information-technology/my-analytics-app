import 'dart:convert';
import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';

class Reservation {
  int idNo;
  String reservNo;
  DateTime reservDate;
  String mid;
  String mName;
  int noOfNights;
  DateTime arrDate;
  DateTime depDate;
  String airticketReservationStatus;
  String remarks;
  String reqBy;
  DateTime insertDate;
  bool isApp;
  DateTime isAppTime;
  String? isAppBy;
  String requestStatus;
  String isAppRemarks;
  List<HotelDescip> hotelDescip;
  List<FlightBooking> airticketDescrip;
  String? lastEditBy;
  DateTime lastEditTime;
  String returnStatus;
  String? gRating;

  Reservation({
    required this.idNo,
    required this.reservNo,
    required this.reservDate,
    required this.mid,
    required this.mName,
    required this.noOfNights,
    required this.arrDate,
    required this.depDate,
    required this.airticketReservationStatus,
    required this.remarks,
    required this.reqBy,
    required this.insertDate,
    required this.isApp,
    required this.isAppTime,
    this.isAppBy,
    required this.requestStatus,
    required this.isAppRemarks,
    required this.hotelDescip,
    required this.airticketDescrip,
    this.lastEditBy,
    required this.lastEditTime,
    required this.returnStatus,
    required this.gRating,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? date) =>
        date != null ? DateTime.parse(date) : null;

    List<HotelDescip> parseHotelDescip(String? jsonStr) {
      if (jsonStr == null || jsonStr.isEmpty) return [];
      try {
        return (jsonDecode(jsonStr) as List)
            .map((item) => HotelDescip.fromJson(item))
            .toList();
      } catch (e) {
      
        return [];
      }
    }

    List<FlightBooking> parseAirticketDescrip(String? jsonStr) {
      if (jsonStr == null || jsonStr.isEmpty) return [];
      try {
        return (jsonDecode(jsonStr) as List)
            .map((item) => FlightBooking.fromJson(item))
            .toList();
      } catch (e) {
       
        return [];
      }
    }

    return Reservation(
      idNo: json['Id_No'] ?? 0,
      reservNo: json['Reserv_No'] as String? ?? '',
      reservDate: parseDate(json['Reserv_Date']) ?? DateTime.now(),
      mid: json['MID'] as String? ?? '',
      mName: json['MNAME'] as String? ?? '',
      noOfNights: json['NoOfNights'] ?? 0,
      arrDate: parseDate(json['Arr_Date']) ?? DateTime.now(),
      depDate: parseDate(json['Dep_Date']) ?? DateTime.now(),
      airticketReservationStatus:
          json['Airticket_Reservation_Status'] as String? ?? '',
      remarks: json['Remarks'] as String? ?? '',
      reqBy: json['Req_By'] as String? ?? '',
      insertDate: parseDate(json['InsertDate']) ?? DateTime.now(),
      isApp: json['Is_App'] ?? false,
      isAppTime: parseDate(json['Is_App_Time']) ?? DateTime.now(),
      isAppBy: json['Is_App_By'], // Nullable field
      requestStatus: json['Request_Status'] as String? ?? '',
      isAppRemarks: json['Is_App_Remarks'] as String? ?? '',
      hotelDescip: parseHotelDescip(json['Hotel_Descip']),
      airticketDescrip: parseAirticketDescrip(json['Airticket_Descrip']),
      lastEditBy: json['Last_Edit_By'],
      lastEditTime: parseDate(json['Last_Edit_Time']) ?? DateTime.now(),
      returnStatus: json['ReturnStatus'] as String? ?? '',
      gRating: json['G_Rating'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    String? formatDate(DateTime? date) => date?.toIso8601String();

    return {
      'Id_No': idNo,
      'Reserv_No': reservNo,
      'Reserv_Date': formatDate(reservDate),
      'MID': mid,
      'MNAME': mName,
      'NoOfNights': noOfNights,
      'Arr_Date': formatDate(arrDate),
      'Dep_Date': formatDate(depDate),
      'Airticket_Reservation_Status': airticketReservationStatus,
      'Remarks': remarks,
      'Req_By': reqBy,
      'InsertDate': formatDate(insertDate),
      'Is_App': isApp,
      'Is_App_Time': formatDate(isAppTime),
      'Is_App_By': isAppBy,
      'Request_Status': requestStatus,
      'Is_App_Remarks': isAppRemarks,
      'Hotel_Descip': hotelDescip.map((item) => item.toJson()).toList(),
      'Airticket_Descrip':
          airticketDescrip.map((item) => item.toJson()).toList(),
      'Last_Edit_By': lastEditBy,
      'Last_Edit_Time': formatDate(lastEditTime),
      'ReturnStatus': returnStatus,
      'G_Rating': gRating,
    };
  }

  // copyWith({required String status}) {}
}

void printLargeBody(String body) {
  const chunkSize = 1024;
  for (int i = 0; i < body.length; i += chunkSize) {
  
  }
}
