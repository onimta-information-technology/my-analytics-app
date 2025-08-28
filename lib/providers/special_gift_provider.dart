import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GiftNotifier extends StateNotifier<GiftState> {
  final GiftsRepository giftRepository;

  GiftNotifier(this.giftRepository) : super(GiftState());

  Future<void> getSpecialGiftData(int iid, String text1) async {
  try {
    var gifttList = await giftRepository.getSpecialGift(iid, text1);
    print('API Response for iid $iid: $gifttList'); // <- debug here

    switch (iid) {
      case 8890:
        state = state.copyWith(pendinggift: gifttList);
        break;
      case 8891:
        state = state.copyWith(approvedgift: gifttList);
        break;
      case 8893:
        state = state.copyWith(rejectgift: gifttList);
        break;
    }
  } catch (e) {
    print('Error fetching gifts for iid $iid: $e');
    // Optional: reset that specific state instead of all
    switch (iid) {
      case 8890:
        state = state.copyWith(pendinggift: []);
        break;
      case 8891:
        state = state.copyWith(approvedgift: []);
        break;
      case 8893:
        state = state.copyWith(rejectgift: []);
        break;
    }
  }
}

  void resetData() {
    state = GiftState();
  }
}


final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final giftRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return GiftsRepository(apiService);
});

final giftProvider = StateNotifierProvider<GiftNotifier, GiftState>((
  ref,
) {
  final giftRepository = ref.read(giftRepositoryProvider);
  return GiftNotifier(giftRepository);
});


class GiftState {
  final List<SpecialGiftRequest> pendinggift;
  final List<SpecialGiftRequest> approvedgift;
  final List<SpecialGiftRequest> rejectgift;

  GiftState({
    this.pendinggift = const [],
    this.approvedgift = const [],
    this.rejectgift = const [],
  });

  GiftState copyWith({
    List<SpecialGiftRequest>? pendinggift,
    List<SpecialGiftRequest>? approvedgift,
    List<SpecialGiftRequest>? rejectgift,
  }) {
    return GiftState(
      pendinggift: pendinggift ?? this.pendinggift,
      approvedgift: approvedgift ?? this.approvedgift,
      rejectgift: rejectgift ?? this.rejectgift,
    );
  }
}
