import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/last_three_months.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class LastThreeMonthsApiResult {
  final List<LastThreeMonthsPerformance> performanceData;
  final List<LastThreeMonthsDetailedData> detailedData;

  LastThreeMonthsApiResult({
    required this.performanceData,
    required this.detailedData,
  });
}

class LastThreeMonthsRepository {
  // Fixed @Iid for the "Last 3 Months" report. Same stored procedure as
  // MarketingRepository (sp_CRM_Common_API), just a different Iid.
  static const int _iid = 778899;

  final ApiService apiService;

  LastThreeMonthsRepository(this.apiService);

  Future<LastThreeMonthsApiResult> getLastThreeMonthsData(
    AppMode appMode,
    String userSalesCode,
  ) async {
    final isMyDataMode = appMode == AppMode.myData;
    // Marketing-permission users see their own numbers under their marketing
    // code, so "My Data" is scoped by that instead of the sales code.
    final scopeCode =
        await StorageUtil.getDataScopeCode(isMyDataMode: isMyDataMode);
    final showsEverything = !isMyDataMode && await StorageUtil.getMarketingP();
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
          "Para_Data": scopeCode,
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
      "SpName": spName,
      "con": "1",
    });

    final List<LastThreeMonthsPerformance> performanceList = [];
    final List<LastThreeMonthsDetailedData> detailedList = [];

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      for (final row in response['CommonResult']['Table']) {
        final performance = LastThreeMonthsPerformance.fromJson(row);
        _applyScopeFilter(
          scopeCode,
          showsEverything,
          performance.sm,
          () => performanceList.add(performance),
        );
      }
    }

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table1'] is List &&
        response['CommonResult']['Table1'].isNotEmpty) {
      for (final row in response['CommonResult']['Table1']) {
        final detailed = LastThreeMonthsDetailedData.fromJson(row);
        _applyScopeFilter(
          scopeCode,
          showsEverything,
          detailed.sm,
          () => detailedList.add(detailed),
        );
      }
    }

    return LastThreeMonthsApiResult(
      performanceData: performanceList,
      detailedData: detailedList,
    );
  }

  // Same "marketing user in overall mode sees everything, everyone else only
  // sees the rows matching their scope code" rule used in MarketingRepository,
  // applied identically to both Table and Table1.
  void _applyScopeFilter(
    String? scopeCode,
    bool showsEverything,
    String rowSmCode,
    void Function() onMatch,
  ) {
    if (showsEverything || rowSmCode == scopeCode) {
      onMatch();
    }
  }
}