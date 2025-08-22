import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/guests_provider.dart';
import 'package:ballys_reservation_app/screens/member_visits.dart';
import 'package:ballys_reservation_app/screens/member_visits/sales_persons.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? userName;
  DateTime? lastseen;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadGuestData();
  }

  _loadUserName() async {
    final name = await StorageUtil.getUserName();
    setState(() {
      userName = name;
      lastseen = DateTime.now();
    });
  }

  _loadGuestData() async {
    String? salesCode = await StorageUtil.getSalesCode();
    await ref.read(guestsProvider.notifier).getGuestData(9009, salesCode!);
    await ref.read(guestsProvider.notifier).getGuestData(9010, salesCode);
    await ref.read(guestsProvider.notifier).getGuestData(9011, salesCode);
  }

  @override
  Widget build(BuildContext context) {
    final guests = ref.watch(guestsProvider);
    final formattedLastSeen = lastseen != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(lastseen!)
        : '';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          userName != null ? 'Welcome, $userName' : 'Loading...',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          // 🔹 Background watermark
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          // Navigator.of(context).push(MaterialPageRoute(
                          //     builder: (context) => const MemberVisits(
                          //           title: 'Today Member Visits',
                          //         )));
                          final userLevel = await StorageUtil.getUserLevel();
                          if (userLevel == '1') {
                            context.push(
                              '/home/sales-persons',
                              extra: {
                                'title': 'All Sales Persons (Today)',
                                'salesPersons': groupByMGroup(
                                  guests.todayGuests,
                                ),
                              },
                            );
                          } else {
                            context.push(
                              '/home/member-visits',
                              extra: {
                                'title': 'Today Member Visits',
                                'guestList': guests.todayGuests,
                              },
                            );
                          }
                        },
                        child: Card(
                          color: const Color.fromARGB(255, 228, 117, 14),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  guests.todayGuests
                                      .where((guest) => guest.mid.isNotEmpty)
                                      .length
                                      .toString(),
                                  style: const TextStyle(
                                    fontSize: 50.0,
                                    fontWeight: FontWeight.w500,
                                    color: Color.fromARGB(255, 255, 255, 255),
                                  ),
                                ),
                                const Text(
                                  'Today',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final userLevel = await StorageUtil.getUserLevel();
                          if (userLevel == '1') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => SalesPersonsScreen(
                                  title: 'All Sales Persons (Yesterday)',
                                  salesPersons: groupByMGroup(
                                    guests.yesterdayGuests,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MemberVisits(
                                  title: 'Yesterday Member Visits',
                                  guestList: guests.yesterdayGuests,
                                ),
                              ),
                            );
                          }
                        },
                        child: Card(
                          color: const Color.fromARGB(255, 78, 179, 81),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  guests.yesterdayGuests
                                      .where((guest) => guest.mid.isNotEmpty)
                                      .length
                                      .toString(),
                                  style: const TextStyle(
                                    fontSize: 50.0,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  'Yesterday',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final userLevel = await StorageUtil.getUserLevel();
                          if (userLevel == '1') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => SalesPersonsScreen(
                                  title: 'All Sales Persons (Monthly)',
                                  salesPersons: groupByMGroup(
                                    guests.monthlyGuests,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MemberVisits(
                                  title: 'Monthly Member Visits',
                                  guestList: guests.monthlyGuests,
                                ),
                              ),
                            );
                          }
                        },
                        child: Card(
                          color: const Color.fromARGB(155, 42, 125, 192),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  guests.monthlyGuests
                                      .where((guest) => guest.mid.isNotEmpty)
                                      .length
                                      .toString(),
                                  style: const TextStyle(
                                    fontSize: 50.0,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  'Monthly',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.2,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      alignment: WrapAlignment.start,
                      runAlignment: WrapAlignment.center,
                      spacing: 1,
                      runSpacing: 25,
                      children: List.generate(
                        100,
                        (index) => Transform.rotate(
                          angle: -0.7,
                          child: Text(
                            (userName ?? "Loading...") +
                                "\n" +
                                (lastseen != null
                                    ? formattedLastSeen
                                    : "Loading..."),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
