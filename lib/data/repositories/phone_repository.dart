import 'dart:convert';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/add_phone/phone_response.dart';

import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class PhoneRepository {
  final ApiService apiService;

  PhoneRepository(this.apiService);

  Future<PhoneResponse?> addPhoneNumber({
    required String memberId,
    required String phoneNumber,
    required String memberName,
    required int phoneType, // 1 for Phone1, 2 for Phone2, 3 for Phone3
  }) async {
    final deviceId = await DeviceId.get();
       final name = await StorageUtil.getUserName();
        final spName = await StorageUtil.getStoredProcedureName();
    // Determine Iid based on phoneType
    int iid;
    switch (phoneType) {
      case 1:
        iid = 8030; // Phone1
        break;
      case 2:
        iid = 8031; // Phone2
        break;
      case 3:
        iid = 8032; // Phone3
        break;
      default:
        iid = 8030; // Default to Phone1
    }
    
    final requestBody = {
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
          "Para_Data": memberId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": phoneNumber,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": name,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text3",
          "Para_Type": "varchar",
        },
      ],
      "SpName": spName,
      "con": "1",
    };

    printLargeBody(jsonEncode(requestBody));

    try {
      final response = await apiService.post('CommonExecute', requestBody);

      if (response['strRturnRes'] == true &&
          response['CommonResult'] != null &&
          response['CommonResult']['Table'] is List &&
          response['CommonResult']['Table'].isNotEmpty) {
        final table = response['CommonResult']['Table'][0];
        return PhoneResponse.fromJson(table, phoneType);
      }
      return null;
    } catch (e) {
      print('Error adding phone number: $e');
      rethrow;
    }
  }

  void printLargeBody(String body) {
    const chunkSize = 1024;
    for (int i = 0; i < body.length; i += chunkSize) {
      print(body.substring(i, i + chunkSize > body.length ? body.length : i + chunkSize));
    }
  }
}