import 'package:ballys_reservation_app/data/repositories/hotel_repository.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_response.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_room_catalog_entry.dart';
import 'package:ballys_reservation_app/providers/hotels_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the combined hotel / category / room type / meal plan catalog
/// (API 90155) for the Ballys reservation forms. Loaded once, then every
/// dropdown is filtered from it in memory.
class HotelCatalogNotifier extends StateNotifier<List<HotelRoomCatalogEntry>> {
  final HotelRepository hotelRepository;

  HotelCatalogNotifier(this.hotelRepository) : super([]);

  bool _loading = false;

  bool get isLoading => _loading;

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (state.isNotEmpty && !force) return;
    _loading = true;
    try {
      state = await hotelRepository.getHotelRoomCatalog();
    } catch (e) {
      state = [];
    } finally {
      _loading = false;
    }
  }

  List<HotelResponse> get hotels => HotelRoomCatalogEntry.hotelsFrom(state);

  List<Map<String, dynamic>> get hotelsAsMap =>
      HotelRoomCatalogEntry.hotelsAsMapFrom(state);

  List<Map<String, dynamic>> categoriesFor(double hotelId) =>
      HotelRoomCatalogEntry.categoriesFrom(state, hotelId);

  List<Map<String, dynamic>> roomTypesFor(double hotelId, int categoryId) =>
      HotelRoomCatalogEntry.roomTypesFrom(state, hotelId, categoryId);

  String hotelCategoryOf(double? hotelId, int? categoryId) =>
      HotelRoomCatalogEntry.hotelCategoryOf(state, hotelId, categoryId);
}

final hotelCatalogProvider =
    StateNotifierProvider<HotelCatalogNotifier, List<HotelRoomCatalogEntry>>(
        (ref) {
  return HotelCatalogNotifier(ref.read(hotelsRepositoryProvider));
});

/// Distinct hotels from the catalog, in the shape the reservation forms
/// already consume.
final hotelCatalogHotelsProvider = Provider<List<HotelResponse>>((ref) {
  return HotelRoomCatalogEntry.hotelsFrom(ref.watch(hotelCatalogProvider));
});
