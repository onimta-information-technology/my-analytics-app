import 'package:ballys_reservation_app/components/Event/events.dart';
import 'package:ballys_reservation_app/components/marketing_breakdown_chart_card.dart';
import 'package:ballys_reservation_app/components/marketing_performance.dart';
import 'package:ballys_reservation_app/components/visit_summary_chart_card.dart';
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
final homeScreenInitializedProvider = StateProvider<bool>((ref) => false);

// 🔹 Single provider for active event
final activeEventProvider = StateProvider<EventType?>((ref) => null);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  String? userName;
  bool _isLoadingData = false;

  // 🔹 Keep the widget alive when navigating away
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserName();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 🔹 Check if user is actually logged in
      final userName = await StorageUtil.getUserName();
      final salesCode = await StorageUtil.getSalesCode();

      if (userName == null || salesCode == null) {
        // User not logged in, reset everything
        ref.read(homeScreenInitializedProvider.notifier).state = false;
        ref.read(guestsProvider.notifier).resetData();
        ref.read(guestCountsProvider.notifier).state = {
          "today": null,
          "yesterday": null,
          "monthly": null,
        };
        return;
      }

      final hasInitialized = ref.read(homeScreenInitializedProvider);
      if (!hasInitialized) {
        ref.read(homeScreenInitializedProvider.notifier).state = true;
        _initializeAppMode();
        _loadGuestData();
        _checkAndShowEvent();
      } else {
        // 🔹 Even if initialized, verify data exists
        final guestsState = ref.read(guestsProvider);
        if (guestsState.todayGuests.isEmpty &&
            guestsState.yesterdayGuests.isEmpty &&
            guestsState.monthlyGuests.isEmpty) {
          _loadGuestData();
        }
      }
    });
  }

  /// 🎉 Unified event checking method
  void _checkAndShowEvent() {
    final now = DateTime.now();
    final currentEvent = ref.read(activeEventProvider);

    // Only show if no event is currently active
    if (currentEvent != null) return;
    EventType? eventToShow;
    int displayDuration = 5;
    if (now.month == 12) {
      eventToShow = EventType.christmas;
      displayDuration = 4;
    } else if (now.month == 1 && now.day == 13) {
      eventToShow = EventType.lohri;
      displayDuration = 4;
    } else if (now.month == 1 && now.day == 14) {
      eventToShow = EventType.thaiPongal;
      displayDuration = 4;
    }else if (now.month == 1 && now.day == 26) {
      eventToShow = EventType.republicDay;
      displayDuration = 4;
    }else if (now.month == 2 && now.day == 4) {
      eventToShow = EventType.independence;
      displayDuration = 4;
    }else if (now.month == 2 && now.day == 14) {
      eventToShow = EventType.valentineDay;
      displayDuration = 5;
    }else if (now.month == 2 && now.day == 17) {
      eventToShow = EventType.chineseNewYear;
      displayDuration = 5;
    }else if (now.month == 3 && now.day == 4) {
      eventToShow = EventType.holi;
      displayDuration = 5;
    }else if (now.month == 3 && now.day == 8) {
      eventToShow = EventType.happyWomen;
      displayDuration = 5;
    }else if (now.month == 3 && now.day == 21) {
      eventToShow = EventType.ramadan;
      displayDuration = 5;
    }else if (now.month == 4 && now.day == 5) {
      eventToShow = EventType.easter;
      displayDuration = 5;
    }else if (now.month == 4 && (now.day == 13 || now.day == 14 || now.day == 15)) {
      eventToShow = EventType.sinhalatamilNewYear;
      displayDuration = 5;
    }else if (now.month == 4 && now.day == 22) {
      eventToShow = EventType.earthDay;
      displayDuration = 5;
    }else if (now.month == 5 && now.day == 1) {
      eventToShow = EventType.labourDay;
      displayDuration = 5;
    }else if (now.month == 5 && now.day == 11) {
      eventToShow = EventType.mothersDay;
      displayDuration = 5;
    }else if (now.month == 5 && now.day == 26) {
      eventToShow = EventType.eidAlAdha;
      displayDuration = 5;
    }else if (now.month == 6 && now.day == 5) {
      eventToShow = EventType.environmentDay;
      displayDuration = 5;
    }else if (now.month == 6 && now.day == 15) {
      eventToShow = EventType.fathersDay;
      displayDuration = 5;
    }else if (now.month == 7 && now.day == 30) {
      eventToShow = EventType.friendshipDay;
      displayDuration = 5;
    }else if (now.month == 8 && now.day == 12) {
      eventToShow = EventType.youthDay;
      displayDuration = 5;
    }else if (now.month == 8 && now.day == 14) {
      eventToShow = EventType.pakistanIndependenceDay;
      displayDuration = 5;
    }else if (now.month == 8 && now.day == 15) {
      eventToShow = EventType.indianIndependenceDay;
      displayDuration = 5;
    }else if (now.month == 8 && now.day == 28) {
      eventToShow = EventType.rakshaBandhan;
      displayDuration = 5;
    }else if (now.month == 9 && now.day == 4) {
      eventToShow = EventType.janmashtamiEvent;
      displayDuration = 5;
    }
    // else if (now.month == 9 && now.day == 14) {
    //   eventToShow = EventType.ganeshchaturthi;
    //   displayDuration = 200;
    // }
    else if (now.month == 9 && now.day == 21) {
      eventToShow = EventType.peaceDay;
      displayDuration = 5;
    }else if (now.month == 9 && now.day == 25) {
      eventToShow = EventType.autumnFestival;
      displayDuration = 5;
    }else if (now.month == 9 && now.day == 27) {
      eventToShow = EventType.travellingBags;
      displayDuration = 5;
    }else if (now.month == 10 && now.day == 31) {
      eventToShow = EventType.halloween;
      displayDuration = 5;
    }else if (now.month == 11 && now.day == 8) {
      eventToShow = EventType.diwali;
      displayDuration = 5;
    }

    if (eventToShow != null) {
      // Show the event
      ref.read(activeEventProvider.notifier).state = eventToShow;

      // Hide after duration
      Future.delayed(Duration(seconds: displayDuration), () {
        if (mounted) {
          ref.read(activeEventProvider.notifier).state = null;
        }
      });
    }
  }

  // 🔹 Override didChangeDependencies to prevent auto-refresh on return
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't reload data when returning from navigation
    // Only reload if explicitly needed (like app mode change)
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
      // Handle error
    }
  }

  Future<void> _loadUserName() async {
    final name = await StorageUtil.getUserName();
    if (mounted) {
      setState(() {
        userName = name;
      });
    }
  }

  // 🔹 Enhanced _loadGuestData with proper state management
  Future<void> _loadGuestData() async {
    // Prevent multiple concurrent loads
    if (_isLoadingData) return;

    _isLoadingData = true;

    String? salesCode = await StorageUtil.getSalesCode();

    if (salesCode == null || salesCode.isEmpty) {
      _isLoadingData = false;
      return;
    }

    try {
      // 🔹 Reset counts to null to show loading state
      ref.read(guestCountsProvider.notifier).state = {
        "today": null,
        "yesterday": null,
        "monthly": null,
      };

      // 🔹 Get current mode at the time of loading
      final currentMode = ref.read(appmodeSettingsProvider).appMode;

      // 🔹 Clear existing guest data first
      ref.read(guestsProvider.notifier).resetData();

      // 🔹 Load data for all three periods
      await Future.wait<void>([
        ref
            .read(guestsProvider.notifier)
            .getGuestData(9009, salesCode, currentMode),
        ref
            .read(guestsProvider.notifier)
            .getGuestData(9010, salesCode, currentMode),
        ref
            .read(guestsProvider.notifier)
            .getGuestData(9011, salesCode, currentMode),
      ]);

      // 🔹 Get the latest guest data after all loads complete
      final guestsState = ref.read(guestsProvider);

      // 🔹 Verify mode hasn't changed during loading
      final finalMode = ref.read(appmodeSettingsProvider).appMode;
      if (currentMode != finalMode) {
        _isLoadingData = false;
        _loadGuestData(); // Reload with new mode
        return;
      }

      // 🔹 Update counts with current data - THIS will hide the spinner
      ref.read(guestCountsProvider.notifier).state = {
        "today": guestsState.todayGuests.where((g) => g.mid.isNotEmpty).length,
        "yesterday": guestsState.yesterdayGuests
            .where((g) => g.mid.isNotEmpty)
            .length,
        "monthly": guestsState.monthlyGuests
            .where((g) => g.mid.isNotEmpty)
            .length,
      };
    } catch (e) {
      // Set counts to 0 on error instead of leaving as null
      ref.read(guestCountsProvider.notifier).state = {
        "today": 0,
        "yesterday": 0,
        "monthly": 0,
      };
    } finally {
      _isLoadingData = false;
    }
  }

  // 🔹 Manual refresh method for explicit user action
  Future<void> _manualRefresh() async {
    if (_isLoadingData) return;

    setState(() {
      userName = null;
    });

    // Reset counts immediately
    ref.read(guestCountsProvider.notifier).state = {
      "today": null,
      "yesterday": null,
      "monthly": null,
    };

    // Reload data
    await Future.wait<void>([_loadUserName(), _loadGuestData()]);
  }

  // 🔹 Reusable fixed size box widget
  Widget buildCountBox({
    required int? count,
    required String label,
    required Color color,
  }) {
    final formatter = NumberFormat.decimalPattern();
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
                    
                        formatter.format(count),
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
    super.build(context); // 🔹 Required for AutomaticKeepAliveClientMixin

    final guests = ref.watch(guestsProvider);
    final counts = ref.watch(guestCountsProvider);
    final activeEvent = ref.watch(activeEventProvider);

    // 🔹 Only listen for app mode changes, not navigation returns
    ref.listen<AppModeSettings>(appmodeSettingsProvider, (prev, next) {
      if (prev?.appMode != next.appMode) {
        // Reset counts and reload data only for mode changes
        ref.read(guestCountsProvider.notifier).state = {
          "today": null,
          "yesterday": null,
          "monthly": null,
        };

        Future.delayed(const Duration(milliseconds: 100), () {
          _loadGuestData();
        });
      }
    });
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, 
        title: Text(         
          userName != null ? 'Welcome, $userName ' : 'Loading...',
          style: const TextStyle(fontSize: 16, fontFamily: 'ABCArizonaFlare'),
        ),
        actions: [
          IconButton(
            padding: const EdgeInsets.all(10.0),
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: _manualRefresh,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // Date display section
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 1.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
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

                  // Performance heading
                  Consumer(
                    builder: (context, ref, _) {
                      final appMode = ref
                          .watch(appmodeSettingsProvider)
                          .appMode;
                      String heading = appMode == AppMode.myData
                          ? "MY PERFORMANCE"
                          : "OVERALL PERFORMANCE";

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              heading,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Today & Yesterday row
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
                      const SizedBox(width: 3),
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

                  const SizedBox(height: 3),

                  // Monthly row
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
                  const SizedBox(height: 8),
                  const MarketingBreakdownHalfPieCard(),
                    const SizedBox(height: 8),
VisitSummaryChartCard(
  todayCount: counts["today"],
  yesterdayCount: counts["yesterday"],
  monthlyCount: counts["monthly"],
),
                  const SizedBox(height: 8),
                  const MarketingPerformanceWidget(),
                ],
              ),
            ),
          ),

          EventOverlay(activeEvent: activeEvent),
        ],
      ),
    );
  }
}
