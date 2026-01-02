
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class InactiveMembersRepository {
  final ApiService apiService;

  InactiveMembersRepository(this.apiService);

  Future<List<Guest>> getInactiveMembers(String text1, String text2,  AppMode appMode, 
    String salesCode) async {
    final salesCode = await StorageUtil.getSalesCode();
    final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9006,
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
      "SpName": "sp_CRM_Common_API",
      "con": "1"
    });
    print("hiii");
print( response);
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<Guest> inactiveGuestList = [];

      if (tableData.length > 0) {
        for (var table in tableData) {
          // inactiveGuestList.add(Guest.fromJson(table));
               final guest = Guest.fromJson(table);
          
          // Filter based on app mode and sales code
          if (appMode == AppMode.overallData && salesCode == 'AD001') {
            // AD001 in overall mode - show all data
            inactiveGuestList.add(guest);
          
          } else {
            // Other users OR AD001 in myData mode - show only matching mGroup
            if (guest.mGroup.toString() == salesCode) {
              inactiveGuestList.add(guest);
            
            }
          }
        }
     
        return inactiveGuestList;
      } else {
        throw Exception('No inactive members found');
      }
    } else {
      throw Exception(
          'No inactive members found: unexpected response structure');
    }
  }
}
