import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class DeviceConfigService {
  static const String _configApiUrl = "https://analyticshubapi.bty.world/api/device/log";

  /// Fetches device configuration and returns the API URL
  /// Returns null if device is not registered
  /// Throws exception on error
  static Future<DeviceConfigResult> fetchDeviceConfig({
     String username = "",
  String password = "",
  }) async {
    try {
      final deviceId = await DeviceId.get();
      
      final response = await http.post(
        Uri.parse(_configApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"device_id": deviceId, "username":username,"password":password}),
      );
print(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Device not registered
        if (data['configured'] == false) {
          return DeviceConfigResult(
            isConfigured: false,
            errorMessage: 'Device is not registered. Please contact administrator.',
          );
        }

        // Admin user with multiple locations
        if (data['data'] != null && data['data']['is_admin'] == true) {
          final locations = (data['data']['locations'] as List)
              .map((loc) => LocationConfig.fromJson(loc))
              .toList();
          
          // Save all locations
          await StorageUtil.saveLocations(locations);
          
          // Set first enabled location as default
          final defaultLocation = locations.firstWhere(
            (loc) => loc.isEnabled,
            orElse: () => locations.first,
          );
          
          await StorageUtil.saveCurrentLocation(defaultLocation);
          
          return DeviceConfigResult(
            isConfigured: true,
            isAdmin: true,
            locations: locations,
            currentLocation: defaultLocation,
            apiUrl: defaultLocation.apiUrl,
          );
        }

        // Regular user with single location
        if (data['data'] != null) {
          final location = LocationConfig(
            id: null,
            name: data['data']['location_name'],
            code: data['data']['location_code'],
            apiUrl: data['data']['api_url'],
            isEnabled: true,
            storedProcedureName: data['data']['stored_procedure_name'] ?? 'sp_CRM_Common_API',
            smsGatewayUrl: data['data']['sms_gateway_url'], 
          );
          
          await StorageUtil.saveCurrentLocation(location);
          
          return DeviceConfigResult(
            isConfigured: true,
            isAdmin: false,
            currentLocation: location,
            apiUrl: location.apiUrl,
          );
        }

        return DeviceConfigResult(
          isConfigured: false,
          errorMessage: 'Invalid configuration data received.',
        );
      } else {
        throw Exception('Failed to fetch device config: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching device configuration: $e');
    }
  }

  /// Gets the current API URL from storage
  static Future<String?> getCurrentApiUrl() async {
    return await StorageUtil.getCurrentApiUrl();
  }

  /// Checks if user is admin
  static Future<bool> isAdmin() async {
    return await StorageUtil.isAdmin();
  }

  /// Gets all available locations (for admin)
  static Future<List<LocationConfig>> getLocations() async {
    return await StorageUtil.getLocations();
  }

  /// Changes current location (admin only)
  static Future<void> changeLocation(LocationConfig location) async {
    await StorageUtil.saveCurrentLocation(location);
  }
  
}

class DeviceConfigResult {
  final bool isConfigured;
  final bool isAdmin;
  final String? apiUrl;
  final String? errorMessage;
  final List<LocationConfig>? locations;
  final LocationConfig? currentLocation;

  DeviceConfigResult({
    required this.isConfigured,
    this.isAdmin = false,
    this.apiUrl,
    this.errorMessage,
    this.locations,
    this.currentLocation,
  });
}

class LocationConfig {
  final String? id;
  final String name;
  final String code;
  final String apiUrl;
  final bool isEnabled;
  final String? imageUrl;
final String storedProcedureName;
  final String? smsGatewayUrl; 
  LocationConfig({
    this.id,
    required this.name,
    required this.code,
    required this.apiUrl,
    required this.isEnabled,
    this.imageUrl,
    required this.storedProcedureName,
    this.smsGatewayUrl,
  });

  factory LocationConfig.fromJson(Map<String, dynamic> json) {
    return LocationConfig(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      apiUrl: json['api_url'],
      isEnabled: json['is_enabled'] ?? true,
      imageUrl: json['image_url'],
      storedProcedureName: json['stored_procedure_name'] ?? 'sp_CRM_Common_API',
      smsGatewayUrl: json['sms_gateway_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'api_url': apiUrl,
      'is_enabled': isEnabled,
      'image_url': imageUrl,
      'stored_procedure_name': storedProcedureName,
      'sms_gateway_url': smsGatewayUrl,
    };
  }
}