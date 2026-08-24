import 'package:ballys_reservation_app/data/repositories/reservation_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

/// Fetches the list of predefined package amounts from
/// `GetPackageAmounts_MyAnalytics` (e.g. `"IND 10,000"`, `"USD 25,000"`).
///
/// Consumed by [PackageAmountField] to populate its dropdown. Kept as a
/// [FutureProvider] so the result is cached for the app session and shared
/// between the new-reservation and quick-reservation screens.
final packageAmountsProvider = FutureProvider<List<String>>((ref) async {
  final repository = ReservationRepository(ApiService(SecureStorage.instance));
  return repository.getPackageAmounts();
});
