import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/member/f_and_b_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FAndBHistoryNotifier extends StateNotifier<FAndBHistory> {
  final MemberProfileRepository memberProfileRepository;

  FAndBHistoryNotifier(this.memberProfileRepository)
      : super(
          FAndBHistory(
            mostOrderedBeverage: "",
            mostOrderedTobacco: "",
            mostOrderedFood: "",
            totalCost: 0.0,
            nongameDetails: [],
          ),
        );

  Future<void> getFAndBHistory({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final fnbHistory = await memberProfileRepository.getFAndBHistory(
          dateFrom: dateFrom, dateTo: dateTo, playerId: playerId);
      state = fnbHistory;
    } catch (e) {
      state = FAndBHistory(
        mostOrderedBeverage: "",
        mostOrderedTobacco: "",
        mostOrderedFood: "",
        totalCost: 0.0,
        nongameDetails: [],
      );
    }
  }

  void reset() {
    state = FAndBHistory(
      mostOrderedBeverage: "",
      mostOrderedTobacco: "",
      mostOrderedFood: "",
      totalCost: 0.0,
      nongameDetails: [],
    );
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

final fAndBHistoryProvider =
    StateNotifierProvider<FAndBHistoryNotifier, FAndBHistory>((ref) {
  final memberProfileRepository = ref.read(memberProfileRepositoryProvider);
  return FAndBHistoryNotifier(memberProfileRepository);
});
