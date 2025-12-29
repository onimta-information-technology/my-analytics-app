import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Import the LocationConfig class
import 'package:ballys_reservation_app/data/services/device_config_service.dart';

class StorageUtil {
  static const _storage = FlutterSecureStorage();
  static const _keyAppVersion = 'app_version';
  static const _keyCurrentApiUrl = 'current_api_url';
  static const _keyCurrentLocation = 'current_location';
  static const _keyIsAdmin = 'is_admin';
  static const _keyLocations = 'locations';

  static Future<void> saveUserData(
      String userName, String userLevel, String salesCode, String marketingCode, String mobileNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString('userName', userName);
    await prefs.setString('userLevel', userLevel);
    await prefs.setString('salesCode', salesCode);
    await prefs.setString('marketingCode', marketingCode);
    await prefs.setString('mobileNumber', mobileNumber);
    

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

  Future getToken() async {}

  // ===== NEW LOCATION MANAGEMENT METHODS =====

  /// Save current location and API URL
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

  /// Get all locations (for admin)
  static Future<List<LocationConfig>> getLocations() async {
    final locationsJson = await _storage.read(key: _keyLocations);
    if (locationsJson != null) {
      final List<dynamic> decoded = jsonDecode(locationsJson);
      return decoded.map((json) => LocationConfig.fromJson(json)).toList();
    }
    return [];
  }

  /// Clear location data (on logout)
  static Future<void> clearLocationData() async {
    await _storage.delete(key: _keyCurrentApiUrl);
    await _storage.delete(key: _keyCurrentLocation);
    await _storage.delete(key: _keyIsAdmin);
    await _storage.delete(key: _keyLocations);
  }
}