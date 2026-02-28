import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/marketing_group.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GuestsNotifier extends StateNotifier<GuestsState> {
  final GuestRepository guestRepository;
  AppMode? _currentMode;

  GuestsNotifier(this.guestRepository) : super(GuestsState());

  Future<void> getGuestData(int iid, String text1, AppMode mode) async {
    try {
      _currentMode = mode;

      final result = await guestRepository.getGuestData2(iid, text1);
      var guestList = result.guests;
      var marketingGroups = result.marketingGroups;

      if (_currentMode != mode) return;

      String? mCode = await StorageUtil.getMarketingCode();

      if (mode == AppMode.myData && mCode != null) {
        // 🔹 Filter guests to only this marketing person's guests
        guestList = guestList.where((g) => g.mGroup == mCode).toList();

        // 🔹 Count how many are THIS person's (my personal count)
        final myCount = guestList.where((g) => g.mid.isNotEmpty).length;

        // 🔹 Check if mCode exists in Table2
        final matchIndex =
            marketingGroups.indexWhere((g) => g.gCode == mCode);

        if (matchIndex != -1) {
          // ✅ Keep ALL groups from Table2, but subtract myCount from the
          //    matched group's rc so the chart shows the remaining value
          //    (i.e. Table2 total minus this person's own contribution)
          marketingGroups = marketingGroups.map((g) {
            if (g.gCode == mCode) {
              final reduced = (g.rc - myCount).clamp(0, g.rc);
              return MarketingGroup(
                gCode: g.gCode,
                gName: g.gName,
                rc: reduced,
              );
            }
            // All other groups stay exactly as Table2 returned them
            return g;
          }).toList();
        } else {
          // 🔹 Fallback: mCode not in Table2 at all — show all groups as-is
          //    plus a synthetic entry for this person so chart has data
          marketingGroups = [
            ...marketingGroups,
            MarketingGroup(
              gCode: mCode,
              gName: 'My Data',
              rc: myCount,
            ),
          ];
        }
      }
      // overallData → use Table2 as-is, no changes

      switch (iid) {
        case 9009:
          state = state.copyWith(
            todayGuests: guestList,
            todayMarketingGroups: marketingGroups,
          );
          break;
        case 9010:
          state = state.copyWith(
            yesterdayGuests: guestList,
            yesterdayMarketingGroups: marketingGroups,
          );
          break;
        case 9011:
          state = state.copyWith(
            monthlyGuests: guestList,
            monthlyMarketingGroups: marketingGroups,
          );
          break;
      }
    } catch (e) {
      // 🔹 On error set empty lists — chart will show "No data available"
      switch (iid) {
        case 9009:
          state = state.copyWith(
            todayGuests: [],
            todayMarketingGroups: [_emptyGroup],
          );
          break;
        case 9010:
          state = state.copyWith(
            yesterdayGuests: [],
            yesterdayMarketingGroups: [_emptyGroup],
          );
          break;
        case 9011:
          state = state.copyWith(
            monthlyGuests: [],
            monthlyMarketingGroups: [_emptyGroup],
          );
          break;
      }
    }
  }

  void resetData() {
    state = GuestsState();
    _currentMode = null;
  }

  void setCurrentMode(AppMode mode) {
    _currentMode = mode;
  }
}

// 🔹 Sentinel value used on error so chart exits loading state
final _emptyGroup = MarketingGroup(gCode: '', gName: 'No Data', rc: 0);

// ── Providers ──────────────────────────────────────────────────────────────

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

final guestsProvider =
    StateNotifierProvider<GuestsNotifier, GuestsState>((ref) {
  return GuestsNotifier(ref.read(guestRepositoryProvider));
});

// ── State ──────────────────────────────────────────────────────────────────

class GuestsState {
  final List<Guest> todayGuests;
  final List<Guest> yesterdayGuests;
  final List<Guest> monthlyGuests;

  final List<MarketingGroup> todayMarketingGroups;
  final List<MarketingGroup> yesterdayMarketingGroups;
  final List<MarketingGroup> monthlyMarketingGroups;

  GuestsState({
    this.todayGuests = const [],
    this.yesterdayGuests = const [],
    this.monthlyGuests = const [],
    this.todayMarketingGroups = const [],
    this.yesterdayMarketingGroups = const [],
    this.monthlyMarketingGroups = const [],
  });

  GuestsState copyWith({
    List<Guest>? todayGuests,
    List<Guest>? yesterdayGuests,
    List<Guest>? monthlyGuests,
    List<MarketingGroup>? todayMarketingGroups,
    List<MarketingGroup>? yesterdayMarketingGroups,
    List<MarketingGroup>? monthlyMarketingGroups,
  }) {
    return GuestsState(
      todayGuests: todayGuests ?? this.todayGuests,
      yesterdayGuests: yesterdayGuests ?? this.yesterdayGuests,
      monthlyGuests: monthlyGuests ?? this.monthlyGuests,
      todayMarketingGroups: todayMarketingGroups ?? this.todayMarketingGroups,
      yesterdayMarketingGroups:
          yesterdayMarketingGroups ?? this.yesterdayMarketingGroups,
      monthlyMarketingGroups:
          monthlyMarketingGroups ?? this.monthlyMarketingGroups,
    );
  }

  bool get isAllDataLoaded =>
      todayGuests.isNotEmpty ||
      yesterdayGuests.isNotEmpty ||
      monthlyGuests.isNotEmpty;

  Map<String, int> get counts => {
        'today': todayGuests.where((g) => g.mid.isNotEmpty).length,
        'yesterday': yesterdayGuests.where((g) => g.mid.isNotEmpty).length,
        'monthly': monthlyGuests.where((g) => g.mid.isNotEmpty).length,
      };
}