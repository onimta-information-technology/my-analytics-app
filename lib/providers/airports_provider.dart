import 'package:ballys_reservation_app/data/repositories/airport_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/airport_search_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AirportsNotifier extends StateNotifier<List<Airport>> {
  final AirportRepository airportRepository;

  AirportsNotifier(this.airportRepository) : super([]);

  List<Airport> allAirports = [];
  List<Airport> visibleAirports = [];

  Future<void> getAllAirports() async {
    try {
      final airports = await airportRepository.getAllAirports();
      allAirports = airports;
      _selectRandomAirports();
    } catch (e) {
    
      allAirports = [];
      visibleAirports = [];
    }
  }

  void _selectRandomAirports() {
    if (allAirports.isNotEmpty) {
      allAirports.shuffle();
      visibleAirports = allAirports.take(50).toList();
      state = visibleAirports;
    }
  }

  /// Looks up a loaded airport by its IATA code, e.g. "CMB".
  Airport? findByCode(String code) {
    final target = code.trim().toLowerCase();
    for (final airport in allAirports) {
      if ((airport.airportCode ?? '').trim().toLowerCase() == target) {
        return airport;
      }
    }
    return null;
  }

  void filterAirports(String query) {
    if (query.isEmpty) {
      state = visibleAirports;
    } else {
      final q = query.toLowerCase();
      bool matches(String? value) =>
          value != null && value.toLowerCase().contains(q);

      final results = allAirports
          .where((airport) =>
              matches(airport.airportCode) ||
              matches(airport.cityName) ||
              matches(airport.airportName) ||
              matches(airport.country) ||
              matches(airport.countryAbbr))
          .toList();

      // Alphabetical order by airport name.
      results.sort((a, b) => (a.airportName ?? '')
          .toLowerCase()
          .compareTo((b.airportName ?? '').toLowerCase()));

      state = results;
    }
  }
}

final flutterSecureStorageProvider =
    Provider((ref) => const FlutterSecureStorage());

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final airportsRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AirportRepository(apiService);
});

final airportsProvider =
    StateNotifierProvider<AirportsNotifier, List<Airport>>((ref) {
  final airportRepository = ref.read(airportsRepositoryProvider);
  return AirportsNotifier(airportRepository);
});
