import 'dart:convert';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/primary_contact_response.dart';

import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class PrimaryContactRepository {
  final ApiService apiService;

  PrimaryContactRepository(this.apiService);

  // Set primary phone
  Future<PrimaryContactResponse?> setPrimaryPhone({
    required String memberId,
    required String phoneNumber,
    required String memberName,
  }) async {
    return await _setPrimary(
      memberId: memberId,
      value: phoneNumber,
      memberName: memberName,
      iid: 8038,
    );
  }

  // Set primary email
  Future<PrimaryContactResponse?> setPrimaryEmail({
    required String memberId,
    required String email,
    required String memberName,
  }) async {
    return await _setPrimary(
      memberId: memberId,
      value: email,
      memberName: memberName,
      iid: 8039,
    );
  }

  // Set primary WhatsApp
  Future<PrimaryContactResponse?> setPrimaryWhatsApp({
    required String memberId,
    required String whatsappNumber,
    required String memberName,
  }) async {
    return await _setPrimary(
      memberId: memberId,
      value: whatsappNumber,
      memberName: memberName,
      iid: 8040,
    );
  }

  Future<PrimaryContactResponse?> _setPrimary({
    required String memberId,
    required String value,
    required String memberName,
    required int iid,
  }) async {
    final deviceId = await DeviceId.get();
    final name = await StorageUtil.getUserName();
 final spName = await StorageUtil.getStoredProcedureName();
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
          "Para_Data": memberName,
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
        {
          "Para_Data": value,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text4",
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
    };

    _printLargeBody(jsonEncode(requestBody));

    try {
      final response = await apiService.post('CommonExecute', requestBody);

      if (response['strRturnRes'] == true &&
          response['CommonResult'] != null &&
          response['CommonResult']['Table'] is List &&
          response['CommonResult']['Table'].isNotEmpty) {
        final table = response['CommonResult']['Table'][0];
        return PrimaryContactResponse.fromJson(table);
      }
      return null;
    } catch (e) {
      print('Error setting primary contact: $e');
      rethrow;
    }
  }

  void _printLargeBody(String body) {
    const chunkSize = 1024;
    for (int i = 0; i < body.length; i += chunkSize) {
      print(body.substring(
          i, i + chunkSize > body.length ? body.length : i + chunkSize));
    }
  }
}