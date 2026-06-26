import 'dart:convert';

import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:ballys_reservation_app/models/reservation/new_reservation.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
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

      return DateTime.now();
    }
  }

  Future<Map<String, List<Reservation>>> getReservations() async {
    final deviceId = await DeviceId.get();
      final spName = await StorageUtil.getStoredProcedureName();
     print('Using stored procedure: $spName');
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9019,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text30",
          "Para_Type": "varchar",
        },
      ],
      "SpName": spName,
      "con": "1",
    });
print('Response from getReservations API: $response');
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      Map<String, List<Reservation>> classifiedReservations = {
        'Pending': [],
        'Approved': [],
        'Rejected': [],
        'Checked': [],
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
          case 'Checked':
            classifiedReservations['Checked']?.add(reservation);
            break;
          case 'Rejected':
            classifiedReservations['Rejected']?.add(reservation);
            break;
        }
      }



      return classifiedReservations;
    } else {
      throw Exception('Unexpected response structure');
    }
  }

  Future<Reservation?> saveReservation(NewReservation newReservation) async {
    final salesCode = await StorageUtil.getSalesCode();
    final userName = await StorageUtil.getUserName();
    final deviceId = await DeviceId.get();
print("test");
    final requestBody = {
      'bm_number': newReservation.bmNumber,
      'guest_name': newReservation.guestName,
      'arrival_date': newReservation.arrivalDate?.toIso8601String(),
      'departure_date': newReservation.departureDate?.toIso8601String(),
      'no_of_nights': newReservation.noOfNights,
      'has_air_ticket_reservation': newReservation.hasAirTicketReservation == '1',
      'remarks': newReservation.remarks,
      'manual_reserv_no': newReservation.reservationnewnumber,
      'package_amount': double.tryParse(newReservation.packageAmount ?? '0') ?? 0.0,
      'selected_marketing_person':"",
      'sales_code': salesCode,
      'user_name': userName,
      'device_id': deviceId,
      'room_details': newReservation.roomDetails,
      'air_ticket_details': newReservation.airTicketDetails,
      'guests': newReservation.guests,
      'passport_images': newReservation.passportImages,
    };

    printLargeBody(jsonEncode(requestBody));

    final response = await apiService.post('Reservation_InsertReservation', requestBody);
print(response);
    final status = response['Status'] as bool? ?? false;
    if (status) {
      return Reservation.fromJson({
        'Reserv_No': response['ReservationId']?.toString() ?? '',
      });
    } else {
      throw Exception(response['Message'] ?? 'Failed to save reservation');
    }
  }

  Future<Reservation?> updateReservation(NewReservation newReservation) async {
    final salesCode = await StorageUtil.getSalesCode();
    final userName = await StorageUtil.getUserName();
    final deviceId = await DeviceId.get();

    final requestBody = {
      'bm_number': newReservation.bmNumber,
      'guest_name': newReservation.guestName,
      'arrival_date': newReservation.arrivalDate?.toIso8601String(),
      'departure_date': newReservation.departureDate?.toIso8601String(),
      'no_of_nights': newReservation.noOfNights,
      'has_air_ticket_reservation': newReservation.hasAirTicketReservation == '1',
      'remarks': newReservation.remarks,
      'reservation_no': newReservation.reservationNo,
      'manual_reserv_no': newReservation.reservationnewnumber,
      'package_amount': double.tryParse(newReservation.packageAmount ?? '0') ?? 0.0,
      'selected_marketing_person': newReservation.selectedMarketingPerson,
      'sales_code': salesCode,
      'user_name': userName,
      'device_id': deviceId,
      'room_details': newReservation.roomDetails,
      'air_ticket_details': newReservation.airTicketDetails,
      'guests': newReservation.guests,
      'passport_images': newReservation.passportImages,
    };

    printLargeBody(jsonEncode(requestBody));

    final response = await apiService.post('UpdateReservation', requestBody);

    if (response['Table'] is List && (response['Table'] as List).isNotEmpty) {
      final table = response['Table'][0];
      final reservationResponse = Reservation.fromJson(table);
      if (reservationResponse.reservNo != '') return reservationResponse;
      return null;
    } else {
      throw Exception('Unexpected response structure');
    }
  }
  // Add this method to your ReservationRepository class

  Future<bool> approveOrRejectReservation({
    required String memberID,
    required String reservationNo,
    required String currentUName,
    required String status,
    required String remarks,

  }) async {
    final deviceId = await DeviceId.get();
    final spName = await StorageUtil.getStoredProcedureName();
print('Approving/Rejecting reservation with status: $status');
print('Member ID: $memberID, Reservation No: $reservationNo, Current User: $currentUName, Remarks: $remarks');
    final requestBody = {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 8014,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": memberID,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": reservationNo,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text12",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": currentUName,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text13",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": status,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text14",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": remarks,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text15",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text30",
          "Para_Type": "varchar",
        },
      ],
      "SpName": spName,
      "con": "1",
    };


    printLargeBody(jsonEncode(requestBody));


    try {
      final response = await apiService.post('CommonExecute', requestBody);
print('Response from approve/reject API: $response');
      if (response['CommonResult'] != null) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
    
      return false;
    }
  }

  void printLargeBody(String body) {
    const chunkSize = 1024;
    for (int i = 0; i < body.length; i += chunkSize) {
     
    }
  }

  String formatArrivalAndDepartureDate(DateTime? date) {
    if (date == null) {
      throw Exception('Arrival / Departure date is null');
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
