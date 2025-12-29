import 'dart:convert';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/add_phone/email_response.dart';

import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class EmailRepository {
  final ApiService apiService;

  EmailRepository(this.apiService);

  Future<EmailResponse?> addOrUpdateEmail({
    required String memberId,
    required String email,
    required String memberName,
    required int emailType, // 1 for Email1, 2 for Email2
  }) async {
    final deviceId = await DeviceId.get();
    final name = await StorageUtil.getUserName();
    // Determine Iid based on emailType
    int iid;
    switch (emailType) {
      case 1:
        iid = 8033; // Email1
        break;
      case 2:
        iid = 8034; // Email2
        break;
      default:
        iid = 8033; // Default to Email1
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
          "Para_Data": email,
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
      "SpName": "sp_CRM_Common_API",
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
        return EmailResponse.fromJson(table, emailType);
      }
      return null;
    } catch (e) {
      print('Error adding/updating email: $e');
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