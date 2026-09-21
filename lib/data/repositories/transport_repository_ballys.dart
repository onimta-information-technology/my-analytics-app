import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation_ballys.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class TransportRepositoryBallys {
  final ApiService apiService;

  TransportRepositoryBallys(this.apiService);

  /// Resolved against the current CRM base URL.
  static const String _listEndpoint = 'TransportReservation/Get';

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
}
