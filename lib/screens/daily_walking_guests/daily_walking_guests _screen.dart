import 'dart:convert';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/models/Guest/daily_walking_guest.dart';
import 'package:ballys_reservation_app/providers/daily_walking_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DailyWalkingGuestScreen extends ConsumerStatefulWidget {
  const DailyWalkingGuestScreen({super.key});

  @override
  ConsumerState<DailyWalkingGuestScreen> createState() =>
      _DailyWalkingGuestScreenState();
}

class _DailyWalkingGuestScreenState
    extends ConsumerState<DailyWalkingGuestScreen> {
  bool _isFirstLoad = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    final guests = ref.read(dailyWalkingProvider);
    if (guests.isEmpty) {
      await ref.read(dailyWalkingProvider.notifier).getDailyWalkingGuests();
    }
    if (mounted) {
      setState(() {
        _isFirstLoad = false;
      });
    }
  }

  Future<void> _refreshGuests() async {
    setState(() {
      _isRefreshing = true;
    });
    await ref.read(dailyWalkingProvider.notifier).getDailyWalkingGuests();
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  String _formatDate2(String dateString) {
    if (dateString.isEmpty) return "N/A";
    final date = DateTime.parse(dateString);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _parseNumberFormat(double? value) {
    if (value == null || value == 0) return "0.00";
    return NumberFormat('#,##0').format(value);
  }

  Future<void> _launchPhone(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  void _goToGuestPerformance(DailyWalkingGuest guest) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfyesterday = DateTime(
      now.year,
      now.month,
      now.day - 1,
      23,
      59,
      59,
    );

    final String today = DateFormat('yyyy-MM-dd').format(startOfToday);
    final String yesterday = DateFormat('yyyy-MM-dd').format(endOfyesterday);

    String safeDateFrom;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(guest.dateRemark)) {
      safeDateFrom = guest.dateRemark;
    } else {
      safeDateFrom = today;
    }

    final selectedGuest = Guest(
      mid: guest.mId,
      memberName: guest.mname,
      country: guest.country ?? '',
      lastVisitDate: safeDateFrom,
      age: 0,
      gRating: guest.gName,
      mGroup: guest.mgroup,
      gName: guest.gName,
      memImage2: guest.menImage2,
      gift: null,
      mDrop: null,
    );

    ref.read(selectedGuestProvider.notifier).setSelectedGuest(selectedGuest);
    // context.push(
    //   '/home/profile/guest-performance',
    //   extra: {'startDateNotifier': yesterday, 'endDateNotifier': safeDateFrom},
    // );
    context.push('/home/profile');
  }

  @override
  Widget build(BuildContext context) {
    final guests = ref.watch(dailyWalkingProvider);
    final fontSettings = ref.watch(fontSettingsProvider);

    final showSpinner = (_isFirstLoad && guests.isEmpty) || _isRefreshing;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Walking Guests"),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh, size: 30),
            onPressed: _isRefreshing ? null : _refreshGuests,
          ),
        ],
      ),
      body: Stack(
        children: [
          guests.isEmpty && !showSpinner
              ? const Center(child: Text("No data available"))
              : Column(
                  children: [
                    // Total Guest Card
                    Card(
                      margin: const EdgeInsets.all(16.0),
                      elevation: 4.0,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.people, color: Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    "Total Guest",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              alignment: Alignment.centerRight,
                              child: Text(
                                guests.length.toString(),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: guests.asMap().entries.map((mapEntry) {
                            final index = mapEntry.key;
                            final entry = mapEntry.value;

                            return Column(
                              children: [
                                Table(
                                  border: TableBorder.all(),
                                  columnWidths: const {
                                    0: FlexColumnWidth(),
                                    1: FlexColumnWidth(),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(
                                        color: Color.fromARGB(
                                          47,
                                          181,
                                          225,
                                          250,
                                        ),
                                      ),
                                      children: const [
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            "",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            "Details",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: Constants.kPrimaryColor
                                            .withAlpha(50),
                                      ),
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(8.0),
                                          alignment: Alignment.centerLeft,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  _goToGuestPerformance(entry);
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Row(
                                                  children: [
                                                    // Icon(
                                                    //   Icons.person_search,
                                                    //   size: 20,
                                                    //   color: const Color.fromARGB(255, 224, 6, 6),
                                                    // ),

                                                  Container(
                                                                        padding: const EdgeInsets.all(4),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color.fromARGB(255, 230, 0, 0),
                                                                          borderRadius: BorderRadius.circular(6),
                                                                        ),
                                                                        child: const Icon(Icons.person_search, size: 20, color: Colors.white),
                                                                      ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        entry.mId,
                                                        style: TextStyle(
                                                          color: Colors.blue,
                                                          fontSize: fontSettings
                                                              .fontSize+2,
                                                          fontWeight:
                                                              fontSettings
                                                                  .fontWeight,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          const Color.fromARGB(
                                                            255,
                                                            230,
                                                            0,
                                                            0,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 20,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      entry.mname.isEmpty
                                                          ? "N/A"
                                                          : entry.mname,
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: fontSettings
                                                            .fontSize,
                                                        fontWeight: fontSettings
                                                            .fontWeight,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          const Color.fromARGB(
                                                            255,
                                                            230,
                                                            0,
                                                            0,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.flag,
                                                      size: 20,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      entry.country?.isEmpty ??
                                                              true
                                                          ? "N/A"
                                                          : entry.country!,
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: fontSettings
                                                            .fontSize,
                                                        fontWeight: fontSettings
                                                            .fontWeight,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          color: Colors.white,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: entry.menImage2.isNotEmpty
                                                ? GestureDetector(
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        barrierDismissible:
                                                            true,
                                                        builder: (_) => Dialog(
                                                          backgroundColor:
                                                              Colors
                                                                  .transparent,
                                                          child: Image.memory(
                                                            base64Decode(
                                                              entry.menImage2,
                                                            ),
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Image.memory(
                                                      base64Decode(
                                                        entry.menImage2,
                                                      ),
                                                      fit: BoxFit.contain,
                                                    ),
                                                  )
                                                : GestureDetector(
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        barrierDismissible:
                                                            true,
                                                        builder: (_) => Dialog(
                                                          backgroundColor:
                                                              Colors
                                                                  .transparent,
                                                          child: Image.asset(
                                                            'assets/images/placeholder_image.jpg',
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Image.asset(
                                                      'assets/images/placeholder_image.jpg',
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ..._buildGuestRows(entry, fontSettings),
                                  ],
                                ),

                                if (index < guests.length - 1)
                                  Container(height: 10, color: Colors.red),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
          // if (showSpinner) const Center(child: CircularProgressIndicator()),
          if (showSpinner)
  Container(
    decoration: const BoxDecoration(
      color: Color.fromARGB(135, 117, 115, 115),
    ),
    child: Center(
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

  List<TableRow> _buildGuestRows(DailyWalkingGuest entry, fontSettings) {
    return [
      _buildRow("Contact No", entry.phone, fontSettings, isPhone: true),
      _buildRow("Register Date", _formatDate2(entry.rdt), fontSettings),
      _buildRow("Latest Visit", entry.dateRemark, fontSettings),
      _buildRow("Type", entry.gName, fontSettings),
      _buildRow("DTL", _parseNumberFormat(entry.dlt), fontSettings),
      _buildRow("ADT", _parseNumberFormat(entry.adt), fontSettings),
    ];
  }

  TableRow _buildRow(
    String label,
    String value,
    fontSettings, {
    bool isPhone = false,
  }) {
    return TableRow(
      decoration: BoxDecoration(color: Constants.kPrimaryColor.withAlpha(50)),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: isPhone && value.isNotEmpty
                ? InkWell(
                    onTap: () => _launchPhone(value),
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Icon(
                        //   Icons.phone,
                        //   size: 22,
                        //   color: const Color.fromARGB(255, 254, 2, 2),
                        // ),
                          Container(
                                                                        padding: const EdgeInsets.all(4),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color.fromARGB(255, 230, 0, 0),
                                                                          borderRadius: BorderRadius.circular(6),
                                                                        ),
                                                                        child: const Icon(Icons.phone, size: 22, color: Colors.white),
                                                                      ),
                        const SizedBox(width: 6),
                        Text(
                          value,
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    value.isEmpty ? "N/A" : value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
