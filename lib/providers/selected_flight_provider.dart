import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedFlightNotifier extends StateNotifier<List<FlightBooking>> {
  SelectedFlightNotifier() : super([]);

  void addFlights(List<FlightBooking> flights) {
    state = [...flights];
  }

  void setFlights(List<FlightBooking> flights) {
    state = [...flights];
  }
}

final selectedFlightProvider =
    StateNotifierProvider<SelectedFlightNotifier, List<FlightBooking>>(
        (ref) => SelectedFlightNotifier());
