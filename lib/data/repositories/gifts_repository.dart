import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/gift/birthday_gift_request.dart';
import 'package:ballys_reservation_app/models/gift/gest_gift_data.dart';
import 'package:ballys_reservation_app/models/gift/gift_type.dart';
import 'package:ballys_reservation_app/models/gift/prev_gift.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:ballys_reservation_app/models/guest_gift_modal.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:http/http.dart' as http;

class GiftsRepository {
  final ApiService apiService;

  GiftsRepository(this.apiService);

  Future<List<Guest>> getGiftMembers() async {
    final salesCode = await StorageUtil.getSalesCode();
    final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9031,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": salesCode,
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

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<Guest> giftGuestsList = [];

      if (tableData.length > 0) {
        for (var table in tableData) {
          giftGuestsList.add(
            Guest.withGift(mid: table['MID'], memberName: table['MNAME']),
          );
        }
 
        return giftGuestsList;
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  Future<List<GuestGift>> getGuestGifts(String mid) async {
    final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9032,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": mid,
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

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<GuestGift> guestGiftsList = [];

      if (tableData.length > 0) {
        for (var table in tableData) {
          guestGiftsList.add(GuestGift.fromJson(table));
        }

        return guestGiftsList;
      } else {
        throw Exception('No gifts found');
      }
    } else {
      throw Exception('No gifts found: unexpected response structure');
    }
  }

  Future<List<SpecialGiftRequest>> getSpecialGift(int iid, String text1) async {
    final deviceId = await DeviceId.get();
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
      "SpName": "sp_CRM_Common_API",
      "con": "1",
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'] as List;
      print('Special Gift Response Table Data: $tableData');
      
      List<SpecialGiftRequest> giftSpecialList = tableData.map((item) {
        return SpecialGiftRequest.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      return giftSpecialList;
    } else {
      return [];
    }
  }

  Future<List<GestGiftData>> getgestgiftGift(
    int iid,
    String text1,
    String text2,
    String text3,
    String text4,
    String text5,
  ) async {
    final deviceId = await DeviceId.get();
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
          "Para_Data": text2,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": text3,
          "Para_Direction": "Input",
          "Para_Lenth": 5000,
          "Para_Name": "@Text3",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": text4,
          "Para_Direction": "Input",
          "Para_Lenth": 1000,
          "Para_Name": "@Text4",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": text5,
          "Para_Direction": "Input",
          "Para_Lenth": 1000,
          "Para_Name": "@Text5",
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

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'] as List;

      List<GestGiftData> giftdataList = tableData.map((item) {
        return GestGiftData.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      return giftdataList;
    } else {
      return [];
    }
  }

  Future<List<GiftType>> getGiftForList() async {
    final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 8887,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
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

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'] as List;

      return tableData.map((item) {
        return GiftType.fromJson(Map<String, dynamic>.from(item));
      }).toList();
    } else {
      return [];
    }
  }

  Future<List<PrevGift>> getPrvGiftList(String text1) async {
    final deviceId = await DeviceId.get();
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 8888,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": text1,
          "Para_Direction": "Input",
          "Para_Lenth": 5000,
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
    
    print('Prev Gift Response: $response');
    
    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        (response['CommonResult']['Table'] as List).isNotEmpty) {
      final tableData = response['CommonResult']['Table'] as List;

      return tableData.map((item) {
        return PrevGift.fromJson(Map<String, dynamic>.from(item));
      }).toList();
    } else {
      return [];
    }
  }

  Future<Map<String, dynamic>?> insertSpecialGiftRequest({
    required String mid,
    required String memberName,
    required String fromDateTime,
    required String toDateTime,
    required String arrivalDate,
    required String departureDate,
    required String giftForCode,
    required String chipTypeCode,
    required String amount,
    required String remarks,
    double? guestDrop,
    double? tmpCashout,
    double? res,
    double? actD,
    double? tmpAvgBet,
    double? guestCoupon,
    double? flushCoupon,
    double? flushActDrop,
    double? tmpPoint,
    double? tmphh,
    double? tmpCommpaid,
    String? grt,
    required String userName,
  }) async {
    try {
      final deviceId = await DeviceId.get();
      String numStr(num? v) => (v == null) ? "0" : v.toString();
      String decStr(num? v) => (v == null) ? "0" : v.toString();

      print('Inserting special gift request for MID: $mid, Member Name: $memberName, Amount: $amount');
      
      final payload = {
        "HasReturnData": "T",
        "Parameters": [
          {
            "Para_Data": 8889,
            "Para_Direction": "Input",
            "Para_Lenth": 1,
            "Para_Name": "@Iid",
            "Para_Type": "int",
          },
          {
            "Para_Data": mid,
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
            "Para_Data": decStr(guestDrop),
            "Para_Direction": "Input",
            "Para_Lenth": 5000,
            "Para_Name": "@Text3",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmpCashout),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text4",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(res),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text5",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(guestCoupon),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text6",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmpAvgBet),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text7",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmpPoint),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text8",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmphh),
            "Para_Direction": "Input",
            "Para_Lenth": 5000,
            "Para_Name": "@Text9",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmphh),
            "Para_Direction": "Input",
            "Para_Lenth": 1000,
            "Para_Name": "@Text10",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": arrivalDate,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text11",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": departureDate,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text12",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": userName,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text13",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": fromDateTime,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text14",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": toDateTime,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text15",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmpCommpaid),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text16",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(actD),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text17",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": grt,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text18",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": remarks,
            "Para_Direction": "Input",
            "Para_Lenth": 250,
            "Para_Name": "@Text19",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": amount,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text20",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(flushCoupon),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text21",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": chipTypeCode,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text22",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": giftForCode,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text23",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": "chip",
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text24",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": flushActDrop,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text25",
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
      };

      final resp = await apiService.post('CommonExecute', payload);
      print('Special Gift Insert Response: $resp');
      return resp;
    } catch (e) {
      print('Error in insertSpecialGiftRequest: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> increeseBirthdayGiftRequest({
    required String mid,
    required String memberName,
    required String fromDateTime,
    required String toDateTime,
    required String arrivalDate,
    required String departureDate,
    required String giftForCode,
    required String chipTypeCode,
    required String amount,
    required String remarks,
    required String previousGiftPrice,
    double? guestDrop,
    double? tmpCashout,
    double? res,
    double? actD,
    double? tmpAvgBet,
    double? guestCoupon,
    double? flushCoupon,
    double? flushActDrop,
    double? tmpPoint,
    double? tmphh,
    double? tmpCommpaid,
    String? grt,
    required String userName,
  }) async {
    try {
      final deviceId = await DeviceId.get();
      String numStr(num? v) => (v == null) ? "0" : v.toString();
      String decStr(num? v) => (v == null) ? "0" : v.toString();

      print('Inserting birthday gift price increase request for MID: $mid, Member Name: $memberName, New Amount: $amount, Previous Amount: $previousGiftPrice, fromDateTime: $fromDateTime, toDateTime: $toDateTime, guestDrop: $guestDrop, tmpCashout: $tmpCashout, res: $res, guestCoupon: $guestCoupon, tmpAvgBet: $tmpAvgBet, tmpPoint: $tmpPoint, tmphh: $tmphh, tmpCommpaid: $tmpCommpaid, grt: $grt,userName: $userName, deviceId: $deviceId, arrivalDate: $arrivalDate, departureDate: $departureDate,act: $actD,flushActDrop: $flushActDrop,flushCoupon: $flushCoupon,chipTypeCode: $chipTypeCode,giftForCode: $giftForCode' );
      
      final payload = {
        "HasReturnData": "T",
        "Parameters": [
          {
            "Para_Data": 98889,
            "Para_Direction": "Input",
            "Para_Lenth": 1,
            "Para_Name": "@Iid",
            "Para_Type": "int",
          },
          {
            "Para_Data": mid,
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
            "Para_Data": decStr(guestDrop),
            "Para_Direction": "Input",
            "Para_Lenth": 5000,
            "Para_Name": "@Text3",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmpCashout),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text4",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(res),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text5",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(guestCoupon),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text6",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmpAvgBet),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text7",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmpPoint),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text8",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmphh),
            "Para_Direction": "Input",
            "Para_Lenth": 5000,
            "Para_Name": "@Text9",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmphh),
            "Para_Direction": "Input",
            "Para_Lenth": 1000,
            "Para_Name": "@Text10",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": arrivalDate,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text11",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": departureDate,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text12",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": userName,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text13",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": fromDateTime,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text14",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": toDateTime,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text15",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(tmpCommpaid),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text16",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(actD),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text17",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": grt,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text18",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": remarks,
            "Para_Direction": "Input",
            "Para_Lenth": 250,
            "Para_Name": "@Text19",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": amount,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text20",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": decStr(flushCoupon),
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text21",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": chipTypeCode,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text22",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": giftForCode,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text23",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": "chip",
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text24",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": flushActDrop,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text25",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": previousGiftPrice,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text26",
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
      };

      final resp = await apiService.post('CommonExecute', payload);
      print('Birthday Gift Price Increase Response: $resp');
      return resp;
    } catch (e) {
      print('Error in increeseBirthdayGiftRequest: $e');
      return null;
    }
  }

  Future<bool> approvedSPecialgiftRequest({
    required double reqid,
    required String remarks,
    required String amount,
    required String userName,
    required String validDates,
  }) async {
    print('Approving special gift request: reqid=$reqid, remarks=$remarks, amount=$amount, userName=$userName, validDates=$validDates'); 

    try {
      final deviceId = await DeviceId.get();
      final reqidInt = reqid.toInt();
      print('Converted reqid to int: $reqidInt');
      
      final payload = {
        "HasReturnData": "T",
        "Parameters": [
          {
            "Para_Data": 8894,
            "Para_Direction": "Input",
            "Para_Lenth": 1,
            "Para_Name": "@Iid",
            "Para_Type": "int",
          },
          {
            "Para_Data": reqidInt,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text1",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": userName,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text2",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": remarks,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text3",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": amount,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text4",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": validDates,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text5",
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
      };

      final resp = await apiService.post('CommonExecute', payload);
      print('Approve Gift Response: $resp');
      return true;
    } catch (e) {
      print('Error approving special gift request: $e');
      return false;
    }
  }

  Future<bool> rejectSPecialgiftRequest({
    required double reqid,
    required String userName,
  }) async {
    try {
      print('Rejecting special gift request: reqid=$reqid, userName=$userName');
      final deviceId = await DeviceId.get();
      final reqidInt = reqid.toInt();
      
      final payload = {
        "HasReturnData": "T",
        "Parameters": [
          {
            "Para_Data": 8892,
            "Para_Direction": "Input",
            "Para_Lenth": 1,
            "Para_Name": "@Iid",
            "Para_Type": "int",
          },
          {
            "Para_Data": reqidInt,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text1",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": userName,
            "Para_Direction": "Input",
            "Para_Lenth": 100,
            "Para_Name": "@Text2",
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
      };

      final resp = await apiService.post('CommonExecute', payload);
      print('Reject Gift Response: $resp');
      return true;
    } catch (e) {
      print('Error rejecting special gift request: $e');
      return false;
    }
  }

  Future<bool> reverseSpecialGiftRequest({
    required double reqid,
    required String userName,
  }) async {
    try {
      print('Approve Reversing special gift request: reqid=$reqid, userName=$userName');
      
      final reqidInt = reqid.toInt();
      print('Converted reqid to int: $reqidInt');
      
      final payload = {
        "HasReturnData": "T",
        "Parameters": [
          {
            "Para_Data": 88894,
            "Para_Direction": "Input",
            "Para_Lenth": 1,
            "Para_Name": "@Iid",
            "Para_Type": "int",
          },
          {
            "Para_Data": reqidInt,
            "Para_Direction": "Input",
            "Para_Lenth": 5000,
            "Para_Name": "@Text1",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": userName,
            "Para_Direction": "Input",
            "Para_Lenth": 5000,
            "Para_Name": "@Text2",
            "Para_Type": "varchar",
          },
        ],
        "SpName": "sp_CRM_Common_API",
        "con": "1",
      };

      final resp = await apiService.post('CommonExecute', payload);
      print('Reverse gift response: $resp');
      return true;
    } catch (e) {
      print('Error reversing special gift request: $e');
      return false;
    }
  }

  Future<bool> reverseSpecialGiftRequestRejected({
    required double reqid,
    required String userName,
  }) async {
    try {
      print('Reject Reversing special gift request: reqid=$reqid, userName=$userName');
      
      final reqidInt = reqid.toInt();
      print('Converted reqid to int: $reqidInt');
      
      final payload = {
        "HasReturnData": "T",
        "Parameters": [
          {
            "Para_Data": 88895,
            "Para_Direction": "Input",
            "Para_Lenth": 1,
            "Para_Name": "@Iid",
            "Para_Type": "int",
          },
          {
            "Para_Data": reqidInt,
            "Para_Direction": "Input",
            "Para_Lenth": 5000,
            "Para_Name": "@Text1",
            "Para_Type": "varchar",
          },
          {
            "Para_Data": userName,
            "Para_Direction": "Input",
            "Para_Lenth": 5000,
            "Para_Name": "@Text2",
            "Para_Type": "varchar",
          },
        ],
        "SpName": "sp_CRM_Common_API",
        "con": "1",
      };

      final resp = await apiService.post('CommonExecute', payload);
      print('Reverse gift rejected response: $resp');
      return true;
    } catch (e) {
      print('Error reversing rejected special gift request: $e');
      return false;
    }
  }
  ///birthday gift price increase request end
  // Add these methods to your existing GiftsRepository class
 Future<List<BirthdayIncressGiftRequest>> getBirthdayIncressGift(int iid, String text1) async {
    final deviceId = await DeviceId.get();
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
      "SpName": "sp_CRM_Common_API",
      "con": "1",
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'] as List;
      print('Special Gift Response Table Data: $tableData');
      
      List<BirthdayIncressGiftRequest> giftSpecialList = tableData.map((item) {
        return BirthdayIncressGiftRequest.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      return giftSpecialList;
    } else {
      return [];
    }
  }
Future<bool> approvedBirthdayGiftRequest({
  required double reqid,
  required String remarks,
  required String amount,
  required String userName,
  required String validDates,
}) async {
  print('Approving birthday gift request: reqid=$reqid, remarks=$remarks, amount=$amount, userName=$userName, validDates=$validDates'); 

  try {
    final deviceId = await DeviceId.get();
    final reqidInt = reqid.toInt();
    print('Converted reqid to int: $reqidInt');
    
    final payload = {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 98894,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": reqidInt,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": userName,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": remarks,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text3",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": amount,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text4",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": validDates,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text5",
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
    };

    final resp = await apiService.post('CommonExecute', payload);
    print('Approve Birthday Gift Response: $resp');
    return true;
  } catch (e) {
    print('Error approving birthday gift request: $e');
    return false;
  }
}

Future<bool> rejectBirthdayGiftRequest({
  required double reqid,
  required String userName,
}) async {
  try {
    print('Rejecting birthday gift request: reqid=$reqid, userName=$userName');
    final deviceId = await DeviceId.get();
    final reqidInt = reqid.toInt();
    
    final payload = {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 98892,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": reqidInt,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": userName,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text2",
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
    };

    final resp = await apiService.post('CommonExecute', payload);
    print('Reject Birthday Gift Response: $resp');
    return true;
  } catch (e) {
    print('Error rejecting birthday gift request: $e');
    return false;
  }
}

Future<bool> reverseBirthdayGiftRequest({
  required double reqid,
  required String userName,
}) async {
  try {
    print('Approve Reversing birthday gift request: reqid=$reqid, userName=$userName');
    
    final reqidInt = reqid.toInt();
    print('Converted reqid to int: $reqidInt');
    
    final payload = {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 988894,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": reqidInt,
          "Para_Direction": "Input",
          "Para_Lenth": 5000,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": userName,
          "Para_Direction": "Input",
          "Para_Lenth": 5000,
          "Para_Name": "@Text2",
          "Para_Type": "varchar",
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1",
    };

    final resp = await apiService.post('CommonExecute', payload);
    print('Reverse birthday gift response: $resp');
    return true;
  } catch (e) {
    print('Error reversing birthday gift request: $e');
    return false;
  }
}

Future<bool> reverseBirthdayGiftRequestRejected({
  required double reqid,
  required String userName,
}) async {
  try {
    print('Reject Reversing birthday gift request: reqid=$reqid, userName=$userName');
    
    final reqidInt = reqid.toInt();
    print('Converted reqid to int: $reqidInt');
    
    final payload = {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 988895,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": reqidInt,
          "Para_Direction": "Input",
          "Para_Lenth": 5000,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": userName,
          "Para_Direction": "Input",
          "Para_Lenth": 5000,
          "Para_Name": "@Text2",
          "Para_Type": "varchar",
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1",
    };

    final resp = await apiService.post('CommonExecute', payload);
    print('Reverse birthday gift rejected response: $resp');
    return true;
  } catch (e) {
    print('Error reversing rejected birthday gift request: $e');
    return false;
  }
}


}