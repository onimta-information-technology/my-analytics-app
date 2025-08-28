import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/member/trip_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TripHistoryNotifier extends StateNotifier<List<TripHistory>> {
  final MemberProfileRepository memberProfileRepository;

  TripHistoryNotifier(this.memberProfileRepository)
    : super([
        // TripHistory(
        //     consecutiveDates: 0.0,
        //     arrivalDate: "",
        //     departureDate: "",
        //     tripDrop: 0.0,
        //     tripCashOut: 0.0,
        //     tripResult: 0.0,
        //     tripCommission: 0.0,
        //     tripActDrop: 0.0,
        //     tripTotalCoupon: 0.0,
        //     tripHour: 0.0,
        //     tripMinutes: 0.0),
      ]);

  Future<void> getTripHistory({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final tripHistory = await memberProfileRepository.getTripHistory(
        dateFrom: dateFrom,
        dateTo: dateTo,
        playerId: playerId,
      );
      state = tripHistory;
    } catch (e) {
      state = [];
    }
  }
  Future<void> getTripHistory2({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final tripHistory = await memberProfileRepository.getTripHistory2(
        dateFrom: dateFrom,
        dateTo: dateTo,
        playerId: playerId,
      );
      state = tripHistory;
    } catch (e) {
      state = [];
    }
  }
  void reset() {
    state = [
      // TripHistory(
      //     consecutiveDates: 0.0,
      //     arrivalDate: "",
      //     departureDate: "",
      //     tripDrop: 0.0,
      //     tripCashOut: 0.0,
      //     tripResult: 0.0,
      //     tripCommission: 0.0,
      //     tripActDrop: 0.0,
      //     tripTotalCoupon: 0.0,
      //     tripHour: 0.0,
      //     tripMinutes: 0.0)
    ];
  }
}

final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final memberProfileRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return MemberProfileRepository(apiService);
});

final tripHistoryProvider =
    StateNotifierProvider<TripHistoryNotifier, List<TripHistory>>((ref) {
      final memberProfileRepository = ref.read(memberProfileRepositoryProvider);
      return TripHistoryNotifier(memberProfileRepository);
    });
