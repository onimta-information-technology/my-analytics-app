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
      print('Error checking biometrics availability: $e');
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
      print('Error checking device support: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
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
      
      print('🔍 BiometricService.isBiometricEnabled():');
      print('   - Enabled flag: $isEnabled');
      print('   - Credentials exist: $credentialsExist');
      print('   - Final result: ${isEnabled && credentialsExist}');
      
      return isEnabled && credentialsExist;
    } catch (e) {
      print('Error checking biometric enabled status: $e');
      return false;
    }
  }

  // Save credentials securely
  Future<void> saveCredentials(String username, String password) async {
    try {
      await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
      await _secureStorage.write(key: _usernameKey, value: username);
      await _secureStorage.write(key: _passwordKey, value: password);
      print('✅ Biometric credentials saved');
      print('   - Username: $username');
    } catch (e) {
      print('❌ Error saving credentials: $e');
      throw Exception('Failed to save credentials');
    }
  }

  // Get saved credentials
  Future<Map<String, String>?> getCredentials() async {
    try {
      final username = await _secureStorage.read(key: _usernameKey);
      final password = await _secureStorage.read(key: _passwordKey);

      print('🔐 BiometricService.getCredentials():');
      print('   - Username: ${username != null ? '***' : 'null'}');
      print('   - Password: ${password != null ? '***' : 'null'}');

      if (username != null && password != null) {
        return {'username': username, 'password': password};
      }
      
      print('   ⚠️ Credentials missing!');
      return null;
    } catch (e) {
      print('Error reading credentials: $e');
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
        print('⚠️ Device does not support biometrics');
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
      print('❌ Biometric authentication error: $e');
      if (e.code == auth_error.notAvailable) {
        print('Biometrics not available');
      } else if (e.code == auth_error.notEnrolled) {
        print('No biometrics enrolled');
      } else if (e.code == auth_error.lockedOut) {
        print('Too many attempts, locked out');
      } else if (e.code == auth_error.permanentlyLockedOut) {
        print('Permanently locked out');
      }
      return false;
    } catch (e) {
      print('❌ Unexpected authentication error: $e');
      return false;
    }
  }

  // Disable biometric authentication (user manually disables it)
  Future<void> disableBiometric() async {
    try {
      print('🧹 Disabling biometric authentication...');
      
      await _secureStorage.delete(key: _biometricEnabledKey);
      await _secureStorage.delete(key: _usernameKey);
      await _secureStorage.delete(key: _passwordKey);
      
      print('✅ Biometric authentication disabled');
      print('   - Deleted enabled flag');
      print('   - Deleted username');
      print('   - Deleted password');
    } catch (e) {
      print('❌ Error disabling biometric: $e');
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