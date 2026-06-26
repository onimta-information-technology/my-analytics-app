import 'dart:convert';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/models/member/trip_history.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TripHistoryScreen extends ConsumerStatefulWidget {
  final MemberProfileRepository memberProfileRepository;

  const TripHistoryScreen({required this.memberProfileRepository, super.key});

  @override
  ConsumerState<TripHistoryScreen> createState() => _GuestPerformanceState();
}

class _GuestPerformanceState extends ConsumerState<TripHistoryScreen> with ConnectivityMixin{
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

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _getTripHistory();
    // });
  }

  @override
  void dispose() {
    startDateNotifier.dispose();
    endDateNotifier.dispose();
    super.dispose();
  }

  bool _isLoading = false;
  List<TripHistory> _tripHistory = [];

  // Pull-to-refresh handler
  Future<void> _handleRefresh() async {
    await _getTripHistory();
  }

  // Manual refresh method (for refresh button)
  Future<void> _refreshData() async {
    await _getTripHistory();
    await _getGuestImage();
  }

  // Shared call to GetVisitFrequency2 (V2 endpoint). `iid` selects the mode:
  //   2 -> Last Trip, 1 -> Last 5 Trips, 0 -> Search by date range
  Future<void> _fetchTripHistory({
    required int iid,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final guest = ref.watch(selectedGuestProvider);
      setState(() {
        _isLoading = true;
      });

      final tripHistory = await widget.memberProfileRepository.getTripHistory3(
        playerId: guest!.mid,
        dateFrom: dateFrom,
        dateTo: dateTo,
        iid: iid,
      );

    //   setState(() {
    //     _tripHistory = tripHistory;
    //     _isLoading = false;
    //   });
    // } catch (e) {
    setState(() {
        _tripHistory = tripHistory;
        _isLoading = false;

        // For "Last Trip" / "Last 5 Trips" quick filters, sync the
        // Start/End date fields to reflect the data that came back:
        // Start Date = earliest arrival, End Date = latest departure.
        if ((iid == 1 || iid == 2) && _tripHistory.isNotEmpty) {
          final arrivalDates = _tripHistory
              .map((e) => DateTime.tryParse(e.arrivalDate))
              .whereType<DateTime>()
              .toList();
          final departureDates = _tripHistory
              .map((e) => DateTime.tryParse(e.departureDate))
              .whereType<DateTime>()
              .toList();

          if (arrivalDates.isNotEmpty) {
            arrivalDates.sort();
            startDateNotifier.value = arrivalDates.first;
          }
          if (departureDates.isNotEmpty) {
            departureDates.sort();
            endDateNotifier.value = departureDates.last;
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load trip history: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(label: 'Retry', onPressed: _refreshData),
          ),
        );
      }
    }
  }

  // Default refresh (used by pull-to-refresh / app bar refresh button):
  // re-runs whatever is currently on screen using the date range, defaulting
  // to a plain search (IID 0) when no dates are set yet.
  Future<void> _getTripHistory() async {
    String? dateFrom;
    String? dateTo;

    if (startDateNotifier.value != null) {
      dateFrom = DateFormat('yyyy-MM-dd').format(startDateNotifier.value!);
    }

    if (endDateNotifier.value != null) {
      dateTo = DateFormat('yyyy-MM-dd').format(endDateNotifier.value!);
    }

    await _fetchTripHistory(iid: 0, dateFrom: dateFrom, dateTo: dateTo);
  }

  // "Last Trip" button -> IID 2, no date filter, hits the API directly.
  Future<void> _showLastTrip() async {
    await _fetchTripHistory(iid: 2, dateFrom: null, dateTo: null);
  }

  // "Last 5 Trips" button -> IID 1, no date filter, hits the API directly.
  Future<void> _showLastFiveTrips() async {
    await _fetchTripHistory(iid: 1, dateFrom: null, dateTo: null);
  }

  Future<void> _getGuestImage() async {
    final guest = ref.read(selectedGuestProvider);
    if (guest!.memImage2 != null) return;

    if (guest.memImage2 == null) {
      await ref
          .read(selectedGuestProvider.notifier)
          .getGuestImage(9021, guest.mid);
    } else {}
  }

  Future<void> _selectArrivalDate(BuildContext context) async {
    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    DateTime selectedDate = startDateNotifier.value ?? now;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Select Start Date",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                minimumDate: DateTime(2000),
                maximumDate: DateTime(2100),
                onDateTimeChanged: (DateTime newDate) {
                  selectedDate = newDate;
                },
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () {
                setState(() {
                  startDateNotifier.value = selectedDate;
                  // Reset end date if before new start date
                  if (endDateNotifier.value != null &&
                      endDateNotifier.value!.isBefore(selectedDate)) {
                    endDateNotifier.value = null;
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text(
                "Confirm",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Future<void> _selectDepartureDate(BuildContext context) async {
    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    DateTime selectedDate =
        endDateNotifier.value ?? startDateNotifier.value ?? now;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Select End Date",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                minimumDate: DateTime(2000),
                maximumDate: DateTime(2100),
                onDateTimeChanged: (DateTime newDate) {
                  selectedDate = newDate;
                },
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () {
                // Validate end date is after start date
                if (startDateNotifier.value != null &&
                    selectedDate.isBefore(startDateNotifier.value!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End date must be after start date'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                setState(() {
                  endDateNotifier.value = selectedDate;
                });
                Navigator.of(context).pop();
              },
              child: const Text(
                "Confirm",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // "Search" button: validates that both Start Date and End Date are
  // filled in before calling the API with IID 0.
  void _performAction() {
    if (startDateNotifier.value == null || endDateNotifier.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both Start Date and End Date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (startDateNotifier.value!.isAfter(endDateNotifier.value!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start date must be before end date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final dateFrom = DateFormat('yyyy-MM-dd').format(startDateNotifier.value!);
    final dateTo = DateFormat('yyyy-MM-dd').format(endDateNotifier.value!);

    _fetchTripHistory(iid: 0, dateFrom: dateFrom, dateTo: dateTo);
  }

  String formatDate(String dateString) {
    if (dateString.isEmpty) return "N/A";
    final date = DateTime.tryParse(dateString);
    if (date == null) return "N/A";
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatDate2(String dateString) {
    if (dateString.isEmpty) return "N/A";
    final date = DateTime.tryParse(dateString);
    if (date == null) return "N/A";
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _parseNumberFormat(double? value) {
    if (value == null || value == 0) return "0.00";
    final formatter = NumberFormat('#,##0');
    String formattedNumber = formatter.format(value);
    return formattedNumber;
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

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final guest = ref.watch(selectedGuestProvider);

    if (guest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Guest Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip History"),
        actions: [
          // Manual refresh button in app bar
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Wrap the main content in RefreshIndicator for pull-to-refresh
          RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Constants.kSecondaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Center(
                                  child: Text(
                                    "M P - ${guest.gName}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Color.fromARGB(255, 158, 0, 148),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Last Visit on -  ${formatDate(guest.lastVisitDate)}",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
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
                          child: Hero(
                                tag: "rating-image-${guest.mid}",
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRatingColorBallys(guest.gRating),
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
                                    guest.gRating ?? 'N/A',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ],
                    ),

                    // Date filter section
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Start Date",
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  labelText: "End Date",
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
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
                    const SizedBox(height: 8),

                    // Quick-filter buttons: call the API directly with the
                    // appropriate IID (2 = Last Trip, 1 = Last 5 Trips).


                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _performAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.kSecondaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
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
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                                        Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _showLastTrip,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Constants.kSecondaryColor,
                              backgroundColor:  Constants.kSecondaryColor,
                              side: BorderSide(
                                color: Constants.kSecondaryColor,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            child: const Text(
                              "Last Trip",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _showLastFiveTrips,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Constants.kSecondaryColor,
                                backgroundColor:  Constants.kSecondaryColor,
                              side: BorderSide(
                                color: Constants.kSecondaryColor,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            child: const Text(
                              "Last 5 Trips",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
// // Visit count summary card
// if (_tripHistory.isNotEmpty)
//   Container(
//     width: double.infinity,
//     margin: const EdgeInsets.only(bottom: 8),
//     padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
//     decoration: BoxDecoration(
//       color: const Color.fromARGB(255, 46, 25, 233).withOpacity(0.1),
//       borderRadius: BorderRadius.circular(12),
//       border: Border.all(color: Constants.kSecondaryColor.withOpacity(0.4)),
//     ),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         const Icon(Icons.confirmation_number_outlined, size: 22),
//         const SizedBox(width: 10),
//         Text(
//           "Total Visits : ${_tripHistory.length}",
//           style: TextStyle(
//             fontSize: fontSettings.fontSize + 5,
//             fontWeight: FontWeight.w900,
//             color: const Color.fromARGB(255, 6, 8, 64),
//           ),
//         ),
//       ],
//     ),
//   ),
// Visit count summary card
if (_tripHistory.isNotEmpty)
  Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 46, 25, 233).withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Constants.kSecondaryColor.withOpacity(0.4)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.confirmation_number_outlined, size: 22),
        const SizedBox(width: 10),
        Text(
          "Total Visits :",
          style: TextStyle(
            fontSize: fontSettings.fontSize + 5,
            fontWeight: FontWeight.w900,
            color: const Color.fromARGB(255, 6, 8, 64),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 233, 80, 25),
            borderRadius: BorderRadius.circular(20), // pill/rounded shape
          ),
          child: Text(
            "${_tripHistory.length}",
            style: TextStyle(
              fontSize: fontSettings.fontSize + 5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  ),
                    // Trip history table
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Table(
                        border: TableBorder.all(),
                        columnWidths: const {
                          0: FractionColumnWidth(0.5),
                          1: FractionColumnWidth(0.5),
                        },
                        children: [
                          ..._tripHistory
                              .asMap()
                              .entries
                              .map((mapEntry) {
                                final index = mapEntry.key;
                                final entry = mapEntry.value;
                                final isLastEntry =
                                    index == _tripHistory.length - 1;
                                return [
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      color: Color.fromARGB(47, 181, 225, 250),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          children: [
                                            Text(
                                              "Arrival Date",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: fontSettings.fontSize,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              _formatDate2(entry.arrivalDate),
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: fontSettings.fontSize,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          children: [
                                            Text(
                                              "Departure Date",
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: fontSettings.fontSize,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              _formatDate2(entry.departureDate),
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: fontSettings.fontSize,
                                                fontWeight: FontWeight.w900,
                                              ),
                                              textAlign: TextAlign.end,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Consecutive Dates",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          entry.consecutiveDates
                                              .toInt()
                                              .toString(),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Arrival Date",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _formatDate2(entry.arrivalDate),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Departure Date",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _formatDate2(entry.departureDate),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Drop (Est)",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _parseNumberFormat(entry.tripDrop),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Cash Out (Est)",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _parseNumberFormat(entry.tripCashOut),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Result (Est)",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _parseNumberFormat(entry.tripResult),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color:
                                                (entry.tripResult != null &&
                                                    entry.tripResult! < 0)
                                                ? Colors.red
                                                : Colors.green,
                                            fontSize: fontSettings.fontSize + 1,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Commision (Est)",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _parseNumberFormat(
                                            entry.tripCommission,
                                          ),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                      decoration: const BoxDecoration(
    color: Color.fromARGB(255, 1, 255, 22), // light green background
  ),
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Actual Drop (Est)",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _parseNumberFormat(entry.tripActDrop),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Total Coupon (Est)",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _parseNumberFormat(
                                            entry.tripTotalCoupon,
                                          ),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "F & B Cost (Est)",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _parseNumberFormat(entry.fbCost),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Air Ticket Cost (Est)",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _parseNumberFormat(entry.atCost),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Transport Cost (Est)",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _parseNumberFormat(
                                            entry.transportCost,
                                          ),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Hotel Cost (Est)",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _parseNumberFormat(entry.htcost),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                    ),
                                    children: [
                                      Container(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "DTL",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        color: Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: (entry.dtlDesc.isEmpty)
                                              ? Text(
                                                  "N/A",
                                                  textAlign: TextAlign.end,
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    fontWeight:
                                                        fontSettings.fontWeight,
                                                  ),
                                                )
                                              : Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: entry.dtlDesc.map((
                                                    dtl,
                                                  ) {
                                                    return Card(
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        side: BorderSide(
                                                          color: Colors
                                                              .grey
                                                              .shade300,
                                                          width: 1,
                                                        ),
                                                      ),
                                                      margin:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8.0,
                                                            ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              "DTL : ${NumberFormat('#,###').format(dtl.dtl.toInt())}",
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    fontSettings
                                                                        .fontWeight,
                                                                fontSize:
                                                                    fontSettings
                                                                        .fontSize -
                                                                    2,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Game: ${dtl.gameType}",
                                                              style: TextStyle(
                                                                fontSize:
                                                                    fontSettings
                                                                        .fontSize -
                                                                    3,
                                                                fontWeight:
                                                                    fontSettings
                                                                        .fontWeight,
                                                                color:
                                                                    const Color.fromARGB(
                                                                      255,
                                                                      22,
                                                                      22,
                                                                      22,
                                                                    ),
                                                              ),
                                                            ),
                                                            Text(
                                                              "Date: ${dtl.gDate.split('T').first}",
                                                              style: TextStyle(
                                                                fontSize:
                                                                    fontSettings
                                                                        .fontSize -
                                                                    4,
                                                                fontWeight:
                                                                    fontSettings
                                                                        .fontWeight,
                                                                color:
                                                                    const Color.fromARGB(
                                                                      255,
                                                                      22,
                                                                      22,
                                                                      22,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                    ),
                                    children: [
                                      Container(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Extra Complimentary",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        color: Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: (entry.exGift.isEmpty)
                                              ? Text(
                                                  "N/A",
                                                  textAlign: TextAlign.end,
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    fontWeight:
                                                        fontSettings.fontWeight,
                                                  ),
                                                )
                                              : Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: entry.exGift.map((
                                                    exgift,
                                                  ) {
                                                    return Card(
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        side: BorderSide(
                                                          color: Colors
                                                              .grey
                                                              .shade300,
                                                          width: 1,
                                                        ),
                                                      ),
                                                      margin:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8.0,
                                                            ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              "Amount: ${NumberFormat('#,###').format(exgift.amount)}",
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    fontSettings
                                                                        .fontWeight,
                                                                fontSize:
                                                                    fontSettings
                                                                        .fontSize -
                                                                    2,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Gift type: ${exgift.giftType}",
                                                              style: TextStyle(
                                                                fontSize:
                                                                    fontSettings
                                                                        .fontSize -
                                                                    3,
                                                                fontWeight:
                                                                    fontSettings
                                                                        .fontWeight,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Remark: ${exgift.remark}",
                                                              style: TextStyle(
                                                                fontSize:
                                                                    fontSettings
                                                                        .fontSize -
                                                                    3,
                                                                fontWeight:
                                                                    fontSettings
                                                                        .fontWeight,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Date: ${exgift.trDate.split('T').first}",
                                                              style: TextStyle(
                                                                fontSize:
                                                                    fontSettings
                                                                        .fontSize -
                                                                    4,
                                                                fontWeight:
                                                                    fontSettings
                                                                        .fontWeight,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "HH",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          entry.tripHour.toInt().toString(),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Container(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "MM",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          entry.tripMinutes.toInt().toString(),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isLastEntry)
                                    TableRow(
                                      children: [
                                        Container(
                                          height: 10,
                                          color: Colors.red,
                                        ),
                                        Container(
                                          height: 10,
                                          color: Colors.red,
                                        ),
                                      ],
                                    ),
                                ];
                              })
                              .expand((x) => x),
                        ],
                      ),
                    ),
                  ],
                ),
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