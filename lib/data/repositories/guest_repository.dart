import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/models/marketing_group.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

/// Which response layout the server returned
enum ResponseLayout {
  /// AD001 / manager: Table2={NON,MKT}, Table=all-mkt, Table1=sales-persons, Table3=NON
  admin,

  /// Regular user with OTHER slice:
  /// Table2={myCode,OTHER,NON}, Table=myData, Table3=NON, Table4=otherMkt
  regularWithOther,

  /// Regular user with only their own slice:
  /// Table2={myCode only}, Table=myData only
  regularMyDataOnly,
}

/// Return type wrapping everything from the API
class GuestDataResult {
  final List<Guest> guests;                    // Table  — meaning depends on layout
  final List<MarketingGroup> marketingGroups;  // Table2 — pie slices
  final List<MarketingGroup> salesPersonGroups;// Table1 — admin only (sales persons)
  final List<Guest> nonMarketingGuests;        // Table3 — NON MARKETING guests
  final List<Guest> otherMarketingGuests;      // Table4 — OTHER MARKETING guests (regular only)
  final ResponseLayout layout;

  const GuestDataResult({
    required this.guests,
    required this.marketingGroups,
    required this.salesPersonGroups,
    required this.nonMarketingGuests,
    required this.otherMarketingGuests,
    required this.layout,
  });
}

class GuestRepository {
  final ApiService apiService;

  GuestRepository(this.apiService);

