
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_gift_modal.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class GiftsRepository {
  final ApiService apiService;

  GiftsRepository(this.apiService);

  Future<List<Guest>> getGiftMembers() async {
    final salesCode = await StorageUtil.getSalesCode();

    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9031,
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
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1"
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        response['CommonResult']['Table'].isNotEmpty) {
      final tableData = response['CommonResult']['Table'];

      List<Guest> giftGuestsList = [];

      if (tableData.length > 0) {
        for (var table in tableData) {
          giftGuestsList.add(
              Guest.withGift(mid: table['MID'], memberName: table['MNAME']));
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
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9032,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int"
        },
        {
          "Para_Data": mid,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar"
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1"
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
}
