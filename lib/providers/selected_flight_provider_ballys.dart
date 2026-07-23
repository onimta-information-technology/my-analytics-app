
import 'package:ballys_reservation_app/models/reservation/flight_bookng_ballys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedFlightBallysNotifier extends StateNotifier<List<FlightBookingBallys>> {
  SelectedFlightBallysNotifier() : super([]);

  void addFlights(List<FlightBookingBallys> flights) {
    state = [...flights];
  }

  void setFlights(List<FlightBookingBallys> flights) {
    state = [...flights];
  }
}

final selectedFlightBallysProvider =
    StateNotifierProvider<SelectedFlightBallysNotifier, List<FlightBookingBallys>>(
        (ref) => SelectedFlightBallysNotifier());
