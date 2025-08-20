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
      print("Error fetching airports: $e");
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

  void filterAirports(String query) {
    if (query.isEmpty) {
      state = visibleAirports;
    } else {
      state = allAirports
          .where((airport) =>
              airport.airportName!
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              airport.country!.toLowerCase().contains(query.toLowerCase()) ||
              airport.airportCode!.toLowerCase().contains(query.toLowerCase()))
          .toList();
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
