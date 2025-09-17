import 'package:ballys_reservation_app/components/marketing_performance.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/guests_provider.dart';
import 'package:ballys_reservation_app/screens/member_visits.dart';
import 'package:ballys_reservation_app/screens/member_visits/sales_persons.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// 🔹 Provider for guest counts
final guestCountsProvider = StateProvider<Map<String, int?>>(
  (ref) => {"today": null, "yesterday": null, "monthly": null},
);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppMode();
      _loadGuestData();
    });
  }

  final String currentDate = DateFormat(
    'EEEE, MMM d, yyyy',
  ).format(DateTime.now());

  Future<void> _initializeAppMode() async {
    try {
      final salesCode = await StorageUtil.getSalesCode();
      if (salesCode != null) {
        ref.read(appmodeSettingsProvider.notifier).setSalesCode(salesCode);
      }
    } catch (e) {
      print('Error initializing app mode: $e');
    }
  }

  _loadUserName() async {
    final name = await StorageUtil.getUserName();
    setState(() {
      userName = name;
    });
  }

  _loadGuestData() async {
    String? salesCode = await StorageUtil.getSalesCode();

    if (salesCode == null || salesCode.isEmpty) {
      print('Error: sales code not found');
      return;
    }

    try {
      final mode = ref.read(appmodeSettingsProvider).appMode;

      // 🔹 Today count
      await ref
          .read(guestsProvider.notifier)
          .getGuestData(9009, salesCode, mode);
      final todayGuests = ref.read(guestsProvider).todayGuests;

      // 🔹 Yesterday count
      await ref
          .read(guestsProvider.notifier)
          .getGuestData(9010, salesCode, mode);
      final yesterdayGuests = ref.read(guestsProvider).yesterdayGuests;

      // 🔹 Monthly count
      await ref
          .read(guestsProvider.notifier)
          .getGuestData(9011, salesCode, mode);
      final monthlyGuests = ref.read(guestsProvider).monthlyGuests;

      // Update Riverpod provider instead of setState
      ref.read(guestCountsProvider.notifier).state = {
        "today": todayGuests.where((g) => g.mid.isNotEmpty).length,
        "yesterday": yesterdayGuests.where((g) => g.mid.isNotEmpty).length,
        "monthly": monthlyGuests.where((g) => g.mid.isNotEmpty).length,
      };
    } catch (e) {
      print('Error loading guest data: $e');
    }
  }

  // 🔹 Reusable fixed size box widget
  Widget buildCountBox({
    required int? count,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      height: 150, // fixed height
      child: Card(
        color: color,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                          fontSize: 40.0,
                          fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guests = ref.watch(guestsProvider);
    final counts = ref.watch(guestCountsProvider);
    ref.listen<AppModeSettings>(appmodeSettingsProvider, (prev, next) {
      if (prev?.appMode != next.appMode) {
        ref.read(guestCountsProvider.notifier).state = {
          "today": null,
          "yesterday": null,
          "monthly": null,
        };

        _loadGuestData(); // reload guest data when mode changes
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          userName != null ? 'Welcome, $userName ' : 'Loading...',
          style: const TextStyle(fontSize: 16),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: () async {
              setState(() {
                // reset data before reloading
                userName = null;
                ref.read(guestCountsProvider.notifier).state = {
                  "today": null,
                  "yesterday": null,
                  "monthly": null,
                };
              });

              // reload username and guest data
              await _loadUserName();
              await _loadGuestData();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
           SingleChildScrollView(
              physics: const BouncingScrollPhysics(),

         child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Replace the existing date display section with this:
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                 // color: const Color.fromARGB(255, 99, 110, 109),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentDate,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Consumer(
                  builder: (context, ref, _) {
                    final appMode = ref.watch(appmodeSettingsProvider).appMode;
                    String heading = appMode == AppMode.myData
                        ? "MY PERFORMANCE"
                        : "OVERALL PERFORMANCE";

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        heading,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                // 🔹 Today & Yesterday row
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
                        child: buildCountBox(
                          count: counts["today"],
                          label: "Today",
                          color: const Color.fromARGB(255, 228, 117, 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final userLevel = await StorageUtil.getUserLevel();
                          if (userLevel == '1') {
                            context.push(
                              '/home/sales-persons',
                              extra: {
                                'title': 'All Sales Persons (Yesterday)',
                                'salesPersons': groupByMGroup(
                                  guests.yesterdayGuests,
                                ),
                              },
                            );
                          } else {
                            context.push(
                              '/home/member-visits',
                              extra: {
                                'title': 'Yesterday Member Visits',
                                'guestList': guests.yesterdayGuests,
                              },
                            );
                          }
                        },
                        child: buildCountBox(
                          count: counts["yesterday"],
                          label: "Yesterday",
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 🔹 Monthly row
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
                                'title': 'All Sales Persons (Monthly)',
                                'salesPersons': groupByMGroup(
                                  guests.monthlyGuests,
                                ),
                              },
                            );
                          } else {
                            context.push(
                              '/home/member-visits',
                              extra: {
                                'title': 'Monthly Member Visits',
                                'guestList': guests.monthlyGuests,
                              },
                            );
                          }
                        },
                        child: buildCountBox(
                          count: counts["monthly"],
                          label: "Monthly",
                          color: const Color.fromARGB(255, 42, 125, 192),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const MarketingPerformanceWidget(),
              ],
            ),
          ),
            ),
          const Watermark(),
        ],
      ),
    );
  }
}
