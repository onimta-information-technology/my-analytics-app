import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedHotelNotifier extends StateNotifier<List<HotelDescip>> {
  SelectedHotelNotifier() : super([]);

  void addHotels(List<HotelDescip> hotels) {
    state = [...hotels];
  }

  void setHotels(List<HotelDescip> hotels) {
    state = [...hotels];
  }
}

final selectedHotelProvider =
    StateNotifierProvider<SelectedHotelNotifier, List<HotelDescip>>(
        (ref) => SelectedHotelNotifier());
