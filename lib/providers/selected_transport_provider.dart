import 'package:ballys_reservation_app/models/transport/transport_reservation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedTransportNotifier extends StateNotifier<TransportReservation?> {
  SelectedTransportNotifier() : super(null);

  void setSelectedTransport(TransportReservation transport) {
    state = transport;
  }

  void clearSelectedTransport() {
    state = null;
  }
}

final selectedTransportProvider =
    StateNotifierProvider<SelectedTransportNotifier, TransportReservation?>(
        (ref) {
  return SelectedTransportNotifier();
});
