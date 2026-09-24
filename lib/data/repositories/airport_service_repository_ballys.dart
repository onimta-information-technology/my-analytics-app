import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/airport_service/airport_service_ballys.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class AirportServiceRepositoryBallys {
  final ApiService apiService;

  AirportServiceRepositoryBallys(this.apiService);

  /// Resolved against the current CRM base URL.
  static const String _listEndpoint = 'AirportService/Get';
  static const String _updateStatusEndpoint = 'AirportService/UpdateStatus';

  /// GET `{baseUrl}/AirportService/Get` —
  /// `{ success, count, airport_services }`.
  ///
  /// Sales code AD001 and users with the `ResApp` / `ResChk` permission see
  /// every request, so they call it without query parameters; everyone else
  /// is scoped to their own marketing code.
  Future<List<AirportServiceBallys>> getAirportServices() async {
    final isAdmin = await StorageUtil.isAdminSalesCode();
    final resApp = await StorageUtil.getResApp() == true;
    final resChk = await StorageUtil.getResChk() == true;

    String endpoint = _listEndpoint;
    if (!isAdmin && !resApp && !resChk) {
      final marketingCode = await StorageUtil.getMarketingCode();
      if (marketingCode == null) return [];
      endpoint =
          '$_listEndpoint?marketingCode=${Uri.encodeQueryComponent(marketingCode)}';
    }

    final response = await apiService.get(endpoint);

    if (response['success'] != true) return [];

    final data = response['airport_services'];
    if (data is! List) return [];

    final requests = data
        .whereType<Map>()
        .map((item) =>
            AirportServiceBallys.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    // Newest first — the API's order is not guaranteed.
    requests.sort((a, b) {
      final aDate = a.createdDate;
      final bDate = b.createdDate;
      if (aDate == null || bDate == null) return b.id.compareTo(a.id);
      return bDate.compareTo(aDate);
    });

    return requests;
  }

  /// POST `{baseUrl}/AirportService/UpdateStatus` — moves a request to
  /// `Checked`, `Approved` or `Rejected`.
  Future<AirportServiceStatusUpdateResult> updateStatus({
    required String masterId,
    required String status,
    required String remark,
  }) async {
    final body = <String, Object?>{
      'master_id': masterId,
      'reservation_status': status,
      'user_name': await StorageUtil.getUserName() ?? '',
      'remark': remark,
      'device_id': await DeviceId.get(),
    };
    print('AirportService UpdateStatus payload → $body');
    final response = await apiService.post(_updateStatusEndpoint, body);
    print('AirportService UpdateStatus result → $response');

    return AirportServiceStatusUpdateResult(
      success: response['success'] == true || response['Status'] == true,
      message: (response['message'] ?? response['Message'])?.toString(),
    );
  }
}

/// Outcome of an `AirportService/UpdateStatus` call.
class AirportServiceStatusUpdateResult {
  final bool success;
  final String? message;

  const AirportServiceStatusUpdateResult({required this.success, this.message});
}
