import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/Guest/guest_booking.dart';

import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GuestBookingRepository {
  final ApiService apiService;

  GuestBookingRepository(this.apiService);

  Future<List<GuestBooking>> getAllBookings() async {
    try {
      final deviceId = await DeviceId.get();
      
      final response = await http.get(
        Uri.parse('https://api.ballyscolombo.com/api/Ballys/CheckAllBookings'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('Guest Booking Response Status: ${response.statusCode}');
      print('Guest Booking Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        
        List<GuestBooking> bookings = jsonData.map((item) {
          return GuestBooking.fromJson(Map<String, dynamic>.from(item));
        }).toList();

        return bookings;
      } else {
        print('Failed to load bookings: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error in getAllBookings: $e');
      return [];
    }
  }
Future<bool> acceptBooking({
  required String mid,
  required String bookingId,
  String remark = "Done",
}) async {
  try {
    
    final name = await StorageUtil.getUserName();
    final payload = {
      "MID": mid,
      "BookingId": bookingId,
      "Remark": remark,
      "AcceptUser": name,
      "AcceptTime": DateTime.now().toIso8601String(),
      
    };
print('Accept Booking Payload: $payload');
    final response = await http.post(
      Uri.parse('https://api.ballyscolombo.com/api/Ballys/AcceptMyBooking'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    print('Accept Booking Response Status: ${response.statusCode}');
    print('Accept Booking Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return jsonData['success'] == true;
    } else {
      print('Failed to accept booking: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('Error in acceptBooking: $e');
    return false;
  }
}
  // Future<bool> acceptBooking({
  //   required int idNo,
  //   required String userName,
  // }) async {
  //   try {
  //     final deviceId = await DeviceId.get();
      
  //     final payload = {
  //       "HasReturnData": "T",
  //       "Parameters": [
  //         {
  //           "Para_Data": 99001, // You'll need to get the correct IID from your API team
  //           "Para_Direction": "Input",
  //           "Para_Lenth": 1,
  //           "Para_Name": "@Iid",
  //           "Para_Type": "int",
  //         },
  //         {
  //           "Para_Data": idNo,
  //           "Para_Direction": "Input",
  //           "Para_Lenth": 100,
  //           "Para_Name": "@Text1",
  //           "Para_Type": "varchar",
  //         },
  //         {
  //           "Para_Data": userName,
  //           "Para_Direction": "Input",
  //           "Para_Lenth": 100,
  //           "Para_Name": "@Text2",
  //           "Para_Type": "varchar",
  //         },
  //         {
  //           "Para_Data": deviceId,
  //           "Para_Direction": "Input",
  //           "Para_Lenth": 100,
  //           "Para_Name": "@Text30",
  //           "Para_Type": "varchar",
  //         },
  //       ],
  //       "SpName": "sp_CRM_Common_API",
  //       "con": "1",
  //     };

  //     final resp = await apiService.post('CommonExecute', payload);
  //     print('Accept Booking Response: $resp');
  //     return true;
  //   } catch (e) {
  //     print('Error accepting booking: $e');
  //     return false;
  //   }
  // }

  // Future<bool> rejectBooking({
  //   required int idNo,
  //   required String userName,
  // }) async {
  //   try {
  //     final deviceId = await DeviceId.get();
      
  //     final payload = {
  //       "HasReturnData": "T",
  //       "Parameters": [
  //         {
  //           "Para_Data": 99002, // You'll need to get the correct IID from your API team
  //           "Para_Direction": "Input",
  //           "Para_Lenth": 1,
  //           "Para_Name": "@Iid",
  //           "Para_Type": "int",
  //         },
  //         {
  //           "Para_Data": idNo,
  //           "Para_Direction": "Input",
  //           "Para_Lenth": 100,
  //           "Para_Name": "@Text1",
  //           "Para_Type": "varchar",
  //         },
  //         {
  //           "Para_Data": userName,
  //           "Para_Direction": "Input",
  //           "Para_Lenth": 100,
  //           "Para_Name": "@Text2",
  //           "Para_Type": "varchar",
  //         },
  //         {
  //           "Para_Data": deviceId,
  //           "Para_Direction": "Input",
  //           "Para_Lenth": 100,
  //           "Para_Name": "@Text30",
  //           "Para_Type": "varchar",
  //         },
  //       ],
  //       "SpName": "sp_CRM_Common_API",
  //       "con": "1",
  //     };

  //     final resp = await apiService.post('CommonExecute', payload);
  //     print('Reject Booking Response: $resp');
  //     return true;
  //   } catch (e) {
  //     print('Error rejecting booking: $e');
  //     return false;
  //   }
  // }
}