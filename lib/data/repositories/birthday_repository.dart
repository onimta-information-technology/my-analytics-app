import 'dart:convert';
import 'dart:io';

import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/birthday.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
          "Para_Type": "int",
        },
        {
          "Para_Data": salesCode,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },
      ],
      "SpName": "sp_CRM_Common_API",
      "con": "1",
    });

    if (response['CommonResult'] != null) {
      final commonResult = response['CommonResult'];

      Map<String, List<Birthday>> birthdayMap = {
        'past': [],
        'recentPast': [],
        'recentUpcoming': [],
        'upcoming': [],
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
        'Birthday retrieving failed: unexpected response structure',
      );
    }
  }

  // Future<String> sendWhatsappMessage(
  //     {required String mname,
  //     required String whatsappNumber,
  //     required String gift}) async {
  //   final userName = await StorageUtil.getUserName();
  //   String contact = "94787180744";
  //   String text = '';
  //   String androidUrl = "whatsapp://send?phone=$contact&text=$text";
  //   String iosUrl = "https://wa.me/$contact?text=${Uri.parse(text)}";
  //   String webUrl = 'https://api.whatsapp.com/send/?phone=$contact&text=hi';
  //   // try {
  //   //   if (Platform.isIOS) {
  //   //     if (await canLaunchUrl(Uri.parse(iosUrl))) {
  //   //       await launchUrl(Uri.parse(iosUrl));
  //   //     }
  //   //   } else {
  //   //     if (await canLaunchUrl(Uri.parse(androidUrl))) {
  //   //       await launchUrl(Uri.parse(androidUrl));
  //   //     }
  //   //   }
  //   // } catch (e) {
  //   //   print('object');
  //   //   await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
  //   // }
  //   //  EasyLoading.showError('WhatsApp is not installed.');

  //   // print(jsonEncode({
  //   //   'whatsapp_number': whatsappNumber,
  //   //   'member_name': mname,
  //   //   'gift_value': gift,
  //   //   'created_by': userName
  //   // }));
  //   // final response = await http.post(
  //   //   Uri.parse('${Constants.laravelAPIbaseUrl}/gift/send'),
  //   //   body: jsonEncode({
  //   //     'whatsapp_number': whatsappNumber,
  //   //     'member_name': mname,
  //   //     'gift_value': gift,
  //   //     'created_by': userName
  //   //   }),
  //   // );

  //   // final responseBody = jsonDecode(response.body);
  //   // if (response.statusCode == 200) {
  //   // final whatsappUrl =
  //   //     'https://wa.me/+$whatsappNumber?text=Congratulations!+You+have+received+a+gift+valued+at+$gift!+🎁✨+Enjoy+this+special+token+of+appreciation,+and+may+it+bring+a+little+extra+joy+to+your+day!+https://api.mkt.onimtaitsl.com/gift/50000';
  //   // await http.get(Uri.parse(whatsappUrl));
  //   return "Success";
  //   // } else {
  //   //   throw Exception('Failed to send gift');
  //   // }
  // }
   Future<String> sendWhatsappMessage({
    required String mname,
    required String whatsappNumber,
    required String gift,
  }) async {
    try {
      final userName = await StorageUtil.getUserName();
      
      // First, save the gift data to your API
      final response = await http.post(
        Uri.parse('${Constants.laravelAPIbaseUrl}/gift/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'whatsapp_number': whatsappNumber,
          'member_name': mname,
          'gift_value': gift,
          'created_by': userName
        }),
      );

      if (response.statusCode == 200) {
        // Create the WhatsApp message
        final responseBody= jsonDecode(response.body);
        final giftCode = responseBody['gift_code'];  
        print(giftCode);
        String message = 'Congratulations! \n\n'
            'You have received a gift valued at $gift! 🎁✨\n\n'
            'Enjoy this special token of appreciation, and may it bring '
            'a little extra joy to your day!\n\n'
            'Click here to claim: https://api.mkt.onimtaitsl.com/gift/$giftCode';
        
        // URL encode the message
        String encodedMessage = Uri.encodeComponent(message);
        
        // Ensure phone number has proper format
        String phoneNumber = whatsappNumber.trim();
        // if (!phoneNumber.startsWith('+')) {
        //   phoneNumber = '+$phoneNumber';
        // }
        
        // Create WhatsApp URLs
        String androidUrl = "whatsapp://send?phone=$phoneNumber&text=$encodedMessage";
        String iosUrl = "https://wa.me/$phoneNumber?text=$encodedMessage";
        String webUrl = "https://wa.me/$phoneNumber?text=$encodedMessage";
        
        // Try to launch WhatsApp with more aggressive approach
        bool launched = false;
        
        // Method 1: Try app-specific URLs first without canLaunchUrl check
        try {
          if (Platform.isAndroid) {
            // Try Android app URL directly
            await launchUrl(
              Uri.parse(androidUrl),
              mode: LaunchMode.externalApplication,
            );
            launched = true;
          } else if (Platform.isIOS) {
            // Try iOS app URL directly
            await launchUrl(
              Uri.parse(iosUrl),
              mode: LaunchMode.externalApplication,
            );
            launched = true;
          }
        } catch (e) {
          print('App URL failed: $e');
          launched = false;
        }
        
        // Method 2: If app launch failed, try web WhatsApp
        if (!launched) {
          try {
            await launchUrl(
              Uri.parse(webUrl),
              mode: LaunchMode.externalApplication,
            );
            launched = true;
          } catch (e) {
            print('Web URL failed: $e');
          }
        }
        
        // Method 3: Final fallback - try simple wa.me URL
        if (!launched) {
          try {
            String fallbackUrl = "https://wa.me/$phoneNumber";
            await launchUrl(
              Uri.parse(fallbackUrl),
              mode: LaunchMode.externalApplication,
            );
            launched = true;
          } catch (e) {
            print('Fallback URL failed: $e');
          }
        }
        
        if (launched) {
          EasyLoading.showSuccess('WhatsApp message sent successfully!');
          return "Success";
        } else {
          EasyLoading.showError('WhatsApp is not installed or available.');
          return "WhatsApp not available";
        }
        
      } else {
        final responseBody = jsonDecode(response.body);
        String errorMessage = responseBody['message'] ?? 'Failed to save gift data';
        EasyLoading.showError('Error: $errorMessage');
        throw Exception('Failed to send gift: $errorMessage');
      }
      
    } catch (e) {
      print("Error sending WhatsApp message: $e");
      EasyLoading.showError('Failed to send gift message');
      return "Error: $e";
    }
  }
}
