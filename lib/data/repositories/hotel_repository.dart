import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_cost_response.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_location.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_response.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_room_catalog_entry.dart';
import 'package:ballys_reservation_app/models/reservation/room_category_response.dart';
import 'package:ballys_reservation_app/models/reservation/room_type_response.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class HotelRepository {
  final ApiService apiService;

  HotelRepository(this.apiService);

  Future<List<HotelResponse>> getAllHotels() async {
     final deviceId = await DeviceId.get();
      final spName = await StorageUtil.getStoredProcedureName();
      print('Fetching all hotels with deviceId: $deviceId and spName: $spName');
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
      "SpName": spName,
      "con": "1"
    });
    print('API response for all hotels: $response');
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

  /// Both locations are fetched and merged into one catalog. The forms ask
  /// which type before offering a hotel and filter this list by the answer, so
  /// switching type does not cost another round trip.
  /// Hotels, room categories, room types, meal plans and their rates for the
  /// Ballys reservation forms.
  ///
  /// `GET Hotels/GetByLocationFlat?Location=…` per location, merged — replaces
  /// the 9015 / 9016 / 9017 chain, the combined 90155 call and the nested
  /// `HotelsGetByLocation`, so the dropdowns filter this list in memory instead
  /// of re-fetching. Only rows the back office still has marked active come
  /// through.
  Future<List<HotelRoomCatalogEntry>> getHotelRoomCatalog() async {
    final results = await Future.wait(
      HotelLocation.values.map((l) => _hotelCatalogForLocation(l.apiValue)),
    );

    // A location that fails takes only its own hotels with it: half a list is
    // more use at the dropdown than none. Only a total failure throws, so the
    // notifier can keep whatever catalog it already holds.
    if (results.every((r) => r == null)) {
      throw Exception('Hotel catalog API failed');
    }

    return [
      for (final entries in results)
        if (entries != null) ...entries,
    ];
  }

  /// One location's slice of the catalog, or null if that call failed.
  Future<List<HotelRoomCatalogEntry>?> _hotelCatalogForLocation(
    String location,
  ) async {
    try {
      final response =
          await apiService.get('Hotels/GetByLocationFlat?Location=$location');

      if (response['success'] == false) {
        print('Hotel catalog for $location returned success=false: $response');
        return null;
      }

      return HotelRoomCatalogEntry.fromFlatLocationResponse(response);
    } catch (e) {
      print('Hotel catalog for $location failed: $e');
      return null;
    }
  }

  Future<List<RoomCategoryResponse>> getSelectedHotelRoomCategories(
      double hotelId) async {
         final deviceId = await DeviceId.get();
          final spName = await StorageUtil.getStoredProcedureName();
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
      "SpName": spName,
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
          final spName = await StorageUtil.getStoredProcedureName();
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
      "SpName": spName,
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
          final spName = await StorageUtil.getStoredProcedureName();
          print('Fetching hotel costs with parameters: hotelName=$hotelName, roomCategory=$roomCategory, roomType=$roomType, mealPlan=$mealPlan, deviceId=$deviceId');
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
      "SpName": spName,
      "con": "1"
    });
print('API response for hotel costs: $response');
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

  /// POST `{baseUrl}/Hotel_Amendment_Insert` — submits a hotel amendment
  /// built by [HotelAmendmentBallysScreen].
  Future<HotelAmendmentResult> submitAmendment(
    Map<String, Object?> payload,
  ) async {
    final userName = await StorageUtil.getUserName();
    final deviceId = await DeviceId.get();

    final body = <String, Object?>{
      ...payload,
      'user_name': userName,
      'device_id': deviceId,
      'status': 'Pending',
    };

    print('submitAmendment payload: $body');
    final response = await apiService.post('AmendmentHotel/Insert', body);

    return HotelAmendmentResult(
      success: _insertSucceeded(response),
      message: _insertMessage(response),
      masterRowId: (response['MasterRowId'] as num?)?.toInt(),
    );
  }

  /// The insert endpoint answers `{success: true, MasterRowId: n}`; older
  /// builds of it answered `Status`. Accept either, so one shape changing
  /// does not read as a failed submit. A row id coming back is itself proof
  /// the amendment was written.
  static bool _insertSucceeded(Map<String, dynamic> response) {
    if (response['success'] == true || response['Status'] == true) return true;
    final rowId = (response['MasterRowId'] as num?)?.toInt();
    return rowId != null && rowId > 0;
  }

  static String? _insertMessage(Map<String, dynamic> response) =>
      (response['Message'] ?? response['message'] ?? response['statusMsg'])
          ?.toString();
}

/// Outcome of a `Hotel_Amendment_Insert` call.
class HotelAmendmentResult {
  final bool success;
  final String? message;

  /// The row the amendment was written as, when the endpoint names it.
  final int? masterRowId;

  const HotelAmendmentResult({
    required this.success,
    this.message,
    this.masterRowId,
  });
}
