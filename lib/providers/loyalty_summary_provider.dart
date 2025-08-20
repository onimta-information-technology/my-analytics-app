import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/member/loyalty_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoyaltySummaryNotifier extends StateNotifier<LoyaltySummary> {
  final MemberProfileRepository memberProfileRepository;

  LoyaltySummaryNotifier(this.memberProfileRepository)
      : super(LoyaltySummary(
            mid: "",
            name: "",
            totalPoints: 0,
            ballysRuppes: 0,
            ballysCoinsExpireMessage: "",
            ballysCoins: 0,
            ballysRuppesExpireMessage: "",
            lastUpdateDateTime: "",
            lastRedeemType: "",
            lastRedeemAmount: 0,
            lastRedeemDate: "",
            lastRedeemTime: ""));

  Future<void> getLoyalitySummary({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final loyaltySummary = await memberProfileRepository.getLoyalitySummary(
          dateFrom: dateFrom, dateTo: dateTo, playerId: playerId);
      state = loyaltySummary[0];
    } catch (e) {
      state = LoyaltySummary(
          mid: "",
          name: "",
          totalPoints: 0,
          ballysRuppes: 0,
          ballysCoinsExpireMessage: "",
          ballysCoins: 0,
          ballysRuppesExpireMessage: "",
          lastUpdateDateTime: "",
          lastRedeemType: "",
          lastRedeemAmount: 0,
          lastRedeemDate: "",
          lastRedeemTime: "");
    }
  }

  void reset() {
    state = LoyaltySummary(
        mid: "",
        name: "",
        totalPoints: 0,
        ballysRuppes: 0,
        ballysCoinsExpireMessage: "",
        ballysCoins: 0,
        ballysRuppesExpireMessage: "",
        lastUpdateDateTime: "",
        lastRedeemType: "",
        lastRedeemAmount: 0,
        lastRedeemDate: "",
        lastRedeemTime: "");
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

final loyaltySummaryProvider =
    StateNotifierProvider<LoyaltySummaryNotifier, LoyaltySummary>((ref) {
  final memberProfileRepository = ref.read(memberProfileRepositoryProvider);
  return LoyaltySummaryNotifier(memberProfileRepository);
});
