import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/screens/marketing_detail_page.dart';
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

  @override
  void initState() {
    super.initState();
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
      if (p is MarketingPerformance) {
        return p.winLost.abs();
      } else if (p is MarketingResult) {
        return p.winLost.abs();
      }
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

  @override
  Widget build(BuildContext context) {
    final marketingState = ref.watch(marketingProvider);
    final appModeSettings = ref.watch(appmodeSettingsProvider);
    final currentAppMode = appModeSettings.appMode;
    final fontSettings = ref.watch(fontSettingsProvider);

    _handleAppModeChange(currentAppMode);

    // Get current data based on view type
    final List<dynamic> currentData = marketingState.viewType ==
            MarketingViewType.performance
        ? marketingState.currentPerformanceData
        : marketingState.currentResultData;

    final bool tabsEnabled = _tabsEnabled && !marketingState.isLoading;
    final dataWithPercentages = _calculatePercentages(currentData);

    final positiveData = dataWithPercentages
        .where((item) => item.isPositive)
        .toList()
      ..sort((a, b) {
        final aValue = a.item is MarketingPerformance
            ? (a.item as MarketingPerformance).displayValue
            : (a.item as MarketingResult).displayValue;
        final bValue = b.item is MarketingPerformance
            ? (b.item as MarketingPerformance).displayValue
            : (b.item as MarketingResult).displayValue;
        return bValue.compareTo(aValue);
      });

    final negativeData = dataWithPercentages
        .where((item) => !item.isPositive)
        .toList()
      ..sort((a, b) {
        final aValue = a.item is MarketingPerformance
            ? (a.item as MarketingPerformance).displayValue
            : (a.item as MarketingResult).displayValue;
        final bValue = b.item is MarketingPerformance
            ? (b.item as MarketingPerformance).displayValue
            : (b.item as MarketingResult).displayValue;
        return aValue.compareTo(bValue);
      });

    final sortedData = [...positiveData, ...negativeData];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Reduced padding to give more space
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with expand/collapse icon
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

            // Tab buttons
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTabButton("Today", 0,
                        marketingState.selectedTab == 0, tabsEnabled),
                    const SizedBox(width: 7),
                    _buildTabButton("Yesterday", 1,
                        marketingState.selectedTab == 1, tabsEnabled),
                    const SizedBox(width: 7),
                    _buildTabButton("Monthly", 2,
                        marketingState.selectedTab == 2, tabsEnabled),
                    const SizedBox(width: 7),
                    _buildTabButton("Last Month", 3,
                        marketingState.selectedTab == 3, tabsEnabled),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // NEW: Performance/Result toggle (show for all tabs when a tab is selected)
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
                        marketingState.viewType ==
                            MarketingViewType.performance,
                      ),
                      _buildViewTypeButton(
                        "Result",
                        MarketingViewType.result,
                        marketingState.viewType == MarketingViewType.result,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Performance/Result list
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
            else if (currentData.isEmpty)
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
              Container(
                width: double.infinity, // Make container take full width
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
                    // Add table header for Result view
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
                      onPressed: !_refreshEnabled || marketingState.isLoading
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
                        ),
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

  // NEW: View type button
  Widget _buildViewTypeButton(
      String text, MarketingViewType viewType, bool isSelected) {
    return GestureDetector(
      onTap: () {
        ref.read(marketingProvider.notifier).setViewType(viewType);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
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

  Widget _buildTabButton(
      String text, int index, bool isSelected, bool isEnabled) {
    Color borderColor;
    switch (index) {
      case 0:
        borderColor = Colors.orange;
        break;
      case 1:
        borderColor = Colors.green;
        break;
      case 2:
        borderColor = Colors.blue;
        break;
      case 3:
        borderColor = const Color.fromARGB(255, 203, 56, 196);
        break;
      default:
        borderColor = Colors.grey;
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

  Widget _buildPerformanceItem(_ItemWithPercentage itemWithPercentage) {
    final performance = itemWithPercentage.item as MarketingPerformance;
    final percentage = itemWithPercentage.percentage;
    final double barWidthFactor = (percentage / 100.0).clamp(0.0, 1.0);

    return Consumer(
      builder: (context, ref, child) {
        final fontSettings = ref.watch(fontSettingsProvider);
        
        return GestureDetector(
          onTap: () {
            _navigateToMarketingDetail(
                performance.sm, performance.smName, performance.winLost);
          },
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
                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
              ],
            ),
          ),
        );
      },
    );
  }

  // NEW: Build result item with two-row layout (similar to screenshot)
  Widget _buildResultItem(_ItemWithPercentage itemWithPercentage) {
    final result = itemWithPercentage.item as MarketingResult;

    return Consumer(
      builder: (context, ref, child) {
        final fontSettings = ref.watch(fontSettingsProvider);
        
        return GestureDetector(
          onTap: () {
            // Navigate to detail page with MDrop and CashOut
            _navigateToMarketingDetailFromResult(
              result.sm,
              result.smName,
              result.winLost,
              result.mDrop,
              result.cashOut,
            );
          },
          child: Container(
            //margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First Row: SM Name and values row container
                  Row(
                    children: [
                      // SM Name (flex 3 to match header)
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
                      // Empty space for arrow alignment
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
               //   const SizedBox(height: 12), // Space between rows
                  // Second Row: Grid layout for three values aligned with header
                  Row(
                    children: [
                      // Left padding to align with header (flex 3 for SM Name space)
                      const Expanded(
                        flex: 1,
                        child: SizedBox.shrink(),
                      ),
                      // Three value columns (flex 5 to match header)
                      Expanded(
                        flex: 4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // MDrop Column
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
                            // Cash Out Column
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
                            // Win/Lost Column
                            Expanded(
                              child: Text(
                                _formatCurrency(result.winLost),
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize - 1,
                                  fontWeight: FontWeight.bold,
                                  color: result.isPositive ? Colors.green : Colors.red,
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

  // NEW: Build table header for Result view
  Widget _buildResultTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(
          bottom: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          // SM Name Header (reduced flex to give more space to values)
          const Expanded(
            flex: 2,
            child: Text(
              'SM Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Three value columns (increased flex for more space)
          Expanded(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // MDrop Header
                Expanded(
                  child: Text(
                    'MDrop',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Cash Out Header
                Expanded(
                  child: Text(
                    'Cash Out',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Win/Lost Header
                Expanded(
                  child: Text(
                    'Win/Lost',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build data columns in Result cards (no longer used but kept for compatibility)
  Widget _buildDataColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'monospace',
          ),
          textAlign: TextAlign.center,
        ),
      ],
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

  // NEW: Navigation from Result view with MDrop and CashOut
  void _navigateToMarketingDetailFromResult(
      String smCode, String smName, double winLost, double mDrop, double cashOut) {
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

  void _onTabSelected(int index) {
    final notifier = ref.read(marketingProvider.notifier);
    final state = ref.read(marketingProvider);
    notifier.setSelectedTab(index);
    
    // Reset to Performance view when changing tabs
    notifier.setViewType(MarketingViewType.performance);
    
    if (!_refreshEnabled) {
      setState(() {
        _refreshEnabled = true;
      });
    }

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
      case 3:
        if (state.lastmonthPerformance.isEmpty) {
          notifier.getLastMonthPerformance();
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
    super.dispose();
  }
}

// Helper class
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