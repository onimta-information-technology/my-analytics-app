import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation_ballys.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class TransportRepositoryBallys {
  final ApiService apiService;

  TransportRepositoryBallys(this.apiService);

  /// Resolved against the current CRM base URL.
  static const String _listEndpoint = 'TransportReservation/Get';
  static const String _updateStatusEndpoint = 'TransportReservation/UpdateStatus';

  /// GET `{baseUrl}/TransportReservation/Get` — `{ success, count,
  /// transport_reservations }`.
  ///
  /// Sales code AD001 sees every request, so it queries by sales code;
  /// everyone else is scoped to their own marketing code.
  Future<List<TransportReservationBallys>> getTransportReservations() async {
    final String query;
    if (await StorageUtil.isAdminSalesCode()) {
      final salesCode = (await StorageUtil.getSalesCode())!.trim();
      query = 'salesCode=${Uri.encodeQueryComponent(salesCode)}';
    } else {
      final marketingCode = await StorageUtil.getMarketingCode();
      if (marketingCode == null) return [];
      query = 'marketingCode=${Uri.encodeQueryComponent(marketingCode)}';
    }

    final response = await apiService.get('$_listEndpoint?$query');

    if (response['success'] != true) return [];

    final data = response['transport_reservations'];
    if (data is! List) return [];

    final reservations = data
        .whereType<Map>()
        .map((item) => TransportReservationBallys.fromJson(
            Map<String, dynamic>.from(item)))
        .toList();

    // Newest first — the API's order is not guaranteed.
    reservations.sort((a, b) {
      final aDate = a.createdDate;
      final bDate = b.createdDate;
      if (aDate == null || bDate == null) return b.id.compareTo(a.id);
      return bDate.compareTo(aDate);
    });

    return reservations;
  }

  /// POST `{baseUrl}/TransportReservation/UpdateStatus` — moves a request to
  /// `Checked`, `Approved` or `Rejected`.
  Future<TransportStatusUpdateResult> updateStatus({
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
    print('Transport UpdateStatus payload → $body');
    final response = await apiService.post(_updateStatusEndpoint, body);
    print('Transport UpdateStatus result → $response');

    return TransportStatusUpdateResult(
      success: response['success'] == true || response['Status'] == true,
      message: (response['message'] ?? response['Message'])?.toString(),
    );
  }
}

/// Outcome of a `TransportReservation/UpdateStatus` call.
class TransportStatusUpdateResult {
  final bool success;
  final String? message;

  const TransportStatusUpdateResult({required this.success, this.message});
}
