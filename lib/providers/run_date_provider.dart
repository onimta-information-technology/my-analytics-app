import 'package:ballys_reservation_app/data/repositories/run_date_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/run_date.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

final _flutterSecureStorageProvider = Provider(
  (ref) => SecureStorage.instance,
);
final _apiServiceProvider = Provider((ref) {
  final storage = ref.read(_flutterSecureStorageProvider);
  return ApiService(storage);
});
final runDateRepositoryProvider = Provider((ref) {
  final apiService = ref.read(_apiServiceProvider);
  return RunDateRepository(apiService);
});

// ── Wrapper state so UI can distinguish loading vs failed ──────────────────
class RunDateState {
  final RunDate? runDate;
  final bool isLoading;
  final bool hasError;

  const RunDateState({
    this.runDate,
    this.isLoading = false,
    this.hasError = false,
  });
}

class RunDateNotifier extends StateNotifier<RunDateState> {
  final RunDateRepository runDateRepository;

  RunDateNotifier(this.runDateRepository) : super(const RunDateState());

  Future<void> getRunDate() async {
    state = const RunDateState(isLoading: true);
    try {
      final runDate = await runDateRepository.getRunDate();
      state = RunDateState(runDate: runDate);
    } catch (e) {
      state = const RunDateState(hasError: true); // ← UI can now detect failure
    }
  }

  void reset() => state = const RunDateState(isLoading: true);
}

final runDateProvider =
    StateNotifierProvider<RunDateNotifier, RunDateState>((ref) {
  final repository = ref.read(runDateRepositoryProvider);
  return RunDateNotifier(repository);
});