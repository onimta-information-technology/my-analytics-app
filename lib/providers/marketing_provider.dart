import 'package:ballys_reservation_app/data/repositories/marketing_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum MarketingViewType {
  performance,
  result,
  target, // NEW — only valid when selectedTab == 2 or 3
}

class MarketingNotifier extends StateNotifier<MarketingState> {
  final MarketingRepository marketingRepository;
  final Ref ref;

  MarketingNotifier(this.marketingRepository, this.ref)
      : super(MarketingState());

  void clearMarketing() {
    state = MarketingState(
      todayPerformance: [],
      yesterdayPerformance: [],
      monthlyPerformance: [],
      lastmonthPerformance: [],
      todayDetailedData: [],
      yesterdayDetailedData: [],
      monthlyDetailedData: [],
      lastmonthDetailedData: [],
      detailedData: [],
      selectedTab: -1,
      isLoading: false,
    );
  }

  Future<void> getMarketingData(int iid, {AppMode? overrideAppMode}) async {
    state = state.copyWith(isLoading: true);

    try {
      final salesCode = await StorageUtil.getSalesCode();
      final currentAppModeSettings = ref.read(appmodeSettingsProvider);
      final appMode = overrideAppMode ?? currentAppModeSettings.appMode;

      final result = await marketingRepository.getMarketingData(
        iid,
        appMode,
        salesCode!,
      );

      switch (iid) {
        case 8896:
          state = state.copyWith(
            todayPerformance: result.performanceData,
            todayDetailedData: result.detailedData,
            todayResultData: result.resultData,
            isLoading: false,
          );
          break;
        case 8897:
          state = state.copyWith(
            yesterdayPerformance: result.performanceData,
            yesterdayDetailedData: result.detailedData,
            yesterdayResultData: result.resultData,
            isLoading: false,
          );
          break;
        case 8898:
          state = state.copyWith(
            monthlyPerformance: result.performanceData,
            monthlyDetailedData: result.detailedData,
            monthlyResultData: result.resultData,
            isLoading: false,
          );
          break;
        case 8899:
          state = state.copyWith(
            lastmonthPerformance: result.performanceData,
            lastmonthDetailedData: result.detailedData,
            lastmonthResultData: result.resultData,
            isLoading: false,
          );
          break;
      }
    } catch (e) {
      switch (iid) {
        case 8896:
          state = state.copyWith(
              todayPerformance: [],
              todayDetailedData: [],
              todayResultData: [],
              isLoading: false);
          break;
        case 8897:
          state = state.copyWith(
              yesterdayPerformance: [],
              yesterdayDetailedData: [],
              yesterdayResultData: [],
              isLoading: false);
          break;
        case 8898:
          state = state.copyWith(
              monthlyPerformance: [],
              monthlyDetailedData: [],
              monthlyResultData: [],
              isLoading: false);
          break;
        case 8899:
          state = state.copyWith(
              lastmonthPerformance: [],
              lastmonthDetailedData: [],
              lastmonthResultData: [],
              isLoading: false);
          break;
      }
    }
  }

  // NEW: Fetch target data for monthly (IID 778898) or last month (IID 558899)
  Future<void> getTargetData(int tabIndex, {AppMode? overrideAppMode}) async {
    state = state.copyWith(isLoading: true);

    try {
      final currentAppModeSettings = ref.read(appmodeSettingsProvider);
      final appMode = overrideAppMode ?? currentAppModeSettings.appMode;

      // Monthly = 778898, Last Month = 558899
      final iid = tabIndex == 2 ? 778898 : 558899;

      final result = await marketingRepository.getTargetData(iid, appMode);

      if (tabIndex == 2) {
        state = state.copyWith(
          monthlyTargetSummary: result.summaryRows,
          monthlyTargetDetail: result.detailRows,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          lastmonthTargetSummary: result.summaryRows,
          lastmonthTargetDetail: result.detailRows,
          isLoading: false,
        );
      }
    } catch (e) {
      if (tabIndex == 2) {
        state = state.copyWith(
            monthlyTargetSummary: [],
            monthlyTargetDetail: [],
            isLoading: false);
      } else {
        state = state.copyWith(
            lastmonthTargetSummary: [],
            lastmonthTargetDetail: [],
            isLoading: false);
      }
    }
  }

  Future<void> refreshCurrentTab({AppMode? overrideAppMode}) async {
    switch (state.selectedTab) {
      case 0:
        await getMarketingData(8896, overrideAppMode: overrideAppMode);
        break;
      case 1:
        await getMarketingData(8897, overrideAppMode: overrideAppMode);
        break;
      case 2:
        await getMarketingData(8898, overrideAppMode: overrideAppMode);
        break;
      case 3:
        await getMarketingData(8899, overrideAppMode: overrideAppMode);
        break;
      default:
        await getMarketingData(8896, overrideAppMode: overrideAppMode);
        break;
    }
  }

