import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/member/member_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

class MemberSummaryNotifier extends StateNotifier<MemberSummaryResult> {
  final MemberProfileRepository memberProfileRepository;

  MemberSummaryNotifier(this.memberProfileRepository)
      : super(MemberSummaryResult(table: []));

  Future<void> getMemberSummary({
    required String playerId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final result = await memberProfileRepository.getMemberSummary(
        dateFrom: dateFrom,
        dateTo: dateTo,
        playerId: playerId,
      );
      state = result;
    } catch (e) {
      print('MemberSummaryNotifier error: $e');
      state = MemberSummaryResult(table: []);
    }
  }

  void reset() {
    state = MemberSummaryResult(table: []);
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

final memberSummaryProvider =
    StateNotifierProvider<MemberSummaryNotifier, MemberSummaryResult>((ref) {
  final memberProfileRepository = ref.read(memberProfileRepositoryProvider);
  return MemberSummaryNotifier(memberProfileRepository);
});