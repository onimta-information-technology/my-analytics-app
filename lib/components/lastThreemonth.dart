import 'dart:math' as math;

import 'package:ballys_reservation_app/models/last_three_months.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/last_three_months_provider.dart';
import 'package:ballys_reservation_app/screens/last_three_months_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card showing the SM-wise Win/Lost breakdown for the "Last 3 Months"
/// report (sp_CRM_Common_API, @Iid 778899). Pulls live data through
/// [lastThreeMonthsProvider] — the old mock guest-count data is gone.
///
/// Zoom-in/zoom-out -> full screen behavior is copied from
/// MarketingPerformanceWidget: tapping the icon in compact mode pushes a
/// full screen route containing this same widget with isFullScreen: true;
/// tapping it again in full screen mode pops back (and clears the loaded
/// data, same as the zoom-out / dispose behavior on the marketing card).
///
/// Guest count is NOT a separate API field — it's derived from the
/// already-loaded `detailedData` (distinct memId per SM, and overall).
class LastThreeMonthsGuestCard extends ConsumerStatefulWidget {
  final bool isFullScreen;

  const LastThreeMonthsGuestCard({super.key, this.isFullScreen = false});

  @override
  ConsumerState<LastThreeMonthsGuestCard> createState() =>
      _LastThreeMonthsGuestCardState();
}

