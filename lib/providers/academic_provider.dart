import 'package:ballys_reservation_app/data/repositories/academic_repository.dart';
// Reuses the apiServiceProvider already declared in marketing_provider.dart
// rather than redeclaring it.
import 'package:ballys_reservation_app/providers/marketing_provider.dart'
    show apiServiceProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final academicRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AcademicRepository(apiService);
});
