import 'package:ballys_reservation_app/data/repositories/pending_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/pendingCounts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final pendingCountRepositoryProvider = Provider((ref) {
  final apiService = ApiService(const FlutterSecureStorage());
  return PendingCountRepository(apiService);
});

// Notifier that holds loading / error / data state
class PendingCountNotifier extends StateNotifier<AsyncValue<PendingCounts>> {
  final PendingCountRepository repository;

  PendingCountNotifier(this.repository) : super(const AsyncValue.loading());

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    print('Fetching pending counts...');
    try {
      final counts = await repository.getPendingCounts();
      state = AsyncValue.data(counts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final pendingCountProvider =
    StateNotifierProvider<PendingCountNotifier, AsyncValue<PendingCounts>>((ref) {
  final repository = ref.read(pendingCountRepositoryProvider);
  final notifier = PendingCountNotifier(repository);
  notifier.fetch(); // auto-fetch on first use
  return notifier;
});