class _LastThreeMonthsGuestCardState
    extends ConsumerState<LastThreeMonthsGuestCard> {
  AppMode? _previousAppMode;

  // Max height for the SM list when this widget is embedded (not full
  // screen). Beyond this, the list scrolls internally instead of
  // expanding the card indefinitely. Mirrors
  // MarketingPerformanceWidget._embeddedMaxContentHeight.
  static const double _embeddedMaxContentHeight = 320.0;

  @override
  void initState() {
    super.initState();
    // Intentionally no auto-fetch here. Data only loads when the user
    // taps "Load Data" (first time) or "Refresh" (afterwards) below.
  }

  @override
  void dispose() {
    ref.read(lastThreeMonthsProvider.notifier).clearData();
    super.dispose();
  }

  // Mirrors MarketingPerformanceWidget._handleAppModeChange. There, the
  // refresh only fires if a tab has already been selected
  // (selectedTab != -1); here the equivalent guard is hasLoadedOnce — so
  // switching app mode before the first manual load does NOT trigger a
  // fetch, but switching it after data has been loaded does refresh it.
  void _handleAppModeChange(AppMode currentAppMode, bool hasLoadedOnce) {
    if (_previousAppMode != null &&
        _previousAppMode != currentAppMode &&
        hasLoadedOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(lastThreeMonthsProvider.notifier)
              .onAppModeChanged(currentAppMode);
        }
      });
    }
    _previousAppMode = currentAppMode;
  }

  // Guest count is the number of distinct memIds per SM, computed from
  // the detailed rows already loaded alongside the performance data.
  List<_ItemWithPercentage> _calculatePercentages(
    List<LastThreeMonthsPerformance> data,
    Map<String, Set<String>> guestIdsBySm,
  ) {
    if (data.isEmpty) return [];

    final maxAbsAmount =
        data.map((p) => p.winLost.abs()).reduce((a, b) => math.max(a, b));

    const double minVisibleWidth = 5.0;
    const double maxWidth = 100.0;

    return data.map((item) {
      double percentage = 0.0;

      if (maxAbsAmount > 0 && item.winLost != 0) {
        final absValue = item.winLost.abs();
        final linearRatio = absValue / maxAbsAmount;
        final logRatio = math.log(absValue + 1) / math.log(maxAbsAmount + 1);
        final blendedRatio = 0.85 * linearRatio + 0.15 * logRatio;
        percentage =
            minVisibleWidth + blendedRatio * (maxWidth - minVisibleWidth);
        percentage =
            math.min(math.max(percentage, minVisibleWidth), maxWidth);
      } else if (item.winLost != 0) {
        percentage = 50.0;
      }

      return _ItemWithPercentage(
        item: item,
        percentage: (percentage * 100).round() / 100,
        guestCount: guestIdsBySm[item.sm]?.length ?? 0,
      );
    }).toList();
  }

  // ── Wraps content so it scrolls within a bounded height when this
  // widget is embedded (not full screen). In full screen mode the
  // parent page already provides its own scroll view, so we return
  // the child unchanged there. Mirrors
  // MarketingPerformanceWidget._wrapScrollable.
  Widget _wrapScrollable(Widget child,
      {double maxHeight = _embeddedMaxContentHeight}) {
    if (widget.isFullScreen) {
      return child;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastThreeMonthsState = ref.watch(lastThreeMonthsProvider);
    final appModeSettings = ref.watch(appmodeSettingsProvider);
    final currentAppMode = appModeSettings.appMode;

    _handleAppModeChange(currentAppMode, lastThreeMonthsState.hasLoadedOnce);

    // Guest count per SM, derived from already-loaded detailedData.
    final guestIdsBySm = <String, Set<String>>{};
    for (final detail in lastThreeMonthsState.detailedData) {
      guestIdsBySm.putIfAbsent(detail.sm, () => {}).add(detail.memId);
    }
    final totalGuestCount =
        lastThreeMonthsState.detailedData.map((d) => d.memId).toSet().length;

    final dataWithPercentages = _calculatePercentages(
      lastThreeMonthsState.performanceData,
      guestIdsBySm,
    );

    final positiveData = dataWithPercentages
        .where((item) => item.item.isPositive)
        .toList()
      ..sort((a, b) => b.item.displayValue.compareTo(a.item.displayValue));

    final negativeData = dataWithPercentages
        .where((item) => !item.item.isPositive)
        .toList()
      ..sort((a, b) => b.item.displayValue.compareTo(a.item.displayValue));

    final sortedData = [...positiveData, ...negativeData];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with refresh + expand/collapse icons — refresh moved
            // up to the top per request. Guest count total shown under
            // the title once data has been loaded.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "LAST 3 MONTHS PERFORMANCE",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (lastThreeMonthsState.hasLoadedOnce &&
                          !lastThreeMonthsState.isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            "$totalGuestCount guest${totalGuestCount == 1 ? '' : 's'} this period",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: lastThreeMonthsState.isLoading
                        ? Colors.grey
                        : Colors.blue,
                    size: 26,
                  ),
                  onPressed: lastThreeMonthsState.isLoading
                      ? null
                      : () =>
                          ref.read(lastThreeMonthsProvider.notifier).getData(),
                ),
                IconButton(
                  icon: Icon(
                    widget.isFullScreen ? Icons.zoom_out : Icons.zoom_in,
                    color: Colors.blue,
                    size: 30,
                  ),
                  onPressed: () {
                    if (widget.isFullScreen) {
                      ref.read(lastThreeMonthsProvider.notifier).clearData();
                      Navigator.pop(context);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text(
                                'Last 3 Months Performance',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            body: const SafeArea(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(8),
                                child: LastThreeMonthsGuestCard(
                                  isFullScreen: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (lastThreeMonthsState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text(
                        "Loading data...",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else if (!lastThreeMonthsState.hasLoadedOnce)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        "Tap below to load the last 3 months data",
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => ref
                            .read(lastThreeMonthsProvider.notifier)
                            .getData(),
                        icon: const Icon(Icons.cloud_download, size: 18),
                        label: const Text("Load Data"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (lastThreeMonthsState.performanceData.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "No data available",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              _wrapScrollable(
                Column(
                  children: sortedData
                      .map((itemWithPercentage) =>
                          _buildPerformanceItem(itemWithPercentage))
                      .toList(),
                ),
              ),

            const SizedBox(height: 16),

            // Legend — refresh button now lives in the title row above.
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text("WIN"),
                const SizedBox(width: 20),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text("LOST"),
                const SizedBox(width: 20),
                Icon(Icons.people, size: 14, color: Colors.blue[700]),
                const SizedBox(width: 4),
                const Text("GUESTS"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceItem(_ItemWithPercentage itemWithPercentage) {
    final performance = itemWithPercentage.item;
    final percentage = itemWithPercentage.percentage;
    final guestCount = itemWithPercentage.guestCount;
    final double barWidthFactor = (percentage / 100.0).clamp(0.0, 1.0);

    return Consumer(
      builder: (context, ref, child) {
        final fontSettings = ref.watch(fontSettingsProvider);

        return GestureDetector(
          onTap: () => _navigateToDetail(performance),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Text(
                    performance.smName,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: barWidthFactor,
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: performance.isPositive
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Guest count badge for this SM.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon(Icons.people, size: 12, color: Colors.blue[700]),
                      // const SizedBox(width: 3),
                      Text(
                        '$guestCount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.grey[600]),
              ],
            ),
          ),
        );
      },
    );
  }

  // Mirrors MarketingPerformanceWidget._navigateToMarketingDetail.
  void _navigateToDetail(LastThreeMonthsPerformance performance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LastThreeMonthsDetailPage(
          smCode: performance.sm,
          smName: performance.smName,
          winSpecificMember: performance.winLost,
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return 'N/A';
    final absAmount = amount.abs();
    if (absAmount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (absAmount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }
    return amount.toStringAsFixed(2);
  }
}

class _ItemWithPercentage {
  final LastThreeMonthsPerformance item;
  final double percentage;
  final int guestCount;

  _ItemWithPercentage({
    required this.item,
    required this.percentage,
    required this.guestCount,
  });
}