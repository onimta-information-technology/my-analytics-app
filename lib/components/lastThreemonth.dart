import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Simple data holder for one month's guest count.
/// Swap the mock list in [LastThreeMonthsGuestCard._mockData] with real
/// API data later — the UI doesn't need to change, just the data source.
class MonthlyGuestData {
  final String monthLabel;
  final int guestCount;

  const MonthlyGuestData({
    required this.monthLabel,
    required this.guestCount,
  });
}

/// 🎨 DESIGN-ONLY CARD — no API call wired up yet.
/// Shows guest counts for the last 3 months as a simple horizontal
/// bar comparison, matching the visual language of
/// MarketingPerformanceWidget (label + bar + count).
///
/// To wire this up later:
/// 1. Replace `data` with a value coming from a provider
///    (e.g. ref.watch(lastThreeMonthsGuestProvider)).
/// 2. Add a loading / error state the same way MarketingPerformanceWidget
///    handles `marketingState.isLoading`.
class LastThreeMonthsGuestCard extends StatelessWidget {
  final List<MonthlyGuestData>? data;

  const LastThreeMonthsGuestCard({super.key, this.data});

  // Mock data so the card has something to render before the API exists.
  static List<MonthlyGuestData> _mockData() {
    final now = DateTime.now();
    final formatter = DateFormat('MMMM');
    return List.generate(3, (i) {
      final monthDate = DateTime(now.year, now.month - (2 - i), 1);
      final mockCounts = [842, 915, 1023]; // oldest -> newest
      return MonthlyGuestData(
        monthLabel: formatter.format(monthDate),
        guestCount: mockCounts[i],
      );
    });
  }

  static const List<Color> _barColors = [
    Color(0xFF8E7CC3), // light purple - oldest month
    Color(0xFF5B8DEF), // blue - middle month
    Color(0xFF2A7DC0), // deep blue - most recent month
  ];

  @override
  Widget build(BuildContext context) {
    final months = data ?? _mockData();
    final formatter = NumberFormat.decimalPattern();
    final maxCount = months.isEmpty
        ? 1
        : months.map((m) => m.guestCount).reduce((a, b) => a > b ? a : b);

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
                    "LAST 3 MONTHS GUESTS",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Small badge so it's obvious this is a design preview
                // until the real API is connected. Remove once wired up.
                // Container(
                //   padding:
                //       const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                //   decoration: BoxDecoration(
                //     color: Colors.amber[100],
                //     borderRadius: BorderRadius.circular(12),
                //     border: Border.all(color: Colors.amber[400]!),
                //   ),
                //   // child: Text(
                //   //   "Design preview",
                //   //   style: TextStyle(
                //   //     fontSize: 11,
                //   //     fontWeight: FontWeight.w600,
                //   //     color: Colors.amber[800],
                //   //   ),
                //   // ),
                // ),
              ],
            ),
            const SizedBox(height: 16),

            // Bars — one row per month
            ...List.generate(months.length, (index) {
              final month = months[index];
              final barColor = _barColors[index % _barColors.length];
              final widthFactor =
                  maxCount == 0 ? 0.0 : month.guestCount / maxCount;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        month.monthLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: widthFactor.clamp(0.0, 1.0),
                            child: Container(
                              height: 26,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        formatter.format(month.guestCount),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 4),
            Center(
              child: Text(
                "Values shown are placeholders — live data coming soon",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}