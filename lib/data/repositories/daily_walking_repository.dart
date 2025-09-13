import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/Guest/daily_walking_guest.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';


class DailyWalkingGuestRepository {
  final ApiService apiService;

  DailyWalkingGuestRepository(this.apiService);



  Future<List<DailyWalkingGuest>> getAllgest() async {
     final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 8895,
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

      List<DailyWalkingGuest> dailywalkinggest = [];

      if (tableData.length > 0) {
        for (var json in tableData) {
          DailyWalkingGuest dailyResponse = DailyWalkingGuest.fromJson(json);
          dailywalkinggest.add(dailyResponse);
        }
        return dailywalkinggest;
      } else {
        throw Exception(
            'Login failed: Invalid credentials or LoginStatus is not True');
      }
    } else {
      throw Exception('Login failed: unexpected response structure');
    }
  }




}
