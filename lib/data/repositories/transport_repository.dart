import 'dart:convert';

import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
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

  /// Amendment endpoint, resolved against the current CRM base URL — i.e.
  /// `https://bty.world/api/Bellagio/CRM/Transport_Amendment_Insert`.
  static const String amendmentEndpoint = 'Transport_Amendment_Insert';

  /// POST `{baseUrl}/Transport_Amendment_Insert` — records an amendment note
  /// against an existing transport request.
  Future<TransportInsertResult> submitAmendment({
    required String masterId,
    required String mid,
    required String guestName,
    required String amendment,
  }) async {
    final userName = await StorageUtil.getUName();
  print('Submitting amendment for $guestName ($mid) by $userName: $amendment');
    final deviceId = await DeviceId.get();

    final body = <String, Object?>{
      'master_id': masterId,
      'mid': mid,
      'guest_name': guestName,
      'amendment': amendment,
      'user_name': userName,
      'device_id': deviceId,
      'amendment_details': [
        {
          'mid': mid,
          'guest_name': guestName,
                    'amendment': amendment,
        }
      ],
    };

    final url =
        '${await StorageUtil.getCurrentApiUrl() ?? ''}/$amendmentEndpoint';
    print('Amendment POST → $url');
    print('Amendment payload → ${jsonEncode(body)}');

    final response = await apiService.post(amendmentEndpoint, body);
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
