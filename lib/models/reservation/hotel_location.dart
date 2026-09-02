/// The two lists `HotelsGetByLocation` is partitioned by.
///
/// The reservation forms ask which one before offering a hotel, so the hotel
/// dropdown only ever carries the hotels of the picked type.
enum HotelLocation {
  cityHotel('CityHotel', 'City Hotel'),
  outsideColombo('OutsideColombo', 'Outside Colombo');

  /// The `Location` query value the API is called with — and the value it
  /// returns on every hotel it sends back.
  final String apiValue;

  /// How the type reads on the form.
  final String label;

  const HotelLocation(this.apiValue, this.label);

  /// The type a hotel's `HotelLocation` names, or null when it names something
  /// neither call covers. Case and spacing are ignored: the value is
  /// hand-maintained, so "City Hotel" and "CityHotel" both arrive.
  static HotelLocation? fromApiValue(String? value) {
    final key = value?.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (key == null || key.isEmpty) return null;
    for (final location in HotelLocation.values) {
      if (location.apiValue.toLowerCase() == key) return location;
    }
    return null;
  }
}
