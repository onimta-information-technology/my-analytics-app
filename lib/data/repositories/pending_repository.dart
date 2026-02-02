import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/pendingCounts.dart';

class PendingCountRepository {
  final ApiService apiService;

  PendingCountRepository(this.apiService);

  Future<PendingCounts> getPendingCounts() async {
    print('Fetching pending counts from API...');
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 88965,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        }
      ],
      "SpName": "sp_CRM_Common_API",
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