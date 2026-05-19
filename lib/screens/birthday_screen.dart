import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/birthday.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/birthdays_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
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
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
    setState(() {
    _selectedMid = null;
  });
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        
      });
    });
    _fetchBirthdays();
  }

  Future<void> _fetchBirthdays() async {
    final birthdayData = ref.read(birthdayProvider);
    if (birthdayData['recentUpcoming']!.isEmpty &&
        birthdayData['recentPast']!.isEmpty) {
      setState(() {
        _isLoading = true;
      });
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
    setState(() {
      _isRefreshing = true;
    });

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
      setState(() {
        _isRefreshing = false;
      });
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

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

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
      print('Checking ${b.mname}, ${b.mid}, ${b.mobile}, ${b.bDate}, ${b.gRating} against query "$_searchQuery"');
      return b.mname.toLowerCase().contains(_searchQuery) ||
          b.mid.toLowerCase().contains(_searchQuery) ||
          (b.mobile ?? '').toLowerCase().contains(_searchQuery) ||
          (b.bDate ?? '').toString().contains(_searchQuery) ||
          DateFormat('dd MMM yyyy').format(b.bDate).toString().contains(_searchQuery) ||
          (b.gRating ?? '').toLowerCase().contains(_searchQuery);
    }).toList();
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

  /// Builds the horizontal DOB-only scroll strip at the top.
