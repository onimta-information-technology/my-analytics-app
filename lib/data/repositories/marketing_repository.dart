import 'dart:convert';

import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class MarketingApiResult {
  final List<MarketingPerformance> performanceData;
  final List<MarketingDetailedData> detailedData;
  final List<MarketingResult> resultData;

  MarketingApiResult({
    required this.performanceData,
    required this.detailedData,
    required this.resultData,
  });
}

// NEW: Result type for target API calls
class MarketingTargetApiResult {
  final List<MarketingTargetDetail> detailRows; // Table  (individual trips)
  final List<MarketingTarget> summaryRows;      // Table1 (per-SM summary)

  MarketingTargetApiResult({
    required this.detailRows,
    required this.summaryRows,
  });
}

class MarketingRepository {
  final ApiService apiService;

  MarketingRepository(this.apiService);

  Future<MarketingApiResult> getMarketingData(
    int iid,
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
    List<MarketingResult> marketingResultList = [];

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      for (var table in response['CommonResult']['Table']) {
        final performance = MarketingPerformance.fromJson(table);
        if (actualSalesCode == 'AD001' && appMode == AppMode.overallData) {
          marketingPerformanceList.add(performance);
        } else {
          if (performance.sm.toString() == actualSalesCode) {
            marketingPerformanceList.add(performance);
          }
        }
      }
    }

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table1'] is List &&
        response['CommonResult']['Table1'].isNotEmpty) {
      for (var memberData in response['CommonResult']['Table1']) {
        final detailed = MarketingDetailedData.fromJson(memberData);
        if (actualSalesCode == 'AD001' && appMode == AppMode.overallData) {
          marketingDetailedList.add(detailed);
        } else {
          if (detailed.sm.toString() == actualSalesCode) {
            marketingDetailedList.add(detailed);
          }
        }
      }
    }

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table2'] is List &&
        response['CommonResult']['Table2'].isNotEmpty) {
      for (var resultData in response['CommonResult']['Table2']) {
        final result = MarketingResult.fromJson(resultData);
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
      resultData: marketingResultList,
    );
  }

  // NEW: Fetch target data — IID 778898 (monthly) or 558899 (last month)
  Future<MarketingTargetApiResult> getTargetData(
    int iid,
    AppMode appMode,
  ) async {
    final actualSalesCode = await StorageUtil.getSalesCode();
    final deviceId = await DeviceId.get();
    final spName = await StorageUtil.getStoredProcedureName();

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

    // DEBUG: inspect IID 558899 / 778898 — focus on the summary set (Table1),
    // which is what drives "No target data available". Logcat truncates long
    // lines, so print the keys + Table1 separately and chunk the full dump.
    final common = response['CommonResult'];
    print('=== getTargetData IID=$iid ===');
    print('CommonResult keys: ${common is Map ? common.keys.toList() : common}');
    if (common is Map) {
      final table = common['Table'];
      final table1 = common['Table1'];
      print('Table length:  ${table is List ? table.length : 'not a list'}');
      print('Table1 length: ${table1 is List ? table1.length : 'not a list'}');
      print('Table1 content: ${jsonEncode(table1)}');
    }
    // Full response, chunked so logcat does not cut it off.
    final full = jsonEncode(response);
    const chunk = 800;
    for (var i = 0; i < full.length; i += chunk) {
      print('RAW[$iid] ${full.substring(i, i + chunk > full.length ? full.length : i + chunk)}');
    }
    print('=== getTargetData IID=$iid END ===');

    List<MarketingTargetDetail> detailRows = [];
    List<MarketingTarget> summaryRows = [];

    // Table — individual member trip rows
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List) {
      for (var row in response['CommonResult']['Table']) {
        detailRows.add(MarketingTargetDetail.fromJson(row));
      }
    }

    // Table1 — per-SM/group summary rows
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table1'] is List) {
      for (var row in response['CommonResult']['Table1']) {
        summaryRows.add(MarketingTarget.fromJson(row));
      }
    }

    return MarketingTargetApiResult(
      detailRows: detailRows,
      summaryRows: summaryRows,
    );
  }

  List<MarketingDetailedData> getDetailedDataForSM(
    List<MarketingDetailedData> allDetailedData,
    String smCode,
  ) {
    return allDetailedData.where((data) => data.sm == smCode).toList();
  }

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