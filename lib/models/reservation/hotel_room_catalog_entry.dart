import 'package:ballys_reservation_app/models/reservation/hotel_response.dart';

/// One hotel → room category → room type combination as returned by the
/// combined catalog API (`@Iid` 90155).
///
/// The Ballys reservation forms used to chain three calls (hotels 9015,
/// categories 9016, room types 9017). This single row carries all of it —
/// hotel name, hotel category, room category, room type and meal plan — so the
/// dropdowns are derived in memory from one response.
class HotelRoomCatalogEntry {
  final double hotelId;
  final String hotelCode;
  final String hotelName;
  final int roomCategoryId;
  final String roomCategoryCode;

  /// Grading of the room category, e.g. "(Standard)" / "(Executive Room)".
  final String hotelCategory;
  final String roomCategoryName;
  final String mealPlan;
  final int roomTypeId;
  final String roomTypeCode;
  final String roomTypeName;

  HotelRoomCatalogEntry({
    required this.hotelId,
    required this.hotelCode,
    required this.hotelName,
    required this.roomCategoryId,
    required this.roomCategoryCode,
    required this.hotelCategory,
    required this.roomCategoryName,
    required this.mealPlan,
    required this.roomTypeId,
    required this.roomTypeCode,
    required this.roomTypeName,
  });

  factory HotelRoomCatalogEntry.fromJson(Map<String, dynamic> json) {
    return HotelRoomCatalogEntry(
      hotelId: _toDouble(json['HotelId']),
      hotelCode: _text(json['HotelCode']),
      hotelName: _text(json['HotelName']),
      roomCategoryId: _toInt(json['RoomCategoryId']),
      roomCategoryCode: _text(json['RoomCategoryCode']),
      hotelCategory: _text(json['HotelCategory']),
      roomCategoryName: _text(json['RoomCategoryName']),
      mealPlan: _text(json['MealPlan']),
      roomTypeId: _toInt(json['RoomTypeId']),
      roomTypeCode: _text(json['RoomTypeCode']),
      roomTypeName: _text(json['RoomTypeName']),
    );
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
  // Each keeps the order 90155 returned. The API decides how the lists read —
  // re-sorting them here would override an ordering the back office controls.
  // Deduping runs through a plain map, which keeps insertion order, so first
  // occurrence wins and the rest follow as they arrived.

  static List<HotelResponse> hotelsFrom(List<HotelRoomCatalogEntry> entries) {
    final byId = <double, HotelResponse>{};
    for (final e in entries) {
      byId.putIfAbsent(
        e.hotelId,
        () => HotelResponse(hotelId: e.hotelId, hotelName: e.hotelName),
      );
    }
    return byId.values.toList();
  }

  static List<Map<String, dynamic>> hotelsAsMapFrom(
    List<HotelRoomCatalogEntry> entries,
  ) =>
      hotelsFrom(entries)
          .map((h) => {'Hotel_IID': h.hotelId, 'HotelName': h.hotelName})
          .toList();

  static List<Map<String, dynamic>> categoriesFrom(
    List<HotelRoomCatalogEntry> entries,
    double hotelId,
  ) {
    final byId = <int, Map<String, dynamic>>{};
    for (final e in entries.where((e) => e.hotelId == hotelId)) {
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
      (e) => e.hotelId == hotelId && e.roomCategoryId == categoryId,
    )) {
      byKey.putIfAbsent(
        '${e.roomTypeId}|${e.mealPlan}',
        () => {
          'ID': e.roomTypeId,
          'RoomType': e.roomTypeName,
          'MealPlan': e.mealPlan,
        },
      );
    }
    return byKey.values.toList();
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
      'HotelId': hotelId,
      'HotelCode': hotelCode,
      'HotelName': hotelName,
      'RoomCategoryId': roomCategoryId,
      'RoomCategoryCode': roomCategoryCode,
      'HotelCategory': hotelCategory,
      'RoomCategoryName': roomCategoryName,
      'MealPlan': mealPlan,
      'RoomTypeId': roomTypeId,
      'RoomTypeCode': roomTypeCode,
      'RoomTypeName': roomTypeName,
    };
  }
}
