import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Sample data structure for marketing performance
class MarketingPerformance {
  final String name;
  final double value;
  final bool isPositive;

  MarketingPerformance({
    required this.name,
    required this.value,
    required this.isPositive,
  });
}

// Providers for different time periods
final todayPerformanceProvider = Provider<List<MarketingPerformance>>((ref) => [
      MarketingPerformance(name: "JIHANI", value: 12.9, isPositive: true),
      MarketingPerformance(name: "MR.WASANTHA", value: 10.7, isPositive: true),
    ]);

final yesterdayPerformanceProvider =
    Provider<List<MarketingPerformance>>((ref) => [
          MarketingPerformance(name: "MS. JASICA", value: 10.4, isPositive: true),
          MarketingPerformance(name: "MR.SRIDHARAN", value: 8.7, isPositive: true),
          MarketingPerformance(name: "MR.SUDESH", value: 7.8, isPositive: true),
        ]);

final monthlyPerformanceProvider =
    Provider<List<MarketingPerformance>>((ref) => [
          MarketingPerformance(name: "MR.KASUN", value: 5.3, isPositive: true),
          MarketingPerformance(name: "MS.DILRUKSHI", value: 3.8, isPositive: false),
          MarketingPerformance(name: "MR.DIMUTHU", value: 2.9, isPositive: false),
          MarketingPerformance(name: "MR.PAVAN", value: 2.6, isPositive: false),
          MarketingPerformance(name: "MR.MADHAWA", value: 2.4, isPositive: false),
        ]);

// Provider for selected tab
final selectedTabProvider = StateProvider<int>((ref) => 0);

class MarketingPerformanceWidget extends ConsumerWidget {
  const MarketingPerformanceWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);

    // Pick dataset based on tab
    List<MarketingPerformance> performanceData;
    if (selectedTab == 0) {
      performanceData = ref.watch(todayPerformanceProvider);
    } else if (selectedTab == 1) {
      performanceData = ref.watch(yesterdayPerformanceProvider);
    } else {
      performanceData = ref.watch(monthlyPerformanceProvider);
    }

    // Sort highest first
    performanceData =
        [...performanceData]..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Center(
              child: Text(
                "MARKETING PERFORMANCE",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab buttons
            Row(
              children: [
                _buildTabButton(context, ref, "Today", 0, selectedTab == 0),
                const SizedBox(width: 8),
                _buildTabButton(context, ref, "Yesterday", 1, selectedTab == 1),
                const SizedBox(width: 8),
                _buildTabButton(context, ref, "Monthly", 2, selectedTab == 2),
              ],
            ),
            const SizedBox(height: 16),

            // Performance list
            Column(
              children: performanceData
                  .map((performance) => _buildPerformanceItem(performance))
                  .toList(),
            ),

            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    const Text("Positive (+)"),
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
                    const Text("Negative (-)"),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    WidgetRef ref,
    String text,
    int index,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        ref.read(selectedTabProvider.notifier).state = index;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceItem(MarketingPerformance performance) {
    const double maxValue = 15.0;
    final double barWidthFactor =
        (performance.value / maxValue).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Name
          SizedBox(
            width: 100,
            child: Text(
              performance.name,
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
                // Background bar
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Progress bar
                FractionallySizedBox(
                  widthFactor: barWidthFactor,
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: performance.isPositive ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "${performance.value}K",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Value
          SizedBox(
            width: 40,
            child: Text(
              "${performance.value}K",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: performance.isPositive ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
