import 'package:ballys_reservation_app/models/auth_state.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/api_service.dart';
import '../utils/storage_util.dart';

final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final authRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  final storage = ref.read(flutterSecureStorageProvider);
  return AuthRepository(apiService, storage);
});

// Define the AuthNotifier to manage authentication state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState?>((ref) {
  final authRepository = ref.read(authRepositoryProvider);

  return AuthNotifier(authRepository);
});

class AuthNotifier extends StateNotifier<AuthState?> {
  final AuthRepository authRepository;

  bool isLoading = false;

  dynamic _pendingUser;
  String? _currentSessionPassword;
  String? _currentSessionusername;
  // Biometric storage keys that should NOT be deleted
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _usernameKey = 'biometric_username';
  static const String _passwordKey = 'biometric_password';
  AuthNotifier(this.authRepository)
    : super(AuthState(user: null, isLoading: false)) {
    _checkAppVersion();
  }

  // Future<void> _checkAppVersion() async {
  //     try {
  //       final packageInfo = await PackageInfo.fromPlatform();
  //       final currentVersion = packageInfo.version;

  //       final savedVersion = await StorageUtil.getAppVersion();

  //       if (savedVersion == null || savedVersion != currentVersion) {
  //         // App is either newly installed OR updated
  //         await StorageUtil.clearUserData();
  //         await StorageUtil.saveAppVersion(currentVersion);

  //         // Reset auth state
  //         state = AuthState(user: null, isLoading: false, error: null);

  //         print('App version changed. Cleared old data.');
  //       }
  //     } catch (e) {
  //       print('Version check failed: $e');
  //     }
  //   }

  Future<void> _checkAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final savedVersion = await StorageUtil.getAppVersion();
      final hasUser = await StorageUtil.hasUserData();

      if (savedVersion == null || savedVersion != currentVersion || !hasUser) {
        // Save biometric data before clearing storage
        final biometricEnabled = await authRepository.storage.read(
          key: _biometricEnabledKey,
        );
        final biometricUsername = await authRepository.storage.read(
          key: _usernameKey,
        );
        final biometricPassword = await authRepository.storage.read(
          key: _passwordKey,
        );

        await authRepository.storage.deleteAll();
        await StorageUtil.clearUserData();

        // Restore biometric data
        if (biometricEnabled != null) {
          await authRepository.storage.write(
            key: _biometricEnabledKey,
            value: biometricEnabled,
          );

        }
        if (biometricUsername != null) {
          await authRepository.storage.write(
            key: _usernameKey,
            value: biometricUsername,
          );

        }
        if (biometricPassword != null) {
          await authRepository.storage.write(
            key: _passwordKey,
            value: biometricPassword,
          );
        }
        await StorageUtil.saveAppVersion(currentVersion);

        state = AuthState(user: null, isLoading: false, error: null);
       
      }
    } catch (e) {
  
    }
  }

  Future<void> authenticateAndLogin(String username, String password) async {
    isLoading = true;
    state = AuthState(user: null, isLoading: true);

    try {
      String accessToken = await authRepository.authenticate();
      if (accessToken.isEmpty) {
        throw Exception('Authentication failed');
      }

      final user = await authRepository.login(username, password);
      _pendingUser = user;
      _currentSessionPassword = password;
      _currentSessionusername = username;

      state = AuthState(user: user, isLoading: false);
    } catch (e) {
     
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(
          11,
        ); // Remove "Exception: " prefix
      }
      state = AuthState(user: null, isLoading: false, error: errorMessage);
    } finally {
      isLoading = false;
    }
  }

  Future<void> completeLoginAfterOTP() async {
    try {
      if (_pendingUser != null) {
        await StorageUtil.clearUserData();
        // Now save the user data to storage after successful OTP verification
        await StorageUtil.saveUserData(
          _pendingUser.userName,
          _pendingUser.userLevel,
          _pendingUser.salesCode,
          _pendingUser.marketingCode,
          _pendingUser.mobileNumber ?? "",
          _pendingUser.memProfSH,
        );

        // Update state to fully authenticated
        state = AuthState(user: _pendingUser, isLoading: false);
        _pendingUser = null; // Clear pending data

   
      } else {
        throw Exception('No pending user data found');
      }
    } catch (e) {

      state = AuthState(
        user: null,
        isLoading: false,
        error: 'Login completion failed',
      );
      _pendingUser = null;
    }
  }

  String? getCurrentSessionPassword() {
    return _currentSessionPassword;
  }

  String? getCurrentSessionUsername() {
    return _currentSessionusername;
  }

  void clearError() {
    if (state?.error != null) {
      state = AuthState(
        user: state?.user,
        isLoading: state?.isLoading ?? false,
        error: null,
      );
    }
  }

  // Future<void> logout() async {
  //   await StorageUtil.clearUserData();
  //     _currentSessionPassword = null;
  //     _currentSessionusername = null;
  //   state = AuthState(user: null, isLoading: false, error: null);
  // }
  Future<void> logout() async {
    try {

    
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('FCMToken');
      if (fcmToken != null) {
        await FirebaseMessaging.instance.deleteToken();
     

        // Clear stored FCM token
        await prefs.remove('FCMToken');
    
      } else {
      
      }
      // Clear user data
      await StorageUtil.clearUserData();

      // Clear session data
      _currentSessionPassword = null;
      _currentSessionusername = null;

      // Update state
      state = AuthState(user: null, isLoading: false, error: null);
await prefs.setBool('is_logged_in', false);
   
    } catch (e) {
   
      // Still clear local data even if server call fails
      await StorageUtil.clearUserData();
      _currentSessionPassword = null;
      _currentSessionusername = null;
      state = AuthState(user: null, isLoading: false, error: null);
    }
  }
// Add this method to the AuthNotifier class

Future<bool> deleteAccount() async {
  try {
    state = AuthState(user: state?.user, isLoading: true);

    final success = await authRepository.deleteAccount();

    if (success) {
      // Reuse logout logic
      await logout();
      return true;
    } else {
      state = AuthState(
        user: state?.user,
        isLoading: false,
        error: 'Account deletion failed',
      );
      return false;
    }
  } catch (e) {
    print("Delete account error: $e");
    await logout(); // Force logout even on error
    state = AuthState(
      user: null,
      isLoading: false,
      error: 'Failed to delete account: ${e.toString()}',
    );
    return false;
  }
}
  void clearPendingUser() {
    _pendingUser = null;
    state = AuthState(user: null, isLoading: false);
  }
}
