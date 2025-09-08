import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';
import '../../models/user_model.dart';

class AuthRepository {
  final ApiService apiService;
  final FlutterSecureStorage storage;

  AuthRepository(this.apiService, this.storage);

  Future<String> authenticate() async {
    try {
      final response = await apiService.post('Login', {
        "UserName": "BaLlY\$#Crm619",
        "PassWord": "cRm_0987_@bL",
      });

      if (response['Token'] != null &&
          response['Token']['access_token'] != null) {
        String accessToken = response['Token']['access_token'];
        // Debug print
        await storage.write(key: 'access_token', value: accessToken);
        print('accessToken: $accessToken');
        return accessToken;
      } else {
        throw Exception('Authentication failed: No token received');
      }
    } catch (e) {
      print('Authentication failed with error: $e');
      rethrow;
    }
  }

  Future<User> login(String text1, String text2) async {
    final deviceId = await DeviceId.get();
    print('Device ID being used: $deviceId');

    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 90144,
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
          "Para_Data": text2,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text3",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": "APP",
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text4",
          "Para_Type": "varchar",
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1",
    });

    print('hhhhh :$response');

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'][0];

      if (tableData['LoginStatus'] == 'True') {
        return User(
          userName: tableData['Login_By'],
          userLevel: tableData['User_Level'].toString(),
          salesCode: tableData['Sales_Code'].toString(),
          marketingCode: tableData['Marketing_Code'].toString(),
          mobileNumber: tableData['Mobile'].toString(),
        );
      } else if (tableData['LoginID'] != null) {
        throw Exception('Login failed: login id not found ');
      } else {
        throw Exception(
          'Login failed: Invalid credentials or LoginStatus is not True',
        );
      }
    } else {
      throw Exception('Login failed: unexpected response structure');
    }
  }
}