  Future<void> onAppModeChanged(AppMode newAppMode) async {
    if (state.selectedTab == -1) return;
    await refreshAllDataWithAppMode(newAppMode);
  }

  Future<void> refreshAllDataWithAppMode(AppMode appMode) async {
    state = state.copyWith(isLoading: true);
    try {
      await Future.wait([
        getMarketingData(8896, overrideAppMode: appMode),
        getMarketingData(8897, overrideAppMode: appMode),
        getMarketingData(8898, overrideAppMode: appMode),
        getMarketingData(8899, overrideAppMode: appMode),
      ]);
    } catch (e) {
      // ignore
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  List<MarketingDetailedData> getDetailedDataForSM(String smCode) {
    List<MarketingDetailedData> currentDetailedData;
    switch (state.selectedTab) {
      case 0:
        currentDetailedData = state.todayDetailedData;
        break;
      case 1:
        currentDetailedData = state.yesterdayDetailedData;
        break;
      case 2:
        currentDetailedData = state.monthlyDetailedData;
        break;
      case 3:
        currentDetailedData = state.lastmonthDetailedData;
        break;
      default:
        currentDetailedData = state.todayDetailedData;
        break;
    }
    return currentDetailedData.where((data) => data.sm == smCode).toList();
  }

  // NEW: Get target detail rows for a specific group code
  List<MarketingTargetDetail> getTargetDetailForGroup(String gcode) {
    final details = state.selectedTab == 2
        ? state.monthlyTargetDetail
        : state.lastmonthTargetDetail;
    return details.where((d) => d.gcode == gcode).toList();
  }

  Future<void> getTodayData() async => getMarketingData(8896);
  Future<void> getYesterdayData() async => getMarketingData(8897);
  Future<void> getMonthlyData() async => getMarketingData(8898);
  Future<void> getLastMonthData() async => getMarketingData(8899);

  Future<void> getTodayPerformance() async => getTodayData();
  Future<void> getYesterdayPerformance() async => getYesterdayData();
  Future<void> getMonthlyPerformance() async => getMonthlyData();
  Future<void> getLastMonthPerformance() async => getLastMonthData();

  Future<void> getMonthlyPerformanceOverall() async =>
      getMarketingData(8898, overrideAppMode: AppMode.overallData);

  Future<void> refreshAllData({AppMode? overrideAppMode}) async {
    if (overrideAppMode != null) {
      await refreshAllDataWithAppMode(overrideAppMode);
    } else {
      await Future.wait([
        getTodayData(),
        getYesterdayData(),
        getMonthlyData(),
        getLastMonthData(),
      ]);
    }
  }

  void resetData() {
    state = MarketingState();
  }

  void setSelectedTab(int tabIndex) {
    state = state.copyWith(selectedTab: tabIndex);
  }

  void setViewType(MarketingViewType viewType) {
    state = state.copyWith(viewType: viewType);
  }
}

// Providers
final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final marketingRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return MarketingRepository(apiService);
});

final marketingProvider =
    StateNotifierProvider<MarketingNotifier, MarketingState>((ref) {
  final marketingRepository = ref.read(marketingRepositoryProvider);
  return MarketingNotifier(marketingRepository, ref);
});

class MarketingState {
  final List<MarketingPerformance> todayPerformance;
  final List<MarketingPerformance> yesterdayPerformance;
  final List<MarketingPerformance> monthlyPerformance;
  final List<MarketingPerformance> lastmonthPerformance;

  final List<MarketingDetailedData> todayDetailedData;
  final List<MarketingDetailedData> yesterdayDetailedData;
  final List<MarketingDetailedData> monthlyDetailedData;
  final List<MarketingDetailedData> lastmonthDetailedData;

  final List<MarketingResult> todayResultData;
  final List<MarketingResult> yesterdayResultData;
  final List<MarketingResult> monthlyResultData;
  final List<MarketingResult> lastmonthResultData;

  // NEW: Target data (monthly & last month only)
  final List<MarketingTarget> monthlyTargetSummary;
  final List<MarketingTarget> lastmonthTargetSummary;
  final List<MarketingTargetDetail> monthlyTargetDetail;
  final List<MarketingTargetDetail> lastmonthTargetDetail;

  final List<MarketingDetailedData> detailedData;
  final int selectedTab;
  final bool isLoading;
  final MarketingViewType viewType;

