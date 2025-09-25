import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GuestsNotifier extends StateNotifier<GuestsState> {
  final GuestRepository guestRepository;

  // 🔹 Track current app mode to prevent stale updates
  AppMode? _currentMode;

  GuestsNotifier(this.guestRepository) : super(GuestsState());

  Future<void> getGuestData(int iid, String text1, AppMode mode) async {
    try {
      // 🔹 Store current mode for this operation
      _currentMode = mode;

      print('Loading data for iid: $iid, mode: $mode');

      var guestList = await guestRepository.getGuestData(iid, text1);

      // 🔹 Check if mode changed during API call
      if (_currentMode != mode) {
        print('Mode changed during API call, discarding results');
        return;
      }

      String? mCode = await StorageUtil.getMarketingCode();

      // 🔹 Apply filtering based on mode
      if (mode == AppMode.myData && mCode != null) {
        guestList = guestList.where((guest) => guest.mGroup == mCode).toList();
        print('Filtered ${guestList.length} guests for mCode: $mCode');
      } else {
        print('Using all ${guestList.length} guests (mode: $mode)');
      }

      // 🔹 Update state based on iid
      switch (iid) {
        case 9009: // Today
          state = state.copyWith(todayGuests: guestList);
          print('Updated today guests: ${guestList.length}');
          break;
        case 9010: // Yesterday
          state = state.copyWith(yesterdayGuests: guestList);
          print('Updated yesterday guests: ${guestList.length}');
          break;
        case 9011: // Monthly
          state = state.copyWith(monthlyGuests: guestList);
          print('Updated monthly guests: ${guestList.length}');
          break;
        default:
          print('Unknown iid: $iid');
      }
    } catch (e) {
      print('Error retrieving data for iid $iid: $e');

      // 🔹 Set empty list for specific period on error
      switch (iid) {
        case 9009:
          state = state.copyWith(todayGuests: []);
          break;
        case 9010:
          state = state.copyWith(yesterdayGuests: []);
          break;
        case 9011:
          state = state.copyWith(monthlyGuests: []);
          break;
      }
    }
  }

  void resetData() {
    print('Resetting guest data');
    state = GuestsState();
    _currentMode = null;
  }

  // 🔹 Method to update current mode tracking
  void setCurrentMode(AppMode mode) {
    _currentMode = mode;
  }
}

final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final guestRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return GuestRepository(apiService);
});

final guestsProvider = StateNotifierProvider<GuestsNotifier, GuestsState>((
  ref,
) {
  final guestRepository = ref.read(guestRepositoryProvider);
  return GuestsNotifier(guestRepository);
});

final appmodebutton = AppMode.myData;

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

  // 🔹 Helper method to check if all data is loaded
  bool get isAllDataLoaded {
    return todayGuests.isNotEmpty ||
        yesterdayGuests.isNotEmpty ||
        monthlyGuests.isNotEmpty;
  }

  // 🔹 Helper method to get counts
  Map<String, int> get counts {
    return {
      'today': todayGuests.where((g) => g.mid.isNotEmpty).length,
      'yesterday': yesterdayGuests.where((g) => g.mid.isNotEmpty).length,
      'monthly': monthlyGuests.where((g) => g.mid.isNotEmpty).length,
    };
  }
}
