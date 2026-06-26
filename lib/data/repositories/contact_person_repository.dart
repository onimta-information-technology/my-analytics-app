import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class ContactPersonRepository {
  final ApiService apiService;

  ContactPersonRepository(this.apiService);

  Future<List<String>> getContactPersons() async {
    final deviceId = await DeviceId.get();
    final spName = await StorageUtil.getStoredProcedureName();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 641,
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
          "Para_Type": "varchar"
        }
      ],
      "SpName": spName,
      "con": "1"
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List) {
      final table = response['CommonResult']['Table'] as List;
      return table
          .map((e) => e['Contact_Person'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }
}
