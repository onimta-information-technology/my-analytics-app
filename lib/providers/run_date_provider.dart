import 'package:ballys_reservation_app/data/repositories/run_date_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/run_date.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


final _flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final _apiServiceProvider = Provider((ref) {
  final storage = ref.read(_flutterSecureStorageProvider);
  return ApiService(storage);
});


final runDateRepositoryProvider = Provider((ref) {
  final apiService = ref.read(_apiServiceProvider);
  return RunDateRepository(apiService);
});



class RunDateNotifier extends StateNotifier<RunDate?> {
  final RunDateRepository runDateRepository;

  RunDateNotifier(this.runDateRepository) : super(null);

  /// Fetches the server run date. Returns the [RunDate] on success, null on failure.
  Future<RunDate?> getRunDate() async {
    try {
      final runDate = await runDateRepository.getRunDate();
      state = runDate;
      return runDate;
    } catch (e) {
      state = null;
      return null;
    }
  }

  /// Clears the stored run date (e.g. on logout).
  void reset() => state = null;
}

// ─── Exposed provider ─────────────────────────────────────────────────────────

final runDateProvider = StateNotifierProvider<RunDateNotifier, RunDate?>((ref) {
  final repository = ref.read(runDateRepositoryProvider);
  return RunDateNotifier(repository);
});