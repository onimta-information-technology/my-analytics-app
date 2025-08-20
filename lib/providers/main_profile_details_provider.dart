import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/member/member_main_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MainProfileDetailsNotifier
    extends StateNotifier<List<MemberMainProfile>> {
  final MemberProfileRepository memberProfileRepository;

  MainProfileDetailsNotifier(this.memberProfileRepository)
      : super(
          [
            MemberMainProfile(details: {"Name": "", "Detail": ""})
          ],
        );

  Future<void> getMemberMainProfileDetails(String playerId) async {
    try {
      final profileDetails =
          await memberProfileRepository.getMemberMainProfileDetails(playerId);
      state = profileDetails;
    } catch (e) {
      state = [
        MemberMainProfile(details: {"Name": "", "Detail": ""})
      ];
    }
  }

  void reset() {
    state = [
      MemberMainProfile(details: {"Name": "", "Detail": ""})
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

final mainProfileDetailsProvider =
    StateNotifierProvider<MainProfileDetailsNotifier, List<MemberMainProfile>>(
        (ref) {
  final memberProfileRepository = ref.read(memberProfileRepositoryProvider);
  return MainProfileDetailsNotifier(memberProfileRepository);
});