  MarketingState({
    this.todayPerformance = const [],
    this.yesterdayPerformance = const [],
    this.monthlyPerformance = const [],
    this.lastmonthPerformance = const [],
    this.todayDetailedData = const [],
    this.yesterdayDetailedData = const [],
    this.monthlyDetailedData = const [],
    this.lastmonthDetailedData = const [],
    this.todayResultData = const [],
    this.yesterdayResultData = const [],
    this.monthlyResultData = const [],
    this.lastmonthResultData = const [],
    this.monthlyTargetSummary = const [],     // NEW
    this.lastmonthTargetSummary = const [],   // NEW
    this.monthlyTargetDetail = const [],      // NEW
    this.lastmonthTargetDetail = const [],    // NEW
    this.detailedData = const [],
    this.selectedTab = -1,
    this.isLoading = false,
    this.viewType = MarketingViewType.performance,
  });

  MarketingState copyWith({
    List<MarketingPerformance>? todayPerformance,
    List<MarketingPerformance>? yesterdayPerformance,
    List<MarketingPerformance>? monthlyPerformance,
    List<MarketingPerformance>? lastmonthPerformance,
    List<MarketingDetailedData>? todayDetailedData,
    List<MarketingDetailedData>? yesterdayDetailedData,
    List<MarketingDetailedData>? monthlyDetailedData,
    List<MarketingDetailedData>? lastmonthDetailedData,
    List<MarketingResult>? todayResultData,
    List<MarketingResult>? yesterdayResultData,
    List<MarketingResult>? monthlyResultData,
    List<MarketingResult>? lastmonthResultData,
    List<MarketingTarget>? monthlyTargetSummary,      // NEW
    List<MarketingTarget>? lastmonthTargetSummary,    // NEW
    List<MarketingTargetDetail>? monthlyTargetDetail, // NEW
    List<MarketingTargetDetail>? lastmonthTargetDetail, // NEW
    List<MarketingDetailedData>? detailedData,
    int? selectedTab,
    bool? isLoading,
    MarketingViewType? viewType,
  }) {
    return MarketingState(
      todayPerformance: todayPerformance ?? this.todayPerformance,
      yesterdayPerformance: yesterdayPerformance ?? this.yesterdayPerformance,
      monthlyPerformance: monthlyPerformance ?? this.monthlyPerformance,
      lastmonthPerformance: lastmonthPerformance ?? this.lastmonthPerformance,
      todayDetailedData: todayDetailedData ?? this.todayDetailedData,
      yesterdayDetailedData: yesterdayDetailedData ?? this.yesterdayDetailedData,
      monthlyDetailedData: monthlyDetailedData ?? this.monthlyDetailedData,
      lastmonthDetailedData: lastmonthDetailedData ?? this.lastmonthDetailedData,
      todayResultData: todayResultData ?? this.todayResultData,
      yesterdayResultData: yesterdayResultData ?? this.yesterdayResultData,
      monthlyResultData: monthlyResultData ?? this.monthlyResultData,
      lastmonthResultData: lastmonthResultData ?? this.lastmonthResultData,
      monthlyTargetSummary: monthlyTargetSummary ?? this.monthlyTargetSummary,
      lastmonthTargetSummary: lastmonthTargetSummary ?? this.lastmonthTargetSummary,
      monthlyTargetDetail: monthlyTargetDetail ?? this.monthlyTargetDetail,
      lastmonthTargetDetail: lastmonthTargetDetail ?? this.lastmonthTargetDetail,
      detailedData: detailedData ?? this.detailedData,
      selectedTab: selectedTab ?? this.selectedTab,
      isLoading: isLoading ?? this.isLoading,
      viewType: viewType ?? this.viewType,
    );
  }

  List<MarketingPerformance> get currentPerformanceData {
    switch (selectedTab) {
      case 0: return todayPerformance;
      case 1: return yesterdayPerformance;
      case 2: return monthlyPerformance;
      case 3: return lastmonthPerformance;
      default: return todayPerformance;
    }
  }

  List<MarketingDetailedData> get currentDetailedData {
    switch (selectedTab) {
      case 0: return todayDetailedData;
      case 1: return yesterdayDetailedData;
      case 2: return monthlyDetailedData;
      case 3: return lastmonthDetailedData;
      default: return todayDetailedData;
    }
  }

  List<MarketingResult> get currentResultData {
    switch (selectedTab) {
      case 0: return todayResultData;
      case 1: return yesterdayResultData;
      case 2: return monthlyResultData;
      case 3: return lastmonthResultData;
      default: return todayResultData;
    }
  }

  // NEW: Current target summary list
  List<MarketingTarget> get currentTargetSummary {
    switch (selectedTab) {
      case 2: return monthlyTargetSummary;
      case 3: return lastmonthTargetSummary;
      default: return [];
    }
  }

  // NEW: Whether target tab is available for the current tab selection
  bool get isTargetAvailable => selectedTab == 2 || selectedTab == 3;

  String get currentTabTitle {
    switch (selectedTab) {
      case 0: return "Today";
      case 1: return "Yesterday";
      case 2: return "Monthly";
      case 3: return "Last Month";
      default: return "Today";
    }
  }
}