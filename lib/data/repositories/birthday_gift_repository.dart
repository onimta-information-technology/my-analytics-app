import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/birthday_gift_model.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class BirthdayGiftRepository {
  final ApiService apiService;

  BirthdayGiftRepository(this.apiService);

  Future<BirthdayGiftResponse?> getBirthdayGift(String memberId) async {
 //   final deviceId = await DeviceId.get();
  final spName = await StorageUtil.getStoredProcedureName();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 8875,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": memberId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        }
      ],
      "SpName": spName,
      "con": "1",
    });

    if (response['strRturnRes'] == true &&
        response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'][0];
      return BirthdayGiftResponse.fromJson(tableData);
    }
    
    return null;
  }
}