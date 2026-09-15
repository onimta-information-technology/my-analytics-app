import 'package:ballys_reservation_app/data/repositories/group_reservation_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/group_reservation.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final groupReservationRepositoryProvider =
    Provider<GroupReservationRepository>((ref) {
  return GroupReservationRepository(ApiService(SecureStorage.instance));
});

/// Saved group reservations from `GroupReservation/Get`, newest first.
///
/// `autoDispose` so a group saved in this session shows up the next time the
/// list is opened; `ref.invalidate` forces a refetch while it is on screen.
final groupReservationsProvider =
    FutureProvider.autoDispose<List<GroupReservationRecord>>((ref) async {
  return ref.read(groupReservationRepositoryProvider).getGroupReservations();
});

/// Scheme + authority of the current API URL — uploaded sheets and passports
/// are served from the host root, not under `/api/Ballys/CRM`. Null when no
/// API URL is stored.
final groupReservationFileHostProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final apiUrl = await StorageUtil.getCurrentApiUrl();
  final uri = apiUrl == null ? null : Uri.tryParse(apiUrl);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  return '${uri.scheme}://${uri.authority}';
});
