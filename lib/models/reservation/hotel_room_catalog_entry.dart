import 'package:ballys_reservation_app/models/reservation/hotel_location.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_response.dart';

/// One hotel → room category → room type combination, flattened out of
/// `HotelsGetByLocation?Location=…`.
///
/// The Ballys reservation forms used to chain three calls (hotels 9015,
/// categories 9016, room types 9017), then a single combined one (90155).
/// `HotelsGetByLocation` returns the same data nested — hotels, each with its
/// categories, each with its rooms — so it is flattened into these rows and the
/// dropdowns keep deriving themselves in memory from one list.
///
/// The nesting allows branches the flat APIs could not express: a hotel with no
/// categories, or a category with no rooms. Those still have to reach the hotel
/// and category dropdowns, so they are kept as placeholder rows — see
/// [hasRoomCategory] / [hasRoomType].
class HotelRoomCatalogEntry {
  final double hotelId;
  final String hotelName;

  /// `CityHotel` or `OutsideColombo` — which call the row came back from.
  final String hotelLocation;
  final String hotelAddress;
  final String hotelPhone;
  final int roomCategoryId;
  final String roomCategoryName;

  /// Grading of the room category, e.g. "(Standard)" / "(Executive Room)".
  ///
  /// `HotelsGetByLocation` carries no grading, so this stays empty and the
  /// suffix simply drops off the category labels. Kept so the forms that show
  /// it need no change if the API starts returning one.
  final String hotelCategory;

  final String mealPlan;
  final int roomTypeId;
  final String roomTypeName;

  // Rates as the API holds them for this room row.
  final double roomRate;
  final double tax;
  final double netRate;
  final double comm;
  final double ourRate;
  final double extraBed;

  HotelRoomCatalogEntry({
    required this.hotelId,
    required this.hotelName,
    this.hotelLocation = '',
    this.hotelAddress = '',
    this.hotelPhone = '',
    this.roomCategoryId = 0,
    this.roomCategoryName = '',
    this.hotelCategory = '',
    this.mealPlan = '',
    this.roomTypeId = 0,
    this.roomTypeName = '',
    this.roomRate = 0,
    this.tax = 0,
    this.netRate = 0,
    this.comm = 0,
    this.ourRate = 0,
    this.extraBed = 0,
  });

  /// True when this row names a real room category rather than standing in for
  /// a hotel that lists none.
  bool get hasRoomCategory => roomCategoryId != 0 || roomCategoryName.isNotEmpty;

  /// True when this row names a real room type rather than standing in for a
  /// category that lists no rooms.
  bool get hasRoomType => roomTypeId != 0 || roomTypeName.isNotEmpty;

  /// Which of the two lists this hotel belongs to, or null when [hotelLocation]
  /// names neither.
  HotelLocation? get location => HotelLocation.fromApiValue(hotelLocation);

  // ── Parsing ───────────────────────────────────────────────────────────────

  /// Flattens one `HotelsGetByLocation` response into catalog rows.
  ///
  /// Shape: `{ success, location, groups: [ { location, hotels: [ { …hotel,
  /// categories: [ { …category, rooms: [ … ] } ] } ] } ] }`.
  static List<HotelRoomCatalogEntry> fromLocationResponse(
    Map<String, dynamic> json,
  ) {
    final entries = <HotelRoomCatalogEntry>[];
    final groups = json['groups'];
    if (groups is! List) return entries;

    for (final group in groups.whereType<Map>()) {
      // Each hotel carries its own HotelLocation; the group's is the fallback
      // for the rare row that comes back without one.
      final groupLocation = _text(group['location']);
      final hotels = group['hotels'];
      if (hotels is! List) continue;

      for (final hotel in hotels.whereType<Map>()) {
        entries.addAll(_rowsForHotel(
          Map<String, dynamic>.from(hotel),
          groupLocation,
        ));
      }
    }
    return entries;
  }

