import 'package:ballys_reservation_app/data/repositories/hotel_repository.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_location.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_response.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_room_catalog_entry.dart';
import 'package:ballys_reservation_app/providers/hotels_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the combined hotel / category / room type / meal plan catalog
/// (`HotelsGetByLocation`, both locations merged) for the Ballys reservation
/// forms. Held in memory so every
/// dropdown filters it without re-fetching, and re-read whenever a form is
/// about to offer it — see [refresh].
class HotelCatalogNotifier extends StateNotifier<List<HotelRoomCatalogEntry>> {
  final HotelRepository hotelRepository;

  HotelCatalogNotifier(this.hotelRepository) : super([]);

  /// The fetch currently in flight. Callers that arrive mid-request wait on
  /// this one rather than returning straight away — an `await load()` that
  /// returned early used to hand back a catalog that had not landed yet.
  Future<void>? _inFlight;

  bool get isLoading => _inFlight != null;

  /// Fetches the catalog unless one is already held. Use this to warm the
  /// cache; anything actually showing the dropdowns wants [refresh].
  Future<void> load({bool force = false}) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    if (state.isNotEmpty && !force) return Future.value();
    return _inFlight = _fetch();
  }

  /// Re-reads the catalog from the API. Hotels, room categories and room types
  /// are maintained server-side, so a list cached at app start goes stale and
  /// the dropdowns keep offering the previous hotels until the app restarts.
  Future<void> refresh() => load(force: true);

  Future<void> _fetch() async {
    try {
      state = await hotelRepository.getHotelRoomCatalog();
    } catch (_) {
      // Whatever we already hold stays put: emptying the list here would blank
      // the dropdowns mid-booking over one dropped request.
    } finally {
      _inFlight = null;
    }
  }

  List<HotelResponse> hotels({HotelLocation? location}) =>
      HotelRoomCatalogEntry.hotelsFrom(state, location: location);

  List<Map<String, dynamic>> hotelsAsMap({HotelLocation? location}) =>
      HotelRoomCatalogEntry.hotelsAsMapFrom(state, location: location);

  /// The type an already-picked hotel is listed under.
  HotelLocation? locationOfHotel(double? hotelId) =>
      HotelRoomCatalogEntry.locationOfHotel(state, hotelId);

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
/// already consume, narrowed to the hotel type the form asked for. A null
/// argument means the type has not been answered yet and hands back every
/// hotel; the forms keep their hotel dropdown disabled until it is.
final hotelCatalogHotelsProvider =
    Provider.family<List<HotelResponse>, HotelLocation?>((ref, location) {
  return HotelRoomCatalogEntry.hotelsFrom(
    ref.watch(hotelCatalogProvider),
    location: location,
  );
});
