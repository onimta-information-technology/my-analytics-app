import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/member/games_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GamesSummaryNotifier extends StateNotifier<GamesSummary> {
  final MemberProfileRepository memberProfileRepository;

  GamesSummaryNotifier(this.memberProfileRepository)
      : super(
          GamesSummary(
            totalTimespent: 0,
            mostPlayedGame: "",
            gameDetails: [],
          ),
        );

  Future<void> getGamesSummary({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final fnbHistory = await memberProfileRepository.getGamesSummary(
          dateFrom: dateFrom, dateTo: dateTo, playerId: playerId);
      state = fnbHistory;
    } catch (e) {
      state = GamesSummary(
        totalTimespent: 0,
        mostPlayedGame: "",
        gameDetails: [],
      );
    }
  }

  void reset() {
    state = GamesSummary(
      totalTimespent: 0,
      mostPlayedGame: "",
      gameDetails: [],
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

final gamesSummaryProvider =
    StateNotifierProvider<GamesSummaryNotifier, GamesSummary>((ref) {
  final memberProfileRepository = ref.read(memberProfileRepositoryProvider);
  return GamesSummaryNotifier(memberProfileRepository);
});
