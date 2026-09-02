import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/authorization_level.dart';

class AuthorizationLevelRepository {
  final ApiService apiService;

  AuthorizationLevelRepository(this.apiService);

  /// Fetches the approvers from `GetAuthorizationLevels`.
  ///
  /// The endpoint answers `{ "success": true, "data": [ ... ] }`; a false or
  /// missing `success` is treated as an empty list rather than an error, since
  /// the API carries no error payload of its own. Inactive rows are dropped and
  /// the rest are ordered by level, then by name, so the dropdown reads
  /// Level 1 → Level 4 regardless of the order the API returns.
  Future<List<AuthorizationLevel>> getAuthorizationLevels() async {
    final response = await apiService.get('GetAuthorizationLevels');

    if (response['success'] != true) return const <AuthorizationLevel>[];

    final data = response['data'] as List<dynamic>? ?? const [];
    final levels = data
        .whereType<Map>()
        .map((e) => AuthorizationLevel.fromJson(Map<String, dynamic>.from(e)))
        .where((level) => level.isActive)
        .toList();

    levels.sort((a, b) {
      final byLevel = a.levelNo.compareTo(b.levelNo);
      return byLevel != 0 ? byLevel : a.name.compareTo(b.name);
    });

    return levels;
  }
}
