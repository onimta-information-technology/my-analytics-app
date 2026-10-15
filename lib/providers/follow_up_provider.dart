import 'package:ballys_reservation_app/data/repositories/follow_up_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/follow_up_item.dart';
import 'package:ballys_reservation_app/models/unfollow_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

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

  /// Unfollows [item] with the given [reason]/[remarks], then reloads the
  /// list. Errors propagate so the caller can show them.
  Future<void> unfollow(
    FollowUpItem item, {
    required String reason,
    String remarks = '',
  }) async {
    await ref.read(followUpRepositoryProvider).unfollow(
          followupId: item.followupId,
          memberId: item.memberId,
          memberName: item.memberName,
          reason: reason,
          remarks: remarks,
        );
    ref.invalidate(unfollowListProvider);
    await refresh();
  }
}

/// Loads every unfollowed follow-up for the unfollowed list screen.
class UnfollowListNotifier extends AsyncNotifier<List<UnfollowItem>> {
  @override
  Future<List<UnfollowItem>> build() => _load();

  Future<List<UnfollowItem>> _load() =>
      ref.read(followUpRepositoryProvider).fetchAllUnfollowups();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final unfollowListProvider =
    AsyncNotifierProvider<UnfollowListNotifier, List<UnfollowItem>>(
  UnfollowListNotifier.new,
);

/// The logged-in user's name, compared against a follow-up's `Login_By` to
/// decide who may unfollow it.
final currentUserNameProvider = FutureProvider<String?>(
  (ref) => StorageUtil.getUserName(),
);

/// Whether the logged-in user is the AD001 admin, who may share any
/// follow-up rather than only their own.
final isAdminSalesCodeProvider = FutureProvider<bool>(
  (ref) => StorageUtil.isAdminSalesCode(),
);

final followUpListProvider =
    AsyncNotifierProvider<FollowUpListNotifier, List<FollowUpItem>>(
  FollowUpListNotifier.new,
);
