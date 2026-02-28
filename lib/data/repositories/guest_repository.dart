import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/models/marketing_group.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';

/// 🔹 Return type wrapping guests + Table2 marketing groups
class GuestDataResult {
  final List<Guest> guests;
  final List<MarketingGroup> marketingGroups;

  const GuestDataResult({
    required this.guests,
    required this.marketingGroups,
  });
}

class GuestRepository {
  final ApiService apiService;

  GuestRepository(this.apiService);

  Future<GuestDataResult> getGuestData2(int iid, String text1) async {
    final deviceId = await DeviceId.get();
    print("iid is $iid and text1 is $text1");

    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": iid,
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
      "con": "1",
    });

    print("hiii2");
    print(response);

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];
      final table2Data = response['CommonResult']['Table2'];

      // 🔹 Parse guests from Table
      List<Guest> guestList = [];
      for (var table in tableData) {
        guestList.add(Guest.fromJson(table));
      }

      // 🔹 Parse marketing groups from Table2
      List<MarketingGroup> marketingGroups = [];
      if (table2Data is List && table2Data.isNotEmpty) {
        for (var row in table2Data) {
          marketingGroups.add(MarketingGroup.fromJson(row));
        }
      }

      if (guestList.isNotEmpty) {
        return GuestDataResult(
          guests: guestList,
          marketingGroups: marketingGroups,
        );
      } else {
        throw Exception(
          'Login failed: Invalid credentials or LoginStatus is not True',
        );
      }
    } else {
      throw Exception('Login failed: unexpected response structure');
    }
  }
Future<List<Guest>> getGuestData(int iid, String text1) async {
    final deviceId = await DeviceId.get();
    print("iid is $iid and text1 is $text1");
    
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": iid,
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
      "con": "1",
    });
    
    print("hiii2");
    print(response);
    
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];
      final table1Data = response['CommonResult']['Table1'];

      List<Guest> guestList = [];

      if (tableData.length > 0) {
        for (var table in tableData) {
          // ✅ FIX: Use fromJson to properly parse all fields including memImage2
          guestList.add(Guest.fromJson(table));
        }
      }

      // if (table1Data is List && table1Data.isNotEmpty) {
      //   for (var table2 in table1Data) {
      //     guestList.add(
      //       Guest(
      //         mid: '',
      //         memberName: '',
      //         country: '',
      //         lastVisitDate: '',
      //         age: 0,
      //         gRating: '',
      //         mGroup: table2['GCode'] + '0' ?? '',
      //         gName: table2['GName'] ?? '',
      //       ),
      //     );
      //   }
      // }

      if (guestList.isNotEmpty) {
        return guestList;
      } else {
        throw Exception(
          'Login failed: Invalid credentials or LoginStatus is not True',
        );
      }
    } else {
      throw Exception('Login failed: unexpected response structure');
    }
  }


  Future<String?> fetchGuestImage(int iid, String text1) async {
    final deviceId = await DeviceId.get();

    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": iid,
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
      "con": "1",
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'][0];

      if (tableData.containsKey('MemImage2') && tableData['MemImage2'] != null) {
        print('Guest image URL fetched: ${tableData['MemImage2']}');
        return tableData['MemImage2'];
      } else {
        print('No MemImage2 found in response');
        return null;
      }
    }
    return null;
  }

  Future<List<GuestSearchResponse>> searchGuest(int iid, String text1) async {
    final deviceId = await DeviceId.get();

    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": iid,
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
      "con": "1",
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<GuestSearchResponse> guestSearchResults = [];
      for (var json in tableData) {
        guestSearchResults.add(GuestSearchResponse.fromJson(json));
      }

      if (guestSearchResults.isNotEmpty) {
        return guestSearchResults;
      } else {
        throw Exception(
          'Failed guests searching: Invalid credentials or LoginStatus is not True',
        );
      }
    }
    throw Exception(
      'Failed guests searching: Invalid credentials or LoginStatus is not True',
    );
  }
}