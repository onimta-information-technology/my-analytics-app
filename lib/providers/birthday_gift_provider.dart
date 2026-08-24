import 'package:ballys_reservation_app/data/repositories/birthday_gift_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/birthday_gift_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

// State class to hold gift data
class BirthdayGiftState {
  final BirthdayGiftResponse? giftData;
  final bool isLoading;
  final String? error;

  BirthdayGiftState({
    this.giftData,
    this.isLoading = false,
    this.error,
  });

  BirthdayGiftState copyWith({
    BirthdayGiftResponse? giftData,
    bool? isLoading,
    String? error,
  }) {
    return BirthdayGiftState(
      giftData: giftData ?? this.giftData,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Notifier class
class BirthdayGiftNotifier extends StateNotifier<BirthdayGiftState> {
  final BirthdayGiftRepository repository;

  BirthdayGiftNotifier(this.repository) : super(BirthdayGiftState());

  Future<void> fetchGiftData(String memberId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final giftData = await repository.getBirthdayGift(memberId);
      
      if (giftData != null) {
        state = state.copyWith(
          giftData: giftData,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'No gift data found',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = BirthdayGiftState();
  }
}

// Providers
final birthdayGiftRepositoryProvider = Provider<BirthdayGiftRepository>((ref) {
  final storage = SecureStorage.instance;
  final apiService = ApiService(storage);
  return BirthdayGiftRepository(apiService);
});

final birthdayGiftProvider = StateNotifierProvider<BirthdayGiftNotifier, BirthdayGiftState>((ref) {
  final repository = ref.read(birthdayGiftRepositoryProvider);
  return BirthdayGiftNotifier(repository);
});