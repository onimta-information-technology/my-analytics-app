import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/member/member_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MemberSummaryNotifier extends StateNotifier<List<MemberSummary>> {
  final MemberProfileRepository memberProfileRepository;

  MemberSummaryNotifier(this.memberProfileRepository) : super([]);

  Future<void> getMemberSummary({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final memberSummaries = await memberProfileRepository.getMemberSummary(
          dateFrom: dateFrom, dateTo: dateTo, playerId: playerId);
      state = memberSummaries;
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

final memberProfileRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return MemberProfileRepository(apiService);
});

final memberSummaryProvider =
    StateNotifierProvider<MemberSummaryNotifier, List<MemberSummary>>((ref) {
  final memberProfileRepository = ref.read(memberProfileRepositoryProvider);
  return MemberSummaryNotifier(memberProfileRepository);
});
