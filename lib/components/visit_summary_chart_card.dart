import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class VisitSummaryChartCard extends StatelessWidget {
  final int? todayCount;
  final int? yesterdayCount;
  final int? monthlyCount;

  const VisitSummaryChartCard({
    super.key,
    required this.todayCount,
    required this.yesterdayCount,
    required this.monthlyCount,
  });

  static const Color _todayColor = Color.fromARGB(255, 228, 117, 14);
  static const Color _yesterdayColor = Colors.green;
  static const Color _monthlyColor = Color.fromARGB(255, 42, 125, 192);

  bool get _isLoading =>
      todayCount == null || yesterdayCount == null || monthlyCount == null;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────────────────
            const Text(
              'VISIT SUMMARY',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            _isLoading
                ? const _SkeletonLoader()
                : Column(
                    children: [
                      // ── Multi-ring half-donut ────────────────────────
                      Center(
                        child: SizedBox(
                          width: 260,
                          height: 140,
                          child: CustomPaint(
                            painter: _MultiRingHalfDonutPainter(
                              todayCount: todayCount!,
                              yesterdayCount: yesterdayCount!,
                              monthlyCount: monthlyCount!,
                              todayColor: _todayColor,
                              yesterdayColor: _yesterdayColor,
                              monthlyColor: _monthlyColor,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── 3 separate bar rows ──────────────────────────
                      _BarRow(
                        label: 'Monthly',
                        count: monthlyCount!,
                        maxCount: monthlyCount!,
                        color: _monthlyColor,
                      ),
                      const SizedBox(height: 12),
                      _BarRow(
                        label: 'Yesterday',
                        count: yesterdayCount!,
                        maxCount: monthlyCount!,
                        color: _yesterdayColor,
                      ),
                      const SizedBox(height: 12),
                      _BarRow(
                        label: 'Today',
                        count: todayCount!,
                        maxCount: monthlyCount!,
                        color: _todayColor,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer skeleton loader
// ─────────────────────────────────────────────────────────────────────────────
class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Column(
          children: [
            // ── Half-donut skeleton ──────────────────────────────────
            Center(
              child: SizedBox(
                width: 260,
                height: 140,
                child: CustomPaint(
                  painter: _SkeletonDonutPainter(
                    shimmerProgress: _shimmerAnimation.value,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── 3 bar row skeletons ──────────────────────────────────
            ...[0.9, 0.55, 0.3].map(
              (width) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SkeletonBarRow(
                  barWidthFactor: width,
                  shimmerProgress: _shimmerAnimation.value,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Paints three concentric grey half-donut arcs with a shimmer sweep.
class _SkeletonDonutPainter extends CustomPainter {
  final double shimmerProgress;

  const _SkeletonDonutPainter({required this.shimmerProgress});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 16.0;
    const gap = 12.0;

    final cx = size.width / 2;
    final cy = size.height;

    final outerR = size.height - strokeWidth / 2 - 2;
    final middleR = outerR - strokeWidth - gap;
    final innerR = middleR - strokeWidth - gap;

    for (final r in [outerR, middleR, innerR]) {
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

      // Base grey arc
      canvas.drawArc(
        rect,
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = Colors.grey.shade200
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      // Shimmer sweep on top
      final shimmerPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: math.pi,
          endAngle: 2 * math.pi,
          colors: const [
            Colors.transparent,
            Color(0x55FFFFFF),
            Colors.transparent,
          ],
          stops: [
            (shimmerProgress.clamp(-1.5, 1.5) + 1.5) / 3 - 0.15,
            (shimmerProgress.clamp(-1.5, 1.5) + 1.5) / 3,
            (shimmerProgress.clamp(-1.5, 1.5) + 1.5) / 3 + 0.15,
          ].map((s) => s.clamp(0.0, 1.0)).toList(),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, math.pi, math.pi, false, shimmerPaint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonDonutPainter old) =>
      old.shimmerProgress != shimmerProgress;
}

/// A single shimmer bar-row skeleton.
class _SkeletonBarRow extends StatelessWidget {
  final double barWidthFactor;
  final double shimmerProgress;

  const _SkeletonBarRow({
    required this.barWidthFactor,
    required this.shimmerProgress,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Normalise shimmerProgress (-1.5 → 1.5) to a 0→1 gradient stop centre
        final shimmerPos = ((shimmerProgress + 1.5) / 3.0).clamp(0.0, 1.0);

        final shimmerGradient = LinearGradient(
          colors: const [
            Color(0xFFE0E0E0),
            Color(0xFFF5F5F5),
            Color(0xFFE0E0E0),
          ],
          stops: [
            (shimmerPos - 0.2).clamp(0.0, 1.0),
            shimmerPos,
            (shimmerPos + 0.2).clamp(0.0, 1.0),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + count placeholders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ShimmerBox(
                  width: 70,
                  height: 12,
                  gradient: shimmerGradient,
                ),
                _ShimmerBox(
                  width: 40,
                  height: 12,
                  gradient: shimmerGradient,
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Progress bar placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 10,
                width: width * barWidthFactor,
                decoration: BoxDecoration(
                  gradient: shimmerGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final LinearGradient gradient;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bar row: dot + label + progress bar + count
// ─────────────────────────────────────────────────────────────────────────────
class _BarRow extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;
  final Color color;

  const _BarRow({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    final pct = maxCount > 0 ? (count / maxCount).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            Text(
              formatter.format(count),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3 concentric half-donut rings
// ─────────────────────────────────────────────────────────────────────────────
class _MultiRingHalfDonutPainter extends CustomPainter {
  final int todayCount;
  final int yesterdayCount;
  final int monthlyCount;
  final Color todayColor;
  final Color yesterdayColor;
  final Color monthlyColor;

  const _MultiRingHalfDonutPainter({
    required this.todayCount,
    required this.yesterdayCount,
    required this.monthlyCount,
    required this.todayColor,
    required this.yesterdayColor,
    required this.monthlyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 16.0;
    const gap = 12.0;

    final cx = size.width / 2;
    final cy = size.height;

    final outerR = size.height - strokeWidth / 2 - 2;
    final middleR = outerR - strokeWidth - gap;
    final innerR = middleR - strokeWidth - gap;

    final total = monthlyCount > 0 ? monthlyCount.toDouble() : 1.0;
    final yesterdayPct = (yesterdayCount / total).clamp(0.0, 1.0);
    final todayPct = (todayCount / total).clamp(0.0, 1.0);

    _ring(canvas, cx, cy, outerR, strokeWidth, Colors.grey.shade200, 1.0);
    _ring(canvas, cx, cy, outerR, strokeWidth, monthlyColor, 1.0);

    _ring(canvas, cx, cy, middleR, strokeWidth, Colors.grey.shade200, 1.0);
    _ring(canvas, cx, cy, middleR, strokeWidth, yesterdayColor, yesterdayPct);

    _ring(canvas, cx, cy, innerR, strokeWidth, Colors.grey.shade200, 1.0);
    _ring(canvas, cx, cy, innerR, strokeWidth, todayColor, todayPct);

    _centreLabel(canvas, cx, cy, innerR, strokeWidth);
  }

  void _ring(Canvas canvas, double cx, double cy, double radius,
      double strokeWidth, Color color, double pct) {
    if (pct <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      math.pi,
      math.pi * pct,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  void _centreLabel(Canvas canvas, double cx, double cy,
      double innerRadius, double strokeWidth) {
    final formatter = NumberFormat.decimalPattern();

    final countTp = TextPainter(
      text: TextSpan(
        text: formatter.format(todayCount),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: todayColor,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final labelTp = TextPainter(
      text: const TextSpan(
        text: 'Today',
        style: TextStyle(fontSize: 9, color: Colors.black45),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final totalH = countTp.height + 2 + labelTp.height;
    final baseY = cy - strokeWidth / 2 - 6;

    countTp.paint(canvas, Offset(cx - countTp.width / 2, baseY - totalH));
    labelTp.paint(canvas,
        Offset(cx - labelTp.width / 2, baseY - totalH + countTp.height + 2));
  }

  @override
  bool shouldRepaint(_MultiRingHalfDonutPainter old) =>
      old.todayCount != todayCount ||
      old.yesterdayCount != yesterdayCount ||
      old.monthlyCount != monthlyCount;
}