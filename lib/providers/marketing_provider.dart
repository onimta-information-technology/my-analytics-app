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

  MarketingNotifier(this.marketingRepository, this.ref) : super(MarketingState());

  // Updated to fetch both performance and detailed data in one call
  Future<void> getMarketingData(int iid, {AppMode? overrideAppMode}) async {
    state = state.copyWith(isLoading: true);

    try {
      final salesCode = await StorageUtil.getSalesCode();
      final currentAppModeSettings = ref.read(appmodeSettingsProvider);
      final appMode = overrideAppMode ?? currentAppModeSettings.appMode;

      print('=== MarketingNotifier: Starting combined data fetch ===');
      print('IID: $iid, Sales Code: $salesCode, App Mode: $appMode');

      // Single API call to get both tables
      final result = await marketingRepository.getMarketingData(iid, appMode, salesCode!);
      
      print('MarketingNotifier - Combined API Response for iid $iid:');
      print('Performance items: ${result.performanceData.length}');
      print('Detailed items: ${result.detailedData.length}');

      if (result.performanceData.isNotEmpty) {
        print('Sample performance data: ${result.performanceData.first}');
      }
      if (result.detailedData.isNotEmpty) {
        print('Sample detailed data: ${result.detailedData.first}');
      }

      // Update state based on IID
      switch (iid) {
        case 8896: // Today
          state = state.copyWith(
            todayPerformance: result.performanceData,
            todayDetailedData: result.detailedData,
            isLoading: false,
          );
          break;
        case 8897: // Yesterday
          state = state.copyWith(
            yesterdayPerformance: result.performanceData,
            yesterdayDetailedData: result.detailedData,
            isLoading: false,
          );
          break;
        case 8898: // Monthly
          state = state.copyWith(
            monthlyPerformance: result.performanceData,
            monthlyDetailedData: result.detailedData,
            isLoading: false,
          );
          break;
      }

      print('State updated successfully for IID $iid');
    } catch (e, stackTrace) {
      print('Error fetching marketing data for iid $iid: $e');
      print('Stack trace: $stackTrace');

      // Reset specific state instead of all
      switch (iid) {
        case 8896:
          state = state.copyWith(
            todayPerformance: [],
            todayDetailedData: [],
            isLoading: false,
          );
          break;
        case 8897:
          state = state.copyWith(
            yesterdayPerformance: [],
            yesterdayDetailedData: [],
            isLoading: false,
          );
          break;
        case 8898:
          state = state.copyWith(
            monthlyPerformance: [],
            monthlyDetailedData: [],
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
      default:
        // If no tab selected, refresh today by default
        await getMarketingData(8896, overrideAppMode: overrideAppMode);
        break;
    }
  }

  // NEW METHOD: Handle app mode change - refresh ALL tabs
Future<void> onAppModeChanged(AppMode newAppMode) async {
  // Only refresh data if a tab is currently selected
  if (state.selectedTab == -1) {
    print('No tab selected, skipping app mode refresh');
    return;
  }
  
  print('=== App Mode Changed: $newAppMode ===');
  print('Refreshing all tabs with new app mode: $newAppMode');
  
  // Refresh ALL tabs with the new app mode
  await refreshAllDataWithAppMode(newAppMode);
}

  // NEW METHOD: Refresh all data with specific app mode
  Future<void> refreshAllDataWithAppMode(AppMode appMode) async {
    // Show loading state
    state = state.copyWith(isLoading: true);
    
    try {
      // Refresh all tabs with the specified app mode
      await Future.wait([
        getMarketingData(8896, overrideAppMode: appMode), // Today
        getMarketingData(8897, overrideAppMode: appMode), // Yesterday
        getMarketingData(8898, overrideAppMode: appMode), // Monthly
      ]);
      
      print('All tabs refreshed successfully with app mode: $appMode');
    } catch (e) {
      print('Error refreshing all tabs with app mode $appMode: $e');
    } finally {
      // Ensure loading state is turned off
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

  Future<void> getMonthlyPerformanceOverall() async {
    await getMarketingData(8898, overrideAppMode: AppMode.overallData);
  }

  // Keep this method and update it to use the new approach
  Future<void> refreshAllData({AppMode? overrideAppMode}) async {
    if (overrideAppMode != null) {
      await refreshAllDataWithAppMode(overrideAppMode);
    } else {
      await Future.wait([
        getTodayData(),
        getYesterdayData(),
        getMonthlyData(),
      ]);
    }
  }

  void resetData() {
    state = MarketingState();
  }

  void setSelectedTab(int tabIndex) {
    state = state.copyWith(selectedTab: tabIndex);
  }
}

// Providers remain the same
final flutterSecureStorageProvider = Provider((ref) => const FlutterSecureStorage());

final apiServiceProvider = Provider((ref) {
  final storage = ref.read(flutterSecureStorageProvider);
  return ApiService(storage);
});

final marketingRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return MarketingRepository(apiService);
});

final marketingProvider = StateNotifierProvider<MarketingNotifier, MarketingState>((ref) {
  final marketingRepository = ref.read(marketingRepositoryProvider);
  return MarketingNotifier(marketingRepository, ref);
});

// Updated MarketingState to store detailed data for each time period
class MarketingState {
  final List<MarketingPerformance> todayPerformance;
  final List<MarketingPerformance> yesterdayPerformance;
  final List<MarketingPerformance> monthlyPerformance;
  
  // Store detailed data for each time period
  final List<MarketingDetailedData> todayDetailedData;
  final List<MarketingDetailedData> yesterdayDetailedData;
  final List<MarketingDetailedData> monthlyDetailedData;
  
  final List<MarketingDetailedData> detailedData; // Keep for backward compatibility
  final int selectedTab;
  final bool isLoading;

  MarketingState({
    this.todayPerformance = const [],
    this.yesterdayPerformance = const [],
    this.monthlyPerformance = const [],
    this.todayDetailedData = const [],
    this.yesterdayDetailedData = const [],
    this.monthlyDetailedData = const [],
    this.detailedData = const [],
    this.selectedTab = -1,
    this.isLoading = false,
  });

  MarketingState copyWith({
    List<MarketingPerformance>? todayPerformance,
    List<MarketingPerformance>? yesterdayPerformance,
    List<MarketingPerformance>? monthlyPerformance,
    List<MarketingDetailedData>? todayDetailedData,
    List<MarketingDetailedData>? yesterdayDetailedData,
    List<MarketingDetailedData>? monthlyDetailedData,
    List<MarketingDetailedData>? detailedData,
    int? selectedTab,
    bool? isLoading,
  }) {
    return MarketingState(
      todayPerformance: todayPerformance ?? this.todayPerformance,
      yesterdayPerformance: yesterdayPerformance ?? this.yesterdayPerformance,
      monthlyPerformance: monthlyPerformance ?? this.monthlyPerformance,
      todayDetailedData: todayDetailedData ?? this.todayDetailedData,
      yesterdayDetailedData: yesterdayDetailedData ?? this.yesterdayDetailedData,
      monthlyDetailedData: monthlyDetailedData ?? this.monthlyDetailedData,
      detailedData: detailedData ?? this.detailedData,
      selectedTab: selectedTab ?? this.selectedTab,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  // Helper methods to get current data based on selected tab
  List<MarketingPerformance> get currentPerformanceData {
    switch (selectedTab) {
      case 0: return todayPerformance;
      case 1: return yesterdayPerformance;
      case 2: return monthlyPerformance;
      default: return todayPerformance;
    }
  }

  List<MarketingDetailedData> get currentDetailedData {
    switch (selectedTab) {
      case 0: return todayDetailedData;
      case 1: return yesterdayDetailedData;
      case 2: return monthlyDetailedData;
      default: return todayDetailedData;
    }
  }

  String get currentTabTitle {
    switch (selectedTab) {
      case 0: return "Today";
      case 1: return "Yesterday";
      case 2: return "Monthly";
      default: return "Today";
    }
  }
}