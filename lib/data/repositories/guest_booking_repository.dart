import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/Guest/guest_booking.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class GuestBookingRepository {
  final ApiService apiService;
  final FlutterSecureStorage storage;

  GuestBookingRepository(this.apiService, this.storage);

  Future<List<GuestBooking>> getAllBookings() async {
    try {
      final response = await apiService.getResponse('CheckAllBookings');

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
    String remark = "",
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

      final response = await apiService.postResponse(
        'AcceptMyBooking',
        payload,
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
}