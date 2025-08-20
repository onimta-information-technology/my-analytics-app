import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedReservationNotifier extends StateNotifier<Reservation?> {
  SelectedReservationNotifier() : super(null);

  void setSelectedReservation(Reservation reservation) {
    state = reservation;
  }

  void clearSelectedReservation() {
    state = null;
  }
}

final selectedReservationProvider =
    StateNotifierProvider<SelectedReservationNotifier, Reservation?>((ref) {
  return SelectedReservationNotifier();
});
