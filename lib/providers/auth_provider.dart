import 'package:ballys_reservation_app/data/services/fcm_token_service.dart';
import 'package:ballys_reservation_app/models/auth_state.dart';
import 'package:ballys_reservation_app/utils/token_refresh_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/api_service.dart';
import '../data/services/token_manager.dart';
import '../utils/storage_util.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

final flutterSecureStorageProvider = Provider(
  (ref) => SecureStorage.instance,
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
  static const Set<String> _biometricKeys = {
    'biometric_enabled',
    'biometric_username',
    'biometric_password',
  };

  /// [_clearStaleCredentials], started when the notifier is built. A login
  /// waits for it, so the cleanup can never land on top of the new session.
  late final Future<void> _staleCredentialsCleanup;

  AuthNotifier(this.authRepository)
    : super(AuthState(user: null, isLoading: false)) {
    _staleCredentialsCleanup = _clearStaleCredentials();
  }

  /// Clears credentials an earlier install left behind, keeping the biometric
  /// login. Runs only while nobody is signed in: SharedPreferences goes with
  /// the app on uninstall but the iOS keychain does not, so a reinstall can
  /// find an old access token in secure storage with no session beside it.
  ///
  /// A signed-in session is left alone, app updates included. This used to
  /// wipe it whenever the app version changed, and since this notifier is
  /// built lazily (login screen, Settings, a logout, a 401) rather than by the
  /// splash, the wipe hit after the user was already on home: screens lost
  /// their sales code and stopped loading, and the next launch went to /login.
  Future<void> _clearStaleCredentials() async {
    try {
      if (await StorageUtil.hasUserData()) return;

      // Deleted key by key rather than deleteAll-then-restore, so the
      // biometric login is never briefly missing while the login screen
      // checks for it.
      final stored = await authRepository.storage.readAll();
      for (final key in stored.keys) {
        if (_biometricKeys.contains(key)) continue;
        await authRepository.storage.delete(key: key);
      }
      await StorageUtil.clearUserData();
    } catch (_) {}
  }

  Future<void> authenticateAndLogin(String username, String password) async {
    isLoading = true;
    state = AuthState(user: null, isLoading: true);

    try {
      await _staleCredentialsCleanup;

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
          _pendingUser.giftApp,
          _pendingUser.resApp,
          _pendingUser.resChk,
          _pendingUser.otgiApp,
          _pendingUser.otgiChk,
          _pendingUser.bgApp,
          _pendingUser.bgChk,
          _pendingUser.marketingP,
          uName: _pendingUser.uName,
          coordinatorId: _pendingUser.coordinatorId,
          transportApp: _pendingUser.transportApp,
        );

        // Iid 646 decides whether this user's access is unrestricted. It has
        // to run after saveUserData — that call clears SharedPreferences.
        await _refreshAccessStatus();

        // Update state to fully authenticated
        state = AuthState(user: _pendingUser, isLoading: false);
        _pendingUser = null; // Clear pending data

      //  TokenRefreshService().start(authRepository);
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

  /// Fetches ReturnSatetus (Iid 646) for the logged-in user and stores it so
  /// the Access Denied checks across the app can read it without a round trip.
  Future<void> _refreshAccessStatus() async {
    try {
      final code = await StorageUtil.getAccessCheckCode();
      final userName = await StorageUtil.getUserName();
      if (code == null || code.isEmpty || userName == null) {
        await StorageUtil.saveAccessStatus(false);
        return;
      }
      final hasAccess = await authRepository.fetchAccessStatus(code, userName);
      await StorageUtil.saveAccessStatus(hasAccess);
    } catch (e) {
      await StorageUtil.saveAccessStatus(false);
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
     // TokenRefreshService().stop();
      final prefs = await SharedPreferences.getInstance();

      // Flip the flag first so a token refresh landing mid-logout cannot sync
      // this device back onto the user we are signing out.
      await prefs.setBool('is_logged_in', false);

      // Detaches the token on the backend. Must run before clearUserData() —
      // it needs the auth token and property url that call wipes.
      await FcmTokenService.clearOnLogout();

      // The access token belongs to this property's API. Left behind, the next
      // login — possibly to the other property — starts out sending it there.
      await TokenManager(authRepository.storage).clearAccessToken();

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
