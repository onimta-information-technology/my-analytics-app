
import 'package:ballys_reservation_app/data/repositories/daily_walking_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/Guest/daily_walking_guest.dart';
import 'package:ballys_reservation_app/models/member/airline_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class DailyWalkingNotifier extends StateNotifier<List<DailyWalkingGuest>> {
  final DailyWalkingGuestRepository dailyWalkingGuestRepository;

  DailyWalkingNotifier(this.dailyWalkingGuestRepository) : super([]);

  Future<void> getDailyWalkingGuests() async {
    try {
      final gestHistory = await dailyWalkingGuestRepository.getAllgest(); 
      state = gestHistory;
    } catch (e) {
      state = [];
    }
  }

  void reset() {
    state = [];
  }
}

final flutterSecureStorageProvider =
    Provider((ref) => const FlutterSecureStorage());

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final dailyWalkingRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return DailyWalkingGuestRepository(apiService);
});

final dailyWalkingProvider =
    StateNotifierProvider<DailyWalkingNotifier, List<DailyWalkingGuest>>((ref) {
  final repository = ref.read(dailyWalkingRepositoryProvider);
  return DailyWalkingNotifier(repository);
});
