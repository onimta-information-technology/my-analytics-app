import 'dart:convert';

import 'package:ballys_reservation_app/data/services/device_config_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageUtil {
  static const _storage = FlutterSecureStorage();
  static const _keyAppVersion = 'app_version';
 static const _keyCurrentApiUrl = 'current_api_url';
  static const _keyCurrentLocation = 'current_location';
  static const _keyIsAdmin = 'is_admin';
  static const _keyLocations = 'locations';
  
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
    bool? marketingP,
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
    if (marketingP != null) {
      await prefs.setBool('marketingP', marketingP);
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
    final code = prefs.getString('marketingCode');
    // Marketing_Code arrives via toString(), so a missing value lands as "null".
    if (code == null || code.isEmpty || code == 'null') return null;
    return code;
  }

  /// Sales code AD001 is the admin login. Overall data is theirs alone —
  /// every other sales code is scoped to their own numbers.
  static Future<bool> isAdminSalesCode() async {
    final salesCode = await getSalesCode();
    return salesCode != null && salesCode.trim().toUpperCase() == 'AD001';
  }

  /// MArketing_P from the login response — the user manages a marketing group,
  /// so their own numbers live under the marketing code, not the sales code.
  /// This is what unlocks the My Data / Overall Data switch in Settings.
  static Future<bool> getMarketingP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('marketingP') ?? false;
  }

  /// Whether the user belongs to a marketing group at all. Marketing_Code 0
  /// means they don't, so there is no "my data" for them to look at — those
  /// users see overall data instead, whatever MArketing_P says.
  static Future<bool> hasOwnMarketingGroup() async {
    final code = await getMarketingCode();
    return code != null && code != '0';
  }

  /// The code to send as @Text1 on data-scoping reports (marketing performance,
  /// last three months, guests 9009-9011, birthdays 9004).
  ///
  /// A marketing-permission user asking for "Show My Data" is scoped by their
  /// marketing code — their rows are tagged with it rather than their sales
  /// code. Everyone else, and overall-data mode, keeps using the sales code.
  static Future<String?> getDataScopeCode({required bool isMyDataMode}) async {
    final salesCode = await getSalesCode();
    if (!isMyDataMode) return salesCode;
    if (!await getMarketingP()) return salesCode;
    if (!await hasOwnMarketingGroup()) return salesCode;
    return await getMarketingCode() ?? salesCode;
  }

  /// The code Iid 646 identifies the user by: AD001 is looked up by its sales
  /// code, every other user by their marketing code.
  static Future<String?> getAccessCheckCode() async {
    final salesCode = await getSalesCode();
    if (salesCode != null && salesCode.trim().toUpperCase() == 'AD001') {
      return salesCode;
    }
    return await getMarketingCode() ?? salesCode;
  }

  /// ReturnSatetus from Iid 646, stored right after login. True means the
  /// user's access is not restricted to their own marketing group, so screens
  /// that gate on the marketing code must skip their Access Denied check.
  ///
  /// Written after [saveUserData] — that call clears SharedPreferences first.
  static Future<void> saveAccessStatus(bool hasAccess) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accessStatus', hasAccess);
  }

  static Future<bool> getAccessStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('accessStatus') ?? false;
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
   static Future<void> saveCurrentLocation(LocationConfig location) async {
    await _storage.write(key: _keyCurrentApiUrl, value: location.apiUrl);
    await _storage.write(key: _keyCurrentLocation, value: jsonEncode(location.toJson()));
  }

  /// Get current API URL
  static Future<String?> getCurrentApiUrl() async {
    return await _storage.read(key: _keyCurrentApiUrl);
  }

  /// Get current location
  static Future<LocationConfig?> getCurrentLocation() async {
    final locationJson = await _storage.read(key: _keyCurrentLocation);
    if (locationJson != null) {
      return LocationConfig.fromJson(jsonDecode(locationJson));
    }
    return null;
  }

  /// Save admin status
  static Future<void> saveAdminStatus(bool isAdmin) async {
    await _storage.write(key: _keyIsAdmin, value: isAdmin.toString());
  }

  /// Check if user is admin
  static Future<bool> isAdmin() async {
    final isAdminStr = await _storage.read(key: _keyIsAdmin);
    return isAdminStr == 'true';
  }
   /// Save all locations (for admin)
  static Future<void> saveLocations(List<LocationConfig> locations) async {
    final locationsJson = jsonEncode(locations.map((loc) => loc.toJson()).toList());
    await _storage.write(key: _keyLocations, value: locationsJson);
    await saveAdminStatus(true);
  }
  static Future<List<LocationConfig>> getLocations() async {
    final locationsJson = await _storage.read(key: _keyLocations);
    if (locationsJson != null) {
      final List<dynamic> decoded = jsonDecode(locationsJson);
      return decoded.map((json) => LocationConfig.fromJson(json)).toList();
    }
    return [];
  }
static Future<String> getStoredProcedureName() async {
  final location = await getCurrentLocation();
  return location?.storedProcedureName ?? 'sp_CRM_Common_API';
}
static Future<String?> getSmsGatewayUrl() async {
  final location = await getCurrentLocation();
  return location?.smsGatewayUrl;
}
  /// Clear location data (on logout)
  static Future<void> clearLocationData() async {
    await _storage.delete(key: _keyCurrentApiUrl);
    await _storage.delete(key: _keyCurrentLocation);
    await _storage.delete(key: _keyIsAdmin);
    await _storage.delete(key: _keyLocations);
  }
}
