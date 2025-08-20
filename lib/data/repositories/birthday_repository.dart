import 'dart:io';

import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/birthday.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class BirthdayRepository {
  final ApiService apiService;

  BirthdayRepository(this.apiService);

  Future<Map<String, List<Birthday>>> getBirthdays() async {
    final salesCode = await StorageUtil.getSalesCode();

    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": 9004,
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

    if (response['CommonResult'] != null) {
      final commonResult = response['CommonResult'];

      Map<String, List<Birthday>> birthdayMap = {
        'past': [],
        'recentPast': [],
        'recentUpcoming': [],
        'upcoming': []
      };

      if (commonResult['Table'] is List && commonResult['Table'].isNotEmpty) {
        birthdayMap['past'] = commonResult['Table']
            .map<Birthday>((e) => Birthday.fromJson(e))
            .toList();
      }

      if (commonResult['Table1'] is List && commonResult['Table1'].isNotEmpty) {
        birthdayMap['recentPast'] = commonResult['Table1']
            .map<Birthday>((e) => Birthday.fromJson(e))
            .toList();
      }

      if (commonResult['Table2'] is List && commonResult['Table2'].isNotEmpty) {
        birthdayMap['recentUpcoming'] = commonResult['Table2']
            .map<Birthday>((e) => Birthday.fromJson(e))
            .toList();
      }

      if (commonResult['Table3'] is List && commonResult['Table3'].isNotEmpty) {
        birthdayMap['upcoming'] = commonResult['Table3']
            .map<Birthday>((e) => Birthday.fromJson(e))
            .toList();
      }

      return birthdayMap;
    } else {
      throw Exception(
          'Birthday retrieving failed: unexpected response structure');
    }
  }

  Future<String> sendWhatsappMessage(
      {required String mname,
      required String whatsappNumber,
      required String gift}) async {
    final userName = await StorageUtil.getUserName();
    String contact = "94787180744";
    String text = '';
    String androidUrl = "whatsapp://send?phone=$contact&text=$text";
    String iosUrl = "https://wa.me/$contact?text=${Uri.parse(text)}";
    String webUrl = 'https://api.whatsapp.com/send/?phone=$contact&text=hi';
    // try {
    //   if (Platform.isIOS) {
    //     if (await canLaunchUrl(Uri.parse(iosUrl))) {
    //       await launchUrl(Uri.parse(iosUrl));
    //     }
    //   } else {
    //     if (await canLaunchUrl(Uri.parse(androidUrl))) {
    //       await launchUrl(Uri.parse(androidUrl));
    //     }
    //   }
    // } catch (e) {
    //   print('object');
    //   await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    // }
    //  EasyLoading.showError('WhatsApp is not installed.');

    // print(jsonEncode({
    //   'whatsapp_number': whatsappNumber,
    //   'member_name': mname,
    //   'gift_value': gift,
    //   'created_by': userName
    // }));
    // final response = await http.post(
    //   Uri.parse('${Constants.laravelAPIbaseUrl}/gift/send'),
    //   body: jsonEncode({
    //     'whatsapp_number': whatsappNumber,
    //     'member_name': mname,
    //     'gift_value': gift,
    //     'created_by': userName
    //   }),
    // );

    // final responseBody = jsonDecode(response.body);
    // if (response.statusCode == 200) {
    // final whatsappUrl =
    //     'https://wa.me/+$whatsappNumber?text=Congratulations!+You+have+received+a+gift+valued+at+$gift!+🎁✨+Enjoy+this+special+token+of+appreciation,+and+may+it+bring+a+little+extra+joy+to+your+day!+https://api.mkt.onimtaitsl.com/gift/50000';
    // await http.get(Uri.parse(whatsappUrl));
    return "Success";
    // } else {
    //   throw Exception('Failed to send gift');
    // }
  }
}
