
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/inactive_member_group.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class InactiveMembersRepository {
  final ApiService apiService;

  InactiveMembersRepository(this.apiService);

  Future<InactiveMembersResult> getInactiveMembers(String text1, String text2,
      AppMode appMode, String salesCode) async {
    final salesCode = await StorageUtil.getSalesCode();
    final deviceId = await DeviceId.get();
    final spName = await StorageUtil.getStoredProcedureName();
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    final isBellagio = apiUrl.contains('bty.world');

    // Ballys moved to a new stored-procedure branch that returns the marketing
    // group summary (Table1) alongside the members; Bellagio stays on 9006.
    final iid = isBellagio ? 9006 : 1059006;

    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": iid,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int"
        },
        {
          "Para_Data": salesCode,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": text1,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar"
        },
        {
          "Para_Data": text2,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text3",
          "Para_Type": "varchar"
        },{
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text30",
          "Para_Type": "varchar",
        },
      ],
      "SpName": spName,
      "con": "1"
    });

    final commonResult = response['CommonResult'];
    if (commonResult == null) {
      return InactiveMembersResult(members: const [], groups: const []);
    }

    final tableData = commonResult['Table'] is List
        ? commonResult['Table'] as List
        : const [];
    final groupData = commonResult['Table1'] is List
        ? commonResult['Table1'] as List
        : const [];

    List<Guest> inactiveGuestList = [];
    for (var table in tableData) {
      final guest = Guest.fromJson(table);

      // Ballys shows every member the SP returned; they are browsed through the
      // Table1 group list instead. Bellagio keeps the old mGroup gating.
      if (!isBellagio) {
        inactiveGuestList.add(guest);
      } else if (appMode == AppMode.overallData && salesCode == 'AD001') {
        // AD001 in overall mode - show all data
        inactiveGuestList.add(guest);
      } else {
        // Other users OR AD001 in myData mode - show only matching mGroup
        if (guest.mGroup.toString() == salesCode) {
          inactiveGuestList.add(guest);
        }
      }
    }

    final groups = groupData
        .map((row) => InactiveMemberGroup.fromJson(row))
        .where((g) => g.gName.isNotEmpty)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return InactiveMembersResult(members: inactiveGuestList, groups: groups);
  }
}
