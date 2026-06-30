import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/birthday.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/birthdays_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BirthdayScreen extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;

  const BirthdayScreen({super.key, required this.giftsRepository});

  @override
  ConsumerState<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends ConsumerState<BirthdayScreen>
    with SingleTickerProviderStateMixin,ConnectivityMixin {
  late TabController _tabController;
  final List<Birthday> _birthdays = [];
  List<Birthday> _recentBirthdays = [];
  bool _showRecentUpcoming = true;
  bool _isLoading = false;
  bool _isRefreshing = false;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  // DOB strip selection
  String? _selectedMid;

  // scroll-sync state
  final ScrollController _stripScrollController = ScrollController();
  final List<ScrollController> _listControllers = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];
  String? _visibleBirthdayKey;

  // ── KEY-BASED approach: one GlobalKey per card per tab ──────────────────
  // _itemKeys[tabIndex][listIndex] = GlobalKey
  final List<Map<int, GlobalKey>> _itemKeys = [{}, {}, {}];
  // ────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      setState(() {
        _selectedMid = null;
        _visibleBirthdayKey = null;
      });
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    for (int i = 0; i < _listControllers.length; i++) {
      final tabIndex = i;
      _listControllers[i].addListener(() => _onListScroll(tabIndex));
    }

    _fetchBirthdays();
  }
  @override
  void onConnectivityRestored() {
   _refreshBirthdays();
  }

  // ── NEW: find the topmost visible card using RenderBox hit-testing ───────
  void _onListScroll(int tabIndex) {
    if (_tabController.index != tabIndex) return;
    if (!mounted) return;

    final currentList = _getCurrentFilteredList(tabIndex);
    if (currentList.isEmpty) return;

    // Find the list's RenderBox so we can get its top-left in global coords
    final listController = _listControllers[tabIndex];
    if (!listController.hasClients) return;

    // Walk through item keys and find the first one whose widget
    // is at or below the top of the scroll view's visible area.
    final keys = _itemKeys[tabIndex];

    int? topVisibleIndex;

    for (int i = 0; i < currentList.length; i++) {
      final key = keys[i];
      if (key == null) continue;

      final context = key.currentContext;
      if (context == null) continue;

      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;

      // Position of this card's top edge in global coordinates
      final position = box.localToGlobal(Offset.zero);

      // If the card's bottom is above screen top, skip
      // If the card's top is within the visible area (>= some threshold from top),
      // treat it as the topmost visible card.
      // We use a small offset (80px) to account for AppBar + strip height
      if (position.dy + box.size.height > 80) {
        topVisibleIndex = i;
        break;
      }
    }

    if (topVisibleIndex == null) return;
    if (topVisibleIndex >= currentList.length) return;

    final topBirthday = currentList[topVisibleIndex];
    final key = '${topBirthday.bDate.day}-${topBirthday.bDate.month}';

    if (_visibleBirthdayKey != key) {
      setState(() => _visibleBirthdayKey = key);
      _scrollStripToKey(key, _getCurrentTabBirthdays(tabIndex));
    }
  }
  // ────────────────────────────────────────────────────────────────────────

  List<Birthday> _getCurrentFilteredList(int tabIndex) {
    final birthdayData = ref.read(birthdayProvider);
    final raw = tabIndex == 0
        ? birthdayData['past']!
        : tabIndex == 1
        ? _recentBirthdays
        : birthdayData['upcoming']!;
    return _filterBirthdays(applyMidFilter(raw, _getAllBirthdays()));
  }

  List<Birthday> _getCurrentTabBirthdays(int tabIndex) {
    final birthdayData = ref.read(birthdayProvider);
    return tabIndex == 0
        ? birthdayData['past']!
        : tabIndex == 1
        ? _recentBirthdays
        : birthdayData['upcoming']!;
  }

  void _scrollStripToKey(String key, List<Birthday> tabBirthdays) {
    final sorted = [...tabBirthdays]
      ..sort((a, b) {
        final aVal = a.bDate.month * 100 + a.bDate.day;
        final bVal = b.bDate.month * 100 + b.bDate.day;
        return aVal.compareTo(bVal);
      });

    final seen = <String>{};
    final unique = sorted.where((b) {
      final k = '${b.bDate.day}-${b.bDate.month}';
      return seen.add(k);
    }).toList();

    final chipIndex = unique.indexWhere(
      (b) => '${b.bDate.day}-${b.bDate.month}' == key,
    );
    if (chipIndex == -1) return;

    const double chipWidth = 90.0;
    const double allButtonWidth = 60.0;
    final double targetOffset = allButtonWidth + chipIndex * chipWidth - 8;

    if (_stripScrollController.hasClients) {
      _stripScrollController.animateTo(
        targetOffset.clamp(
          0.0,
          _stripScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  List<Birthday> _getAllBirthdays() {
    final birthdayData = ref.read(birthdayProvider);
    return [
      ...birthdayData['past']!,
      ..._recentBirthdays,
      ...birthdayData['upcoming']!,
    ];
  }

  Future<void> _fetchBirthdays() async {
    final birthdayData = ref.read(birthdayProvider);
    if (birthdayData['recentUpcoming']!.isEmpty &&
        birthdayData['recentPast']!.isEmpty) {
      setState(() => _isLoading = true);
      final birthdays = await ref
          .read(birthdayProvider.notifier)
          .getBirthdays();
      setState(() {
        _isLoading = false;
        _recentBirthdays = birthdays['recentUpcoming']!;
      });
    } else {
      setState(() {
        _recentBirthdays = birthdayData['recentUpcoming']!;
      });
    }
  }

  Future<void> _refreshBirthdays() async {
    setState(() => _isRefreshing = true);
    try {
      final birthdays = await ref
          .read(birthdayProvider.notifier)
          .getBirthdays();
      setState(() {
        _recentBirthdays = _showRecentUpcoming
            ? birthdays['recentUpcoming']!
            : birthdays['recentPast']!;
      });
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _toggleRecentBirthdays(bool showUpcoming) {
    setState(() {
      _showRecentUpcoming = showUpcoming;
      _recentBirthdays = showUpcoming
          ? ref.read(birthdayProvider)['recentUpcoming']!
          : ref.read(birthdayProvider)['recentPast']!;
    });
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  List<Birthday> _filterBirthdays(List<Birthday> birthdays) {
    if (_searchQuery.isEmpty) return birthdays;
    return birthdays.where((b) {
      return b.mname.toLowerCase().contains(_searchQuery) ||
          b.mid.toLowerCase().contains(_searchQuery) ||
          (b.mobile ?? '').toLowerCase().contains(_searchQuery) ||
          (b.bDate).toString().contains(_searchQuery) ||
          DateFormat(
            'dd MMM yyyy',
          ).format(b.bDate).toString().contains(_searchQuery) ||
          (b.gRating ?? '').toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<Birthday> applyMidFilter(
    List<Birthday> list,
    List<Birthday> allBirthdays,
  ) {
    if (_selectedMid == null) return list;
    final selected = allBirthdays.firstWhere((b) => b.mid == _selectedMid);
    return list
        .where(
          (b) =>
              b.bDate.day == selected.bDate.day &&
              b.bDate.month == selected.bDate.month,
        )
        .toList();
  }

  Color _getRatingColorBallys(String? rating) {
    switch ((rating ?? '').toUpperCase()) {
      case 'GOLD':
        return const Color(0xFFDAA520);
      case 'PLATINUM':
        return const Color(0xFF707070);
      case 'DIAMOND':
        return const Color(0xFF1565C0);
      case 'SILVER':
        return const Color(0xFF9E9E9E);
      case 'INFINITY':
        return const Color(0xFF4A148C);
      case 'CLASSIC':
        return const Color(0xFF5D4037);
      case 'PREMIER':
        return const Color(0xFF1B5E20);
      case 'RAFFELS CLUB':
        return const Color(0xFF880E4F);
      default:
        return Colors.grey;
    }
  }

  Widget _buildDobStrip(List<Birthday> allBirthdays) {
    final sorted = [...allBirthdays]
      ..sort((a, b) {
        final aVal = a.bDate.month * 100 + a.bDate.day;
        final bVal = b.bDate.month * 100 + b.bDate.day;
        return aVal.compareTo(bVal);
      });
  final Map<String, int> dateCounts = {};
  for (final b in sorted) {
    final key = '${b.bDate.day}-${b.bDate.month}';
    dateCounts[key] = (dateCounts[key] ?? 0) + 1;
  }
    final seen = <String>{};
    final unique = sorted.where((b) {
      final key = '${b.bDate.day}-${b.bDate.month}';
      return seen.add(key);
    }).toList();

    return Container(
      height: 49,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: ListView.builder(
        controller: _stripScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: unique.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAll = _selectedMid == null;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedMid = null;
                _visibleBirthdayKey = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isAll ? const Color(0xFF534AB7) : Colors.white,
                  border: Border.all(
                    color: isAll
                        ? const Color(0xFF534AB7)
                        : Colors.grey.shade300,
                    width: isAll ? 2 : 0.5,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                // child: Text(
                //   'All (${sorted.length})',
                //   style: TextStyle(
                //     fontSize: 20,
                //     fontWeight: FontWeight.bold,
                //     color: isAll ? Colors.white : Colors.black87,
                //   ),
                // ),
                child: Text.rich(
  TextSpan(
    children: [
      TextSpan(
        text: 'All ',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isAll ? Colors.white : Colors.black87,
        ),
      ),
      TextSpan(
        text: '(${sorted.length})',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: isAll ? Colors.amberAccent : Colors.deepOrange,
        ),
      ),
    ],
  ),
),
              ),
            );
          }

          final b = unique[index - 1];
          final chipKey = '${b.bDate.day}-${b.bDate.month}';
           final count = dateCounts[chipKey] ?? 0;
          final isHighlighted = _visibleBirthdayKey == chipKey;
          final isSelected = _selectedMid == b.mid;
          final isActive = isHighlighted || isSelected;

          return GestureDetector(
            onTap: () => setState(() {
              _selectedMid = isSelected ? null : b.mid;
              _visibleBirthdayKey = isSelected ? null : chipKey;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.black : Colors.white,
                border: Border.all(
                  color: isActive ? Colors.black : Colors.grey.shade300,
                  width: isActive ? 2 : 0.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              // child: Text(
              //   // DateFormat('dd MMM').format(b.bDate),
              //    '${DateFormat('dd MMM').format(b.bDate)} ($count)',
              //   style: TextStyle(
              //     fontSize: 19,
              //     fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
              //     color: isActive ? Colors.white : Colors.black87,
              //   ),
              // ),
              child: Text.rich(
  TextSpan(
    children: [
      TextSpan(
        text: DateFormat('dd MMM').format(b.bDate),
        style: TextStyle(
          fontSize: 18,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
          color: isActive ? Colors.white : Colors.black87,
        ),
      ),
      TextSpan(
        text: ' ( $count )',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          // NEW: distinct color for the count
          color: isActive ? Colors.amberAccent : Colors.deepOrange,
        ),
      ),
    ],
  ),
),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _stripScrollController.dispose();
    for (final c in _listControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final birthdayData = ref.read(birthdayProvider);
    final allBirthdays = _getAllBirthdays();

    return Scaffold(
      appBar: AppBar(
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _stopSearch,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/menu');
                  }
                },
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name,Date,ID, mobile...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color.fromARGB(153, 0, 0, 0)),
                ),
                style: const TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              )
            : const Text('Birthdays', style: TextStyle(fontSize: 20.0)),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, size: 30),
              onPressed: _stopSearch,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search, size: 30),
              onPressed: _startSearch,
            ),
            IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromARGB(255, 114, 6, 100),
                        ),
                      ),
                    )
                  : const Icon(Icons.refresh, size: 30),
              onPressed: _isRefreshing ? null : _refreshBirthdays,
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Constants.kPrimaryColor,
          tabs: const [
            Tab(child: Text('Past', style: TextStyle(fontSize: 16.0))),
            Tab(child: Text('Recent', style: TextStyle(fontSize: 16.0))),
            Tab(child: Text('Upcoming', style: TextStyle(fontSize: 16.0))),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildDobStrip(
                _tabController.index == 0
                    ? birthdayData['past']!
                    : _tabController.index == 1
                    ? _recentBirthdays
                    : birthdayData['upcoming']!,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBirthdayList(
                      _filterBirthdays(
                        applyMidFilter(birthdayData['past']!, allBirthdays),
                      ),
                      tabIndex: 0,
                    ),
                    _buildBirthdayList(
                      _filterBirthdays(
                        applyMidFilter(_recentBirthdays, allBirthdays),
                      ),
                      tabIndex: 1,
                    ),
                    _buildBirthdayList(
                      _filterBirthdays(
                        applyMidFilter(birthdayData['upcoming']!, allBirthdays),
                      ),
                      tabIndex: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_tabController.index == 1 && !_isSearching)
            Positioned(
              top: 52.0,
              right: 5.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    onPressed: () => _toggleRecentBirthdays(true),
                    backgroundColor: Colors.green,
                    mini: true,
                    heroTag: 'recentUpcoming',
                    child: const Icon(
                      Icons.arrow_outward_sharp,
                      color: Colors.white,
                    ),
                  ),
                  FloatingActionButton(
                    onPressed: () => _toggleRecentBirthdays(false),
                    backgroundColor: Constants.kSecondaryColor,
                    mini: true,
                    heroTag: 'recentPast',
                    child: Transform.rotate(
                      angle: -135 * 3.1415926535897932 / 180,
                      child: const Icon(
                        Icons.arrow_back_sharp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color.fromARGB(135, 117, 115, 115),
                ),
                child: const Center(
                  child: RefreshProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Constants.kSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          const Watermark(),
        ],
      ),
    );
  }

  Widget _buildBirthdayList(List<Birthday> birthdays, {required int tabIndex}) {
    final fontSettings = ref.watch(fontSettingsProvider);

    if (birthdays.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? 'No birthdays found'
              : 'No results for "$_searchQuery"',
          style: const TextStyle(
            fontSize: 18.0,
            color: Color.fromARGB(255, 0, 0, 0),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Ensure keys exist for all items
    for (int i = 0; i < birthdays.length; i++) {
      _itemKeys[tabIndex].putIfAbsent(i, () => GlobalKey());
    }

    return ListView.builder(
      controller: _listControllers[tabIndex],
      itemCount: birthdays.length,
      itemBuilder: (context, index) {
        final birthday = birthdays[index];
        // Assign the GlobalKey to this card's container
        final itemKey = _itemKeys[tabIndex].putIfAbsent(
          index,
          () => GlobalKey(),
        );

        return Container(
          key: itemKey,
          child: Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(13.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text(
                      //   'Price : ${birthday.gift}',
                      //   style: TextStyle(
                      //     fontSize: fontSettings.fontSize + 8,
                      //     fontWeight: fontSettings.fontWeight,
                      //     color: const Color.fromARGB(255, 255, 0, 0),
                      //   ),
                      // ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          'Price : ${birthday.gift}',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize + 8,
                            fontWeight: fontSettings.fontWeight,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      Text(
                        '${birthday.mid} - ${birthday.mname}',
                        style: TextStyle(
                          color: const Color.fromARGB(255, 17, 0, 255),
                          fontSize: fontSettings.fontSize + 2,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      // Container(
                      //   padding: const EdgeInsets.symmetric(
                      //     horizontal: 10.0,
                      //     vertical: 4.0,
                      //   ),
                      //   decoration: BoxDecoration(
                      //     color: const Color.fromARGB(255, 255, 255, 255),
                      //     borderRadius: BorderRadius.circular(4.0),
                      //     // border: Border.all(
                      //     //   color: const Color.fromARGB(255, 17, 0, 255),
                      //     //   width: 1.0,
                      //     // ),
                      //     boxShadow: [
                      //       BoxShadow(
                      //         color: Colors.blue.withOpacity(0.1),
                      //         blurRadius: 4,
                      //         offset: const Offset(0, 2),
                      //       ),
                      //     ],
                      //   ),
                      //   child: Text(
                      //     '${birthday.mid} - ${birthday.mname}',
                      //     style: TextStyle(
                      //       color: const Color.fromARGB(255, 17, 0, 255),
                      //       fontSize: fontSettings.fontSize + 2,
                      //       fontWeight: fontSettings.fontWeight,
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(height: 3.0),
                      Text(
                        'Last visit on - ${DateFormat('dd MMM yyyy').format(birthday.lvd)}',
                        style: TextStyle(
                          color: const Color.fromARGB(255, 3, 3, 3),
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      // Row(
                      //   children: [
                      //     const Icon(Icons.cake, color: Colors.pink),
                      //     const SizedBox(width: 8.0),
                      //     Text(
                      //       DateFormat('dd MMM yyyy').format(birthday.bDate),
                      //       style: TextStyle(
                      //         fontSize: fontSettings.fontSize,
                      //         fontWeight: fontSettings.fontWeight,
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(
      children: [
        const Icon(Icons.cake, color: Colors.pink),
        const SizedBox(width: 8.0),
        Text(
          DateFormat('dd MMM yyyy').format(birthday.bDate),
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
          ),
        ),
      ],
    ),
 
    Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: birthday.age <= 0
            ? Colors.green
            : Constants.kSecondaryColor,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        '${birthday.age.abs()} ${birthday.age == -1
            ? 'Day from now'
            : birthday.age <= 0
            ? 'Days from now'
            : birthday.age == 1
            ? 'Day ago'
            : 'Days ago'}',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
        ),
      ),
    ),
  ],
),
                      const SizedBox(height: 3.0),
                      Row(
                        children: [
                          // Container(
                          //   padding: const EdgeInsets.symmetric(
                          //       horizontal: 8.0, vertical: 4.0),
                          //   decoration: BoxDecoration(
                          //     color: birthday.age <= 0
                          //         ? Colors.green
                          //         : Constants.kSecondaryColor,
                          //     borderRadius: BorderRadius.circular(4.0),
                          //   ),
                          //   child: Text(
                          //     '${birthday.age.abs()} ${birthday.age == -1 ? 'Day from now' : birthday.age <= 0 ? 'Days from now' : birthday.age == 1 ? 'Day ago' : 'Days ago'}',
                          //     style: TextStyle(
                          //       color: Colors.white,
                          //       fontSize: fontSettings.fontSize,
                          //       fontWeight: fontSettings.fontWeight,
                          //     ),
                          //   ),
                          // ),
                          // ElevatedButton.icon(
                          //   onPressed: () {
                          //     ref
                          //         .read(selectedGuestProvider.notifier)
                          //         .setSelectedGuest(
                          //           Guest(
                          //             mid: birthday.mid,
                          //             memberName: birthday.mname,
                          //             country: birthday.country,
                          //             lastVisitDate: birthday.lvd.toString(),
                          //             age: birthday.age,
                          //             gRating: birthday.gRating,
                          //             mGroup: birthday.mGroup,
                          //             gName: birthday.gName,
                          //             gift: birthday.gift,
                          //             mobile: birthday.mobile,
                          //           ),
                          //         );
                          //     context.push('/home/profile');
                          //   },
                          //   icon: const Icon(Icons.card_giftcard,
                          //       color: Colors.white),
                          //   label: Text(
                          //     'Request a gift',
                          //     style: TextStyle(
                          //       fontWeight: FontWeight.bold,
                          //       fontSize: fontSettings.fontSize,
                          //       color: Colors.white,
                          //     ),
                          //   ),
                          //   style: ElevatedButton.styleFrom(
                          //     // backgroundColor: birthday.age < 0
                          //     //     ? Colors.green
                          //     //     : Constants.kSecondaryColor,
                          //     backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                          //     foregroundColor: Colors.white,
                          //     shape: RoundedRectangleBorder(
                          //       borderRadius: BorderRadius.circular(4.0),
                          //     ),
                          //   ),
                          // ),
                          InkWell(
                            onTap: () {
                              ref
                                  .read(selectedGuestProvider.notifier)
                                  .setSelectedGuest(
                                    Guest(
                                      mid: birthday.mid,
                                      memberName: birthday.mname,
                                      country: birthday.country,
                                      lastVisitDate: birthday.lvd.toString(),
                                      age: birthday.age,
                                      gRating: birthday.gRating,
                                      mGroup: birthday.mGroup,
                                      gName: birthday.gName,
                                      gift: birthday.gift,
                                      mobile: birthday.mobile,
                                    ),
                                  );
                              context.push('/home/profile');
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 255, 255, 255),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: birthday.age < 0
                                      ? Colors.green
                                      : Constants.kSecondaryColor,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (birthday.age < 0
                                                ? Colors.green
                                                : Constants.kSecondaryColor)
                                            .withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.card_giftcard,
                                    color: birthday.age < 0
                                        ? Colors.green
                                        : Constants.kSecondaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Request a gift',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: fontSettings.fontSize,
                                      color: birthday.age < 0
                                          ? Colors.green
                                          : Constants.kSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Align(
                        alignment: Alignment.centerLeft,
                        // child: ElevatedButton.icon(
                        //   onPressed: () {
                        //     context.push(
                        //       '/birthdays/gift-price-increase',
                        //       extra: birthday,
                        //     );
                        //   },
                        //   icon: const Icon(Icons.trending_up,
                        //       color: Colors.white, size: 16.0),
                        //   label: const Text(
                        //     'Request Gift Price Increase',
                        //     style: TextStyle(
                        //         fontWeight: FontWeight.bold,
                        //         fontSize: 15.0,
                        //         color: Colors.white),
                        //   ),
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                        //     foregroundColor: Colors.white,
                        //     padding: const EdgeInsets.symmetric(
                        //         horizontal: 10.0, vertical: 6.0),
                        //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(4.0),
                        //     ),
                        //   ),
                        // ),
                        child: InkWell(
                          onTap: () {
                            context.push(
                              '/birthdays/gift-price-increase',
                              extra: birthday,
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 255, 255, 255),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // const Icon(Icons.trending_up, color: Colors.orange, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Request Gift Price Increase',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: fontSettings.fontSize,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Hero(
                      tag: "rating-image-${birthday.mid}",
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getRatingColorBallys(birthday.gRating),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          birthday.gRating ?? 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
