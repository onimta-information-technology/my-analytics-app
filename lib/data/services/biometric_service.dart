import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _usernameKey = 'biometric_username';
  static const String _passwordKey = 'biometric_password';

  // Check if device supports biometrics
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  // Check if device has biometrics enrolled
  Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
    
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Check if biometric is enabled for this app
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _biometricEnabledKey);
      final username = await _secureStorage.read(key: _usernameKey);
      final password = await _secureStorage.read(key: _passwordKey);
      
      // Return true only if enabled flag is true AND credentials exist
      bool isEnabled = enabled == 'true';
      bool credentialsExist = username != null && password != null;
      
      return isEnabled && credentialsExist;
    } catch (e) {
      return false;
    }
  }

  // Save credentials securely
  Future<void> saveCredentials(String username, String password) async {
    try {
      await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
      await _secureStorage.write(key: _usernameKey, value: username);
      await _secureStorage.write(key: _passwordKey, value: password);
    } catch (e) {

      throw Exception('Failed to save credentials');
    }
  }

  // Get saved credentials
  Future<Map<String, String>?> getCredentials() async {
    try {
      final username = await _secureStorage.read(key: _usernameKey);
      final password = await _secureStorage.read(key: _passwordKey);
      if (username != null && password != null) {
        return {'username': username, 'password': password};
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticate({
    String reason = 'Please authenticate to login',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        return false;
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return isAuthenticated;
    } on PlatformException catch (e) {
     
      if (e.code == auth_error.notAvailable) {
  
      } else if (e.code == auth_error.notEnrolled) {
      
      } else if (e.code == auth_error.lockedOut) {
      
      } else if (e.code == auth_error.permanentlyLockedOut) {
      
      }
      return false;
    } catch (e) {
  
      return false;
    }
  }

  // Disable biometric authentication (user manually disables it)
  Future<void> disableBiometric() async {
    try {
   
      
      await _secureStorage.delete(key: _biometricEnabledKey);
      await _secureStorage.delete(key: _usernameKey);
      await _secureStorage.delete(key: _passwordKey);
    
    } catch (e) {
  
    }
  }

  // Get biometric type name for UI display
  String getBiometricTypeName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (types.contains(BiometricType.strong)) {
      return 'Biometric';
    }
    return 'Biometric';
  }
}