  static List<HotelRoomCatalogEntry> _rowsForHotel(
    Map<String, dynamic> hotel,
    String groupLocation,
  ) {
    final hotelId = _toDouble(hotel['Hotel_IID']);
    final hotelName = _text(hotel['HotelName']);
    final location = _text(hotel['HotelLocation']).isEmpty
        ? groupLocation
        : _text(hotel['HotelLocation']);
    final address = _text(hotel['Address']);
    final phone = _text(hotel['Phone']);

    HotelRoomCatalogEntry base({
      int roomCategoryId = 0,
      String roomCategoryName = '',
      Map<String, dynamic>? room,
    }) =>
        HotelRoomCatalogEntry(
          hotelId: hotelId,
          hotelName: hotelName,
          hotelLocation: location,
          hotelAddress: address,
          hotelPhone: phone,
          roomCategoryId: roomCategoryId,
          roomCategoryName: roomCategoryName,
          mealPlan: _text(room?['MealPlan']),
          roomTypeId: _toInt(room?['ID']),
          roomTypeName: _text(room?['RoomType']),
          roomRate: _toDouble(room?['RoomRate']),
          tax: _toDouble(room?['Tax']),
          netRate: _toDouble(room?['NetRate']),
          comm: _toDouble(room?['Comm']),
          ourRate: _toDouble(room?['OurRate']),
          extraBed: _toDouble(room?['ExtraBed']),
        );

    final rows = <HotelRoomCatalogEntry>[];
    final categories = hotel['categories'];

    if (categories is List) {
      for (final category in categories.whereType<Map>()) {
        // Only a category the API explicitly retires is dropped; anything
        // without a flag stays, so an unset column cannot empty a dropdown.
        if (_isRetired(category['IsActive'])) continue;

        final categoryId = _toInt(category['CatCode']);
        final categoryName = _text(category['CatName']);
        final rooms = category['rooms'];

        if (rooms is List && rooms.whereType<Map>().isNotEmpty) {
          for (final room in rooms.whereType<Map>()) {
            rows.add(base(
              roomCategoryId: categoryId,
              roomCategoryName: categoryName,
              room: Map<String, dynamic>.from(room),
            ));
          }
        } else {
          // Rates for this category are not loaded yet. The category is still
          // offered — its room type dropdown just comes back empty — rather
          // than the hotel silently losing it.
          rows.add(base(
            roomCategoryId: categoryId,
            roomCategoryName: categoryName,
          ));
        }
      }
    }

    // A hotel with no categories at all still belongs in the hotel dropdown.
    if (rows.isEmpty) rows.add(base());

    return rows;
  }

  /// True only for a flag that explicitly says inactive (`"F"` / `false`).
  static bool _isRetired(dynamic value) {
    if (value is bool) return !value;
    final text = value?.toString().trim().toUpperCase() ?? '';
    return text == 'F' || text == 'FALSE' || text == 'N' || text == '0';
  }

  /// Every name off this API is trimmed. The columns behind it are fixed-width
  /// and hand-maintained, so values come back padded, and the padding shows:
  /// a leading space indents that row away from the rest of the dropdown.
  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Category label with its grading, e.g. "Deluxe City View (Standard)".
  String get roomCategoryLabel =>
      hotelCategory.isEmpty ? roomCategoryName : '$roomCategoryName $hotelCategory';

  /// Room type label with its meal plan, e.g. "Double - BB" — the wording the
  /// reservation forms already store and display.
  String get roomTypeLabel => '$roomTypeName - $mealPlan';

  // ── Derivations for the dropdowns ─────────────────────────────────────────
  // The map shapes below are the ones the reservation forms and the hotel cost
  // API (9022) already speak, so only the data source changes.
  //
  // Each keeps the order the API returned. The API decides how the lists read —
  // re-sorting them here would override an ordering the back office controls.
  // Deduping runs through a plain map, which keeps insertion order, so first
  // occurrence wins and the rest follow as they arrived.

  /// Distinct hotels, narrowed to one [location] when given — the forms ask
  /// for the type before the hotel, so the dropdown behind that answer only
  /// carries that type's hotels.
  static List<HotelResponse> hotelsFrom(
    List<HotelRoomCatalogEntry> entries, {
    HotelLocation? location,
  }) {
    final byId = <double, HotelResponse>{};
    for (final e in entries) {
      if (location != null && e.location != location) continue;
      byId.putIfAbsent(
        e.hotelId,
        () => HotelResponse(hotelId: e.hotelId, hotelName: e.hotelName),
      );
    }
    return byId.values.toList();
  }

