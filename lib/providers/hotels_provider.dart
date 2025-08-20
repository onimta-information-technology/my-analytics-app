import 'package:ballys_reservation_app/data/repositories/hotel_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HotelsNotifier extends StateNotifier<List<HotelResponse>> {
  final HotelRepository hotelRepository;

  HotelsNotifier(this.hotelRepository) : super([]);

  Future<void> getAllHotels() async {
    try {
      final hotels = await hotelRepository.getAllHotels();
      state = hotels;
    } catch (e) {
      print("Error fetching hotels: $e");
      state = [];
    }
  }

  List<Map<String, dynamic>> get hotelsAsMap => state.map((hotel) {
        return {
          'Hotel_IID': hotel.hotelId,
          'HotelName': hotel.hotelName,
        };
      }).toList();
}

final flutterSecureStorageProvider =
    Provider((ref) => const FlutterSecureStorage());

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final hotelsRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return HotelRepository(apiService);
});

final hotelsProvider =
    StateNotifierProvider<HotelsNotifier, List<HotelResponse>>((ref) {
  final hotelRepository = ref.read(hotelsRepositoryProvider);
  return HotelsNotifier(hotelRepository);
});
