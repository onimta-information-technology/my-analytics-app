import 'dart:math';
import 'dart:ui' as ui;

import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/marketing_group.dart';
import 'package:ballys_reservation_app/providers/guests_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Groups guests by country, sorted by count desc
Map<String, List<Guest>> groupByCountry(List<Guest> guests) {
  final Map<String, List<Guest>> grouped = {};
  for (final g in guests) {
    final key = g.country.isNotEmpty ? g.country : 'Unknown';
    grouped.putIfAbsent(key, () => []).add(g);
  }
  return Map.fromEntries(
    grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length)),
  );
}

const List<Color> _sliceColors = [
  Color(0xFFE91E63),
  Color(0xFF00BCD4),
  Color(0xFFE4750E),
  Color(0xFF2A7DC0),
  Color(0xFF4CAF50),
  Color(0xFFE91E63),
  Color(0xFF9C27B0),
  Color(0xFFFF9800),
  Color(0xFF00BCD4),
  Color(0xFF795548),
];

class MarketingBreakdownHalfPieCard extends ConsumerStatefulWidget {
  const MarketingBreakdownHalfPieCard({super.key});

  @override
  ConsumerState<MarketingBreakdownHalfPieCard> createState() =>
      _MarketingBreakdownHalfPieCardState();
}

class _MarketingBreakdownHalfPieCardState
    extends ConsumerState<MarketingBreakdownHalfPieCard> {
  int _selectedPeriod = 0;
  String? _myDataCode;

  final Set<int> _loadedPeriods = {};

  static const List<String> _periodLabels = ['Today', 'Yesterday', 'Monthly'];
  static const List<Color> _tabColors = [
    Color(0xFFE4750E),
    Color(0xFF4CAF50),
    Color(0xFF2A7DC0),
  ];

  @override
  void initState() {
    super.initState();
    _loadMyDataCode();
  }

  Future<void> _loadMyDataCode() async {
    final code = await StorageUtil.getMarketingCode();
    if (mounted) setState(() => _myDataCode = code);
  }

  @override
  Widget build(BuildContext context) {
    final guestsState = ref.watch(guestsProvider);

    final allGroups = [
      guestsState.todayMarketingGroups,
      guestsState.yesterdayMarketingGroups,
      guestsState.monthlyMarketingGroups,
    ];

    final allMarketingGuests = [
      guestsState.todayAllMarketingGuests,
      guestsState.yesterdayAllMarketingGuests,
      guestsState.monthlyAllMarketingGuests,
    ];

    final allNonMarketingGuests = [
      guestsState.todayNonMarketingGuests,
      guestsState.yesterdayNonMarketingGuests,
      guestsState.monthlyNonMarketingGuests,
    ];

    final myDataGuests = [
      guestsState.todayGuests,
      guestsState.yesterdayGuests,
      guestsState.monthlyGuests,
    ];

    for (int i = 0; i < allGroups.length; i++) {
      if (allGroups[i].isNotEmpty) _loadedPeriods.add(i);
    }

    final selectedGroups = allGroups[_selectedPeriod];
    final isLoaded = _loadedPeriods.contains(_selectedPeriod);
    final total = selectedGroups.fold<int>(0, (s, g) => s + g.rc);

    final displayGroups = selectedGroups
        .where((g) => g.gCode.isNotEmpty && g.rc > 0)
        .toList()
      ..sort((a, b) => b.rc.compareTo(a.rc));

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart_rounded,
                    color: Color(0xFF2A7DC0), size: 22),
                SizedBox(width: 8),
                Text(
                  'Visit Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _PeriodTabBar(
              selectedIndex: _selectedPeriod,
              labels: _periodLabels,
              colors: _tabColors,
              onTap: (i) => setState(() => _selectedPeriod = i),
              fontSize: 15,
            ),
            const SizedBox(height: 16),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: !isLoaded
                  ? const _LoadingPlaceholder()
                  : displayGroups.isEmpty
                      ? const _EmptyPlaceholder()
                      : _HalfPieSection(
                          key: ValueKey(
                              '$_selectedPeriod-${displayGroups.length}'),
                          groups: displayGroups,
                          total: total,
                          myDataCode: _myDataCode,
                          selectedPeriod: _selectedPeriod,
                          tabColors: _tabColors,
                          marketingGuests: allMarketingGuests[_selectedPeriod],
                          nonMarketingGuests:
                              allNonMarketingGuests[_selectedPeriod],
                          myDataGuests: myDataGuests[_selectedPeriod],
                          periodLabel: _periodLabels[_selectedPeriod],
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
  final String? myDataCode;
  final int selectedPeriod;
  final List<Color> tabColors;
  final List<Guest> marketingGuests;
  final List<Guest> nonMarketingGuests;
  final List<Guest> myDataGuests;
  final String periodLabel;

  const _HalfPieSection({
    super.key,
    required this.groups,
    required this.total,
    required this.myDataCode,
    required this.selectedPeriod,
    required this.tabColors,
    required this.marketingGuests,
    required this.nonMarketingGuests,
    required this.myDataGuests,
    required this.periodLabel,
  });

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

  Color _colorFor(int index) {
    final g = widget.groups[index];
    final isMyData = widget.myDataCode != null &&
        (g.gCode == widget.myDataCode || g.gName == 'My Data');
    if (isMyData) return widget.tabColors[widget.selectedPeriod];
    return _sliceColors[index % _sliceColors.length];
  }

  void _showSheet(BuildContext context, MarketingGroup group, Color color) {
    final gCode = group.gCode;
    final label = widget.periodLabel;

    // MARKETING (all) → sales-persons style sheet (grouped)
    if (gCode == 'MKT') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SalesPersonsSheet(
          title: 'Marketing — $label',
          salesPersons: groupByMGroup(widget.marketingGuests),
          accentColor: color,
        ),
      );
      return;
    }

    // NON MARKETING → grouped by country (same style as MARKETING)
    if (gCode == 'NON') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SalesPersonsSheet(
          title: 'Non Marketing — $label',
          salesPersons: groupByCountry(widget.nonMarketingGuests),
          accentColor: color,
          useKeyAsName: true,
        ),
      );
      return;
    }

    // My Data → member-visits style sheet
    if (gCode == widget.myDataCode || group.gName == 'My Data') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MemberVisitsSheet(
          title: 'My Visits — $label',
          guests: widget.myDataGuests,
          accentColor: color,
        ),
      );
      return;
    }

    // Individual marketing person → member-visits style sheet
    final personGuests =
        widget.marketingGuests.where((g) => g.mGroup == gCode).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberVisitsSheet(
        title: '${group.gName} — $label',
        guests: personGuests,
        accentColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Half-pie chart ──
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
                    colorForIndex: _colorFor,
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
                                fontWeight: FontWeight.w900,
                                color: Colors.black87),
                          ),
                          const Text('Total Visits',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color.fromARGB(255, 0, 0, 0))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // ── Legend rows ──
        Column(
          children: List.generate(widget.groups.length, (i) {
            final g = widget.groups[i];
            final pct = widget.total > 0
                ? (g.rc / widget.total * 100).toStringAsFixed(1)
                : '0.0';
            final color = _colorFor(i);
            final isActive = _hoveredIndex == null || _hoveredIndex == i;

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isActive ? 1.0 : 0.35,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showSheet(context, g, color),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            g.gName,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          g.rc.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$pct %',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right,
                            color: color.withOpacity(0.6), size: 20),
                      ],
                    ),
                  ),
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
// Sales-persons style sheet  (MARKETING slice)
// Shows grouped sales persons; tap a person → _MemberVisitsSheet for that person
// ────────────────────────────────────────────────────────────────────────────
class _SalesPersonsSheet extends StatefulWidget {
  final String title;
  final Map<String, List<Guest>> salesPersons;
  final Color accentColor;
  /// When true the map key (e.g. country name) is used as the row label
  /// instead of guests.first.gName (used for the MARKETING grouping).
  final bool useKeyAsName;

