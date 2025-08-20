import 'package:ballys_reservation_app/models/reservation/new_reservation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NewReservationNotifier extends StateNotifier<NewReservation> {
  NewReservationNotifier() : super(NewReservation());

  void updateMemberInfo(String mid, String mName) {
    state = state.copyWith(
      bmNumber: mid.isEmpty ? null : mid,
      guestName: mName.isEmpty ? null : mName,
    );
  }

  void resetState() {
    state = NewReservation(
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

final newReservationProvider =
    StateNotifierProvider<NewReservationNotifier, NewReservation>(
        (ref) => NewReservationNotifier());
