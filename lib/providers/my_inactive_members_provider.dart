import 'package:ballys_reservation_app/data/repositories/inactive_members_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/my_inactive_member.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inactiveMembersRepositoryProvider = Provider(
  (ref) => InactiveMembersRepository(ApiService(SecureStorage.instance)),
);

/// The logged-in user's own inactive members, shared by the card count on the
/// Inactive Members menu and the "My Inactive" list screen.
class MyInactiveMembersNotifier extends AutoDisposeAsyncNotifier<List<MyInactiveMember>> {
  @override
  Future<List<MyInactiveMember>> build() => _load();

  Future<List<MyInactiveMember>> _load() =>
      ref.read(inactiveMembersRepositoryProvider).getMyInactiveMembers();

  Future<void> refresh() async {
    state = const AsyncLoading<List<MyInactiveMember>>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }
}

final myInactiveMembersProvider = AsyncNotifierProvider.autoDispose<
    MyInactiveMembersNotifier, List<MyInactiveMember>>(
  MyInactiveMembersNotifier.new,
);
