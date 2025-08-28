import 'dart:convert';

import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/models/member/loyalty_summary.dart';
import 'package:ballys_reservation_app/providers/airline_history_provider.dart';
import 'package:ballys_reservation_app/providers/f_and_b_history_provider.dart';
import 'package:ballys_reservation_app/providers/games_summary_provider.dart';
import 'package:ballys_reservation_app/providers/hotel_history_provider.dart';
import 'package:ballys_reservation_app/providers/loyalty_summary_provider.dart';
import 'package:ballys_reservation_app/providers/profile_date_filter_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/trip_information_provider.dart';
import 'package:ballys_reservation_app/screens/profile/guest_performance/air_ticket_reservation.dart';
import 'package:ballys_reservation_app/screens/profile/guest_performance/f_and_b_history.dart';
import 'package:ballys_reservation_app/screens/profile/guest_performance/games_summary.dart';
import 'package:ballys_reservation_app/screens/profile/guest_performance/hotel_reservation.dart';
import 'package:ballys_reservation_app/screens/profile/guest_performance/loyalty_summary.dart';
import 'package:ballys_reservation_app/screens/profile/guest_performance/trip_information.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GuestPerformanceScreen extends ConsumerStatefulWidget {
  final MemberProfileRepository memberProfileRepository;

  const GuestPerformanceScreen({
    required this.memberProfileRepository,
    super.key,
  });

  @override
  ConsumerState<GuestPerformanceScreen> createState() =>
      _GuestPerformanceState();
}

class _GuestPerformanceState extends ConsumerState<GuestPerformanceScreen> {
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final ValueNotifier<DateTime?> startDateNotifier = ValueNotifier<DateTime?>(
    null,
  );
  final ValueNotifier<DateTime?> endDateNotifier = ValueNotifier<DateTime?>(
    null,
  );
  
