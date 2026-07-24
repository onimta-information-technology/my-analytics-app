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

  // Captured in initState so dispose() never touches `ref` (illegal in
  // Riverpod once the element is disposed).
  LastThreeMonthsNotifier? _lastThreeMonthsNotifier;

  // Max height for the SM list when this widget is embedded (not full
  // screen). Beyond this, the list scrolls internally instead of
  // expanding the card indefinitely. Mirrors
  // MarketingPerformanceWidget._embeddedMaxContentHeight.
  static const double _embeddedMaxContentHeight = 320.0;

  @override
  void initState() {
    super.initState();
    _lastThreeMonthsNotifier = ref.read(lastThreeMonthsProvider.notifier);
    // Intentionally no auto-fetch here. Data only loads when the user
    // taps "Load Data" (first time) or "Refresh" (afterwards) below.
  }

  @override
  void dispose() {
    // Defer the state reset: mutating a StateNotifier synchronously inside
    // dispose() runs during finalizeTree/lockState and notifying listeners
    // there is illegal. Use the captured notifier (NOT `ref`) on a microtask.
    final notifier = _lastThreeMonthsNotifier;
    if (notifier != null) {
      Future.microtask(notifier.clearData);
    }
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

  // New/old guest counts come straight from the API (N_Reg / O_Reg on
  // each performance row) — no longer derived from the detail rows.
  List<_ItemWithPercentage> _calculatePercentages(
    List<LastThreeMonthsPerformance> data,
    Map<String, Set<String>> packageMembersBySm,
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
        newReg: item.newReg,
        oldReg: item.oldReg,
        packageReg: packageMembersBySm[item.sm]?.length ?? 0,
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

    // New/old guest totals come straight from the API (N_Reg / O_Reg
    // summed across the SM rows).
    final totalNewReg = lastThreeMonthsState.performanceData
        .fold<int>(0, (sum, p) => sum + p.newReg);
    final totalOldReg = lastThreeMonthsState.performanceData
        .fold<int>(0, (sum, p) => sum + p.oldReg);
    final totalGuestCount = totalNewReg + totalOldReg;

    // Package guests are counted from the detail rows (PKG_Status == 'Y').
    // Group distinct memIds per SM so a guest with multiple rows isn't
    // double-counted, then the overall total is the sum of the per-SM sets.
    final packageMembersBySm = <String, Set<String>>{};
    for (final d in lastThreeMonthsState.detailedData) {
      if (d.hasPackage) {
        packageMembersBySm.putIfAbsent(d.sm, () => <String>{}).add(d.memId);
      }
    }
    final packageGuestCount = packageMembersBySm.values
        .fold<int>(0, (sum, members) => sum + members.length);

    final dataWithPercentages = _calculatePercentages(
      lastThreeMonthsState.performanceData,
      packageMembersBySm,
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
                            "$totalGuestCount guest${totalGuestCount == 1 ? '' : 's'} this period "
                            "($totalNewReg new, $totalOldReg old, $packageGuestCount package)",
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
                Text("N",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green[700])),
                const SizedBox(width: 4),
                const Text("NEW"),
                const SizedBox(width: 12),
                Text("O",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue[700])),
                const SizedBox(width: 4),
                const Text("OLD"),
                const SizedBox(width: 12),
                Text("P",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple[400])),
                const SizedBox(width: 4),
                const Text("PACKAGE"),
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
    final newReg = itemWithPercentage.newReg;
    final oldReg = itemWithPercentage.oldReg;
    final packageReg = itemWithPercentage.packageReg;
    final double barWidthFactor = (percentage / 100.0).clamp(0.0, 1.0);

    return Consumer(
      builder: (context, ref, child) {
        final fontSettings = ref.watch(fontSettingsProvider);

        return GestureDetector(
          onTap: () => _navigateToDetail(performance),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full-width name line (uses the whole row width).
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        performance.smName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 12, color: Colors.grey[600]),
                  ],
                ),
                const SizedBox(height: 4),
                // Badges + bar on the line below.
                Row(
                  children: [
                    // New / old / package guest count badges for this SM
                    // (N_Reg / O_Reg / PKG_Status) — fixed width so every bar
                    // starts at the same point and is the same size.
                    SizedBox(
                      width: 150,
                      child: Row(
                        children: [
                          _buildRegBadge(
                            count: newReg,
                            label: 'N',
                            background: Colors.green[50]!,
                            foreground: Colors.green[700]!,
                          ),
                          const SizedBox(width: 4),
                          _buildRegBadge(
                            count: oldReg,
                            label: 'O',
                            background: Colors.blue[50]!,
                            foreground: Colors.blue[700]!,
                          ),
                          const SizedBox(width: 4),
                          _buildRegBadge(
                            count: packageReg,
                            label: 'P',
                            background: Colors.deepPurple[50]!,
                            foreground: Colors.deepPurple[400]!,
                          ),
                        ],
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
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Small pill showing a registration count with a single-letter label
  // (N = new from N_Reg, O = old from O_Reg).
  Widget _buildRegBadge({
    required int count,
   required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
         const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
        ],
      ),
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
  final int newReg;
  final int oldReg;
  final int packageReg;

  _ItemWithPercentage({
    required this.item,
    required this.percentage,
    required this.newReg,
    required this.oldReg,
    required this.packageReg,
  });
}