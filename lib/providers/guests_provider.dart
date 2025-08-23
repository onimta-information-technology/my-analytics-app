import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GuestsNotifier extends StateNotifier<GuestsState> {
  final GuestRepository guestRepository;

  GuestsNotifier(this.guestRepository) : super(GuestsState());

  Future<void> getGuestData(int iid, String text1) async {
    try {
      final guestList = await guestRepository.getGuestData(iid, text1);
      switch (iid) {
        case 9009:
          state = state.copyWith(todayGuests: guestList);
        case 9010:
          state = state.copyWith(yesterdayGuests: guestList);
        case 9011:
          state = state.copyWith(monthlyGuests: guestList);
          break;
        default:
      }
    } catch (e) {
      print('Data retrivng: $e');
      state = state.copyWith(todayGuests: []);
    } finally {
           
    }
  }

  void resetData() {
    state = GuestsState();
  }
}

final flutterSecureStorageProvider =
    Provider((ref) => const FlutterSecureStorage());

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final guestRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return GuestRepository(apiService);
});

final guestsProvider =
    StateNotifierProvider<GuestsNotifier, GuestsState>((ref) {
  final guestRepository = ref.read(guestRepositoryProvider);
  return GuestsNotifier(guestRepository);
});

class GuestsState {
  final List<Guest> todayGuests;
  final List<Guest> yesterdayGuests;
  final List<Guest> monthlyGuests;


  GuestsState({
    this.todayGuests = const [],
    this.yesterdayGuests = const [],
    this.monthlyGuests = const [],
    
  });

  GuestsState copyWith({
    List<Guest>? todayGuests,
    List<Guest>? yesterdayGuests,
    List<Guest>? monthlyGuests,
    
  }) {
    return GuestsState(
      todayGuests: todayGuests ?? this.todayGuests,
      yesterdayGuests: yesterdayGuests ?? this.yesterdayGuests,
      monthlyGuests: monthlyGuests ?? this.monthlyGuests,
      
    );
  }
}
