import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/birthday.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/birthdays_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';

class BirthdayScreen extends ConsumerStatefulWidget {
  const BirthdayScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      setState(() {});
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
      final birthdays =
          await ref.read(birthdayProvider.notifier).getBirthdays();
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

  void _toggleRecentBirthdays(bool showUpcoming) {
    setState(() {
      _showRecentUpcoming = showUpcoming;
      _recentBirthdays = showUpcoming
          ? ref.read(birthdayProvider)['recentUpcoming']!
          : ref.read(birthdayProvider)['recentPast']!;
    });
  }

  final Map<String, String> ratingImageMap = {
    "CLASSIC": "assets/images/ratings/CLASSIC.png",
    "DIAMOND": "assets/images/ratings/DIAMOND.png",
    "GOLD": "assets/images/ratings/GOLD.png",
    "INFINITY": "assets/images/ratings/INFINITY.png",
    "PLATINUM": "assets/images/ratings/PLATINUM.png",
    "SILVER": "assets/images/ratings/SILVER.png",
  };

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Birthdays',
          style: TextStyle(fontSize: 20.0),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Constants.kPrimaryColor,
          tabs: const [
            Tab(
              child: Text(
                'Past',
                style: TextStyle(fontSize: 16.0),
              ),
            ),
            Tab(
              child: Text(
                'Recent',
                style: TextStyle(fontSize: 16.0),
              ),
            ),
            Tab(
              child: Text(
                'Upcoming',
                style: TextStyle(fontSize: 16.0),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildBirthdayList(ref.read(birthdayProvider)['past']!),
              _buildBirthdayList(_recentBirthdays),
              _buildBirthdayList(ref.read(birthdayProvider)['upcoming']!),
            ],
          ),
          if (_tabController.index == 1)
            Positioned(
              top: 5.0,
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
                      child: const Icon(Icons.arrow_back_sharp,
                          color: Colors.white),
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
                        Constants.kSecondaryColor),
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
      return const Center(
        child: Text(
          'No birthdays found',
          style: TextStyle(fontSize: 18.0, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: birthdays.length,
      itemBuilder: (context, index) {
        final birthday = birthdays[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(13.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price: ${birthday.gift}',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      '${birthday.mid} - ${birthday.mname}',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      'Last visit on - ${DateFormat('dd MMM yyyy').format(birthday.lvd)}',
                      style: TextStyle(
                        color: Colors.grey,
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
                              horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: birthday.age <= 0
                                ? Colors.green
                                : Constants.kSecondaryColor,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            '${birthday.age.abs()} ${birthday.age == -1 ? 'Day from now' : birthday.age <= 0 ? 'Days from now' : birthday.age == 1 ? 'Day ago' : 'Days ago'}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(selectedGuestProvider.notifier)
                                .setSelectedGuest(Guest(
                                    mid: birthday.mid,
                                    memberName: birthday.mname,
                                    country: birthday.country,
                                    lastVisitDate: birthday.lvd.toString(),
                                    age: birthday.age,
                                    gRating: birthday.gRating,
                                    mGroup: "",
                                    gName: birthday.gName,
                                    gift: birthday.gift));
                            context.push('/home/profile');
                          },
                          icon: Icon(Icons.card_giftcard,
                              color: birthday.age < 0
                                  ? Colors.green
                                  : Constants.kSecondaryColor),
                          label: const Text('Request a gift'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: birthday.age < 0
                                ? Colors.green
                                : Constants.kSecondaryColor,
                            side: BorderSide(
                                color: birthday.age < 0
                                    ? Colors.green
                                    : Constants.kSecondaryColor),
                          ),
                        ),
                      ],
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
                  child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: SizedBox(
                      width: 100,
                      height: 35,
                      child: ratingImageMap[birthday.gRating] != null
                          ? Hero(
                              tag: "rating-image-${birthday.mid}",
                              child: Image.asset(
                                ratingImageMap[birthday.gRating]!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Hero(
                              tag: "rating-image-${birthday.mid}",
                              child: Image.asset(
                                "assets/images/ratings/CLASSIC.png",
                                fit: BoxFit.contain,
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
