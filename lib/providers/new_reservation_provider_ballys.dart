import 'package:ballys_reservation_app/models/reservation/new_reservation.dart';
import 'package:ballys_reservation_app/models/reservation/new_reservation_ballys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NewReservationBallysNotifier extends StateNotifier<NewReservationBallys> {
  NewReservationBallysNotifier() : super(NewReservationBallys());

  void updateMemberInfo(String mid, String mName) {
    state = state.copyWith(
      bmNumber: mid.isEmpty ? null : mid,
      guestName: mName.isEmpty ? null : mName,
    );
  }

  void resetState() {
    state = NewReservationBallys(
        bmNumber: null,
        guestName: null,
        hotelName: null,
        roomDetails: [],
        noOfNights: null,
        arrivalDate: null,
        departureDate: null,
        hasAirTicketReservation: null,
        remarks: null,
        airTicketDetails: null);
  }

  void resetMemberInfo() {
    state = state.copyWith(
      bmNumber: null,
      guestName: null,
    );
  }
}

final newReservationBallysProvider =
    StateNotifierProvider<NewReservationBallysNotifier, NewReservationBallys>(
        (ref) => NewReservationBallysNotifier());
