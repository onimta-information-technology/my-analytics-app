import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/gift/gest_gift_data.dart';
import 'package:ballys_reservation_app/models/gift/gift_type.dart';
import 'package:ballys_reservation_app/models/gift/prev_gift.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:ballys_reservation_app/models/guest_gift_modal.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

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
        print(giftGuestsList[0].memberName);
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
  // Inside GiftsRepository class

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

      // Map API response to SpecialGiftRequest
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

      // Map API response to SpecialGiftRequest
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

  // GiftsRepository.dart

  Future<bool> insertSpecialGiftRequest({
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
      // helpers
      String numStr(num? v) => (v == null) ? "0" : v.toString();
      String decStr(num? v) => (v == null) ? "0" : v.toString();

      //final double totalCoupon = (guestCoupon ?? 0.0) + (flushCoupon ?? 0.0);

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

      return resp['strRturnRes'];
    } catch (e) {
      print('insertSpecialGiftRequest error: $e');
      return false;
    }
  }

  Future<bool> approvedSPecialgiftRequest({
    required double reqid,
    required String remarks,
    required String amount,
    required String userName,
  }) async {
    try {
      final deviceId = await DeviceId.get();
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
            "Para_Data": reqid,
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

      return resp['strRturnRes'];
    } catch (e) {
      print('APProve specialGiftRequest error: $e');
      return false;
    }
  }

  Future<bool> rejectSPecialgiftRequest({
    required double reqid,
    required String userName,
  }) async {
    try {
      final deviceId = await DeviceId.get();
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
            "Para_Data": reqid,
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

      return resp['strRturnRes'];
    } catch (e) {
      print('APProve specialGiftRequest error: $e');
      return false;
    }
  }
}