  @override
void initState() {
  super.initState();
  _getGuestImage();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final extras = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (extras != null) {
      if (extras['startDateNotifier'] != null) {
        startDateNotifier.value = DateTime.parse(extras['startDateNotifier']);
        _dateFrom = startDateNotifier.value;
        ref.read(dateFilterProvider.notifier).setDateFrom(_dateFrom!);
      }
      if (extras['endDateNotifier'] != null) {
        endDateNotifier.value = DateTime.parse(extras['endDateNotifier']);
        _dateTo = endDateNotifier.value;
        ref.read(dateFilterProvider.notifier).setDateTo(_dateTo!);
      }
          setState(() {
      selectedMenu = 2;
    });
        _performAction();
    }

    // force Trip History tab (menu = 2)


    // auto-run search

  });
}


  int selectedMenu = 1;

  bool _isLoading = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final LoyaltySummary _loyaltySummary = LoyaltySummary(
    mid: "",
    name: "",
    totalPoints: 0,
    ballysRuppes: 0,
    ballysRuppesExpireMessage: "",
    ballysCoins: 0,
    ballysCoinsExpireMessage: "",
    lastUpdateDateTime: "",
    lastRedeemType: "",
    lastRedeemAmount: 0,
    lastRedeemDate: "",
    lastRedeemTime: "",
  );

  Future<void> _getGuestImage() async {
    final guest = ref.read(selectedGuestProvider);
    if (guest!.memImage2 != null) return;

    if (guest.memImage2 == null) {
      print("Fetching image for guest: ${guest.mid}");
      await ref
          .read(selectedGuestProvider.notifier)
          .getGuestImage(9021, guest.mid);
    } else {
      print("Image already loaded for guest: ${guest.memImage2}");
    }
  }

  Future<void> _selectArrivalDate(BuildContext context) async {
    final DateTime? selectedArrivalDate = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (selectedArrivalDate != null && selectedArrivalDate != _dateFrom) {
      ref.read(dateFilterProvider.notifier).setDateFrom(selectedArrivalDate);
      // setState(() {
      //   _dateFrom = selectedArrivalDate;
      //   _startDateController.text = '${_dateFrom!.toLocal()}'.split(' ')[0];
      // Reset the departure date if the arrival date is changed
      // _dateTo = null;
      // _endDateController.clear();
      // });
    }
    print("date is ${ref.watch(dateFilterProvider).dateFrom}");
  }

  Future<void> _selectDepartureDate(BuildContext context) async {
    final DateTime? selectedDepartureDate = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? _dateFrom ?? DateTime.now(),
      firstDate: _dateFrom ?? DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (selectedDepartureDate != null && selectedDepartureDate != _dateTo) {
      ref.read(dateFilterProvider.notifier).setDateTo(selectedDepartureDate);
      // setState(() {
      //   _dateTo = selectedDepartureDate;
      //   _endDateController.text = '${_dateTo!.toLocal()}'.split(' ')[0];
      // });
    }
  }

  Future<void> _performAction() async {
    try {
      if (startDateNotifier.value == null || endDateNotifier.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select start and end dates.")),
        );
        return;
      }

      final guest = ref.watch(selectedGuestProvider);
      setState(() {
        _isLoading = true;
      });

      switch (selectedMenu) {
        case 1:
          await getLoyalitySummary(guest!.mid);
          break;
        case 2:
          if (startDateNotifier.value != null ||
              endDateNotifier.value != null) {
            await getTripHistory2(
              guest!.mid,
              startDateNotifier.value?.toIso8601String() ?? "",
              endDateNotifier.value?.toIso8601String() ?? "",
            );
          } else {
            await getTripHistory(guest!.mid);
          }

          break;
        case 3:
          await getAirlineHistory(guest!.mid);
          break;
        case 4:
          await getHotelHistory(guest!.mid);
          break;
        case 5:
          await getFAndBHistory(guest!.mid);
          break;
        case 6:
          await getGamesSummary(guest!.mid);
          break;
        default:
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching loyalty summary: $e');
    }
  }

  Future<void> getLoyalitySummary(String mid) async {
    await ref
        .read(loyaltySummaryProvider.notifier)
        .getLoyalitySummary(
          playerId: mid,
          dateFrom: startDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(startDateNotifier.value!)
              : '',
          dateTo: endDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(endDateNotifier.value!)
              : '',
        );
  }

  Future<void> getTripHistory(String mid) async {
    await ref
        .read(tripHistoryProvider.notifier)
        .getTripHistory(
          playerId: mid,
          dateFrom: startDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(startDateNotifier.value!)
              : '',
          dateTo: endDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(endDateNotifier.value!)
              : '',
        );
    print(
      "Date from: $DateFormat('yyyy-MM-dd').format(startDateNotifier.value!), Date to: $endDateNotifier, Player ID: $mid",
    );
  }

  Future<void> getTripHistory2(
    String mid,
    String dateFrom,
    String dateTo,
  ) async {
    await ref
        .read(tripHistoryProvider.notifier)
        .getTripHistory2(playerId: mid, dateFrom: dateFrom, dateTo: dateTo);
    print(
      "Date from: $DateFormat('yyyy-MM-dd').format(startDateNotifier.value!), Date to: $endDateNotifier, Player ID: $mid",
    );
  }

  Future<void> getAirlineHistory(String mid) async {
    await ref
        .read(airlineHistoryProvider.notifier)
        .getAirlineHistory(
          playerId: mid,
          dateFrom: startDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(startDateNotifier.value!)
              : '',
          dateTo: endDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(endDateNotifier.value!)
              : '',
        );
  }

  Future<void> getHotelHistory(String mid) async {
    await ref
        .read(hotelHistoryProvider.notifier)
        .getHotelHistory(
          playerId: mid,
          dateFrom: startDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(startDateNotifier.value!)
              : '',
          dateTo: endDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(endDateNotifier.value!)
              : '',
        );
  }

  Future<void> getFAndBHistory(String mid) async {
    await ref
        .read(fAndBHistoryProvider.notifier)
        .getFAndBHistory(
          playerId: mid,
          dateFrom: startDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(startDateNotifier.value!)
              : '',
          dateTo: endDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(endDateNotifier.value!)
              : '',
        );
  }

  Future<void> getGamesSummary(String mid) async {
    await ref
        .read(gamesSummaryProvider.notifier)
        .getGamesSummary(
          playerId: mid,
          dateFrom: startDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(startDateNotifier.value!)
              : '',
          dateTo: endDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(endDateNotifier.value!)
              : '',
        );
  }

  String formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('dd MMM yyyy').format(date);
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
  Widget build(BuildContext context) {
    final guest = ref.watch(selectedGuestProvider);
    final dateFilter = ref.watch(dateFilterProvider);

    String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dateFilter.dateFrom == null) {
      startDateNotifier.value = DateTime.parse(formattedDate);
      _dateFrom = DateTime.parse(formattedDate);
    } else {
      startDateNotifier.value = dateFilter.dateFrom;
      _dateFrom = dateFilter.dateFrom;
    }

    if (dateFilter.dateTo == null) {
      endDateNotifier.value = DateTime.parse(formattedDate);
      _dateTo = DateTime.parse(formattedDate);
    } else {
      endDateNotifier.value = dateFilter.dateTo;
      _dateTo = dateFilter.dateTo;
    }

    if (guest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Guest Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String? imagePath = ratingImageMap[guest.gRating];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Guest Performance",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert, size: 30),
            onSelected: (int result) {
              setState(() {
                selectedMenu = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              const PopupMenuItem<int>(
                value: 1,
                child: ListTile(
                  iconColor: Colors.black,
                  leading: Icon(Icons.attach_money),
                  title: Text(
                    'Loyalty Summary',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<int>(
                value: 2,
                child: ListTile(
                  iconColor: Colors.black,
                  leading: Icon(Icons.local_taxi),
                  title: Text(
                    'Trip Information',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<int>(
                value: 3,
                child: ListTile(
                  iconColor: Colors.black,
                  leading: Icon(Icons.airplanemode_active),
                  title: Text(
                    'Air Ticket Reservation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<int>(
                value: 4,
                child: ListTile(
                  iconColor: Colors.black,
                  leading: Icon(Icons.hotel),
                  title: Text(
                    'Hotel Reservation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<int>(
                value: 5,
                child: ListTile(
                  iconColor: Colors.black,
                  leading: Icon(Icons.local_cafe),
                  title: Text(
                    'F & B',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<int>(
                value: 6,
                child: ListTile(
                  iconColor: Colors.black,
                  leading: Icon(Icons.sports_esports),
                  title: Text(
                    'Games Summary',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 15.0,
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Card(
                        elevation: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20.0,
                            horizontal: 5.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 3,
                                      blurRadius: 5,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return Dialog(
                                          backgroundColor: Colors.transparent,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Hero(
                                                tag: "guest-image",
                                                child: guest.memImage2 != null
                                                    ? Image.memory(
                                                        base64Decode(
                                                          guest.memImage2!,
                                                        ),
                                                        fit: BoxFit.contain,
                                                      )
                                                    : Image.asset(
                                                        'assets/images/placeholder_image.jpg',
                                                        fit: BoxFit.contain,
                                                      ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Hero(
                                    tag: "guest-image",
                                    child: CircleAvatar(
                                      radius: 70,
                                      backgroundImage: guest.memImage2 != null
                                          ? MemoryImage(
                                              base64Decode(guest.memImage2!),
                                            )
                                          : const AssetImage(
                                              'assets/images/placeholder_image.jpg',
                                            ),
                                      backgroundColor: Colors.grey[200],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  "${guest.mid} -  ${guest.memberName}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Last Visit on -  ${formatDate(guest.lastVisitDate)}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(0),
                            child: SizedBox(
                              width: 80,
                              height: 30,
                              child: imagePath != null
                                  ? Hero(
                                      tag: "rating-image",
                                      child: Image.asset(
                                        imagePath,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Hero(
                                      tag: "rating-image",
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
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<DateTime?>(
                          valueListenable: startDateNotifier,
                          builder: (context, value, child) {
                            return TextFormField(
                              controller: TextEditingController(
                                text: value != null
                                    ? DateFormat('yyyy-MM-dd').format(value)
                                    : '',
                              ),
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "Start Date",
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () {
                                    _selectArrivalDate(context);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ValueListenableBuilder<DateTime?>(
                          valueListenable: endDateNotifier,
                          builder: (context, value, child) {
                            return TextFormField(
                              controller: TextEditingController(
                                text: value != null
                                    ? DateFormat('yyyy-MM-dd').format(value)
                                    : '',
                              ),
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "End Date",
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () {
                                    _selectDepartureDate(context);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _performAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.kSecondaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 20),
                          SizedBox(width: 10),
                          Text(
                            "Search",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  if (selectedMenu == 1)
                    LoyaltySummaryWidget(key: ValueKey(selectedMenu)),
                  if (selectedMenu == 2)
                    TripInformationWidget(key: ValueKey(selectedMenu)),
                  if (selectedMenu == 3)
                    AirTicketReservationWidget(key: ValueKey(selectedMenu)),
                  if (selectedMenu == 4)
                    HotelReservationWidget(key: ValueKey(selectedMenu)),
                  if (selectedMenu == 5)
                    FAndBHistoryWidget(key: ValueKey(selectedMenu)),
                  if (selectedMenu == 6)
                    GamesSummaryWidget(key: ValueKey(selectedMenu)),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
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
          const Watermark(),
        ],
      ),
    );
  }
}
