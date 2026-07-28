import 'dart:convert';

import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class TransportRepository {
  final ApiService apiService;

  TransportRepository(this.apiService);

  /// GET `{baseUrl}/Transport_Get_Data` — Bellagio only.
  Future<List<TransportReservation>> getTransportData() async {
    final response = await apiService.get('Transport_Get_Data');

    if (response['Status'] != true) return [];

    final data = response['Data'];
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((item) =>
            TransportReservation.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// POST `{baseUrl}/Transport_Insert` — creates a transport reservation with
  /// one or more vehicle/hire legs in `transport_details`.
  Future<TransportInsertResult> insertTransport(
    Map<String, Object?> body,
  ) async {
    final response = await apiService.post('Transport_Insert', body);

    return TransportInsertResult(
      success: response['Status'] as bool? ?? false,
      message: response['Message'] as String?,
    );
  }

  /// POST `{baseUrl}/amendment` — records an amendment note against an existing
  /// transport request (Bellagio: `https://bty.world/api/Bellagio/CRM/amendment`).
  Future<TransportInsertResult> submitAmendment({
    required String masterId,
    required String amendment,
  }) async {
    final body = <String, Object?>{
      'master_id': masterId,
      'amendment': amendment,
    };

    final url = '${await StorageUtil.getCurrentApiUrl() ?? ''}/amendment';
    print('Amendment POST → $url');
    print('Amendment payload → ${jsonEncode(body)}');

    final response = await apiService.post('amendment', body);
    print('Amendment result → $response');

    return TransportInsertResult(
      success: response['Status'] as bool? ?? false,
      message: response['Message'] as String?,
    );
  }
}

/// Outcome of a `Transport_Insert` call.
class TransportInsertResult {
  final bool success;
  final String? message;

  const TransportInsertResult({required this.success, this.message});
}
