import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/marketing_group.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

class GuestsNotifier extends StateNotifier<GuestsState> {
  final GuestRepository guestRepository;
  AppMode? _currentMode;

  // ── Raw cache (unfiltered API results) ──────────────────────────────────
  final Map<int, List<Guest>> _rawGuests = {};
  final Map<int, List<MarketingGroup>> _rawGroups = {};
  final Map<int, List<Guest>> _rawNonMarketingGuests = {};
  final Map<int, List<Guest>> _rawOtherMarketingGuests = {};
  final Map<int, List<MarketingGroup>> _rawSalesPersonGroups = {};
  final Map<int, ResponseLayout> _rawLayouts = {};

  GuestsNotifier(this.guestRepository) : super(GuestsState());

  Future<void> getGuestData(int iid, String text1, AppMode mode) async {
    try {
      _currentMode = mode;

      final result = await guestRepository.getGuestData2(iid, text1);

      if (_currentMode != mode) return;

      // Cache raw results before any filtering
      _rawGuests[iid] = result.guests;
      _rawGroups[iid] = result.marketingGroups;
      _rawNonMarketingGuests[iid] = result.nonMarketingGuests;
      _rawOtherMarketingGuests[iid] = result.otherMarketingGuests;
      _rawSalesPersonGroups[iid] = result.salesPersonGroups;
      _rawLayouts[iid] = result.layout;

      await _applyFilterAndUpdateState(iid, mode);
    } catch (e) {
      print('getGuestData error iid=$iid: $e');
      switch (iid) {
        case 9009:
          state = state.copyWith(
            todayGuests: [],
            todayMarketingGroups: [_emptyGroup],
            todayAllMarketingGuests: [],
            todayNonMarketingGuests: [],
            todayOtherMarketingGuests: [],
            todaySalesPersonGroups: [],
          );
          break;
        case 9010:
          state = state.copyWith(
            yesterdayGuests: [],
            yesterdayMarketingGroups: [_emptyGroup],
            yesterdayAllMarketingGuests: [],
            yesterdayNonMarketingGuests: [],
            yesterdayOtherMarketingGuests: [],
            yesterdaySalesPersonGroups: [],
          );
          break;
        case 9011:
          state = state.copyWith(
            monthlyGuests: [],
            monthlyMarketingGroups: [_emptyGroup],
            monthlyAllMarketingGuests: [],
            monthlyNonMarketingGuests: [],
            monthlyOtherMarketingGuests: [],
            monthlySalesPersonGroups: [],
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
    final allMarketingGuests = List<Guest>.from(_rawGuests[iid] ?? []);
    final nonMarketingGuests = List<Guest>.from(_rawNonMarketingGuests[iid] ?? []);
    final otherMarketingGuests = List<Guest>.from(_rawOtherMarketingGuests[iid] ?? []);
    final salesPersonGroups = List<MarketingGroup>.from(_rawSalesPersonGroups[iid] ?? []);
    final layout = _rawLayouts[iid] ?? ResponseLayout.regularMyDataOnly;

    // ── myData mode filtering ─────────────────────────────────────────────
    //
    // Regular users (regularWithOther / regularMyDataOnly):
    //   Server already sends only their data in Table — no filtering needed.
    //
    // AD001 (admin layout), myData mode:
    //   Server sends ALL marketing guests in Table.
    //   Filter by mGroup == mCode to get only AD001's own guests,
    //   then replace the pie with a single "My Data" slice.
    //
    // AD001, overallData mode:
    //   No filtering — show everything as-is.

    if (mode == AppMode.myData && layout == ResponseLayout.admin) {
      final mCode = await StorageUtil.getMarketingCode();

      if (mCode != null && mCode.isNotEmpty) {
        // Filter guestList to AD001's own guests only.
        // This is what todayGuests/yesterdayGuests/monthlyGuests stores —
        // used by count boxes and home screen tap navigation.
        // allMarketingGuests stays unfiltered so the pie MKT tap can filter per person.
        guestList = guestList.where((g) => g.mGroup == mCode).toList();
        final myCount = guestList.length;

        // Split MKT into: "My Data" (myCount) + "MARKETING" (remainder).
        // NON MARKETING passes through unchanged.
        final mktGroup = marketingGroups.firstWhere(
          (g) => g.gCode == 'MKT',
          orElse: () => MarketingGroup(gCode: 'MKT', gName: 'MARKETING', rc: 0),
        );
        final remainingMkt = (mktGroup.rc - myCount).clamp(0, mktGroup.rc);

        marketingGroups = [
          MarketingGroup(gCode: mCode, gName: 'My Data', rc: myCount),
          if (remainingMkt > 0)
            MarketingGroup(gCode: 'MKT', gName: 'MARKETING', rc: remainingMkt),
          ...marketingGroups.where((g) => g.gCode == 'NON'),
        ];
      }
      // If no mCode stored, fall back to overallData behaviour (show as-is)
    }

    switch (iid) {
      case 9009:
        state = state.copyWith(
          todayGuests: guestList,
          todayMarketingGroups: marketingGroups,
          todayAllMarketingGuests: allMarketingGuests,
          todayNonMarketingGuests: nonMarketingGuests,
          todayOtherMarketingGuests: otherMarketingGuests,
          todaySalesPersonGroups: salesPersonGroups,
          todayLayout: layout,
        );
        break;
      case 9010:
        state = state.copyWith(
          yesterdayGuests: guestList,
          yesterdayMarketingGroups: marketingGroups,
          yesterdayAllMarketingGuests: allMarketingGuests,
          yesterdayNonMarketingGuests: nonMarketingGuests,
          yesterdayOtherMarketingGuests: otherMarketingGuests,
          yesterdaySalesPersonGroups: salesPersonGroups,
          yesterdayLayout: layout,
        );
        break;
      case 9011:
        state = state.copyWith(
          monthlyGuests: guestList,
          monthlyMarketingGroups: marketingGroups,
          monthlyAllMarketingGuests: allMarketingGuests,
          monthlyNonMarketingGuests: nonMarketingGuests,
          monthlyOtherMarketingGuests: otherMarketingGuests,
          monthlySalesPersonGroups: salesPersonGroups,
          monthlyLayout: layout,
        );
        break;
    }
  }

  void resetData() {
    state = GuestsState();
    _currentMode = null;
    _rawGuests.clear();
    _rawGroups.clear();
    _rawNonMarketingGuests.clear();
    _rawOtherMarketingGuests.clear();
    _rawSalesPersonGroups.clear();
    _rawLayouts.clear();
  }

  void setCurrentMode(AppMode mode) {
    _currentMode = mode;
  }
}

// Sentinel value used on error so chart exits loading state
final _emptyGroup = MarketingGroup(gCode: '', gName: 'No Data', rc: 0);

// ── Providers ──────────────────────────────────────────────────────────────

final flutterSecureStorageProvider = Provider(
  (ref) => SecureStorage.instance,
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

  // Raw (unfiltered) marketing guests from Table
  final List<Guest> todayAllMarketingGuests;
  final List<Guest> yesterdayAllMarketingGuests;
  final List<Guest> monthlyAllMarketingGuests;

  // Non-marketing guests from Table3
  final List<Guest> todayNonMarketingGuests;
  final List<Guest> yesterdayNonMarketingGuests;
  final List<Guest> monthlyNonMarketingGuests;

  // Other marketing guests from Table4 (regular user layout only)
  final List<Guest> todayOtherMarketingGuests;
  final List<Guest> yesterdayOtherMarketingGuests;
  final List<Guest> monthlyOtherMarketingGuests;

  // Sales person summaries from Table1 (admin layout only)
  final List<MarketingGroup> todaySalesPersonGroups;
  final List<MarketingGroup> yesterdaySalesPersonGroups;
  final List<MarketingGroup> monthlySalesPersonGroups;

  // Which response layout was returned by the server
  final ResponseLayout todayLayout;
  final ResponseLayout yesterdayLayout;
  final ResponseLayout monthlyLayout;

  GuestsState({
    this.todayGuests = const [],
    this.yesterdayGuests = const [],
    this.monthlyGuests = const [],
    this.todayMarketingGroups = const [],
    this.yesterdayMarketingGroups = const [],
    this.monthlyMarketingGroups = const [],
    this.todayAllMarketingGuests = const [],
    this.yesterdayAllMarketingGuests = const [],
    this.monthlyAllMarketingGuests = const [],
    this.todayNonMarketingGuests = const [],
    this.yesterdayNonMarketingGuests = const [],
    this.monthlyNonMarketingGuests = const [],
    this.todayOtherMarketingGuests = const [],
    this.yesterdayOtherMarketingGuests = const [],
    this.monthlyOtherMarketingGuests = const [],
    this.todaySalesPersonGroups = const [],
    this.yesterdaySalesPersonGroups = const [],
    this.monthlySalesPersonGroups = const [],
    this.todayLayout = ResponseLayout.regularMyDataOnly,
    this.yesterdayLayout = ResponseLayout.regularMyDataOnly,
    this.monthlyLayout = ResponseLayout.regularMyDataOnly,
  });

  GuestsState copyWith({
    List<Guest>? todayGuests,
    List<Guest>? yesterdayGuests,
    List<Guest>? monthlyGuests,
    List<MarketingGroup>? todayMarketingGroups,
    List<MarketingGroup>? yesterdayMarketingGroups,
    List<MarketingGroup>? monthlyMarketingGroups,
    List<Guest>? todayAllMarketingGuests,
    List<Guest>? yesterdayAllMarketingGuests,
    List<Guest>? monthlyAllMarketingGuests,
    List<Guest>? todayNonMarketingGuests,
    List<Guest>? yesterdayNonMarketingGuests,
    List<Guest>? monthlyNonMarketingGuests,
    List<Guest>? todayOtherMarketingGuests,
    List<Guest>? yesterdayOtherMarketingGuests,
    List<Guest>? monthlyOtherMarketingGuests,
    List<MarketingGroup>? todaySalesPersonGroups,
    List<MarketingGroup>? yesterdaySalesPersonGroups,
    List<MarketingGroup>? monthlySalesPersonGroups,
    ResponseLayout? todayLayout,
    ResponseLayout? yesterdayLayout,
    ResponseLayout? monthlyLayout,
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
      todayOtherMarketingGuests:
          todayOtherMarketingGuests ?? this.todayOtherMarketingGuests,
      yesterdayOtherMarketingGuests:
          yesterdayOtherMarketingGuests ?? this.yesterdayOtherMarketingGuests,
      monthlyOtherMarketingGuests:
          monthlyOtherMarketingGuests ?? this.monthlyOtherMarketingGuests,
      todaySalesPersonGroups:
          todaySalesPersonGroups ?? this.todaySalesPersonGroups,
      yesterdaySalesPersonGroups:
          yesterdaySalesPersonGroups ?? this.yesterdaySalesPersonGroups,
      monthlySalesPersonGroups:
          monthlySalesPersonGroups ?? this.monthlySalesPersonGroups,
      todayLayout: todayLayout ?? this.todayLayout,
      yesterdayLayout: yesterdayLayout ?? this.yesterdayLayout,
      monthlyLayout: monthlyLayout ?? this.monthlyLayout,
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