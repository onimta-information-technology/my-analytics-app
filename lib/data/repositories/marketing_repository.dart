import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

// Create a combined result class to hold both tables
class MarketingApiResult {
  final List<MarketingPerformance> performanceData;
  final List<MarketingDetailedData> detailedData;

  MarketingApiResult({
    required this.performanceData,
    required this.detailedData,
  });
}

class MarketingRepository {
  final ApiService apiService;

  MarketingRepository(this.apiService);

  // Modified to return both Table and Table1 data
  Future<MarketingApiResult> getMarketingData(
    int iid,
    AppMode appMode,
    String userSalesCode,
  ) async {
    final actualSalesCode = await StorageUtil.getSalesCode();
    final deviceId = await DeviceId.get();

    print('=== Marketing Data API Call ===');
    print('IID: $iid');
    print('User Sales Code (parameter): $userSalesCode');
    print('Actual Sales Code (from storage): $actualSalesCode');
    print('App Mode: $appMode');

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
      "SpName": "sp_CRM_Common_API",
      "con": "1",
    });

    print('Full API Response: $response');

    List<MarketingPerformance> marketingPerformanceList = [];
    List<MarketingDetailedData> marketingDetailedList = [];

    // Process Table (Performance Summary)
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];
      print('Table Data: $tableData');

      for (var table in tableData) {
        final performance = MarketingPerformance.fromJson(table);
        print(
          'Processing: ${performance.smName} (SM: ${performance.sm}, WinLost: ${performance.winLost})',
        );

        // Filter based on app mode and sales code
        if (actualSalesCode == 'AD001' && appMode == AppMode.overallData) {
          marketingPerformanceList.add(performance);
          print('✅ Added (admin access): ${performance.smName}');
        } else {
          print(
            '🔍 Checking filter: SM(${performance.sm}) vs SalesCode($actualSalesCode)',
          );
          if (performance.sm.toString() == actualSalesCode) {
            marketingPerformanceList.add(performance);
            print('✅ Added (filtered): ${performance.smName}');
          } else {
            print(
              '❌ Filtered out: ${performance.smName} (SM: ${performance.sm} != $actualSalesCode)',
            );
          }
        }
      }

      print(
        'Total marketing performance after filtering: ${marketingPerformanceList.length}',
      );
    }

    // Process Table1 (Detailed Member Data)
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table1'] is List &&
        response['CommonResult']['Table1'].isNotEmpty) {
      final table1Data = response['CommonResult']['Table1'];
      print('Table1 Data: $table1Data');

      for (var memberData in table1Data) {
        final detailed = MarketingDetailedData.fromJson(memberData);
        print('Processing member: ${detailed.memId} (SM: ${detailed.sm})');

        // Apply same filtering logic as performance data
        if (actualSalesCode == 'AD001' && appMode == AppMode.overallData) {
          marketingDetailedList.add(detailed);
          print('✅ Added detailed (admin access): ${detailed.memId}');
        } else {
          if (detailed.sm.toString() == actualSalesCode) {
            marketingDetailedList.add(detailed);
            print('✅ Added detailed (filtered): ${detailed.memId}');
          } else {
            print(
              '❌ Filtered out detailed: ${detailed.memId} (SM: ${detailed.sm} != $actualSalesCode)',
            );
          }
        }
      }

      print(
        'Total detailed data after filtering: ${marketingDetailedList.length}',
      );
    }

    return MarketingApiResult(
      performanceData: marketingPerformanceList,
      detailedData: marketingDetailedList,
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
