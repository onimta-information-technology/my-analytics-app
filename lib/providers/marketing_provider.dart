import 'package:ballys_reservation_app/data/repositories/marketing_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MarketingNotifier extends StateNotifier<MarketingState> {
  final MarketingRepository marketingRepository;
  final Ref ref;

  MarketingNotifier(this.marketingRepository, this.ref)
      : super(MarketingState());

  // Updated to fetch performance, detailed, and result data in one call
  Future<void> getMarketingData(int iid, {AppMode? overrideAppMode}) async {
    state = state.copyWith(isLoading: true);

    try {
      final salesCode = await StorageUtil.getSalesCode();
      final currentAppModeSettings = ref.read(appmodeSettingsProvider);
      final appMode = overrideAppMode ?? currentAppModeSettings.appMode;

      // Single API call to get all three tables
      final result = await marketingRepository.getMarketingData(
        iid,
        appMode,
        salesCode!,
      );

      // Update state based on IID
      switch (iid) {
        case 8896: // Today
          state = state.copyWith(
            todayPerformance: result.performanceData,
            todayDetailedData: result.detailedData,
            todayResultData: result.resultData, // NEW
            isLoading: false,
          );
          break;
        case 8897: // Yesterday
          state = state.copyWith(
            yesterdayPerformance: result.performanceData,
            yesterdayDetailedData: result.detailedData,
            yesterdayResultData: result.resultData, // NEW
            isLoading: false,
          );
          break;
        case 8898: // Monthly
          state = state.copyWith(
            monthlyPerformance: result.performanceData,
            monthlyDetailedData: result.detailedData,
            monthlyResultData: result.resultData, // NEW
            isLoading: false,
          );
          break;
        case 8899: // Last Monthly
          state = state.copyWith(
            lastmonthPerformance: result.performanceData,
            lastmonthDetailedData: result.detailedData,
            lastmonthResultData: result.resultData, // NEW
            isLoading: false,
          );
          break;
      }
    } catch (e, stackTrace) {
      // Reset specific state instead of all
      switch (iid) {
        case 8896:
          state = state.copyWith(
            todayPerformance: [],
            todayDetailedData: [],
            todayResultData: [],
            isLoading: false,
          );
          break;
        case 8897:
          state = state.copyWith(
            yesterdayPerformance: [],
            yesterdayDetailedData: [],
            yesterdayResultData: [],
            isLoading: false,
          );
          break;
        case 8898:
          state = state.copyWith(
            monthlyPerformance: [],
            monthlyDetailedData: [],
            monthlyResultData: [],
            isLoading: false,
          );
          break;
        case 8899:
          state = state.copyWith(
            lastmonthPerformance: [],
            lastmonthDetailedData: [],
            lastmonthResultData: [],
            isLoading: false,
          );
          break;
      }
    }
  }

  // NEW METHOD: Refresh only the current tab based on selectedTab
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

  // NEW METHOD: Handle app mode change - refresh ALL tabs
  Future<void> onAppModeChanged(AppMode newAppMode) async {
    if (state.selectedTab == -1) {
      return;
    }
    await refreshAllDataWithAppMode(newAppMode);
  }

  // NEW METHOD: Refresh all data with specific app mode
  Future<void> refreshAllDataWithAppMode(AppMode appMode) async {
    state = state.copyWith(isLoading: true);

    try {
      await Future.wait([
        getMarketingData(8896, overrideAppMode: appMode), // Today
        getMarketingData(8897, overrideAppMode: appMode), // Yesterday
        getMarketingData(8898, overrideAppMode: appMode), // Monthly
        getMarketingData(8899, overrideAppMode: appMode), // last month
      ]);
    } catch (e) {
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // Get detailed data for a specific SM from already loaded data
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

  // Updated methods using the new combined approach
  Future<void> getTodayData() async {
    await getMarketingData(8896);
  }

  Future<void> getYesterdayData() async {
    await getMarketingData(8897);
  }

  Future<void> getMonthlyData() async {
    await getMarketingData(8898);
  }

  Future<void> getLastMonthData() async {
    await getMarketingData(8899);
  }

  // Legacy methods for backward compatibility
  Future<void> getTodayPerformance() async {
    await getTodayData();
  }

  Future<void> getYesterdayPerformance() async {
    await getYesterdayData();
  }

  Future<void> getMonthlyPerformance() async {
    await getMonthlyData();
  }

  Future<void> getLastMonthPerformance() async {
    await getLastMonthData();
  }

  Future<void> getMonthlyPerformanceOverall() async {
    await getMarketingData(8898, overrideAppMode: AppMode.overallData);
  }

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

  // NEW: Set view type (Performance or Result)
  void setViewType(MarketingViewType viewType) {
    state = state.copyWith(viewType: viewType);
  }
}

// NEW: Enum for view type
enum MarketingViewType {
  performance,
  result,
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

// Updated MarketingState to store result data for each time period
class MarketingState {
  final List<MarketingPerformance> todayPerformance;
  final List<MarketingPerformance> yesterdayPerformance;
  final List<MarketingPerformance> monthlyPerformance;
  final List<MarketingPerformance> lastmonthPerformance;

  // Store detailed data for each time period
  final List<MarketingDetailedData> todayDetailedData;
  final List<MarketingDetailedData> yesterdayDetailedData;
  final List<MarketingDetailedData> monthlyDetailedData;
  final List<MarketingDetailedData> lastmonthDetailedData;

  // NEW: Store result data (Table2) for each time period
  final List<MarketingResult> todayResultData;
  final List<MarketingResult> yesterdayResultData;
  final List<MarketingResult> monthlyResultData;
  final List<MarketingResult> lastmonthResultData;

  final List<MarketingDetailedData> detailedData;
  final int selectedTab;
  final bool isLoading;
  final MarketingViewType viewType; // NEW

  MarketingState({
    this.todayPerformance = const [],
    this.yesterdayPerformance = const [],
    this.monthlyPerformance = const [],
    this.lastmonthPerformance = const [],
    this.todayDetailedData = const [],
    this.yesterdayDetailedData = const [],
    this.monthlyDetailedData = const [],
    this.lastmonthDetailedData = const [],
    this.todayResultData = const [], // NEW
    this.yesterdayResultData = const [], // NEW
    this.monthlyResultData = const [], // NEW
    this.lastmonthResultData = const [], // NEW
    this.detailedData = const [],
    this.selectedTab = -1,
    this.isLoading = false,
    this.viewType = MarketingViewType.performance, // NEW
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
    List<MarketingResult>? todayResultData, // NEW
    List<MarketingResult>? yesterdayResultData, // NEW
    List<MarketingResult>? monthlyResultData, // NEW
    List<MarketingResult>? lastmonthResultData, // NEW
    List<MarketingDetailedData>? detailedData,
    int? selectedTab,
    bool? isLoading,
    MarketingViewType? viewType, // NEW
  }) {
    return MarketingState(
      todayPerformance: todayPerformance ?? this.todayPerformance,
      yesterdayPerformance: yesterdayPerformance ?? this.yesterdayPerformance,
      monthlyPerformance: monthlyPerformance ?? this.monthlyPerformance,
      lastmonthPerformance: lastmonthPerformance ?? this.lastmonthPerformance,
      todayDetailedData: todayDetailedData ?? this.todayDetailedData,
      yesterdayDetailedData:
          yesterdayDetailedData ?? this.yesterdayDetailedData,
      monthlyDetailedData: monthlyDetailedData ?? this.monthlyDetailedData,
      lastmonthDetailedData:
          lastmonthDetailedData ?? this.lastmonthDetailedData,
      todayResultData: todayResultData ?? this.todayResultData, // NEW
      yesterdayResultData: yesterdayResultData ?? this.yesterdayResultData, // NEW
      monthlyResultData: monthlyResultData ?? this.monthlyResultData, // NEW
      lastmonthResultData: lastmonthResultData ?? this.lastmonthResultData, // NEW
      detailedData: detailedData ?? this.detailedData,
      selectedTab: selectedTab ?? this.selectedTab,
      isLoading: isLoading ?? this.isLoading,
      viewType: viewType ?? this.viewType, // NEW
    );
  }

  // Helper methods to get current data based on selected tab
  List<MarketingPerformance> get currentPerformanceData {
    switch (selectedTab) {
      case 0:
        return todayPerformance;
      case 1:
        return yesterdayPerformance;
      case 2:
        return monthlyPerformance;
      case 3:
        return lastmonthPerformance;
      default:
        return todayPerformance;
    }
  }

  List<MarketingDetailedData> get currentDetailedData {
    switch (selectedTab) {
      case 0:
        return todayDetailedData;
      case 1:
        return yesterdayDetailedData;
      case 2:
        return monthlyDetailedData;
      case 3:
        return lastmonthDetailedData;
      default:
        return todayDetailedData;
    }
  }

  // NEW: Helper method to get current result data
  List<MarketingResult> get currentResultData {
    switch (selectedTab) {
      case 0:
        return todayResultData;
      case 1:
        return yesterdayResultData;
      case 2:
        return monthlyResultData;
      case 3:
        return lastmonthResultData;
      default:
        return todayResultData;
    }
  }

  String get currentTabTitle {
    switch (selectedTab) {
      case 0:
        return "Today";
      case 1:
        return "Yesterday";
      case 2:
        return "Monthly";
      case 3:
        return "Last Month";
      default:
        return "Today";
    }
  }
}