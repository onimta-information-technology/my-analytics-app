import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

// Create a combined result class to hold all three tables
class MarketingApiResult {
  final List<MarketingPerformance> performanceData;
  final List<MarketingDetailedData> detailedData;
  final List<MarketingResult> resultData; // NEW: Table2 data

  MarketingApiResult({
    required this.performanceData,
    required this.detailedData,
    required this.resultData,
  });
}

class MarketingRepository {
  final ApiService apiService;

  MarketingRepository(this.apiService);

  // Modified to return Table, Table1, and Table2 data
  Future<MarketingApiResult> getMarketingData(
    int iid,
    AppMode appMode,
    String userSalesCode,
  ) async {
    final actualSalesCode = await StorageUtil.getSalesCode();
    final deviceId = await DeviceId.get();
    print('Marketing Repository - IID: $iid, Sales Code: $actualSalesCode, Device ID: $deviceId');
     final spName = await StorageUtil.getStoredProcedureName();
     print('Using stored procedure: $spName');
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

    List<MarketingPerformance> marketingPerformanceList = [];
    List<MarketingDetailedData> marketingDetailedList = [];
    List<MarketingResult> marketingResultList = []; // NEW

    // Process Table (Performance Summary)
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      for (var table in tableData) {
        final performance = MarketingPerformance.fromJson(table);

        // Filter based on app mode and sales code
        if (actualSalesCode == 'AD001' && appMode == AppMode.overallData) {
          marketingPerformanceList.add(performance);
        } else {
          if (performance.sm.toString() == actualSalesCode) {
            marketingPerformanceList.add(performance);
          }
        }
      }
    }

    // Process Table1 (Detailed Member Data)
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table1'] is List &&
        response['CommonResult']['Table1'].isNotEmpty) {
      final table1Data = response['CommonResult']['Table1'];

      for (var memberData in table1Data) {
        final detailed = MarketingDetailedData.fromJson(memberData);

        // Apply same filtering logic as performance data
        if (actualSalesCode == 'AD001' && appMode == AppMode.overallData) {
          marketingDetailedList.add(detailed);
        } else {
          if (detailed.sm.toString() == actualSalesCode) {
            marketingDetailedList.add(detailed);
          }
        }
      }
    }

    // NEW: Process Table2 (Result Data)
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table2'] is List &&
        response['CommonResult']['Table2'].isNotEmpty) {
      final table2Data = response['CommonResult']['Table2'];

      for (var resultData in table2Data) {
        final result = MarketingResult.fromJson(resultData);

        // Apply same filtering logic as other tables
        if (actualSalesCode == 'AD001' && appMode == AppMode.overallData) {
          marketingResultList.add(result);
        } else {
          if (result.sm.toString() == actualSalesCode) {
            marketingResultList.add(result);
          }
        }
      }
    }

    return MarketingApiResult(
      performanceData: marketingPerformanceList,
      detailedData: marketingDetailedList,
      resultData: marketingResultList, // NEW
    );
  }

  // Helper method to get detailed data for specific SM
  List<MarketingDetailedData> getDetailedDataForSM(
    List<MarketingDetailedData> allDetailedData,
    String smCode,
  ) {
    return allDetailedData.where((data) => data.sm == smCode).toList();
  }

  // Updated methods to use the new combined API call
  Future<MarketingApiResult> getTodayData(
    AppMode appMode,
    String salesCode,
  ) async {
    return await getMarketingData(8896, appMode, salesCode);
  }

  Future<MarketingApiResult> getYesterdayData(
    AppMode appMode,
    String salesCode,
  ) async {
    return await getMarketingData(8897, appMode, salesCode);
  }

  Future<MarketingApiResult> getMonthlyData(
    AppMode appMode,
    String salesCode,
  ) async {
    return await getMarketingData(8898, appMode, salesCode);
  }

  // Legacy methods for backward compatibility (if needed)
  Future<List<MarketingPerformance>> getMarketingPerformance(
    int iid,
    AppMode appMode,
    String userSalesCode,
  ) async {
    final result = await getMarketingData(iid, appMode, userSalesCode);
    return result.performanceData;
  }

  Future<List<MarketingPerformance>> getTodayPerformance(
    AppMode appMode,
    String salesCode,
  ) async {
    final result = await getTodayData(appMode, salesCode);
    return result.performanceData;
  }

  Future<List<MarketingPerformance>> getYesterdayPerformance(
    AppMode appMode,
    String salesCode,
  ) async {
    final result = await getYesterdayData(appMode, salesCode);
    return result.performanceData;
  }

  Future<List<MarketingPerformance>> getMonthlyPerformance(
    AppMode appMode,
    String salesCode,
  ) async {
    final result = await getMonthlyData(appMode, salesCode);
    return result.performanceData;
  }
}