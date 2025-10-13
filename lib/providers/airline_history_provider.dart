import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/member/airline_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AirlineHistoryNotifier extends StateNotifier<List<AirlineHistory>> {
  final MemberProfileRepository memberProfileRepository;

  AirlineHistoryNotifier(this.memberProfileRepository)
      : super([
        
        ]);

  Future<void> getAirlineHistory({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final airlineHistory = await memberProfileRepository.getAirlineHistory(
          dateFrom: dateFrom, dateTo: dateTo, playerId: playerId);
      state = airlineHistory;
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
    Provider((ref) => const FlutterSecureStorage());

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final memberProfileRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return MemberProfileRepository(apiService);
});

final airlineHistoryProvider =
    StateNotifierProvider<AirlineHistoryNotifier, List<AirlineHistory>>((ref) {
  final memberProfileRepository = ref.read(memberProfileRepositoryProvider);
  return AirlineHistoryNotifier(memberProfileRepository);
});
