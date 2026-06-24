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
    final actualSalesCode = await StorageUtil.getSalesCode();
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
          "Para_Data": actualSalesCode,
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
        _applySalesCodeFilter(
          actualSalesCode,
          appMode,
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
        _applySalesCodeFilter(
          actualSalesCode,
          appMode,
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

  // Same "admin (AD001) in overall mode sees everything, everyone else
  // only sees their own SM" rule used in MarketingRepository, applied
  // identically to both Table and Table1.
  void _applySalesCodeFilter(
    String? actualSalesCode,
    AppMode appMode,
    String rowSmCode,
    void Function() onMatch,
  ) {
    if (actualSalesCode == 'AD001' && appMode == AppMode.overallData) {
      onMatch();
    } else if (rowSmCode == actualSalesCode) {
      onMatch();
    }
  }
}