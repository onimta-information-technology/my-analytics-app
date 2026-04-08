// lib/providers/cdd_history_provider.dart

import 'package:ballys_reservation_app/data/repositories/customer_due_diligence_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/cdd/cdd_history_item.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _apiServiceProvider = Provider(
  (ref) => ApiService(const FlutterSecureStorage()),
);

final cddRepositoryProvider2 = Provider((ref) {
  return CustomerDueDiligenceRepository(ref.read(_apiServiceProvider));
});

// AsyncNotifier that loads the history list
class CddHistoryNotifier extends AsyncNotifier<List<CddHistoryItem>> {
  @override
  Future<List<CddHistoryItem>> build() => _load();

  Future<List<CddHistoryItem>> _load() async {
    final username = await StorageUtil.getUserName() ?? '';
    final deviceId = await DeviceId.get();
    final repo = ref.read(cddRepositoryProvider2);
    return repo.fetchCDDHistory(username: username, deviceId: deviceId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final cddHistoryProvider =
    AsyncNotifierProvider<CddHistoryNotifier, List<CddHistoryItem>>(
  CddHistoryNotifier.new,
);