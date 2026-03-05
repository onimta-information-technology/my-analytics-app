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
  final Map<int, List<Guest>> _rawNonMarketingGuests = {}; // 🆕 Table3

  GuestsNotifier(this.guestRepository) : super(GuestsState());

  Future<void> getGuestData(int iid, String text1, AppMode mode) async {
    try {
      _currentMode = mode;

      final result = await guestRepository.getGuestData2(iid, text1);

      if (_currentMode != mode) return;

      // Cache raw results before any filtering
      _rawGuests[iid] = result.guests;
      _rawGroups[iid] = result.marketingGroups;
      _rawNonMarketingGuests[iid] = result.nonMarketingGuests; // 🆕

      await _applyFilterAndUpdateState(iid, mode);
    } catch (e) {
      switch (iid) {
        case 9009:
          state = state.copyWith(
            todayGuests: [],
            todayMarketingGroups: [_emptyGroup],
            todayAllMarketingGuests: [],      // 🆕
            todayNonMarketingGuests: [],      // 🆕
          );
          break;
        case 9010:
          state = state.copyWith(
            yesterdayGuests: [],
            yesterdayMarketingGroups: [_emptyGroup],
            yesterdayAllMarketingGuests: [],  // 🆕
            yesterdayNonMarketingGuests: [],  // 🆕
          );
          break;
        case 9011:
          state = state.copyWith(
            monthlyGuests: [],
            monthlyMarketingGroups: [_emptyGroup],
            monthlyAllMarketingGuests: [],    // 🆕
            monthlyNonMarketingGuests: [],    // 🆕
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
    final allMarketingGuests = List<Guest>.from(_rawGuests[iid] ?? []); // 🆕 always raw
    final nonMarketingGuests = List<Guest>.from(_rawNonMarketingGuests[iid] ?? []); // 🆕

    if (mode == AppMode.myData) {
      final mCode = await StorageUtil.getMarketingCode();

      if (mCode != null) {
        guestList = guestList.where((g) => g.mGroup == mCode).toList();
        final myCount = guestList.where((g) => g.mid.isNotEmpty).length;

        final matchIndex =
            marketingGroups.indexWhere((g) => g.gCode == mCode);

        if (matchIndex != -1) {
          marketingGroups = marketingGroups.map((g) {
            if (g.gCode == mCode) {
              final reduced = (g.rc - myCount).clamp(0, g.rc);
              return MarketingGroup(
                gCode: g.gCode,
                gName: g.gName,
                rc: reduced,
              );
            }
            return g;
          }).toList();
        } else {
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

    switch (iid) {
      case 9009:
        state = state.copyWith(
          todayGuests: guestList,
          todayMarketingGroups: marketingGroups,
          todayAllMarketingGuests: allMarketingGuests,       // 🆕
          todayNonMarketingGuests: nonMarketingGuests,       // 🆕
        );
        break;
      case 9010:
        state = state.copyWith(
          yesterdayGuests: guestList,
          yesterdayMarketingGroups: marketingGroups,
          yesterdayAllMarketingGuests: allMarketingGuests,   // 🆕
          yesterdayNonMarketingGuests: nonMarketingGuests,   // 🆕
        );
        break;
      case 9011:
        state = state.copyWith(
          monthlyGuests: guestList,
          monthlyMarketingGroups: marketingGroups,
          monthlyAllMarketingGuests: allMarketingGuests,     // 🆕
          monthlyNonMarketingGuests: nonMarketingGuests,     // 🆕
        );
        break;
    }
  }

  void resetData() {
    state = GuestsState();
    _currentMode = null;
    _rawGuests.clear();
    _rawGroups.clear();
    _rawNonMarketingGuests.clear(); // 🆕
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

  // 🆕 Raw (unfiltered) marketing guests from Table
  final List<Guest> todayAllMarketingGuests;
  final List<Guest> yesterdayAllMarketingGuests;
  final List<Guest> monthlyAllMarketingGuests;

  // 🆕 Non-marketing guests from Table3
  final List<Guest> todayNonMarketingGuests;
  final List<Guest> yesterdayNonMarketingGuests;
  final List<Guest> monthlyNonMarketingGuests;

  GuestsState({
    this.todayGuests = const [],
    this.yesterdayGuests = const [],
    this.monthlyGuests = const [],
    this.todayMarketingGroups = const [],
    this.yesterdayMarketingGroups = const [],
    this.monthlyMarketingGroups = const [],
    this.todayAllMarketingGuests = const [],       // 🆕
    this.yesterdayAllMarketingGuests = const [],   // 🆕
    this.monthlyAllMarketingGuests = const [],     // 🆕
    this.todayNonMarketingGuests = const [],       // 🆕
    this.yesterdayNonMarketingGuests = const [],   // 🆕
    this.monthlyNonMarketingGuests = const [],     // 🆕
  });

  GuestsState copyWith({
    List<Guest>? todayGuests,
    List<Guest>? yesterdayGuests,
    List<Guest>? monthlyGuests,
    List<MarketingGroup>? todayMarketingGroups,
    List<MarketingGroup>? yesterdayMarketingGroups,
    List<MarketingGroup>? monthlyMarketingGroups,
    List<Guest>? todayAllMarketingGuests,       // 🆕
    List<Guest>? yesterdayAllMarketingGuests,   // 🆕
    List<Guest>? monthlyAllMarketingGuests,     // 🆕
    List<Guest>? todayNonMarketingGuests,       // 🆕
    List<Guest>? yesterdayNonMarketingGuests,   // 🆕
    List<Guest>? monthlyNonMarketingGuests,     // 🆕
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
      todayAllMarketingGuests:
          todayAllMarketingGuests ?? this.todayAllMarketingGuests,
      yesterdayAllMarketingGuests:
          yesterdayAllMarketingGuests ?? this.yesterdayAllMarketingGuests,
      monthlyAllMarketingGuests:
          monthlyAllMarketingGuests ?? this.monthlyAllMarketingGuests,
      todayNonMarketingGuests:
          todayNonMarketingGuests ?? this.todayNonMarketingGuests,
      yesterdayNonMarketingGuests:
          yesterdayNonMarketingGuests ?? this.yesterdayNonMarketingGuests,
      monthlyNonMarketingGuests:
          monthlyNonMarketingGuests ?? this.monthlyNonMarketingGuests,
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