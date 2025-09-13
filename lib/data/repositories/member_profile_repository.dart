import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/member/airline_history.dart';
import 'package:ballys_reservation_app/models/member/f_and_b_history.dart';
import 'package:ballys_reservation_app/models/member/games_summary.dart';
import 'package:ballys_reservation_app/models/member/hotel_history.dart';
import 'package:ballys_reservation_app/models/member/loyalty_summary.dart';
import 'package:ballys_reservation_app/models/member/member_main_profile.dart';
import 'package:ballys_reservation_app/models/member/member_summary.dart';
import 'package:ballys_reservation_app/models/member/trip_history.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';

class MemberProfileRepository {
  final ApiService apiService;

  MemberProfileRepository(this.apiService);

  Future<List<MemberMainProfile>> getMemberMainProfileDetails(
    String text1,
  ) async {
     final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9030,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": text1,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },{
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text30",
          "Para_Type": "varchar",
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1",
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<MemberMainProfile> guestMainProfileDynamicData = [];

      for (var json in tableData) {
        MemberMainProfile guestProfileDetail = MemberMainProfile.fromJson(json);
        print(guestProfileDetail.toJson());
        guestMainProfileDynamicData.add(guestProfileDetail);
      }

      return guestMainProfileDynamicData;
    }
    throw Exception(
      'Failed guests searching: Invalid credentials or LoginStatus is not True',
    );
  }

  Future<List<LoyaltySummary>> getLoyalitySummary({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    final response = await apiService.post('GetLoyalitySummary', {
      "playerId": playerId,
      "DateFrom": dateFrom,
      "DateTo": dateTo,
    });

    if (response['status'] == 'SUCCESS' &&
        response['data'] is List &&
        response['data'].isNotEmpty) {
      final data = response['data'];

      List<LoyaltySummary> loyaltySummaryData = data
          .map<LoyaltySummary>((item) => LoyaltySummary.fromJson(item))
          .toList();

      return loyaltySummaryData;
    } else {
      throw Exception('Data retrieval failed: unexpected response structure');
    }
  }

  Future<List<TripHistory>> getTripHistory({
    required String playerId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await apiService.post('GetVisitFrequency', {
      "playerId": playerId,
      "DateFrom": dateFrom,
      "DateTo": dateTo,
    });

    if (response['status'] == 'SUCCESS' &&
        response['data'] is Map &&
        response['data']['Visits'] is List &&
        response['data']['Visits'].isNotEmpty) {
      final data = response['data']['Visits'];

      List<TripHistory> tripHistoryData = data
          .map<TripHistory>((item) => TripHistory.fromJson(item))
          .toList();

      return tripHistoryData;
    } else {
      throw Exception('Data retrieval failed: unexpected response structure');
    }
  }

    Future<List<TripHistory>> getTripHistory2({
    required String playerId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await apiService.post('GetVisitFrequency2', {
      "playerId": playerId,
      "DateFrom": dateFrom,
      "DateTo": dateTo,
    });

    if (response['status'] == 'SUCCESS' &&
        response['data'] is Map &&
        response['data']['Visits'] is List &&
        response['data']['Visits'].isNotEmpty) {
      final data = response['data']['Visits'];

      List<TripHistory> tripHistoryData = data
          .map<TripHistory>((item) => TripHistory.fromJson(item))
          .toList();

      return tripHistoryData;
    } else {
      throw Exception('Data retrieval failed: unexpected response structure');
    }
  }

  Future<List<AirlineHistory>> getAirlineHistory({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    final response = await apiService.post('GetTravelHistory', {
      "playerId": playerId,
      "DateFrom": dateFrom,
      "DateTo": dateTo,
    });

    if (response['status'] == 'SUCCESS' &&
        response['data'] is Map &&
        response['data']['Airlines'] is List &&
        response['data']['Airlines'].isNotEmpty) {
      final data = response['data']['Airlines'];

      List<AirlineHistory> airlineHistoryData = data
          .map<AirlineHistory>((item) => AirlineHistory.fromJson(item))
          .toList();

      return airlineHistoryData;
    } else {
      throw Exception('Data retrieval failed: unexpected response structure');
    }
  }

  Future<List<HotelHistory>> getHotelHistory({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    final response = await apiService.post('GetTravelHistory', {
      "playerId": playerId,
      "DateFrom": dateFrom,
      "DateTo": dateTo,
    });

    if (response['status'] == 'SUCCESS' &&
        response['data'] is Map &&
        response['data']['Hotels'] is List &&
        response['data']['Hotels'].isNotEmpty) {
      final data = response['data']['Hotels'];

      List<HotelHistory> hotelHistory = data
          .map<HotelHistory>((item) => HotelHistory.fromJson(item))
          .toList();

      return hotelHistory;
    } else {
      throw Exception('Data retrieval failed: unexpected response structure');
    }
  }

  Future<FAndBHistory> getFAndBHistory({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    final response = await apiService.post('GetNonGamingActivities', {
      "playerId": playerId,
      "DateFrom": dateFrom,
      "DateTo": dateTo,
    });
    print(response['data']);
    if (response['status'] == 'SUCCESS' && response['data'] is Map) {
      final data = response['data'];

      FAndBHistory fnbHistory = FAndBHistory.fromJson(data);

      return fnbHistory;
    } else {
      throw Exception('Data retrieval failed: unexpected response structure');
    }
  }

  Future<GamesSummary> getGamesSummary({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    final response = await apiService.post('GetGamingActivities', {
      "playerId": playerId,
      "DateFrom": dateFrom,
      "DateTo": dateTo,
    });
    print(response['data']);
    if (response['status'] == 'SUCCESS' && response['data'] is Map) {
      final data = response['data'];

      GamesSummary gamesSummary = GamesSummary.fromJson(data);

      return gamesSummary;
    } else {
      throw Exception('Data retrieval failed: unexpected response structure');
    }
  }

  Future<List<MemberSummary>> getMemberSummary({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
     final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9020,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": playerId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": dateFrom,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": dateTo,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text3",
          "Para_Type": "varchar",
        },{
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text30",
          "Para_Type": "varchar",
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1",
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<MemberSummary> memberSummaries = [];

      if (tableData.length > 0) {
        for (var json in tableData) {
          MemberSummary memberSummary = MemberSummary.fromJson(json);
          memberSummaries.add(memberSummary);
        }

        return memberSummaries;
      } else {
        throw Exception('Data retrieval failed: no data found');
      }
    } else {
      throw Exception('Data retrieval failed: unexpected response structure');
    }
  }
}
