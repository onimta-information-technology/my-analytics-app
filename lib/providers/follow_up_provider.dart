import 'package:ballys_reservation_app/data/repositories/follow_up_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _followUpSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final _followUpApiServiceProvider = Provider((ref) {
  final storage = ref.read(_followUpSecureStorageProvider);
  return ApiService(storage);
});

final followUpRepositoryProvider = Provider((ref) {
  final apiService = ref.read(_followUpApiServiceProvider);
  return FollowUpRepository(apiService);
});
