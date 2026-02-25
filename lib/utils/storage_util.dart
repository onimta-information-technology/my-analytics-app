import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageUtil {
  static const _storage = FlutterSecureStorage();
  static const _keyAppVersion = 'app_version';

  static Future<void> saveUserData(
    String userName,
    String userLevel,
    String salesCode,
    String marketingCode,
    String mobileNumber,
    bool? memProfSH,
    bool? giftApp,
    bool? resApp,
    bool? resChk,
    bool? otgiApp,
    bool? otgiChk,
    bool? bgApp,
    bool? bgChk,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString('userName', userName);
    await prefs.setString('userLevel', userLevel);
    await prefs.setString('salesCode', salesCode);
    await prefs.setString('marketingCode', marketingCode);
    await prefs.setString('mobileNumber', mobileNumber);
    if (memProfSH != null) {
      await prefs.setBool('memProfSH', memProfSH);
    }
    if (giftApp != null) {
      await prefs.setBool('giftApp', giftApp);
    }
    if (resApp != null) {
      await prefs.setBool('resApp', resApp);
    }
    if (resChk != null) {
      await prefs.setBool('resChk', resChk);
    }
    if (otgiApp != null) {
      await prefs.setBool('otgiApp', otgiApp);
    }
    if (otgiChk != null) {
      await prefs.setBool('otgiChk', otgiChk);
    }
    if (bgApp != null) {
      await prefs.setBool('bgApp', bgApp);
    }
    if (bgChk != null) {
      await prefs.setBool('bgChk', bgChk);
    }
    final now = DateTime.now();
    final expiryTime = now.add(const Duration(days: 365));
    await prefs.setString('expiry', expiryTime.toIso8601String());
  }

  static Future<String?> getExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('expiry');
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName');
  }

  static Future<String?> getMobileNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('mobileNumber');
  }

  static Future<String?> getUserLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userLevel');
  }

  static Future<String?> getSalesCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('salesCode');
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<String?> getMarketingCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('marketingCode');
  }

  static Future<void> saveAppVersion(String version) async {
    await _storage.write(key: _keyAppVersion, value: version);
  }

  static Future<String?> getAppVersion() async {
    return await _storage.read(key: _keyAppVersion);
  }

  static Future<bool> hasUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('userName') || prefs.containsKey('userLevel');
  }

  static Future<bool?> getMemProfSH() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('memProfSH');
  }

  static Future<bool?> getGiftApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('giftApp');
  }

  static Future<bool?> getResApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('resApp');
  }

  static Future<bool?> getResChk() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('resChk');
  }

  static Future<bool?> getOtgiApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('otgiApp');
  }

  static Future<bool?> getOtgiChk() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('otgiChk');
  }

  static Future<bool?> getBgApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('bgApp');
  }

  static Future<bool?> getBgChk() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('bgChk');
  }

  Future getToken() async {}
}
