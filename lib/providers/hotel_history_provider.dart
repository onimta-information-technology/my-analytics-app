import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/member/hotel_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

class HotelHistoryNotifier extends StateNotifier<List<HotelHistory>> {
  final MemberProfileRepository memberProfileRepository;

  HotelHistoryNotifier(this.memberProfileRepository)
      : super([
         
        ]);

  Future<void> getHotelHistory({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final hotelHistory = await memberProfileRepository.getHotelHistory(
          dateFrom: dateFrom, dateTo: dateTo, playerId: playerId);
      state = hotelHistory;
    } catch (e) {
      state = [];
    }
  }

  void reset() {
    state = [
     
    ];
  }
}

final flutterSecureStorageProvider =
    Provider((ref) => SecureStorage.instance);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final memberProfileRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return MemberProfileRepository(apiService);
});

final hotelHistoryProvider =
    StateNotifierProvider<HotelHistoryNotifier, List<HotelHistory>>((ref) {
  final memberProfileRepository = ref.read(memberProfileRepositoryProvider);
  return HotelHistoryNotifier(memberProfileRepository);
});
