import 'package:ballys_reservation_app/models/reservation/hotel_location.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_response.dart';

/// One hotel → room category → room type → meal plan combination, as
/// `Hotels/GetByLocationFlat?Location=…` returns it.
///
/// The Ballys reservation forms used to chain three calls (hotels 9015,
/// categories 9016, room types 9017), then a single combined one (90155), then
/// the nested `HotelsGetByLocation`. The flat endpoint already returns one row
/// per hotel/category/room/meal plan — the shape this class holds — so rows map
/// across one for one and the dropdowns keep deriving themselves in memory from
/// the single list.
class HotelRoomCatalogEntry {
  final double hotelId;
  final String hotelName;

  /// `CityHotel` or `OutsideColombo` — which call the row came back from.
  final String hotelLocation;
  final int roomCategoryId;
  final String roomCategoryName;

  /// Grading of the room category, e.g. "(Standard)" / "(Executive Room)".
  ///
  /// The flat endpoint carries no grading, so this stays empty and the suffix
  /// simply drops off the category labels. Kept so the forms that show it need
  /// no change if the API starts returning one.
  final String hotelCategory;

  final String mealPlan;

  /// The room row's own id.
  ///
  /// `GetByLocationFlat` does not return one, so this is 0 on everything read
  /// off the API and rooms are identified by [roomTypeKey] instead. It stays on
  /// the model because a saved reservation still carries the id it was booked
  /// with, and re-opening that row must not lose it.
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
  bool get hasRoomType => roomTypeName.isNotEmpty;

  /// What identifies a room row now that the API sends no id: its name and
  /// meal plan, which is also exactly what a saved reservation stores in
  /// `room_type_name` ("SINGLE - BED & BREAKFAST"). Matching on this keeps a
  /// booked room recognisable across the change of endpoint, where matching on
  /// an id the API no longer sends would not.
  String get roomTypeKey => roomTypeKeyFrom(roomTypeName, mealPlan);

  /// Which of the two lists this hotel belongs to, or null when [hotelLocation]
  /// names neither.
  HotelLocation? get location => HotelLocation.fromApiValue(hotelLocation);

  // ── Parsing ───────────────────────────────────────────────────────────────

  /// Turns one `Hotels/GetByLocationFlat` response into catalog rows.
  ///
  /// Shape: `{ success, location, count, data: [ { HCode, HotelName, CatCode,
  /// CatName, RoomType, MealPlan, RoomRate, Tax, NetRate, Comm, OurRate,
  /// ExtraBed, Active, HotelLocation } ] }`.
  static List<HotelRoomCatalogEntry> fromFlatLocationResponse(
    Map<String, dynamic> json,
  ) {
    final rows = json['data'];
    if (rows is! List) return const [];

    // Each row carries its own HotelLocation; the response's is the fallback
    // for the rare row that comes back without one.
    final responseLocation = _text(json['location']);
    final entries = <HotelRoomCatalogEntry>[];

    for (final row in rows.whereType<Map>()) {
      // Retired rates stay out of the dropdowns entirely: the back office marks
      // a room / meal plan combination inactive when it must not be booked, and
      // a hotel whose every row is inactive drops out with them.
      if (!_isActive(row['Active'])) continue;

      final rowLocation = _text(row['HotelLocation']);

      entries.add(HotelRoomCatalogEntry(
        hotelId: _toDouble(row['HCode']),
        hotelName: _text(row['HotelName']),
        hotelLocation: rowLocation.isEmpty ? responseLocation : rowLocation,
        roomCategoryId: _toInt(row['CatCode']),
        roomCategoryName: _text(row['CatName']),
        mealPlan: _text(row['MealPlan']),
        // Read anyway, so the id comes back through on its own if the endpoint
        // starts sending one; 0 until then.
        roomTypeId: _toInt(row['ID']),
        roomTypeName: _text(row['RoomType']),
        roomRate: _toDouble(row['RoomRate']),
        tax: _toDouble(row['Tax']),
        netRate: _toDouble(row['NetRate']),
        comm: _toDouble(row['Comm']),
        ourRate: _toDouble(row['OurRate']),
        extraBed: _toDouble(row['ExtraBed']),
      ));
    }

    return entries;
  }

  /// True unless the row is explicitly retired. `Active` reads "Active" /
  /// "Inactive"; earlier shapes of this column sent "T"/"F" or a bool. A row
  /// carrying no flag at all counts as active, so an unset column cannot empty
  /// a dropdown.
  static bool _isActive(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    final text = value.toString().trim().toUpperCase();
    if (text.isEmpty) return true;
    return text == 'ACTIVE' ||
        text == 'T' ||
        text == 'TRUE' ||
        text == 'Y' ||
        text == '1';
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

  // ── Room type identity ────────────────────────────────────────────────────

  /// [roomTypeKey] built from a name and meal plan held apart from a row.
  static String roomTypeKeyFrom(String? roomType, String? mealPlan) =>
      '${roomType?.trim().toUpperCase() ?? ''}|'
      '${mealPlan?.trim().toUpperCase() ?? ''}';

  /// [roomTypeKey] of one of the room type maps below — or of a map a form
  /// rebuilt from a saved reservation, which carries the same two fields.
  static String roomTypeKeyOf(Map<String, dynamic>? roomType) =>
      roomTypeKeyFrom(
        roomType?['RoomType'] as String?,
        roomType?['MealPlan'] as String?,
      );

  /// Whether two room type maps name the same room — what the dropdowns
  /// compare on, in place of the id the API no longer sends.
  static bool sameRoomType(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) =>
      roomTypeKeyOf(a) == roomTypeKeyOf(b);

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
    // Keyed on name + meal plan, not on the id: the flat endpoint sends none,
    // so keying on it would collapse every room type of a category into one.
    final byKey = <String, Map<String, dynamic>>{};
    for (final e in entries.where(
      (e) => e.hotelId == hotelId && e.roomCategoryId == categoryId && e.hasRoomType,
    )) {
      byKey.putIfAbsent(
        e.roomTypeKey,
        () => {
          'ID': e.roomTypeId,
          'RoomType': e.roomTypeName,
          'MealPlan': e.mealPlan,
          // Rates ride along: the location endpoint returns them with the room,
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
      'HCode': hotelId,
      'HotelName': hotelName,
      'HotelLocation': hotelLocation,
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
