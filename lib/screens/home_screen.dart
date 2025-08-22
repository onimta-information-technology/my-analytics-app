import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/guests_provider.dart';
import 'package:ballys_reservation_app/screens/member_visits.dart';
import 'package:ballys_reservation_app/screens/member_visits/sales_persons.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? userName;

  int? todayCount;
  int? yesterdayCount;
  int? monthlyCount;

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
    });
  }

  _loadGuestData() async {
    String? salesCode = await StorageUtil.getSalesCode();

    // 🔹 Today count
    await ref.read(guestsProvider.notifier).getGuestData(9009, salesCode!);
    setState(() {
      todayCount = ref.read(guestsProvider).todayGuests
          .where((guest) => guest.mid.isNotEmpty)
          .length;
    });

    // 🔹 Yesterday count
    await ref.read(guestsProvider.notifier).getGuestData(9010, salesCode);
    setState(() {
      yesterdayCount = ref.read(guestsProvider).yesterdayGuests
          .where((guest) => guest.mid.isNotEmpty)
          .length;
    });

    // 🔹 Monthly count
    await ref.read(guestsProvider.notifier).getGuestData(9011, salesCode);
    setState(() {
      monthlyCount = ref.read(guestsProvider).monthlyGuests
          .where((guest) => guest.mid.isNotEmpty)
          .length;
    });
  }

  // 🔹 Reusable box widget
  Widget buildCountBox({
    required int? count,
    required String label,
    required Color color,
  }) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            count == null
                ? const SizedBox(
                    height: 40,
                    width: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 50.0,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.normal,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guests = ref.watch(guestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          userName != null ? 'Welcome, $userName' : 'Loading...',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 🔹 Today & Yesterday
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final userLevel = await StorageUtil.getUserLevel();
                          if (userLevel == '1') {
                            context.push(
                              '/home/sales-persons',
                              extra: {
                                'title': 'All Sales Persons (Today)',
                                'salesPersons':
                                    groupByMGroup(guests.todayGuests),
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
                        child: buildCountBox(
                          count: todayCount,
                          label: "Today",
                          color: const Color.fromARGB(255, 228, 117, 14),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final userLevel = await StorageUtil.getUserLevel();
                          if (userLevel == '1') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => SalesPersonsScreen(
                                  title: 'All Sales Persons (Yesterday)',
                                  salesPersons:
                                      groupByMGroup(guests.yesterdayGuests),
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
                        child: buildCountBox(
                          count: yesterdayCount,
                          label: "Yesterday",
                          color: const Color.fromARGB(255, 78, 179, 81),
                        ),
                      ),
                    ),
                  ],
                ),

                // 🔹 Monthly
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
                                  salesPersons:
                                      groupByMGroup(guests.monthlyGuests),
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
                        child: buildCountBox(
                          count: monthlyCount,
                          label: "Monthly",
                          color: const Color.fromARGB(155, 42, 125, 192),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Watermark(),
        ],
      ),
    );
  }
}
