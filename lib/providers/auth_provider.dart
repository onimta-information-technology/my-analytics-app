import 'package:ballys_reservation_app/models/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/api_service.dart';
import '../utils/storage_util.dart';

final flutterSecureStorageProvider =
    Provider((ref) => const FlutterSecureStorage());

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

  AuthNotifier(this.authRepository)
      : super(AuthState(user: null, isLoading: false));

  Future<void> authenticateAndLogin(String username, String password) async {
    isLoading = true;
    state = AuthState(user: null, isLoading: true);

    try {
      String accessToken = await authRepository.authenticate();
      if (accessToken.isEmpty) {
        throw Exception('Authentication failed');
      }

      final user = await authRepository.login(username, password);
      await StorageUtil.saveUserData(
          user.userName, user.userLevel, user.salesCode, user.marketingCode, user.mobileNumber ?? "");
      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      print('Login failed: $e');
        String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11); // Remove "Exception: " prefix
      }
      state = AuthState(user: null, isLoading: false, error: errorMessage);
    } finally {
      isLoading = false;
    }
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
  Future<void> logout() async {
    await StorageUtil.clearUserData();
    state = AuthState(user: null, isLoading: false,error: null);
  }
}
