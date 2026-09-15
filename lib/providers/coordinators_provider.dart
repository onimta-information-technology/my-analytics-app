import 'package:ballys_reservation_app/data/repositories/coordinator_request_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/coordinator.dart';
import 'package:ballys_reservation_app/models/coordinator_request.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final coordinatorRequestRepositoryProvider =
    Provider<CoordinatorRequestRepository>((ref) {
  return CoordinatorRequestRepository(ApiService(SecureStorage.instance));
});

/// The coordinator picker list from `Coordinators/Get` — active rows only,
/// sorted by name (the repository does both).
///
/// A [FutureProvider] so the list is fetched once and cached for the app
/// session: it changes rarely, and every screen that needs it gets the same
/// result. To force a refetch — a retry after a failed load — call
/// `ref.invalidate(coordinatorsProvider)`.
final coordinatorsProvider = FutureProvider<List<Coordinator>>((ref) async {
  return ref.read(coordinatorRequestRepositoryProvider).getCoordinators();
});

/// `Coordinatorid` from the login response, or null when this login is not a
/// coordinator. Kept as a provider so the screen can tell "not a coordinator"
/// apart from "no requests yet".
///
/// `autoDispose` because it is read from storage: logging out and back in as
/// someone else during the same app session must not be answered from a cache.
final loggedInCoordinatorIdProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final id = await StorageUtil.getCoordinatorId();
  debugPrint('Logged-in Coordinatorid: $id');
  return id;
});

/// Which side of the coordinator requests the logged-in user looks at.
enum CoordinatorRequestsScope {
  /// A coordinator — the requests sent to them.
  received,

  /// A marketing person — the requests they sent to coordinators.
  sent,

  /// Neither, so there is nothing to fetch.
  none,
}

/// A coordinator login sees what it was sent; otherwise a login with its own
/// marketing group sees what that group sent. Marketing_Code 0 means no group.
final coordinatorRequestsScopeProvider =
    FutureProvider.autoDispose<CoordinatorRequestsScope>((ref) async {
  final coordinatorId = await ref.watch(loggedInCoordinatorIdProvider.future);
  if (coordinatorId != null) return CoordinatorRequestsScope.received;
  if (await StorageUtil.hasOwnMarketingGroup()) {
    return CoordinatorRequestsScope.sent;
  }
  return CoordinatorRequestsScope.none;
});

/// The logged-in user's coordinator requests, newest first — received ones
/// for a coordinator, sent ones for a marketing person (see
/// [coordinatorRequestsScopeProvider]).
///
/// A coordinator is matched on `Coordinatorid` and display name, a marketing
/// person on their marketing code; all three come from the login response in
/// storage.
///
/// `autoDispose` so a request sent from this session shows up the next time
/// the list is opened; `ref.invalidate` forces a refetch while it is on screen.
final myCoordinatorRequestsProvider =
    FutureProvider.autoDispose<List<CoordinatorRequestRecord>>((ref) async {
  final scope = await ref.watch(coordinatorRequestsScopeProvider.future);
  final repository = ref.read(coordinatorRequestRepositoryProvider);

  switch (scope) {
    case CoordinatorRequestsScope.received:
      final coordinatorId = await StorageUtil.getCoordinatorId() ?? '';
      final coordinatorName = await StorageUtil.getUserName() ?? '';
      debugPrint('Fetching requests for $coordinatorId / $coordinatorName');
      return repository.getRequestsByCoordinator(
        coordinatorId: coordinatorId,
        coordinatorName: coordinatorName,
      );
    case CoordinatorRequestsScope.sent:
      final marketingCode = await StorageUtil.getMarketingCode() ?? '';
      debugPrint('Fetching requests sent by marketing code $marketingCode');
      return repository.getRequestsByMarketingCode(marketingCode);
    case CoordinatorRequestsScope.none:
      return const [];
  }
});
