import 'package:ballys_reservation_app/components/location_selector_widget.dart';
import 'package:ballys_reservation_app/components/marketing_performance.dart';
import 'package:ballys_reservation_app/components/snow.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/birthdays_provider.dart';
import 'package:ballys_reservation_app/providers/daily_walking_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/guests_provider.dart';
import 'package:ballys_reservation_app/providers/marketing_provider.dart';
import 'package:ballys_reservation_app/providers/reservation_provider.dart';
import 'package:ballys_reservation_app/providers/special_gift_provider.dart';
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
final eventShownProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  String? userName;
  bool _isLoadingData = false;
  bool _showEvent = false;
  String? locationLogo;


  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadLocationLogo();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      
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
      
        final guestsState = ref.read(guestsProvider);
        if (guestsState.todayGuests.isEmpty &&
            guestsState.yesterdayGuests.isEmpty &&
            guestsState.monthlyGuests.isEmpty) {
          _loadGuestData();
        }
      }
    });
  }

  void _checkAndShowEvent() {
    final now = DateTime.now();
    final hasShownEvent = ref.read(eventShownProvider);

    if (now.month == 12 && !hasShownEvent) {
      setState(() {
        _showEvent = true;
      });

      ref.read(eventShownProvider.notifier).state = true;

      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showEvent = false;
          });
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

  
  Future<void> _loadGuestData() async {
  
    if (_isLoadingData) return;

    _isLoadingData = true;

    String? salesCode = await StorageUtil.getSalesCode();

    if (salesCode == null || salesCode.isEmpty) {
      _isLoadingData = false;
      return;
    }

    try {

      ref.read(guestCountsProvider.notifier).state = {
        "today": null,
        "yesterday": null,
        "monthly": null,
      };

     
      final currentMode = ref.read(appmodeSettingsProvider).appMode;


      ref.read(guestsProvider.notifier).resetData();


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
    if (!mounted) return;
    if (_isLoadingData) return;

    if (mounted) {
      setState(() {
        userName = null;
      });
    }

    // Reset counts immediately
    ref.read(guestCountsProvider.notifier).state = {
      "today": null,
      "yesterday": null,
      "monthly": null,
    };

    // Reload data
    await Future.wait<void>([_loadUserName(), _loadGuestData()]);
  }

  Future<void> _loadLocationLogo() async {
    final location = await StorageUtil.getCurrentLocation();
    if (mounted) {
      setState(() {
        locationLogo = location?.imageUrl;
      });
    }
  }


  Widget buildCountBox({
    required int? count,
    required String label,
    required Color color,
  }) {
    final formatter = NumberFormat.decimalPattern();
    return SizedBox(
      height: 150, 
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
        title: Text(
          userName != null ? 'Welcome, $userName' : 'Loading...',
          style: const TextStyle(fontSize: 16),
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                 
                  FutureBuilder<bool>(
                    future: StorageUtil.isAdmin(),
                    builder: (context, snapshot) {
                      // Only show the card if user is admin
                      if (snapshot.hasData && snapshot.data == true) {
                        return Container(
                          width: double.infinity, // Full width
                          margin: const EdgeInsets.only(bottom: 12.0),
                          child: Card(
                            elevation: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 16.0,
                              ),
                              child: Row(
                                children: [
                                  // Bally's Logo
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.shade200,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child:
                                        locationLogo != null &&
                                            locationLogo!.isNotEmpty
                                        ? Image.network(
                                            locationLogo!,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.business,
                                                  size: 28,
                                                ),
                                          )
                                        : const Icon(Icons.business, size: 28),
                                  ),

                                  const SizedBox(width: 8),

                                  // Location Dropdown - Takes remaining space
                                  Expanded(
                                    child: LocationSelectorWidget(
                                      onLocationChanged: () {
                                        // Refresh data when location changes
                                        _manualRefresh();
                                        _loadLocationLogo();

                                        ref
                                            .read(reservationProvider.notifier)
                                            .clearReservations();
                                        ref
                                            .read(giftProvider.notifier)
                                            .clearGifts();
                                        ref
                                            .read(birthdayProvider.notifier)
                                            .clearBirthdays();
                                        ref
                                            .read(dailyWalkingProvider.notifier)
                                            .clearDailyWalkingGuests();
                                        ref
                                            .read(marketingProvider.notifier)
                                            .clearMarketing();
                                      },
                                    ),
                                  ),

                                  // Settings Icon
                                  // IconButton(
                                  //   icon: const Icon(
                                  //     Icons.tune,
                                  //     color: Colors.black54,
                                  //     size: 26,
                                  //   ),
                                  //   onPressed: () {
                                  //     // Handle settings action
                                  //   },
                                  // ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      // Return empty container for non-admin users
                      return const SizedBox.shrink();
                    },
                  ),
                  // Date display section
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 1.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
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
                  const MarketingPerformanceWidget(),
                ],
              ),
            ),
          ),
          Event(isShow: _showEvent),
        ],
      ),
    );
  }
}
