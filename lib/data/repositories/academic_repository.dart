import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class AcademicRepository {
  // Fixed @Iid for the academic web URL lookup.
  static const int _iid = 645;

  final ApiService apiService;

  AcademicRepository(this.apiService);

  /// Returns the academic site URL (`acd_path`) configured for the current
  /// property, or null when the server sends no row back.
  Future<String?> getAcademicUrl() async {
    final deviceId = await DeviceId.get();
    final spName = await StorageUtil.getStoredProcedureName();

    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": _iid,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
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
      "con": "1",
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final path = response['CommonResult']['Table'][0]['acd_path'];
      if (path is String && path.trim().isNotEmpty) {
        return path.trim();
      }
    }

    return null;
  }
}
