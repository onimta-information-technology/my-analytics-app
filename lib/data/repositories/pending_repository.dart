import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/pendingCounts.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class PendingCountRepository {
  final ApiService apiService;

  PendingCountRepository(this.apiService);

  Future<PendingCounts> getPendingCounts() async {
    print('Fetching pending counts from API...');
     final spName = await StorageUtil.getStoredProcedureName();
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    final isBellagio = apiUrl.contains('bty.world');

    // Bellagio runs its own stored-procedure branch; Ballys stays on 88965.
    final iid = isBellagio ? 8896590 : 88965;

    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": iid,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        }
      ],
      "SpName": spName,
      "con": "1",
    });
print('API response for pending counts: $response');
    if (response['strRturnRes'] == true &&
        response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        (response['CommonResult']['Table'] as List).isNotEmpty) {
      final tableData = response['CommonResult']['Table'][0];
      return PendingCounts.fromJson(tableData);
    }

    return const PendingCounts();
  }
}