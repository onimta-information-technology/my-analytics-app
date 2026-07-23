import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc_ballys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedHotelBallysNotifier extends StateNotifier<List<HotelDescipBallys>> {
  SelectedHotelBallysNotifier() : super([]);

  void addHotels(List<HotelDescipBallys> hotels) {
    state = [...hotels];
  }

  void setHotels(List<HotelDescipBallys> hotels) {
    state = [...hotels];
  }
}

final selectedHotelBallysProvider =
    StateNotifierProvider<SelectedHotelBallysNotifier, List<HotelDescipBallys>>(
        (ref) => SelectedHotelBallysNotifier());
