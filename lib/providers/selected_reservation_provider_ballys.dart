import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedReservationBallysNotifier extends StateNotifier<ReservationBallys?> {
  SelectedReservationBallysNotifier() : super(null);

  void setSelectedReservation(ReservationBallys reservation) {
    state = reservation;
  }

  void clearSelectedReservation() {
    state = null;
  }
}

final selectedReservationBallysProvider =
    StateNotifierProvider<SelectedReservationBallysNotifier, ReservationBallys?>((ref) {
  return SelectedReservationBallysNotifier();
});
