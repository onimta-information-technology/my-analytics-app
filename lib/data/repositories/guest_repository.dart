import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';

class GuestRepository {
  final ApiService apiService;

  GuestRepository(this.apiService);

  Future<List<Guest>> getGuestData(int iid, String text1) async {
    final deviceId = await DeviceId.get();
    print('Device ID guestdate used: $deviceId');
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
      final table1Data = response['CommonResult']['Table1'];

      List<Guest> guestList = [];

      if (tableData.length > 0) {
        for (var table in tableData) {
          // print('MNANE value: ${table['MName']}');
          guestList.add(
            Guest(
              mid: table['MID'] ?? '',
              memberName: table['MName'] ?? table['MNane'] ?? table['MNAME'] ?? '',
              country: table['COUNTRY'] ?? '',
              lastVisitDate: table['LVD'] ?? '',
              age: table['AGE'] ?? '',
              gRating: table['G_Rating'] ?? '',
              mGroup: table['mGroup'] ?? '',
              gName: table['GName'] ?? '',
            ),
          );
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

      if (tableData.length > 0) {
        return tableData['MemImage2'];
      } else {
        throw Exception(
          'Login failed: Invalid credentials or LoginStatus is not True',
        );
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

      if (tableData.length > 0) {
        for (var json in tableData) {
          GuestSearchResponse guestSearchResponse =
              GuestSearchResponse.fromJson(json);
          guestSearchResults.add(guestSearchResponse);
        }

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
