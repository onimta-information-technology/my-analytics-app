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

  // ── Raw cache (unfiltered API results) ──────────────────────────────────
  final Map<int, List<Guest>> _rawGuests = {};
  final Map<int, List<MarketingGroup>> _rawGroups = {};

  GuestsNotifier(this.guestRepository) : super(GuestsState());

  Future<void> getGuestData(int iid, String text1, AppMode mode) async {
    try {
      _currentMode = mode;

      final result = await guestRepository.getGuestData2(iid, text1);

      if (_currentMode != mode) return;

      // Cache raw results before any filtering
      _rawGuests[iid] = result.guests;
      _rawGroups[iid] = result.marketingGroups;

      await _applyFilterAndUpdateState(iid, mode);
    } catch (e) {
      // On error set empty lists — chart will show "No data available"
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

  /// Called when the user switches modes in Settings.
  /// Re-filters all cached data without a new network call.
  Future<void> updateMode(AppMode mode) async {
    _currentMode = mode;
    for (final iid in _rawGuests.keys) {
      await _applyFilterAndUpdateState(iid, mode);
    }
  }

  Future<void> _applyFilterAndUpdateState(int iid, AppMode mode) async {
    var guestList = List<Guest>.from(_rawGuests[iid] ?? []);
    var marketingGroups = List<MarketingGroup>.from(_rawGroups[iid] ?? []);

    if (mode == AppMode.myData) {
      final mCode = await StorageUtil.getMarketingCode();

      if (mCode != null) {
        // Filter guests to only this marketing person's guests
        guestList = guestList.where((g) => g.mGroup == mCode).toList();

        // Count how many are THIS person's confirmed visits
        final myCount = guestList.where((g) => g.mid.isNotEmpty).length;

        // Check if mCode exists directly in Table2
        final matchIndex =
            marketingGroups.indexWhere((g) => g.gCode == mCode);

        if (matchIndex != -1) {
          // mCode found in Table2 — subtract myCount from the matched group
          // so the chart shows the remaining value (Table2 total minus this
          // person's own contribution)
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
          // mCode NOT in Table2 — this user's visits are already counted
          // inside the largest Table2 group (e.g. MARKETING).
          // Find that parent group and subtract myCount to avoid double-counting.
          int parentIdx = 0;
          for (int i = 1; i < marketingGroups.length; i++) {
            if (marketingGroups[i].rc > marketingGroups[parentIdx].rc) {
              parentIdx = i;
            }
          }

          final updated = List<MarketingGroup>.from(marketingGroups);
          final parent = updated[parentIdx];
          updated[parentIdx] = MarketingGroup(
            gCode: parent.gCode,
            gName: parent.gName,
            rc: (parent.rc - myCount).clamp(0, parent.rc),
          );

          // Add My Data as a separate slice
          marketingGroups = [
            ...updated,
            MarketingGroup(
              gCode: mCode,
              gName: 'My Data',
              rc: myCount,
            ),
          ];
        }
      }
    }
    // overallData → use raw Table2 as-is, no changes

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
  }

  void resetData() {
    state = GuestsState();
    _currentMode = null;
    _rawGuests.clear();
    _rawGroups.clear();
  }

  void setCurrentMode(AppMode mode) {
    _currentMode = mode;
  }
}

// Sentinel value used on error so chart exits loading state
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