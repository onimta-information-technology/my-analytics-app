import 'package:ballys_reservation_app/data/repositories/last_three_months_repository.dart';
import 'package:ballys_reservation_app/models/last_three_months.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
// Reuses the apiServiceProvider already declared in marketing_provider.dart
// rather than redeclaring it.
import 'package:ballys_reservation_app/providers/marketing_provider.dart'
    show apiServiceProvider;
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LastThreeMonthsState {
  final List<LastThreeMonthsPerformance> performanceData;
  final List<LastThreeMonthsDetailedData> detailedData;
  final bool isLoading;
  final bool hasLoadedOnce;

  const LastThreeMonthsState({
    this.performanceData = const [],
    this.detailedData = const [],
    this.isLoading = false,
    this.hasLoadedOnce = false,
  });

  LastThreeMonthsState copyWith({
    List<LastThreeMonthsPerformance>? performanceData,
    List<LastThreeMonthsDetailedData>? detailedData,
    bool? isLoading,
    bool? hasLoadedOnce,
  }) {
    return LastThreeMonthsState(
      performanceData: performanceData ?? this.performanceData,
      detailedData: detailedData ?? this.detailedData,
      isLoading: isLoading ?? this.isLoading,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

class LastThreeMonthsNotifier extends StateNotifier<LastThreeMonthsState> {
  final LastThreeMonthsRepository repository;
  final Ref ref;

  LastThreeMonthsNotifier(this.repository, this.ref)
      : super(const LastThreeMonthsState());

  Future<void> getData({AppMode? overrideAppMode}) async {
    state = state.copyWith(isLoading: true);

    try {
      final salesCode = await StorageUtil.getSalesCode();
      final currentAppModeSettings = ref.read(appmodeSettingsProvider);
      final appMode = overrideAppMode ?? currentAppModeSettings.appMode;

      final result = await repository.getLastThreeMonthsData(
        appMode,
        salesCode!,
      );

      state = state.copyWith(
        performanceData: result.performanceData,
        detailedData: result.detailedData,
        isLoading: false,
        hasLoadedOnce: true,
      );
    } catch (e) {
      state = state.copyWith(
        performanceData: [],
        detailedData: [],
        isLoading: false,
        hasLoadedOnce: true,
      );
    }
  }

  // Hook this up the same way MarketingNotifier.onAppModeChanged is used,
  // so switching admin overall/own-data mode refreshes this card too.
  Future<void> onAppModeChanged(AppMode newAppMode) async {
    await getData(overrideAppMode: newAppMode);
  }

  // Get member-level detail rows for a specific SM from already-loaded
  // data — mirrors MarketingNotifier.getDetailedDataForSM.
  List<LastThreeMonthsDetailedData> getDetailedDataForSM(String smCode) {
    return state.detailedData.where((data) => data.sm == smCode).toList();
  }
}

final lastThreeMonthsRepositoryProvider = Provider((ref) {
  final apiService = ref.read(apiServiceProvider);
  return LastThreeMonthsRepository(apiService);
});

final lastThreeMonthsProvider =
    StateNotifierProvider<LastThreeMonthsNotifier, LastThreeMonthsState>(
        (ref) {
  final repository = ref.read(lastThreeMonthsRepositoryProvider);
  return LastThreeMonthsNotifier(repository, ref);
});