  Future<GuestDataResult> getGuestData2(int iid, String text1) async {
    final deviceId = await DeviceId.get();
    print("iid is $iid and text1 is $text1");
    final spName = await StorageUtil.getStoredProcedureName();
    print("spname :$spName");
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
          "Para_Data": text1,
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

    print("getGuestData2 response: $response");

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final commonResult = response['CommonResult'];

      // ── Table (always present) ────────────────────────────────────────────
      final tableData = commonResult['Table'] as List? ?? [];

      // // 🔍 DEBUG: Print first Table item keys to check field name casing
      // if (tableData.isNotEmpty) {
      //   print('🔍 [Table] keys: ${(tableData.first as Map).keys.toList()}');
      //   print('🔍 [Table] first item: ${tableData.first}');
      // }

      List<Guest> guestList = tableData.map((e) => Guest.fromJson(e)).toList();

      // ── Table1 (admin only — sales person summary) ───────────────────────
      final table1Data = commonResult['Table1'];

      // // 🔍 DEBUG: Print raw Table1 to check GCode/GName/rc casing
      // if (table1Data is List && table1Data.isNotEmpty) {
      //   print('🔍 [Table1] keys: ${(table1Data.first as Map).keys.toList()}');
      //   print('🔍 [Table1] first item: ${table1Data.first}');
      //   print('🔍 [Table1] ALL items: $table1Data');
      // } else {
      //   print('🔍 [Table1] is empty or null');
      // }

      List<MarketingGroup> salesPersonGroups = [];
      if (table1Data is List && table1Data.isNotEmpty) {
        salesPersonGroups = table1Data
            .map((e) => MarketingGroup.fromJson(e))
            .where((g) => g.gCode.isNotEmpty && g.rc > 0)
            .toList()
          ..sort((a, b) => b.rc.compareTo(a.rc));

        // // 🔍 DEBUG: Print parsed sales person groups to confirm names parsed correctly
        // print('🔍 [Table1] PARSED salesPersonGroups:');
        // for (final g in salesPersonGroups) {
        //   print('   gCode="${g.gCode}"  gName="${g.gName}"  rc=${g.rc}');
        // }
      }

      // ── Table2 (pie slices — always present) ─────────────────────────────
      final table2Data = commonResult['Table2'];

      // 🔍 DEBUG: Print raw Table2 to check GCode/GName/rc casing
      // if (table2Data is List && table2Data.isNotEmpty) {
      //   print('🔍 [Table2] keys: ${(table2Data.first as Map).keys.toList()}');
      //   print('🔍 [Table2] first item: ${table2Data.first}');
      //   print('🔍 [Table2] ALL items: $table2Data');
      // } else {
      //   print('🔍 [Table2] is empty or null');
      // }

      List<MarketingGroup> marketingGroups = [];
      if (table2Data is List && table2Data.isNotEmpty) {
        marketingGroups = table2Data
            .map((e) => MarketingGroup.fromJson(e))
            .where((g) => g.gCode.isNotEmpty && g.rc > 0)
            .toList();

        // // 🔍 DEBUG: Print parsed marketing groups to confirm names parsed correctly
        // print('🔍 [Table2] PARSED marketingGroups:');
        // for (final g in marketingGroups) {
        //   print('   gCode="${g.gCode}"  gName="${g.gName}"  rc=${g.rc}');
        // }
      }

      // ── Table3 (non-marketing guests) ────────────────────────────────────
      final table3Data = commonResult['Table3'];

      // // 🔍 DEBUG: Print first Table3 item keys
      // if (table3Data is List && table3Data.isNotEmpty) {
      //   print('🔍 [Table3] keys: ${(table3Data.first as Map).keys.toList()}');
      //   print('🔍 [Table3] first item: ${table3Data.first}');
      // } else {
      //   print('🔍 [Table3] is empty or null');
      // }

      List<Guest> nonMarketingGuests = [];
      if (table3Data is List && table3Data.isNotEmpty) {
        nonMarketingGuests = table3Data.map((e) => Guest.fromJson(e)).toList();
      }

      // ── Table4 (other marketing guests — regular user only) ───────────────
      final table4Data = commonResult['Table4'];

      // 🔍 DEBUG: Print first Table4 item keys
      if (table4Data is List && table4Data.isNotEmpty) {
        print('🔍 [Table4] keys: ${(table4Data.first as Map).keys.toList()}');
        print('🔍 [Table4] first item: ${table4Data.first}');
      } else {
        print('🔍 [Table4] is empty or null');
      }

      List<Guest> otherMarketingGuests = [];
      if (table4Data is List && table4Data.isNotEmpty) {
        otherMarketingGuests = table4Data.map((e) => Guest.fromJson(e)).toList();
      }

      // ── Detect layout ────────────────────────────────────────────────────
      final hasMkt   = marketingGroups.any((g) => g.gCode == 'MKT');
      final hasOther = marketingGroups.any((g) => g.gCode == 'OTHER');

      final ResponseLayout layout;
      if (hasMkt) {
        layout = ResponseLayout.admin;
      } else if (hasOther) {
        layout = ResponseLayout.regularWithOther;
      } else {
        layout = ResponseLayout.regularMyDataOnly;
      }

      print("Detected layout: $layout");
      print("marketingGroups: ${marketingGroups.map((g) => '${g.gCode}=${g.rc}').join(', ')}");

      if (guestList.isNotEmpty || marketingGroups.isNotEmpty) {
        return GuestDataResult(
          guests: guestList,
          marketingGroups: marketingGroups,
          salesPersonGroups: salesPersonGroups,
          nonMarketingGuests: nonMarketingGuests,
          otherMarketingGuests: otherMarketingGuests,
          layout: layout,
        );
      } else {
        throw Exception('No data returned from server');
      }
    } else {
      throw Exception('Login failed: unexpected response structure');
    }
  }

  Future<List<Guest>> getGuestData(int iid, String text1) async {
    final deviceId = await DeviceId.get();
    final spName = await StorageUtil.getStoredProcedureName();
    print("iid is $iid and text1 is $text1");
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
          "Para_Data": text1,
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
print("getGuestData response: $response");
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];
      List<Guest> guestList =
          (tableData as List).map((e) => Guest.fromJson(e)).toList();

      if (guestList.isNotEmpty) return guestList;
      throw Exception('Login failed: Invalid credentials or LoginStatus is not True');
    } else {
      throw Exception('Login failed: unexpected response structure');
    }
  }

  Future<String?> fetchGuestImage(int iid, String text1) async {
    final deviceId = await DeviceId.get();
    final spName = await StorageUtil.getStoredProcedureName();
    print('Fetching guest image with IID: $iid, Text1: $text1, DeviceId: $deviceId, SpName: $spName');
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
          "Para_Data": text1,
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
print('API response for guest image: $response');
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'][0];
      if (tableData.containsKey('MemImage2') && tableData['MemImage2'] != null) {
        return tableData['MemImage2'];
      }
    }
    return null;
  }

  Future<List<GuestSearchResponse>> searchGuest(int iid, String text1) async {
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
          "Para_Data": text1,
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

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];
      List<GuestSearchResponse> results =
          (tableData as List).map((e) => GuestSearchResponse.fromJson(e)).toList();
      if (results.isNotEmpty) return results;
    }
    throw Exception('Failed guests searching');
  }
}