  static List<Map<String, dynamic>> hotelsAsMapFrom(
    List<HotelRoomCatalogEntry> entries, {
    HotelLocation? location,
  }) =>
      hotelsFrom(entries, location: location)
          .map((h) => {'Hotel_IID': h.hotelId, 'HotelName': h.hotelName})
          .toList();

  /// The type a hotel is listed under — used to answer the type question on
  /// behalf of a hotel that was picked before it was asked, i.e. a saved row
  /// pulled back in for editing.
  static HotelLocation? locationOfHotel(
    List<HotelRoomCatalogEntry> entries,
    double? hotelId,
  ) {
    if (hotelId == null) return null;
    for (final e in entries) {
      if (e.hotelId == hotelId) return e.location;
    }
    return null;
  }

  static List<Map<String, dynamic>> categoriesFrom(
    List<HotelRoomCatalogEntry> entries,
    double hotelId,
  ) {
    final byId = <int, Map<String, dynamic>>{};
    for (final e in entries.where((e) => e.hotelId == hotelId && e.hasRoomCategory)) {
      byId.putIfAbsent(
        e.roomCategoryId,
        () => {
          'CatCode': e.roomCategoryId,
          'CatName': e.roomCategoryName,
          'HotelCategory': e.hotelCategory,
        },
      );
    }
    return byId.values.toList();
  }

  static List<Map<String, dynamic>> roomTypesFrom(
    List<HotelRoomCatalogEntry> entries,
    double hotelId,
    int categoryId,
  ) {
    final byKey = <String, Map<String, dynamic>>{};
    for (final e in entries.where(
      (e) => e.hotelId == hotelId && e.roomCategoryId == categoryId && e.hasRoomType,
    )) {
      byKey.putIfAbsent(
        '${e.roomTypeId}|${e.mealPlan}',
        () => {
          'ID': e.roomTypeId,
          'RoomType': e.roomTypeName,
          'MealPlan': e.mealPlan,
          // Rates ride along: HotelsGetByLocation returns them with the room,
          // where the flat APIs needed a separate cost call (9022).
          'RoomRate': e.roomRate,
          'Tax': e.tax,
          'NetRate': e.netRate,
          'Comm': e.comm,
          'OurRate': e.ourRate,
          'ExtraBed': e.extraBed,
        },
      );
    }
    return byKey.values.toList();
  }

  /// A room type's `OurRate` as it reads on the room type dropdowns, e.g.
  /// "100.00" — shown while the room type is being picked, so the rate is in
  /// front of the user at the moment of choosing rather than only after the
  /// cost calculator is opened.
  ///
  /// Empty when the row carries no rate at all; a rate the API returns as zero
  /// still shows as "0.00", which is the back office saying it has none set.
  static String ourRateLabelOf(Map<String, dynamic>? roomType) {
    final value = roomType?['OurRate'];
    if (value == null) return '';
    return _toDouble(value).toStringAsFixed(2);
  }

  /// Grading of a category, used to label a category picked before the catalog
  /// row it came from is known (e.g. when an existing hotel row is edited).
  static String hotelCategoryOf(
    List<HotelRoomCatalogEntry> entries,
    double? hotelId,
    int? categoryId,
  ) {
    if (hotelId == null || categoryId == null) return '';
    for (final e in entries) {
      if (e.hotelId == hotelId && e.roomCategoryId == categoryId) {
        return e.hotelCategory;
      }
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      'Hotel_IID': hotelId,
      'HotelName': hotelName,
      'HotelLocation': hotelLocation,
      'Address': hotelAddress,
      'Phone': hotelPhone,
      'CatCode': roomCategoryId,
      'CatName': roomCategoryName,
      'HotelCategory': hotelCategory,
      'MealPlan': mealPlan,
      'ID': roomTypeId,
      'RoomType': roomTypeName,
      'RoomRate': roomRate,
      'Tax': tax,
      'NetRate': netRate,
      'Comm': comm,
      'OurRate': ourRate,
      'ExtraBed': extraBed,
    };
  }
}
