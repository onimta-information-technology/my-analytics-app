import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/screens/marketing_detail_page.dart';
import 'package:ballys_reservation_app/screens/marketing_target_detail_page.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'package:ballys_reservation_app/providers/marketing_provider.dart';

class MarketingPerformanceWidget extends ConsumerStatefulWidget {
  final bool isFullScreen;

  const MarketingPerformanceWidget({super.key, this.isFullScreen = false});

  @override
  ConsumerState<MarketingPerformanceWidget> createState() =>
      _MarketingPerformanceWidgetState();
}

class _MarketingPerformanceWidgetState
    extends ConsumerState<MarketingPerformanceWidget> {
  bool _tabsEnabled = false;
  AppMode? _previousAppMode;
  String? userName;
  bool _refreshEnabled = false;

  // Captured in initState so dispose() never touches `ref` (illegal in
  // Riverpod once the element is disposed — it throws and corrupts the
  // element-tree teardown).
  MarketingNotifier? _marketingNotifier;

  // Max height for the content area when this widget is embedded
  // (not full screen). Beyond this, the content scrolls internally
  // instead of expanding the card indefinitely.
  static const double _embeddedMaxContentHeight = 320.0;

  @override
  void initState() {
    super.initState();
    _marketingNotifier = ref.read(marketingProvider.notifier);
    _loadUserName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enableTabsAfterDelay();
    });
  }

  void _enableTabsAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _tabsEnabled = true;
      });
    }
  }

  Future<void> _loadUserName() async {
    final name = await StorageUtil.getUserName();
    if (mounted) {
      setState(() {
        userName = name;
      });
    }
  }

  void _handleAppModeChange(AppMode currentAppMode) {
    if (_previousAppMode != null &&
        _previousAppMode != currentAppMode &&
        ref.read(marketingProvider).selectedTab != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(marketingProvider.notifier).onAppModeChanged(currentAppMode);
        }
      });
    }
    _previousAppMode = currentAppMode;
  }

  List<dynamic> _calculatePercentages(List<dynamic> data) {
    if (data.isEmpty) return [];

    final maxAbsAmount = data.map((p) {
      if (p is MarketingPerformance) return p.winLost.abs();
      if (p is MarketingResult) return p.winLost.abs();
      return 0.0;
    }).reduce((a, b) => math.max(a, b));

    const double minVisibleWidth = 5.0;
    const double maxWidth = 100.0;

    return data.map((item) {
      double winLost = 0.0;
      bool isPositive = false;

      if (item is MarketingPerformance) {
        winLost = item.winLost;
        isPositive = item.isPositive;
      } else if (item is MarketingResult) {
        winLost = item.winLost;
        isPositive = item.isPositive;
      }

      double percentage = 0.0;
      if (maxAbsAmount > 0 && winLost != 0) {
        final absValue = winLost.abs();
        final linearRatio = absValue / maxAbsAmount;
        final logRatio = math.log(absValue + 1) / math.log(maxAbsAmount + 1);
        final blendedRatio = 0.85 * linearRatio + 0.15 * logRatio;
        percentage =
            minVisibleWidth + blendedRatio * (maxWidth - minVisibleWidth);
        percentage = math.min(math.max(percentage, minVisibleWidth), maxWidth);
      } else if (winLost != 0) {
        percentage = 50.0;
      }

      return _ItemWithPercentage(
        item: item,
        percentage: (percentage * 100).round() / 100,
        isPositive: isPositive,
      );
    }).toList();
  }

  // ── Wraps content so it scrolls within a bounded height when this
  // widget is embedded (not full screen). In full screen mode the
  // parent page already provides its own scroll view, so we return
  // the child unchanged there.
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
    final marketingState = ref.watch(marketingProvider);
    final appModeSettings = ref.watch(appmodeSettingsProvider);
    final currentAppMode = appModeSettings.appMode;
    final fontSettings = ref.watch(fontSettingsProvider);

    _handleAppModeChange(currentAppMode);

    // Determine current data
    final bool isTargetView =
        marketingState.viewType == MarketingViewType.target;
    final List<dynamic> currentData =
        marketingState.viewType == MarketingViewType.performance
            ? marketingState.currentPerformanceData
            : marketingState.viewType == MarketingViewType.result
                ? marketingState.currentResultData
                : []; // target view — list built separately

    final bool tabsEnabled = _tabsEnabled && !marketingState.isLoading;
    final dataWithPercentages = _calculatePercentages(currentData);

    final positiveData = dataWithPercentages
        .where((item) => item.isPositive)
        .toList()
      ..sort((a, b) {
        final aVal = a.item is MarketingPerformance
            ? (a.item as MarketingPerformance).displayValue
            : (a.item as MarketingResult).displayValue;
        final bVal = b.item is MarketingPerformance
            ? (b.item as MarketingPerformance).displayValue
            : (b.item as MarketingResult).displayValue;
        return bVal.compareTo(aVal);
      });

    final negativeData = dataWithPercentages
        .where((item) => !item.isPositive)
        .toList()
      ..sort((a, b) {
        final aVal = a.item is MarketingPerformance
            ? (a.item as MarketingPerformance).displayValue
            : (a.item as MarketingResult).displayValue;
        final bVal = b.item is MarketingPerformance
            ? (b.item as MarketingPerformance).displayValue
            : (b.item as MarketingResult).displayValue;
        return aVal.compareTo(bVal);
      });

    final sortedData = [...positiveData, ...negativeData];

    // Target summary data (sorted by achievement desc)
    final targetSummary = [...marketingState.currentTargetSummary]
      ..sort((a, b) => b.achievement.compareTo(a.achievement));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    "MARKETING PERFORMANCE",
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
                      ref.read(marketingProvider.notifier).clearMarketing();
                      Navigator.pop(context);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: Text(
                                userName != null
                                    ? 'Welcome, $userName '
                                    : 'Loading...',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            body: const SafeArea(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(8),
                                child: MarketingPerformanceWidget(
                                    isFullScreen: true),
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

            // Time period tab buttons
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTabButton(
                        "Today", 0, marketingState.selectedTab == 0, tabsEnabled),
                    const SizedBox(width: 7),
                    _buildTabButton(
                        "Yesterday", 1, marketingState.selectedTab == 1, tabsEnabled),
                    const SizedBox(width: 7),
                    _buildTabButton(
                        "Monthly", 2, marketingState.selectedTab == 2, tabsEnabled),
                    const SizedBox(width: 7),
                    _buildTabButton(
                        "Last Month", 3, marketingState.selectedTab == 3, tabsEnabled),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // View type toggle (Performance / Result / Target)
            if (marketingState.selectedTab >= 0) ...[
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildViewTypeButton(
                        "Performance",
                        MarketingViewType.performance,
                        marketingState.viewType == MarketingViewType.performance,
                      ),
                      _buildViewTypeButton(
                        "Result",
                        MarketingViewType.result,
                        marketingState.viewType == MarketingViewType.result,
                      ),
                      // Target only for Monthly & Last Month tabs
                      if (marketingState.isTargetAvailable)
                        _buildViewTypeButton(
                          "Target",
                          MarketingViewType.target,
                          marketingState.viewType == MarketingViewType.target,
                          accentColor: Colors.deepPurple,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Content ──
            if (marketingState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text(
                        "Refreshing data...",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else if (isTargetView) ...[
              // ── TARGET VIEW ──
              if (targetSummary.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "No target data available",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                _wrapScrollable(
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Header intentionally omitted for Target view.
                        ...targetSummary.asMap().entries.map(
                              (entry) => _buildTargetItem(
                                entry.key + 1,
                                entry.value,
                                fontSettings,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
            ] else ...[
              // ── PERFORMANCE / RESULT VIEW ──
              if (currentData.isEmpty)
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
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: marketingState.viewType == MarketingViewType.result
                            ? Colors.grey[400]!
                            : Colors.transparent,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (marketingState.viewType == MarketingViewType.result)
                          _buildResultTableHeader(),
                        ...sortedData.map((itemWithPercentage) {
                          if (marketingState.viewType ==
                              MarketingViewType.performance) {
                            return _buildPerformanceItem(itemWithPercentage);
                          } else {
                            return _buildResultItem(itemWithPercentage);
                          }
                        }),
                      ],
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 16),

            // Legend + refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isTargetView)
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
                  )
                else
                  // Target legend
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text("Achievement %"),
                    ],
                  ),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  color: (!_refreshEnabled || marketingState.isLoading)
                      ? Colors.grey
                      : Colors.blue,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextButton.icon(
                      onPressed:
                          !_refreshEnabled || marketingState.isLoading
                              ? null
                              : _refreshCurrentTab,
                      icon: const Icon(Icons.refresh,
                          size: 14, color: Colors.white),
                      label: const Text(
                        "Refresh",
                        style:
                            TextStyle(fontSize: 16, color: Colors.white),
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

  // ── View type toggle button ──────────────────────────────────────────────
  // Widget _buildViewTypeButton(
  //   String text,
  //   MarketingViewType viewType,
  //   bool isSelected, {
  //   Color? accentColor,
  // }) {
  //   final color = accentColor ?? Colors.blue;
  //   return GestureDetector(
  //     onTap: () {
  //       final notifier = ref.read(marketingProvider.notifier);
  //       notifier.setViewType(viewType);

  //       // If switching to Target and we have no data yet, load it
  //       if (viewType == MarketingViewType.target) {
  //         final state = ref.read(marketingProvider);
  //         final hasData = state.selectedTab == 2
  //             ? state.monthlyTargetSummary.isNotEmpty
  //             : state.lastmonthTargetSummary.isNotEmpty;
  //         if (!hasData) {
  //           notifier.getTargetData(state.selectedTab);
  //         }
  //       }
  //     },
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //       decoration: BoxDecoration(
  //         color: isSelected ? color : Colors.transparent,
  //         borderRadius: BorderRadius.circular(25),
  //       ),
  //       child: Text(
  //         text,
  //         style: TextStyle(
  //           color: isSelected ? Colors.white : Colors.black87,
  //           fontWeight: FontWeight.bold,
  //           fontSize: 14,
  //         ),
  //       ),
  //     ),
  //   );
  // }
Widget _buildViewTypeButton(
  String text,
  MarketingViewType viewType,
  bool isSelected, {
  Color? accentColor,
}) {
  final color = accentColor ?? Colors.blue;
  return GestureDetector(
    onTap: () {
      final notifier = ref.read(marketingProvider.notifier);
      final state = ref.read(marketingProvider);
      notifier.setViewType(viewType);

      if (viewType == MarketingViewType.target) {
        // If switching to Target and we have no data yet, load it
        final hasData = state.selectedTab == 2
            ? state.monthlyTargetSummary.isNotEmpty
            : state.lastmonthTargetSummary.isNotEmpty;
        if (!hasData) {
          notifier.getTargetData(state.selectedTab);
        }
      } else {
        // Performance / Result tapped.
        // This is now the ONLY trigger for the performance/result API
        // call — switching between Today/Yesterday/Monthly/Last Month
        // (see _onTabSelected) no longer fetches anything by itself.
        switch (state.selectedTab) {
          case 0:
            // Today's numbers can change through the day, so always refresh.
            notifier.getTodayPerformance();
            break;
          case 1:
            if (state.yesterdayPerformance.isEmpty) {
              notifier.getYesterdayPerformance();
            }
            break;
          case 2:
            if (state.monthlyPerformance.isEmpty) {
              notifier.getMonthlyPerformance();
            }
            break;
          case 3:
            if (state.lastmonthPerformance.isEmpty) {
              notifier.getLastMonthPerformance();
            }
            break;
        }
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    ),
  );
}
  // ── Time period tab button ───────────────────────────────────────────────
  Widget _buildTabButton(
      String text, int index, bool isSelected, bool isEnabled) {
    Color borderColor;
    switch (index) {
      case 0: borderColor = Colors.orange; break;
      case 1: borderColor = Colors.green; break;
      case 2: borderColor = Colors.blue; break;
      case 3: borderColor = const Color.fromARGB(255, 203, 56, 196); break;
      default: borderColor = Colors.grey;
    }

    Color backgroundColor;
    Color textColor;
    if (!isEnabled) {
      backgroundColor = Colors.grey[200]!;
      textColor = Colors.grey[500]!;
    } else if (isSelected) {
      backgroundColor = borderColor;
      textColor = Colors.white;
    } else {
      backgroundColor = Colors.white;
      textColor = borderColor;
    }

    return GestureDetector(
      onTap: isEnabled ? () => _onTabSelected(index) : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Text(
            text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ── Performance bar item ─────────────────────────────────────────────────
  Widget _buildPerformanceItem(_ItemWithPercentage itemWithPercentage) {
    final performance = itemWithPercentage.item as MarketingPerformance;
    final percentage = itemWithPercentage.percentage;
    final double barWidthFactor = (percentage / 100.0).clamp(0.0, 1.0);

    return Consumer(
      builder: (context, ref, child) {
        final fontSettings = ref.watch(fontSettingsProvider);
        return GestureDetector(
          onTap: () => _navigateToMarketingDetail(
              performance.sm, performance.smName, performance.winLost),
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
                const SizedBox(width: 4),
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
                Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.grey[600]),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Result row item ──────────────────────────────────────────────────────
  Widget _buildResultItem(_ItemWithPercentage itemWithPercentage) {
    final result = itemWithPercentage.item as MarketingResult;

    return Consumer(
      builder: (context, ref, child) {
        final fontSettings = ref.watch(fontSettingsProvider);
        return GestureDetector(
          onTap: () => _navigateToMarketingDetailFromResult(
            result.sm,
            result.smName,
            result.winLost,
            result.mDrop,
            result.cashOut,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          result.smName,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: Colors.grey[400]),
                    ],
                  ),
                  Row(
                    children: [
                      const Expanded(flex: 1, child: SizedBox.shrink()),
                      Expanded(
                        flex: 4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _formatCurrency(result.mDrop),
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize - 1,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatCurrency(result.cashOut),
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize - 1,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatCurrency(result.winLost),
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize - 1,
                                  fontWeight: FontWeight.bold,
                                  color: result.isPositive
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                textAlign: TextAlign.right,
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
          ),
        );
      },
    );
  }

  // ── Result table header ──────────────────────────────────────────────────
  Widget _buildResultTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey[400]!, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          const Expanded(
            flex: 2,
            child: Text(
              'SM Name',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Drop',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  child: Text('Cash Out',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  child: Text('Win/Lost',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Target summary row item ──────────────────────────────────────────────
  // Row 1: row number + group name (with arrow)
  // Row 2: "Drop"        -> actual drop value (thousand-separated)
  // Row 3: "Target"      -> monthly target value (thousand-separated)
  // Row 4: "Achievement" -> achievement percentage
  Widget _buildTargetItem(
      int rowNumber, MarketingTarget target, fontSettings) {
    return GestureDetector(
      onTap: () {
        final detailRows = ref
            .read(marketingProvider.notifier)
            .getTargetDetailForGroup(target.gcode);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MarketingTargetDetailPage(
              gcode: target.gcode,
              gName: target.gName,
              actualDrop: target.actualDrop,
              mTarget: target.mTarget,
              achievement: target.achievement,
              detailRows: detailRows,
              tabTitle: ref.read(marketingProvider).currentTabTitle,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: number + group name + arrow
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$rowNumber. ${target.gName}',
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: Drop
            _buildTargetDetailRow(
              'Drop',
              _formatWithThousands(target.actualDrop),
              fontSettings,
            ),
            // Row 3: Target
            _buildTargetDetailRow(
              'Target',
              _formatWithThousands(target.mTarget),
              fontSettings,
            ),
            // Row 4: Achievement
            _buildTargetDetailRow(
              'Achievement',
              '${target.achievement.toStringAsFixed(2)}%',
              fontSettings,
              valueColor: Colors.deepPurple,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper row: label on the left, value on the right ───────────────────
  Widget _buildTargetDetailRow(
    String label,
    String value,
    fontSettings, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              color: const Color.fromARGB(255, 0, 0, 0),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            fontFeatures: const [FontFeature.tabularFigures()],
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
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

  String _formatLargeNumber(double amount) {
    if (amount == 0) return 'N/A';
    final absAmount = amount.abs();
    if (absAmount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(2)}B';
    } else if (absAmount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (absAmount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }
    return amount.toStringAsFixed(0);
  }

  // Formats a number with thousand separators, e.g. 1234567.5 -> "1,234,567.50"
  // String _formatWithThousands(double amount) {
  //   if (amount == 0) return 'N/A';
  //   final isNegative = amount < 0;
  //   final absAmount = amount.abs();
  //   final parts = absAmount.toStringAsFixed(2).split('.');
  //   final intPart = parts[0];
  //   final decPart = parts[1];

  //   final buffer = StringBuffer();
  //   for (int i = 0; i < intPart.length; i++) {
  //     final posFromEnd = intPart.length - i;
  //     buffer.write(intPart[i]);
  //     if (posFromEnd > 1 && posFromEnd % 3 == 1) {
  //       buffer.write(',');
  //     }
  //   }
  //   return '${isNegative ? '-' : ''}$buffer.$decPart';
  // }
String _formatWithThousands(double amount) {
  if (amount == 0) return 'N/A';
  final isNegative = amount < 0;
  final intPart = amount.abs().round().toString(); // use .truncate() instead of .round() if you want to chop decimals rather than round

  final buffer = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    final posFromEnd = intPart.length - i;
    buffer.write(intPart[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return '${isNegative ? '-' : ''}$buffer';
}
  // ── Navigation ───────────────────────────────────────────────────────────
  void _navigateToMarketingDetail(
      String smCode, String smName, double winLost) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketingDetailPage(
          smCode: smCode,
          smName: smName,
          winSpecificMember: winLost,
          currentTabIndex: ref.read(marketingProvider).selectedTab,
        ),
      ),
    );
  }

  void _navigateToMarketingDetailFromResult(String smCode, String smName,
      double winLost, double mDrop, double cashOut) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketingDetailPage(
          smCode: smCode,
          smName: smName,
          winSpecificMember: winLost,
          currentTabIndex: ref.read(marketingProvider).selectedTab,
          mDrop: mDrop,
          cashOut: cashOut,
        ),
      ),
    );
  }

  // ── Tab selection ─────────────────────────────────────────────────────────
  // void _onTabSelected(int index) {
  //   final notifier = ref.read(marketingProvider.notifier);
  //   final state = ref.read(marketingProvider);
  //   notifier.setSelectedTab(index);

  //   // Always reset to Performance when switching tabs
  //   notifier.setViewType(MarketingViewType.performance);

  //   if (!_refreshEnabled) {
  //     setState(() {
  //       _refreshEnabled = true;
  //     });
  //   }

  //   switch (index) {
  //     case 0:
  //       notifier.getTodayPerformance();
  //       break;
  //     case 1:
  //       if (state.yesterdayPerformance.isEmpty) {
  //         notifier.getYesterdayPerformance();
  //       }
  //       break;
  //     case 2:
  //       if (state.monthlyPerformance.isEmpty) {
  //         notifier.getMonthlyPerformance();
  //       }
  //       break;
  //     case 3:
  //       if (state.lastmonthPerformance.isEmpty) {
  //         notifier.getLastMonthPerformance();
  //       }
  //       break;
  //   }
  // }
void _onTabSelected(int index) {
  final notifier = ref.read(marketingProvider.notifier);
  notifier.setSelectedTab(index);

  // Always reset to Performance when switching tabs.
  // NOTE: switching tabs no longer triggers an API call by itself —
  // the API is now only called when the user taps the Performance or
  // Result view-type button (see _buildViewTypeButton).
  notifier.setViewType(MarketingViewType.performance);

  if (!_refreshEnabled) {
    setState(() {
      _refreshEnabled = true;
    });
  }
}
  void _refreshCurrentTab() {
    final marketingState = ref.read(marketingProvider);
    final notifier = ref.read(marketingProvider.notifier);

    // If currently on target view, refresh target data too
    if (marketingState.viewType == MarketingViewType.target &&
        marketingState.isTargetAvailable) {
      notifier.getTargetData(marketingState.selectedTab);
      return;
    }

    switch (marketingState.selectedTab) {
      case 0:
        notifier.getTodayPerformance();
        break;
      case 1:
        notifier.getYesterdayPerformance();
        break;
      case 2:
        notifier.getMonthlyPerformance();
        break;
      case 3:
        notifier.getLastMonthPerformance();
        break;
      default:
        notifier.getTodayPerformance();
        break;
    }
  }

  @override
  void dispose() {
    // Defer the state reset: mutating a StateNotifier synchronously inside
    // dispose() runs during finalizeTree/lockState and notifying listeners
    // there is illegal. Use the captured notifier (NOT `ref`) on a microtask.
    final notifier = _marketingNotifier;
    if (notifier != null) {
      Future.microtask(notifier.clearMarketing);
    }
    super.dispose();
  }
}

class _ItemWithPercentage {
  final dynamic item;
  final double percentage;
  final bool isPositive;

  _ItemWithPercentage({
    required this.item,
    required this.percentage,
    required this.isPositive,
  });
}