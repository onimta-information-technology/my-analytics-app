import 'dart:convert';

import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:ballys_reservation_app/models/reservation/new_reservation.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:intl/intl.dart';

class ReservationRepository {
  final ApiService apiService;

  ReservationRepository(this.apiService);

  DateTime parseCustomDate(String dateString) {
    try {
      DateFormat format = DateFormat('yyyy/MM/dd');
      return format.parse(dateString);
    } catch (e) {
      print('Error parsing date: $e');
      return DateTime.now();
    }
  }

  Future<Map<String, List<Reservation>>> getReservations() async {
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9019,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int"
        }
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1"
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      Map<String, List<Reservation>> classifiedReservations = {
        'Pending': [],
        'Approved': [],
        'Rejected': [],
      };

      for (var json in tableData) {
        Reservation reservation = Reservation.fromJson(json);

        switch (reservation.requestStatus) {
          case 'Pending':
            classifiedReservations['Pending']?.add(reservation);
            break;
          case 'Approved':
            classifiedReservations['Approved']?.add(reservation);
            break;
          case 'Rejected':
            classifiedReservations['Rejected']?.add(reservation);
            break;
        }
      }

      print(classifiedReservations);

      return classifiedReservations;
    } else {
      throw Exception('Unexpected response structure');
    }
  }

  Future<Reservation?> saveReservation(NewReservation newReservation) async {
    final salesCode = await StorageUtil.getSalesCode();
    final userName = await StorageUtil.getUserName();

    final requestBody = {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9013,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int"
        },
        {
          "Para_Data": newReservation.bmNumber,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": newReservation.guestName,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": jsonEncode(newReservation.roomDetails),
          "Para_Direction": "Input",
          "Para_Lenth": 5000,
          "Para_Name": "@Text3",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": newReservation.noOfNights.toString(),
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text4",
          "Para_Type": "varchar"
        },
        {
          "Para_Data":
              formatArrivalAndDepartureDate(newReservation.arrivalDate),
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text5",
          "Para_Type": "varchar"
        },
        {
          "Para_Data":
              formatArrivalAndDepartureDate(newReservation.departureDate),
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text6",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": newReservation.hasAirTicketReservation,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text7",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": newReservation.remarks,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text8",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": jsonEncode(newReservation.airTicketDetails),
          "Para_Direction": "Input",
          "Para_Lenth": 5000,
          "Para_Name": "@Text9",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": salesCode,
          "Para_Direction": "Input",
          "Para_Lenth": 1000,
          "Para_Name": "@Text10",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": userName,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text11",
          "Para_Type": "varchar"
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1"
    };

    print("################ requestBody #####################");
    printLargeBody(jsonEncode(requestBody));
    print("#####################################");

    final response = await apiService.post('CommonExecute', requestBody);

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final table = response['CommonResult']['Table'][0];

      Reservation reservationResponse = Reservation.fromJson(table);

      // print("#################### reservationResponse reservationResponse");
      // print(reservationResponse);
      // print("####################");
      if (reservationResponse.reservNo != "") {
        return reservationResponse;
      }
      return null;
    } else {
      throw Exception('Unexpected response structure');
    }
  }

  Future<Reservation?> updateReservation(NewReservation newReservation) async {
    final salesCode = await StorageUtil.getSalesCode();
    final userName = await StorageUtil.getUserName();

    final requestBody = {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 8013,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int"
        },
        {
          "Para_Data": newReservation.bmNumber,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": newReservation.guestName,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": jsonEncode(newReservation.roomDetails),
          "Para_Direction": "Input",
          "Para_Lenth": 5000,
          "Para_Name": "@Text3",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": newReservation.noOfNights.toString(),
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text4",
          "Para_Type": "varchar"
        },
        {
          "Para_Data":
              formatArrivalAndDepartureDate(newReservation.arrivalDate),
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text5",
          "Para_Type": "varchar"
        },
        {
          "Para_Data":
              formatArrivalAndDepartureDate(newReservation.departureDate),
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text6",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": newReservation.hasAirTicketReservation,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text7",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": newReservation.remarks,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text8",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": jsonEncode(newReservation.airTicketDetails),
          "Para_Direction": "Input",
          "Para_Lenth": 5000,
          "Para_Name": "@Text9",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": salesCode,
          "Para_Direction": "Input",
          "Para_Lenth": 1000,
          "Para_Name": "@Text10",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": userName,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text11",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": newReservation.reservationNo,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text12",
          "Para_Type": "varchar"
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1"
    };

    print("################ requestBody #####################");
    printLargeBody(jsonEncode(requestBody));
    print("#####################################");

    final response = await apiService.post('CommonExecute', requestBody);

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final table = response['CommonResult']['Table'][0];

      Reservation reservationResponse = Reservation.fromJson(table);

      // print("#################### reservationResponse reservationResponse");
      // print(reservationResponse);
      // print("####################");
      if (reservationResponse.reservNo != "") {
        return reservationResponse;
      }
      return null;
    } else {
      throw Exception('Unexpected response structure');
    }
  }

  void printLargeBody(String body) {
    const chunkSize = 1024;
    for (int i = 0; i < body.length; i += chunkSize) {
      print(body.substring(
          i, i + chunkSize > body.length ? body.length : i + chunkSize));
    }
  }

  String formatArrivalAndDepartureDate(DateTime? date) {
    if (date == null) {
      throw Exception('Arrival / Departure date is null');
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
