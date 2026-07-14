import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation.dart';

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
}
