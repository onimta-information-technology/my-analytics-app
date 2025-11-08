import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_cost_response.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_response.dart';
import 'package:ballys_reservation_app/models/reservation/room_category_response.dart';
import 'package:ballys_reservation_app/models/reservation/room_type_response.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';

class HotelRepository {
  final ApiService apiService;

  HotelRepository(this.apiService);

  Future<List<HotelResponse>> getAllHotels() async {
     final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9015,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int"
        },
        {
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text30",
          "Para_Type": "varchar",
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1"
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<HotelResponse> hotels = [];

      if (tableData.length > 0) {
        for (var json in tableData) {
          HotelResponse hotelResponse = HotelResponse.fromJson(json);
          hotels.add(hotelResponse);
        }
        return hotels;
      } else {
        throw Exception(
            'Login failed: Invalid credentials or LoginStatus is not True');
      }
    } else {
      throw Exception('Login failed: unexpected response structure');
    }
  }

  Future<List<RoomCategoryResponse>> getSelectedHotelRoomCategories(
      double hotelId) async {
         final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9016,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int"
        },
        {
          "Para_Data": hotelId.toInt(),
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar"
        }, {
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text30",
          "Para_Type": "varchar",
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1"
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<RoomCategoryResponse> roomCategories = [];

      if (tableData.length > 0) {
        for (var json in tableData) {
          RoomCategoryResponse roomCategoryResponse =
              RoomCategoryResponse.fromJson(json);
          roomCategories.add(roomCategoryResponse);
        }
        return roomCategories;
      } else {
        throw Exception('Room Category API failed');
      }
    } else {
      throw Exception('Room Category API failed');
    }
  }

  Future<List<RoomTypeResponse>> getSelectedHotelCategoryRoomTypes(
      double hotelId, int categoryId) async {
         final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9017,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int"
        },
        {
          "Para_Data": hotelId.toInt(),
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": categoryId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar"
        }, {
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text30",
          "Para_Type": "varchar",
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1"
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<RoomTypeResponse> roomTypes = [];

      if (tableData.length > 0) {
        for (var json in tableData) {
          RoomTypeResponse roomTypeResponse = RoomTypeResponse.fromJson(json);
          roomTypes.add(roomTypeResponse);
        }
        return roomTypes;
      } else {
        throw Exception('Room Types API failed');
      }
    } else {
      throw Exception('Room Types API failed');
    }
  }

  Future<List<HotelCostResponse>> getHotelCosts(
      {required String hotelName,
      required String roomCategory,
      required String roomType,
      required String mealPlan}) async {
         final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9022,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int"
        },
        {
          "Para_Data": hotelName,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": roomCategory,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": roomType,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text3",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": mealPlan,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text4",
          "Para_Type": "varchar"
        }, {
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text30",
          "Para_Type": "varchar",
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1"
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<HotelCostResponse> hotelCosts = [];

      if (tableData.length > 0) {
        for (var json in tableData) {
          HotelCostResponse hotelCostResponse =
              HotelCostResponse.fromJson(json);
          hotelCosts.add(hotelCostResponse);
        }

        return hotelCosts;
      } else {
        throw Exception('Hotel Cost API failed');
      }
    } else {
      throw Exception('Hotel Cost API failed');
    }
  }
}
