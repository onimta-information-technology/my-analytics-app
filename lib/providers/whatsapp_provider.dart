
import 'package:ballys_reservation_app/data/repositories/whatsapp_number_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';

import 'package:ballys_reservation_app/models/add_phone/whatsApp_response.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

class WhatsappState {
  final bool isLoading;
  final WhatsappResponse? whatsappResponse;
  final String? error;

  WhatsappState({
    this.isLoading = false,
    this.whatsappResponse,
    this.error,
  });

  WhatsappState copyWith({
    bool? isLoading,
    WhatsappResponse? whatsappResponse,
    String? error,
  }) {
    return WhatsappState(
      isLoading: isLoading ?? this.isLoading,
      whatsappResponse: whatsappResponse ?? this.whatsappResponse,
      error: error ?? this.error,
    );
  }
}

class WhatsappNotifier extends StateNotifier<WhatsappState> {
  final WhatsappNumberRepository whatsappRepository;

  WhatsappNotifier(this.whatsappRepository) : super(WhatsappState());

  Future<bool> addWhatsAppNumber({
    required String memberId,
    required String phoneNumber,
    required String memberName,
    required int phoneType, // 1 for Phone1, 2 for Phone2, 3 for Phone3
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await whatsappRepository.addWhatsAppNumber(
        memberId: memberId,
        phoneNumber: phoneNumber,
        memberName: memberName,
        phoneType: phoneType,
      );

      if (response != null) {
        state = state.copyWith(
          isLoading: false,
          whatsappResponse: response,
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
    state = WhatsappState();
  }
}

// Providers
final whatsappRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return WhatsappNumberRepository(apiService);
});

final whatsappProvider = StateNotifierProvider<WhatsappNotifier, WhatsappState>((ref) {
  final whatsappRepository = ref.read(whatsappRepositoryProvider);
  return WhatsappNotifier(whatsappRepository);
});

// Note: Make sure apiServiceProvider is available in your project
// If not already defined, add this:
final flutterSecureStorageProvider = Provider(
  (ref) => SecureStorage.instance,
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});