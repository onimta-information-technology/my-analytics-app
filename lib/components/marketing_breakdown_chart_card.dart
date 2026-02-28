import 'dart:math';

import 'package:ballys_reservation_app/models/marketing_group.dart';
import 'package:ballys_reservation_app/providers/guests_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const List<Color> _sliceColors = [
  Color(0xFFE4750E),
  Color(0xFF2A7DC0),
  Color(0xFF4CAF50),
  Color(0xFFE91E63),
  Color(0xFF9C27B0),
  Color(0xFFFF9800),
  Color(0xFF00BCD4),
  Color(0xFF795548),
];

// 🔹 Track which periods have finished loading (set by GuestsNotifier)
//    We use a simple provider that mirrors whether each period's list
//    has been written at least once.
class MarketingBreakdownHalfPieCard extends ConsumerStatefulWidget {
  const MarketingBreakdownHalfPieCard({super.key});

  @override
  ConsumerState<MarketingBreakdownHalfPieCard> createState() =>
      _MarketingBreakdownHalfPieCardState();
}

class _MarketingBreakdownHalfPieCardState
    extends ConsumerState<MarketingBreakdownHalfPieCard> {
  int _selectedPeriod = 0;

  // 🔹 Track which periods have been loaded at least once
  final Set<int> _loadedPeriods = {};

  static const List<String> _periodLabels = ['Today', 'Yesterday', 'Monthly'];
  static const List<Color> _tabColors = [
    Color(0xFFE4750E),
    Color(0xFF4CAF50),
    Color(0xFF2A7DC0),
  ];

  @override
  Widget build(BuildContext context) {
    final guestsState = ref.watch(guestsProvider);

    final allGroups = [
      guestsState.todayMarketingGroups,
      guestsState.yesterdayMarketingGroups,
      guestsState.monthlyMarketingGroups,
    ];

    // 🔹 Mark a period as loaded the moment its list is non-empty
    for (int i = 0; i < allGroups.length; i++) {
      if (allGroups[i].isNotEmpty) _loadedPeriods.add(i);
    }

    final selectedGroups = allGroups[_selectedPeriod];
    final isLoaded = _loadedPeriods.contains(_selectedPeriod);
    final total = selectedGroups.fold<int>(0, (s, g) => s + g.rc);

    // 🔹 Filter out the sentinel "No Data" / empty entries for display
    final displayGroups =
        selectedGroups.where((g) => g.gCode.isNotEmpty && g.rc > 0).toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Row(
              children: [
                Icon(Icons.pie_chart_rounded,
                    color: Color(0xFF2A7DC0), size: 22),
                SizedBox(width: 8),
                Text(
                  'Visit Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Period tabs
            _PeriodTabBar(
              selectedIndex: _selectedPeriod,
              labels: _periodLabels,
              colors: _tabColors,
              onTap: (i) => setState(() => _selectedPeriod = i),
            ),
            const SizedBox(height: 16),

            // Chart
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: !isLoaded
                  ? const _LoadingPlaceholder()
                  : displayGroups.isEmpty
                      ? const _EmptyPlaceholder()
                      : _HalfPieSection(
                          key: ValueKey('$_selectedPeriod-${displayGroups.length}'),
                          groups: displayGroups,
                          total: total,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Half-pie + legend
// ────────────────────────────────────────────────────────────────────────────
class _HalfPieSection extends StatefulWidget {
  final List<MarketingGroup> groups;
  final int total;

  const _HalfPieSection({super.key, required this.groups, required this.total});

  @override
  State<_HalfPieSection> createState() => _HalfPieSectionState();
}

class _HalfPieSectionState extends State<_HalfPieSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return SizedBox(
              height: 190,
              child: GestureDetector(
                onTapUp: (d) => _handleTap(d, context),
                child: CustomPaint(
                  painter: _HalfPiePainter(
                    groups: widget.groups,
                    total: widget.total,
                    progress: _animation.value,
                    hoveredIndex: _hoveredIndex,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.total.toString(),
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                          const Text('Total Visits',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(widget.groups.length, (i) {
            final g = widget.groups[i];
            final pct = widget.total > 0
                ? (g.rc / widget.total * 100).toStringAsFixed(1)
                : '0.0';
            final color = _sliceColors[i % _sliceColors.length];
            final isActive = _hoveredIndex == null || _hoveredIndex == i;

            return GestureDetector(
              onTap: () => setState(
                  () => _hoveredIndex = _hoveredIndex == i ? null : i),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isActive ? 1.0 : 0.35,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('${g.gName} ($pct%)',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black87)),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _handleTap(TapUpDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);
    final size = box.size;

    final center = Offset(size.width / 2, 170);
    final radius = (size.width / 2) * 0.88;
    final innerRadius = radius * 0.55;

    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance < innerRadius || distance > radius) {
      setState(() => _hoveredIndex = null);
      return;
    }

    double total = widget.groups.fold(0, (s, g) => s + g.rc).toDouble();
    double start = 0;
    for (int i = 0; i < widget.groups.length; i++) {
      final sweep = (widget.groups[i].rc / total) * pi;
      final sliceStart = pi + start;
      final sliceEnd = sliceStart + sweep;

      double a = atan2(dy, dx);
      if (a < 0) a += 2 * pi;
      double ss = sliceStart < 0 ? sliceStart + 2 * pi : sliceStart;
      double se = sliceEnd < 0 ? sliceEnd + 2 * pi : sliceEnd;

      if (a >= ss && a <= se) {
        setState(() => _hoveredIndex = _hoveredIndex == i ? null : i);
        return;
      }
      start += sweep;
    }
    setState(() => _hoveredIndex = null);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Painter
// ────────────────────────────────────────────────────────────────────────────
class _HalfPiePainter extends CustomPainter {
  final List<MarketingGroup> groups;
  final int total;
  final double progress;
  final int? hoveredIndex;

  _HalfPiePainter({
    required this.groups,
    required this.total,
    required this.progress,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = (size.width / 2) * 0.88;
    final innerRadius = radius * 0.55;
    final strokeWidth = radius - innerRadius;

    double startAngle = pi;
    final totalSweep = pi * progress;

    for (int i = 0; i < groups.length; i++) {
      final fraction = groups[i].rc / total;
      final sweep = fraction * totalSweep;
      final color = _sliceColors[i % _sliceColors.length];
      final isHovered = hoveredIndex == i;
      final isOtherHovered = hoveredIndex != null && !isHovered;

      final paint = Paint()
        ..color = isOtherHovered ? color.withOpacity(0.3) : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? strokeWidth + 6 : strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius + strokeWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );

      if (progress > 0.85 && fraction > 0.07) {
        final midAngle = startAngle + sweep / 2;
        final labelRadius = innerRadius + strokeWidth / 2;
        final labelPos = Offset(
          center.dx + labelRadius * cos(midAngle),
          center.dy + labelRadius * sin(midAngle),
        );

        final tp = TextPainter(
          text: TextSpan(
            text: '${(fraction * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.white.withOpacity(progress),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
      }

      startAngle += sweep + (pi / 180 * 1.5);
    }
  }

  @override
  bool shouldRepaint(_HalfPiePainter old) =>
      old.progress != progress || old.hoveredIndex != hoveredIndex;
}

// ────────────────────────────────────────────────────────────────────────────
// Period tab bar
// ────────────────────────────────────────────────────────────────────────────
class _PeriodTabBar extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final List<Color> colors;
  final ValueChanged<int> onTap;

  const _PeriodTabBar({
    required this.selectedIndex,
    required this.labels,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final isSelected = i == selectedIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < labels.length - 1 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? colors[i] : colors[i].withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : colors[i],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Placeholders
// ────────────────────────────────────────────────────────────────────────────
class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 12),
          Text('Loading breakdown…',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text('No data available',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ),
    );
  }
}