  const _SalesPersonsSheet({
    required this.title,
    required this.salesPersons,
    required this.accentColor,
    this.useKeyAsName = false,
  });

  @override
  State<_SalesPersonsSheet> createState() => _SalesPersonsSheetState();
}

class _SalesPersonsSheetState extends State<_SalesPersonsSheet> {
  late List<MapEntry<String, List<Guest>>> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.salesPersons.entries.toList();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.salesPersons.entries.toList()
          : widget.salesPersons.entries
              .where((e) =>
                  (widget.useKeyAsName ? e.key : (e.value.first.gName ?? '')).toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: widget.title,
      accentColor: widget.accentColor,
      count: _filtered.length,
      searchCtrl: _searchCtrl,
      searchHint: widget.useKeyAsName ? 'Search country…' : 'Search sales person…',
      child: _filtered.isEmpty
          ? _emptyWidget()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final entry = _filtered[index];
                final guests = entry.value;
                final name = widget.useKeyAsName ? entry.key : (guests.first.gName ?? '');
                final count = guests.first.mid == '' ? 0 : guests.length;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 1.5,
                  child: ListTile(
                    onTap: () {
                      if (guests.first.mid == '') return;
                      // Push a member-visits sheet on top
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _MemberVisitsSheet(
                          title: widget.useKeyAsName ? '$name' : '$name — visits',
                          guests: guests,
                          accentColor: widget.accentColor,
                          showBackButton: true,
                        ),
                      );
                    },
                    title: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    trailing: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          widget.accentColor.withOpacity(0.15),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: widget.accentColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Member-visits style sheet  (NON MARKETING / individual / My Data)
// Shows flat member list; tap a member → navigate to profile screen
// ────────────────────────────────────────────────────────────────────────────
class _MemberVisitsSheet extends ConsumerStatefulWidget {
  final String title;
  final List<Guest> guests;
  final Color accentColor;
  final bool showBackButton;

  const _MemberVisitsSheet({
    required this.title,
    required this.guests,
    required this.accentColor,
    this.showBackButton = false,
  });

  @override
  ConsumerState<_MemberVisitsSheet> createState() => _MemberVisitsSheetState();
}

class _MemberVisitsSheetState extends ConsumerState<_MemberVisitsSheet> {
  late List<Guest> _filtered;
  final _searchCtrl = TextEditingController();

  static const Map<String, String> _ratingImages = {
    "CLASSIC": "assets/images/ratings/CLASSIC.png",
    "DIAMOND": "assets/images/ratings/DIAMOND.png",
    "GOLD": "assets/images/ratings/GOLD.png",
    "INFINITY": "assets/images/ratings/INFINITY.png",
    "PLATINUM": "assets/images/ratings/PLATINUM.png",
    "SILVER": "assets/images/ratings/SILVER.png",
  };

  @override
  void initState() {
    super.initState();
    _filtered = widget.guests;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.guests
          : widget.guests.where((g) {
              return g.memberName.toLowerCase().contains(q) ||
                  g.mid.toLowerCase().contains(q) ||
                  g.country.toLowerCase().contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: widget.title,
      accentColor: widget.accentColor,
      count: _filtered.length,
      searchCtrl: _searchCtrl,
      searchHint: 'Search by name, ID or country…',
      showBackButton: widget.showBackButton,
      child: _filtered.isEmpty
          ? _emptyWidget()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final guest = _filtered[index];
                final ratingImg = _ratingImages[guest.gRating];

                return Stack(
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 1.5,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          // Set selected guest and navigate to profile —
                          // same pattern as MemberVisits screen
                          ref
                              .read(selectedGuestProvider.notifier)
                              .setSelectedGuest(guest);
                          Navigator.of(context).pop(); // close sheet
                          context.push('/home/profile');
                        },
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(14, 28, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${guest.mid} — ${guest.memberName}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.flag_outlined,
                                      size: 13, color: Colors.black54),
                                  const SizedBox(width: 6),
                                  Text(
                                    guest.country,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 13, color: Colors.black54),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Last visit on ${DateFormat('dd MMM yyyy').format(DateTime.tryParse(guest.lastVisitDate) ?? DateTime(2000))}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Rating badge — top-right, same position as MemberVisits
                    if (ratingImg != null)
                      Positioned(
                        top: 6,
                        right: -2,
                        child: SizedBox(
                          width: 80,
                          height: 26,
                          child: Image.asset(ratingImg, fit: BoxFit.contain),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared sheet scaffold (handle + title + search + body slot)
// ────────────────────────────────────────────────────────────────────────────
class _SheetScaffold extends StatelessWidget {
  final String title;
  final Color accentColor;
  final int count;
  final TextEditingController searchCtrl;
  final String searchHint;
  final Widget child;
  /// Show a back arrow on the left (for nested sheets pushed on top of another)
  final bool showBackButton;

  const _SheetScaffold({
    required this.title,
    required this.accentColor,
    required this.count,
    required this.searchCtrl,
    required this.searchHint,
    required this.child,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),

          // App-bar row: [back?] [title] [count] [close]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Back button (shown only in nested sheets)
                if (showBackButton)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: Colors.black87,
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  const SizedBox(width: 12),

                // Accent bar + title
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),

                // Close button — always visible, closes the whole sheet
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.black54,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: Icon(Icons.search, color: accentColor),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accentColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accentColor, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Body
          Expanded(child: child),
        ],
      ),
    );
  }
}

Widget _emptyWidget() => Center(
      child: Text('No data available',
          style: TextStyle(color: Colors.grey.shade500)),
    );

// ────────────────────────────────────────────────────────────────────────────
// Painter
// ────────────────────────────────────────────────────────────────────────────
class _HalfPiePainter extends CustomPainter {
  final List<MarketingGroup> groups;
  final int total;
  final double progress;
  final int? hoveredIndex;
  final Color Function(int index) colorForIndex;

  _HalfPiePainter({
    required this.groups,
    required this.total,
    required this.progress,
    required this.hoveredIndex,
    required this.colorForIndex,
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
      final color = colorForIndex(i);
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
            text: '${(fraction * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: Colors.white.withOpacity(progress),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
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
  final double fontSize;

  const _PeriodTabBar({
    required this.selectedIndex,
    required this.labels,
    required this.colors,
    required this.onTap,
    this.fontSize = 12,
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
                  fontSize: fontSize,
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