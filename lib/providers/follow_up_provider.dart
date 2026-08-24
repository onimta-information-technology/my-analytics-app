import 'package:ballys_reservation_app/data/repositories/follow_up_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/follow_up_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

final _followUpSecureStorageProvider = Provider(
  (ref) => SecureStorage.instance,
);

final _followUpApiServiceProvider = Provider((ref) {
  final storage = ref.read(_followUpSecureStorageProvider);
  return ApiService(storage);
});

final followUpRepositoryProvider = Provider((ref) {
  final apiService = ref.read(_followUpApiServiceProvider);
  return FollowUpRepository(apiService);
});

/// Loads every saved follow-up for the follow-up list screen.
class FollowUpListNotifier extends AsyncNotifier<List<FollowUpItem>> {
  @override
  Future<List<FollowUpItem>> build() => _load();

  Future<List<FollowUpItem>> _load() =>
      ref.read(followUpRepositoryProvider).fetchAllFollowUps();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final followUpListProvider =
    AsyncNotifierProvider<FollowUpListNotifier, List<FollowUpItem>>(
  FollowUpListNotifier.new,
);
