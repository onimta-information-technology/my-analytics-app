import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/screens/marketing_detail_page.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
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
  // Flag to disable tabs initially
  bool _tabsEnabled = false;
  AppMode? _previousAppMode;
  String? userName;
  @override
  void initState() {
    super.initState();
    _loadUserName();
    // Enable tabs after a short delay (no data loading)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enableTabsAfterDelay();
    });
  }

  void _enableTabsAfterDelay() async {
    // Wait a brief moment then enable tabs
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
    // Only handle app mode changes if a tab is actually selected and there was a previous mode
    if (_previousAppMode != null &&
        _previousAppMode != currentAppMode &&
        ref.read(marketingProvider).selectedTab != -1) {
      print('=== App Mode Changed in MarketingPerformanceWidget ===');
      print('Previous: $_previousAppMode, Current: $currentAppMode');

      // Only refresh if user has already selected a tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(marketingProvider.notifier).onAppModeChanged(currentAppMode);
        }
      });
    }
    _previousAppMode = currentAppMode;
  }

  // New method to calculate percentage using the React Native logic
  List<MarketingPerformanceWithPercentage> _calculatePercentages(
    List<MarketingPerformance> data,
  ) {
    if (data.isEmpty) return [];

    // Find the maximum absolute amount
    final maxAbsAmount = data
        .map((p) => p.winLost.abs())
        .reduce((a, b) => math.max(a, b));

    const double minVisibleWidth = 5.0;
    const double maxWidth = 100.0;

    return data.map((person) {
      double percentage = 0.0;

      if (maxAbsAmount > 0 && person.winLost != 0) {
        final absValue = person.winLost.abs();
        final linearRatio = absValue / maxAbsAmount;
        final logRatio = math.log(absValue + 1) / math.log(maxAbsAmount + 1);
        final blendedRatio = 0.85 * linearRatio + 0.15 * logRatio;
        percentage =
            minVisibleWidth + blendedRatio * (maxWidth - minVisibleWidth);
        percentage = math.min(math.max(percentage, minVisibleWidth), maxWidth);
      } else if (person.winLost != 0) {
        percentage = 50.0;
      }

      return MarketingPerformanceWithPercentage(
        performance: person,
        percentage: (percentage * 100).round() / 100,
      );
    }).toList();
  }

  // void _handleAppModeChange(AppMode currentAppMode) {
  //   if (_previousAppMode != null && _previousAppMode != currentAppMode) {
  //     print('=== App Mode Changed in MarketingPerformanceWidget ===');
  //     print('Previous: $_previousAppMode, Current: $currentAppMode');

  //     // Refresh ALL tabs when app mode changes
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       if (mounted) {
  //         ref.read(marketingProvider.notifier).onAppModeChanged(currentAppMode);
  //       }
  //     });
  //   }
  //   _previousAppMode = currentAppMode;
  // }

  @override
  Widget build(BuildContext context) {
    final marketingState = ref.watch(marketingProvider);
    final appModeSettings = ref.watch(appmodeSettingsProvider);
    final currentAppMode = appModeSettings.appMode;

    // Handle app mode changes
    _handleAppModeChange(currentAppMode);

    final currentPerformanceData = marketingState.currentPerformanceData;

    // Tabs are enabled after delay
    final bool tabsEnabled = _tabsEnabled && !marketingState.isLoading;

    // Calculate percentages using the new logic
    final dataWithPercentages = _calculatePercentages(currentPerformanceData);

    // Separate positive and negative values, then sort each group
    final positiveData =
        dataWithPercentages
            .where((item) => item.performance.isPositive)
            .toList()
          ..sort(
            (a, b) => b.performance.displayValue.compareTo(
              a.performance.displayValue,
            ),
          ); // Highest positive first

    final negativeData =
        dataWithPercentages
            .where((item) => !item.performance.isPositive)
            .toList()
          ..sort(
            (a, b) => a.performance.displayValue.compareTo(
              b.performance.displayValue,
            ),
          ); // Lowest negative first (most negative)

    // Combine: positives at top, negatives at bottom
    final sortedData = [...positiveData, ...negativeData];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with expand/collapse icon and app mode indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // if (!widget.isFullScreen)
                      const Text(
                        "MARKETING PERFORMANCE",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      // Text(
                      //   "Mode: ${currentAppMode.toString().split('.').last}",
                      //   style: TextStyle(
                      //     fontSize: 12,
                      //     color: Colors.grey[600],
                      //     fontWeight: FontWeight.w500,
                      //   ),
                      // ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Show loading indicator when refreshing
                    // if (marketingState.isLoading)
                    //   const Padding(
                    //     padding: EdgeInsets.only(right: 8.0),
                    //     child: SizedBox(
                    //       width: 16,
                    //       height: 16,
                    //       child: CircularProgressIndicator(strokeWidth: 2),
                    //     ),
                    //   ),
                    // Expand/collapse button
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
                                  // title: const Text("Marketing Performance"),
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
              ],
            ),

            const SizedBox(height: 16),

            // Tab buttons - Updated to handle enabled/disabled state
            Row(
              children: [
                _buildTabButton(
                  "Today",
                  0,
                  marketingState.selectedTab == 0,
                  tabsEnabled,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  "Yesterday",
                  1,
                  marketingState.selectedTab == 1,
                  tabsEnabled,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  "Monthly",
                  2,
                  marketingState.selectedTab == 2,
                  tabsEnabled,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Performance list with loading/error handling
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
            else if (currentPerformanceData.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "No performance data available",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Show data count and current tab info
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Text(
                        //   "${marketingState.currentTabTitle} (${sortedData.length} items)",
                        //   style: TextStyle(
                        //     fontSize: 12,
                        //     color: Colors.grey[600],
                        //     fontWeight: FontWeight.w500,
                        //   ),
                        // ),
                        // Text(
                        //   "Last updated: ${DateTime.now().toString().substring(11, 19)}",
                        //   style: TextStyle(
                        //     fontSize: 10,
                        //     color: Colors.grey[500],
                        //   ),
                        // ),
                      ],
                    ),
                  ),

                  // Performance items
                  ...sortedData.map(
                    (performanceWithPercentage) =>
                        _buildPerformanceItem(performanceWithPercentage),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Legend with refresh button
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

                // Manual refresh button
                // TextButton.icon(
                //   onPressed: marketingState.isLoading
                //       ? null
                //       : _refreshCurrentTab,
                //   icon: Icon(
                //     Icons.refresh,
                //     size: 16,
                //     color: marketingState.isLoading ? Colors.grey : Colors.blue,
                //   ),
                //   label: Text(
                //     "Refresh",
                //     style: TextStyle(
                //       fontSize: 12,
                //       color: marketingState.isLoading
                //           ? Colors.grey
                //           : Colors.blue,
                //     ),
                //   ),
                // ),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  color: marketingState.isLoading ? Colors.grey : Colors.blue,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      // vertical: 1,
                    ),
                    child: TextButton.icon(
                      onPressed: marketingState.isLoading
                          ? null
                          : _refreshCurrentTab,
                      icon: const Icon(
                        Icons.refresh,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Refresh",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          //fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, // keep it compact
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

  Widget _buildTabButton(
    String text,
    int index,
    bool isSelected,
    bool isEnabled,
  ) {
    // Define border color for each button
    Color borderColor;
    switch (index) {
      case 0:
        borderColor = Colors.orange; // Today
        break;
      case 1:
        borderColor = Colors.green; // Yesterday
        break;
      case 2:
        borderColor = Colors.blue; // Monthly
        break;
      default:
        borderColor = Colors.grey;
    }

    // Colors depending on selected/enabled
    Color backgroundColor;
    Color textColor;

    if (!isEnabled) {
      backgroundColor = Colors.grey[200]!;
      textColor = Colors.grey[500]!;
    } else if (isSelected) {
      backgroundColor = borderColor; // Fill with border color
      textColor = Colors.white;
    } else {
      backgroundColor = Colors.white;
      textColor = borderColor; // Text same as border color
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

  Widget _buildPerformanceItem(
    MarketingPerformanceWithPercentage performanceWithPercentage,
  ) {
    final performance = performanceWithPercentage.performance;
    final percentage = performanceWithPercentage.percentage;

    // Convert percentage to a factor between 0.0 and 1.0 for the progress bar
    final double barWidthFactor = (percentage / 100.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        _navigateToMarketingDetail(performance);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
        ),
        child: Row(
          children: [
            // Name
            SizedBox(
              width: 120,
              child: Text(
                performance.smName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // Progress bar
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

            // // Value display
            // SizedBox(
            //   width: 60,
            //   child: Text(
            //     performance.displayValue.toString(),
            //     style: TextStyle(
            //       fontSize: 10,
            //       fontWeight: FontWeight.bold,
            //       color: performance.isPositive ? Colors.green : Colors.red,
            //     ),
            //     textAlign: TextAlign.end,
            //   ),
            // ),
            // const SizedBox(width: 4),

            // Add an arrow icon to indicate it's clickable
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  void _navigateToMarketingDetail(MarketingPerformance performance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketingDetailPage(
          smCode: performance.sm,
          smName: performance.smName,
          winSpecificMember: performance.winLost,
          currentTabIndex: ref.read(marketingProvider).selectedTab,
        ),
      ),
    );
  }

  void _onTabSelected(int index) {
    final notifier = ref.read(marketingProvider.notifier);
    final state = ref.read(marketingProvider);
    notifier.setSelectedTab(index);

    // Load data based on selected tab
    switch (index) {
      case 0:
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
    }
  }

  void _refreshCurrentTab() {
    final marketingState = ref.read(marketingProvider);
    final notifier = ref.read(marketingProvider.notifier);

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
      default:
        notifier.getTodayPerformance();
        break;
    }
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }
}

// Helper class to store performance data with calculated percentage
class MarketingPerformanceWithPercentage {
  final MarketingPerformance performance;
  final double percentage;

  MarketingPerformanceWithPercentage({
    required this.performance,
    required this.percentage,
  });
}
