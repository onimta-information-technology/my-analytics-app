import 'dart:convert';

import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/models/member/trip_history.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TripHistoryScreen extends ConsumerStatefulWidget {
  final MemberProfileRepository memberProfileRepository;

  const TripHistoryScreen({required this.memberProfileRepository, super.key});

  @override
  ConsumerState<TripHistoryScreen> createState() => _GuestPerformanceState();
}

class _GuestPerformanceState extends ConsumerState<TripHistoryScreen> {
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  final Map<String, dynamic> tripData = {
    "ConsecutiveDates": 3.0,
    "ArrivalDate": "2024-12-09T00:00:00",
    "DepartureDate": "2024-12-11T00:00:00",
    "Trip_Drop": 3007200.0,
    "Trip_CashOut": 565000.0,
    "Trip_Result": -2442200.0,
    "Trip_Commission": 201000.0,
    "Trip_ActDrop": 2942200.0,
    "Trip_TotalCoupon": 2487.0,
    "Trip_Hour": 29.0,
    "Trip_Minutes": 34.0,
    "DTL_desc":
        "{\"Game_Type\":\"BACCARAT\",\"G_Date\":\"2024-12-09T00:00:00\",\"DTL\":102750}",
  };

  @override
  void initState() {
    super.initState();
    _getGuestImage();
    String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _startDateController.text = formattedDate;
    _endDateController.text = formattedDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getTripHistory();
    });
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

  Future<void> _getTripHistory() async {
   
    try {
      final guest = ref.watch(selectedGuestProvider);
      setState(() {
        _isLoading = true;
      });

      final tripHistory = await widget.memberProfileRepository.getTripHistory2(
        playerId: guest!.mid,
      );

      print(tripHistory[0].toJson());

      setState(() {
        _tripHistory = tripHistory;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching trip history: $e');

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

  String formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _timeFormat(String dateString) {
    if (dateString == "") return "N/A";
    final date = DateTime.parse(dateString);
    return DateFormat('HH:mm:ss').format(date);
  }

  String _formatDate2(String dateString) {
    if (dateString == "") return "N/A";
    final date = DateTime.parse(dateString);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _parseNumberFormat(double? value) {
    if (value == null || value == 0) return "0.00";
    final formatter = NumberFormat('#,##0');
    String formattedNumber = formatter.format(value);
    return formattedNumber;
  }

  String _parseString(String value) {
    if (value == "") return "N/A";
    return value;
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
    final fontSettings = ref.watch(fontSettingsProvider);
    final guest = ref.watch(selectedGuestProvider);

    if (guest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Guest Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String? imagePath = ratingImageMap[guest.gRating];

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
              physics:
                  const AlwaysScrollableScrollPhysics(), // Enables pull-to-refresh even when content doesn't scroll
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
                                Center(
                                  child: Text(
                                    "M P - ${guest.gName}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color.fromARGB(255, 158, 0, 148),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Table(
                        border: TableBorder.all(),
                        columnWidths: const {
                          0: FractionColumnWidth(0.6),
                          1: FractionColumnWidth(0.4),
                        },
                        children: [
                          ..._tripHistory
                              .map((entry) {
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
                                            "DTL", // Label column
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,

                                          children: entry.dtlDesc.map((dtl) {
                                            return Card(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                side: BorderSide(
                                                  color: Colors.grey.shade300,
                                                  width: 1,
                                                ),
                                              ),
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "DTL: ${dtl.dtl.toStringAsFixed(0)}",
                                                      style: TextStyle(
                                                        fontWeight: fontSettings
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
                                                      ),
                                                    ),
                                                    Text(
                                                      "Date: ${dtl.gDate.split('T').first}",
                                                      style: TextStyle(
                                                        fontSize:
                                                            fontSettings
                                                                .fontSize -
                                                            4,
                                                        color:
                                                            const Color.fromARGB(
                                                              255,
                                                              83,
                                                              82,
                                                              82,
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
                                      Padding(
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
                                                    CrossAxisAlignment.stretch,
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
                                                            "Amount: ${exgift.amount}",
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
                                                            ),
                                                          ),
                                                          Text(
                                                            "Remark: ${exgift.remark}",
                                                            style: TextStyle(
                                                              fontSize:
                                                                  fontSettings
                                                                      .fontSize -
                                                                  3,
                                                            ),
                                                          ),
                                                          Text(
                                                            "Date: ${exgift.trDate.split('T').first}",
                                                            style: TextStyle(
                                                              fontSize:
                                                                  fontSettings
                                                                      .fontSize -
                                                                  4,
                                                              color:
                                                                  const Color.fromARGB(
                                                                    255,
                                                                    83,
                                                                    82,
                                                                    82,
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
                                          ),
                                        ),
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
