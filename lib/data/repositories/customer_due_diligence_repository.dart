// lib/data/repositories/customer_due_diligence_repository.dart

import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/cdd/customer_due_diligence_model.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class CustomerDueDiligenceRepository {
  final ApiService apiService;

  CustomerDueDiligenceRepository(this.apiService);

  Future<CustomerDueDiligenceModel> submitCDD({
    required String passportOrNic,
    required String identificationNumber,
    required String sourceOfFunds,       
    required String clientType,           
    required String natureOfBusiness,      
  }) async {
    final deviceId = await DeviceId.get();
    final username = await StorageUtil.getUserName();
    final selseCode = await StorageUtil.getSalesCode();
    print('submitCDD called with:');
    print('  passportOrNic: $passportOrNic');
    print('  identificationNumber: $identificationNumber');
    print('  sourceOfFunds: $sourceOfFunds');
    print('  clientType: $clientType');
    print('  natureOfBusiness: $natureOfBusiness');
    print('  deviceId: $deviceId');
    print('  username: $username');
    print('  selseCode: $selseCode');
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 10002,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
       
        {
          "Para_Data": passportOrNic,   
          "Para_Direction": "Input",
          "Para_Lenth": 50,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": identificationNumber,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": sourceOfFunds,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text3",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": clientType,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text4",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": natureOfBusiness,
          "Para_Direction": "Input",
          "Para_Lenth": 20,
          "Para_Name": "@Text5",
          "Para_Type": "varchar",
        },
           {
          "Para_Data": username,
          "Para_Direction": "Input",
          "Para_Lenth": 20,
          "Para_Name": "@Text6",
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
print('CDD API response: $response');
    if (response['CommonResult'] != null) {
      return CustomerDueDiligenceModel.fromJson(response['CommonResult']);
    } else {
      throw Exception('Unexpected response structure from CDD submission');
    }
  }
}