//   Widget _buildDobStrip(List<Birthday> allBirthdays) {
//     // final sorted = [...allBirthdays]
//     //   // ..sort((a, b) => a.age.compareTo(b.age));
//     // ..sort((a, b) => a.bDate.compareTo(b.bDate));
// final sorted = [...allBirthdays]
//   ..sort((a, b) {
//     final aVal = a.bDate.month * 100 + a.bDate.day;
//     final bVal = b.bDate.month * 100 + b.bDate.day;
//     return aVal.compareTo(bVal);
//   });
//     return Container(
//       height: 46,
//       color: Theme.of(context).colorScheme.surfaceVariant,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//         itemCount: sorted.length,
//         itemBuilder: (context, index) {
//           final b = sorted[index];
//           final isSelected = _selectedMid == b.mid;
//           return GestureDetector(
//             onTap: () => setState(() {
//               _selectedMid = isSelected ? null : b.mid;
//             }),
//             child: AnimatedContainer(
//               duration: const Duration(milliseconds: 150),
//               margin: const EdgeInsets.only(right: 6),
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//               decoration: BoxDecoration(
//                 color: isSelected
//                     ? const Color(0xFFEEEDFE)
//                     : Colors.white,
//                 border: Border.all(
//                   color: isSelected
//                       ? const Color(0xFF7F77DD)
//                       : Colors.grey.shade300,
//                   width: isSelected ? 2 : 0.5,
//                 ),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Text(
//                 DateFormat('dd MMM yyyy').format(b.bDate),
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight:
//                       isSelected ? FontWeight.w900 : FontWeight.bold,
//                   color: isSelected
//                       ? const Color(0xFF534AB7)
//                       : Colors.black87,
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
Widget _buildDobStrip(List<Birthday> allBirthdays) {
  final sorted = [...allBirthdays]
    ..sort((a, b) {
      final aVal = a.bDate.month * 100 + a.bDate.day;
      final bVal = b.bDate.month * 100 + b.bDate.day;
      return aVal.compareTo(bVal);
    });

  final seen = <String>{};
  final unique = sorted.where((b) {
    final key = '${b.bDate.day}-${b.bDate.month}';
    return seen.add(key);
  }).toList();

  return Container(
    height: 49,
    color: Theme.of(context).colorScheme.surfaceVariant,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      itemCount: unique.length + 1, // +1 for All button
      itemBuilder: (context, index) {
        // ALL button at index 0
        if (index == 0) {
          final isAll = _selectedMid == null;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedMid = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isAll ? const Color(0xFF534AB7) : Colors.white,
                border: Border.all(
                  color: isAll ? const Color(0xFF534AB7) : Colors.grey.shade300,
                  width: isAll ? 2 : 0.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'All',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isAll ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        }

        final b = unique[index - 1];
        final isSelected = _selectedMid == b.mid;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedMid = isSelected ? null : b.mid;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color.fromARGB(255, 0, 0, 0) : Colors.white,
              border: Border.all(
                color: isSelected ? const Color.fromARGB(255, 0, 0, 0) : Colors.grey.shade300,
                width: isSelected ? 2 : 0.5,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              DateFormat('dd MMM').format(b.bDate),
              style: TextStyle(
                fontSize: 19,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                color: isSelected ? const Color.fromARGB(255, 255, 255, 255) : Colors.black87,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final birthdayData = ref.read(birthdayProvider);

    // All birthdays combined for the DOB strip
    final allBirthdays = [
      ...birthdayData['past']!,
      ..._recentBirthdays,
      ...birthdayData['upcoming']!,
    ];

    // Apply _selectedMid filter to each tab's list
    // List<Birthday> applyMidFilter(List<Birthday> list) {
    //   if (_selectedMid == null) return list;
    //   return list.where((b) => b.mid == _selectedMid).toList();
    // }
List<Birthday> applyMidFilter(List<Birthday> list) {
  if (_selectedMid == null) return list;
  final selected = allBirthdays.firstWhere((b) => b.mid == _selectedMid);
  return list.where((b) =>
    b.bDate.day == selected.bDate.day &&
    b.bDate.month == selected.bDate.month
  ).toList();
}
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
                  hintStyle:
                      TextStyle(color: Color.fromARGB(153, 0, 0, 0)),
                ),
                style: const TextStyle(
                    color: Color.fromARGB(255, 0, 0, 0),
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold),
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
            Tab(
                child:
                    Text('Recent', style: TextStyle(fontSize: 16.0))),
            Tab(
                child: Text('Upcoming',
                    style: TextStyle(fontSize: 16.0))),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // DOB horizontal scroll strip
              // _buildDobStrip(allBirthdays),
              _buildDobStrip(
  _tabController.index == 0
      ? birthdayData['past']!
      : _tabController.index == 1
          ? _recentBirthdays
          : birthdayData['upcoming']!,
),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBirthdayList(
                      _filterBirthdays(
                          applyMidFilter(birthdayData['past']!)),
                    ),
                    _buildBirthdayList(
                      _filterBirthdays(
                          applyMidFilter(_recentBirthdays)),
                    ),
                    _buildBirthdayList(
                      _filterBirthdays(
                          applyMidFilter(birthdayData['upcoming']!)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_tabController.index == 1 && !_isSearching)
            Positioned(
              top: 52.0, // offset below the DOB strip
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

  Widget _buildBirthdayList(List<Birthday> birthdays) {
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
              fontWeight: FontWeight.bold),
        ),
      );
    }
    return ListView.builder(
      itemCount: birthdays.length,
      itemBuilder: (context, index) {
        final birthday = birthdays[index];
        return Card(
          margin:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(13.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price : ${birthday.gift}',
                      style: TextStyle(
                        fontSize: fontSettings.fontSize + 8,
                        fontWeight: fontSettings.fontWeight,
                        color: const Color.fromARGB(255, 255, 0, 0),
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
                    const SizedBox(height: 3.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
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
                        ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(selectedGuestProvider.notifier)
                                .setSelectedGuest(
                                  Guest(
                                    mid: birthday.mid,
                                    memberName: birthday.mname,
                                    country: birthday.country,
                                    lastVisitDate:
                                        birthday.lvd.toString(),
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
                          icon: const Icon(
                            Icons.card_giftcard,
                            color: Colors.white,
                          ),
                          
                          label:  Text(
                            'Request a gift',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSettings.fontSize,
                              color: Colors.white,
                            ),
                          ),
                          
                          style: ElevatedButton.styleFrom(
                            backgroundColor: birthday.age < 0
                                ? Colors.green
                                : Constants.kSecondaryColor,
                            foregroundColor: Colors.white,
                             shape:  RoundedRectangleBorder(   // ← add this
    borderRadius: BorderRadius.circular(4.0),
    
  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push(
                            '/birthdays/gift-price-increase',
                            extra: birthday,
                          );
                        },
                        icon: const Icon(
                          Icons.trending_up,
                          color: Colors.white,
                          size: 16.0,
                        ),
                        label: const Text(
                          'Request Gift Price Increase',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.0,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 6.0,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                           shape: RoundedRectangleBorder(   // ← add this
   borderRadius: BorderRadius.circular(4.0),
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
        );
      },
    );
  }
}