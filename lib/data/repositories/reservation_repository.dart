import 'dart:convert';

import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:ballys_reservation_app/utils/amount_util.dart';
import 'package:ballys_reservation_app/models/reservation/new_reservation.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:intl/intl.dart';

class ReservationRepository {
  final ApiService apiService;

  ReservationRepository(this.apiService);

  /// Pretty-prints a request body to the terminal with the bulky base64
  /// passport data redacted, so the full structure stays readable instead of
  /// being truncated by the giant image blobs. Prints in chunks to avoid the
  /// platform logger cutting off long output.
  void debugPrintRequestBody(Map<String, dynamic> body) {
    final redacted = Map<String, dynamic>.from(body);
    final images = body['passport_images'];
    if (images is List) {
      redacted['passport_images'] = images.map((img) {
        if (img is Map) {
          final copy = Map<String, dynamic>.from(img);
          final data = copy['Base64Data'];
          if (data is String) {
            copy['Base64Data'] = '<base64: ${data.length} chars>';
          }
          return copy;
        }
        return img;
      }).toList();
    }

    final pretty = const JsonEncoder.withIndent('  ').convert(redacted);
    const chunkSize = 800;
    for (int i = 0; i < pretty.length; i += chunkSize) {
      final end = (i + chunkSize < pretty.length) ? i + chunkSize : pretty.length;
      print(pretty.substring(i, end));
    }
  }

  DateTime parseCustomDate(String dateString) {
    try {
      DateFormat format = DateFormat('yyyy/MM/dd');
      return format.parse(dateString);
    } catch (e) {

      return DateTime.now();
    }
  }

  Future<Map<String, List<Reservation>>> getReservations() async {
    final response = await apiService.get('Reservation_GetAllReservations');
    print('Response from getReservations API: $response');

    final Map<String, List<Reservation>> classifiedReservations = {
      'Pending': [],
      'Approved': [],
      'Rejected': [],
      'Checked': [],
    };

    final status = response['Status'] as bool? ?? false;
    final data = response['Data'];

    if (status && data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          // The new response carries no approval status, so every record is
          // treated as pending.
          classifiedReservations['Pending']!
              .add(Reservation.fromReservationData(item));
        }
      }
      return classifiedReservations;
    } else {
      throw Exception('Unexpected response structure');
    }
  }

  /// Fetches the predefined package amounts (e.g. `"IND 10,000"`,
  /// `"USD 25,000"`). Returns an empty list when the request fails or the
  /// payload is unexpected, so the caller can fall back to free-text entry.
  ///
  /// The endpoint differs per brand: Bellagio (bty.world) exposes it as
  /// `MyAnalytics_GetPackageAmounts`, while Ballys uses the reversed
  /// `GetPackageAmounts_MyAnalytics`.
  Future<List<String>> getPackageAmounts() async {
    try {
      final baseUrl = await StorageUtil.getCurrentApiUrl() ?? '';
      final endpoint = baseUrl.contains('bty.world')
          ? 'MyAnalytics_GetPackageAmounts'
          : 'GetPackageAmounts_MyAnalytics';
      final response = await apiService.get(endpoint);
      final status = response['Status'] as bool? ?? false;
      final data = response['Data'];
      if (status && data is List) {
        return data.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Reservation?> saveReservation(NewReservation newReservation) async {
    final salesCode = await StorageUtil.getSalesCode();
    final userName = await StorageUtil.getUserName();
    final deviceId = await DeviceId.get();
print("test");
///print("passportImages: ${newReservation.passportImages}");
print("bm_number: ${newReservation.bmNumber}");
print("air_ticket_details: ${newReservation.airTicketDetails}");
print("passport_images: ${newReservation.passportImages}");
    final masterId = DateTime.now().millisecondsSinceEpoch.toString();

    final requestBody = {
      'master_id': masterId,
      'bm_number': newReservation.bmNumber,
      'guest_name': newReservation.guestName,
      'arrival_date': newReservation.arrivalDate?.toIso8601String(),
      'departure_date': newReservation.departureDate?.toIso8601String(),
      'no_of_nights': newReservation.noOfNights,
      'has_air_ticket_reservation': newReservation.hasAirTicketReservation == '1',
      'remarks': newReservation.remarks,
      'manual_reserv_no': "",
      'package_amount': packageAmountToInt(newReservation.packageAmount),
      'currency_type': packageAmountCurrency(newReservation.packageAmount),
      'sales_code': salesCode,
      'user_name': userName,
      'device_id': deviceId,
      'selected_marketing_person': "",
      "reservation_status":"Pending",
      'guests': newReservation.guests,
      'room_details': newReservation.roomDetails,
      'air_ticket_details': newReservation.airTicketDetails,
      'passport_images': newReservation.passportImages,
    };

  debugPrintRequestBody(requestBody);
print("test2");
    final response = await apiService.post('Reservation_InsertReservation', requestBody);
print("response: $response");
    final status = response['Status'] as bool? ?? false;
    print('Reservation save status: $status');
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
      'package_amount': packageAmountToInt(newReservation.packageAmount),
      'currency_type': packageAmountCurrency(newReservation.packageAmount),
      'selected_marketing_person': newReservation.selectedMarketingPerson,
      'sales_code': salesCode,
      'user_name': userName,
      'device_id': deviceId,
      'room_details': newReservation.roomDetails,
      'air_ticket_details': newReservation.airTicketDetails,
      'guests': newReservation.guests,
      'passport_images': newReservation.passportImages,
      'reservation_status': "Pending",
    };

    debugPrintRequestBody(requestBody);

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

  // void printLargeBody(String body) {
  //   const chunkSize = 1024;
  //   for (int i = 0; i < body.length; i += chunkSize) {
     
  //   }
  // }
  void printLargeBody(String body) {
    const chunkSize = 800;
    for (int i = 0; i < body.length; i += chunkSize) {
      final end = (i + chunkSize < body.length) ? i + chunkSize : body.length;
      print(body.substring(i, end));
    }
  }
  String formatArrivalAndDepartureDate(DateTime? date) {
    if (date == null) {
      throw Exception('Arrival / Departure date is null');
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
