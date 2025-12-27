import 'package:ballys_reservation_app/data/repositories/phone_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/add_phone/phone_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PhoneState {
  final bool isLoading;
  final PhoneResponse? phoneResponse;
  final String? error;

  PhoneState({
    this.isLoading = false,
    this.phoneResponse,
    this.error,
  });

  PhoneState copyWith({
    bool? isLoading,
    PhoneResponse? phoneResponse,
    String? error,
  }) {
    return PhoneState(
      isLoading: isLoading ?? this.isLoading,
      phoneResponse: phoneResponse ?? this.phoneResponse,
      error: error ?? this.error,
    );
  }
}

class PhoneNotifier extends StateNotifier<PhoneState> {
  final PhoneRepository phoneRepository;

  PhoneNotifier(this.phoneRepository) : super(PhoneState());

  Future<bool> addPhoneNumber({
    required String memberId,
    required String phoneNumber,
    required String memberName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await phoneRepository.addPhoneNumber(
        memberId: memberId,
        phoneNumber: phoneNumber,
        memberName: memberName,
      );

      if (response != null) {
        state = state.copyWith(
          isLoading: false,
          phoneResponse: response,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to add phone number',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = PhoneState();
  }
}

// Providers
final phoneRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return PhoneRepository(apiService);
});

final phoneProvider = StateNotifierProvider<PhoneNotifier, PhoneState>((ref) {
  final phoneRepository = ref.read(phoneRepositoryProvider);
  return PhoneNotifier(phoneRepository);
});

// Note: Make sure apiServiceProvider is available in your project
// If not already defined, add this:
final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});