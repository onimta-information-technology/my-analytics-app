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
/// tapping it again in full screen mode pops back.
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

  @override
  void initState() {
    super.initState();
    // Intentionally no auto-fetch here. Data only loads when the user
    // taps "Load Data" (first time) or "Refresh" (afterwards) below.
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

  List<_ItemWithPercentage> _calculatePercentages(
      List<LastThreeMonthsPerformance> data) {
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
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lastThreeMonthsState = ref.watch(lastThreeMonthsProvider);
    final appModeSettings = ref.watch(appmodeSettingsProvider);
    final currentAppMode = appModeSettings.appMode;

    _handleAppModeChange(currentAppMode, lastThreeMonthsState.hasLoadedOnce);

    final dataWithPercentages =
        _calculatePercentages(lastThreeMonthsState.performanceData);

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
            // Title with expand/collapse icon — same pattern as
            // MarketingPerformanceWidget.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    "LAST 3 MONTHS PERFORMANCE",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    widget.isFullScreen ? Icons.zoom_out : Icons.zoom_in,
                    color: Colors.blue,
                    size: 30,
                  ),
                  onPressed: () {
                    if (widget.isFullScreen) {
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
              Column(
                children: sortedData
                    .map((itemWithPercentage) =>
                        _buildPerformanceItem(itemWithPercentage))
                    .toList(),
              ),

            const SizedBox(height: 16),

            // Legend with refresh button — same pattern as
            // MarketingPerformanceWidget.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
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
                      ],
                    ),
                    const SizedBox(width: 20),
                    Row(
                      children: [
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
                      ],
                    ),
                  ],
                ),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  color: lastThreeMonthsState.isLoading
                      ? Colors.grey
                      : Colors.blue,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextButton.icon(
                      onPressed: lastThreeMonthsState.isLoading
                          ? null
                          : () => ref
                              .read(lastThreeMonthsProvider.notifier)
                              .getData(),
                      icon: const Icon(
                        Icons.refresh,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Refresh",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
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
                width: 120,
                child: Text(
                  performance.smName,
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: fontSettings.fontWeight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
              // SizedBox(
              //   width: 90,
              //   child: Text(
              //     _formatCurrency(performance.winLost),
              //     textAlign: TextAlign.right,
              //     style: TextStyle(
              //       fontSize: fontSettings.fontSize - 1,
              //       fontWeight: FontWeight.bold,
              //       color: performance.isPositive ? Colors.green : Colors.red,
              //     ),
              //   ),
              // ),
              // const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
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

  _ItemWithPercentage({
    required this.item,
    required this.percentage,
  });
}