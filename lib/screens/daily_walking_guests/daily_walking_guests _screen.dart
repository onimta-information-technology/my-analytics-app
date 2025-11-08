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
      mGroup: null,
      gName: guest.gName,
      memImage2: guest.menImage2,
      gift: null,
      mDrop: null,
    );

    ref.read(selectedGuestProvider.notifier).setSelectedGuest(selectedGuest);

    // ref
    //     .read(tripHistoryProvider.notifier)
    //     .getTripHistory(
    //       dateFrom: safeDateFrom,
    //       dateTo: tomorrow,
    //       playerId: guest.mId,
    //     );

    context.push(
      '/home/profile/guest-performance',
      extra: {'startDateNotifier': yesterday, 'endDateNotifier': safeDateFrom},
    );
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

                    // Scrollable Table
                    // Expanded(
                    //   child: SingleChildScrollView(
                    //     padding: const EdgeInsets.all(16.0),
                    //     child: Table(
                    //       border: TableBorder.all(),
                    //       columnWidths: const {
                    //         0: FlexColumnWidth(),
                    //         1: FlexColumnWidth(),
                    //       },
                    //       children: guests
                    //           .map(
                    //             (entry) => [
                    //               TableRow(
                    //                 decoration: const BoxDecoration(
                    //                   color: Color.fromARGB(47, 181, 225, 250),
                    //                 ),
                    //                 children: const [
                    //                   Padding(
                    //                     padding: EdgeInsets.all(8.0),
                    //                     child: Text(
                    //                       "",
                    //                       style: TextStyle(
                    //                         fontWeight: FontWeight.w900,
                    //                       ),
                    //                     ),
                    //                   ),
                    //                   Padding(
                    //                     padding: EdgeInsets.all(8.0),
                    //                     child: Text(
                    //                       "Details",
                    //                       style: TextStyle(
                    //                         color: Colors.black,
                    //                         fontWeight: FontWeight.w900,
                    //                       ),
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),

                    //               TableRow(
                    //                 children: [
                    //                   Container(
                    //                     width: double.infinity,
                    //                     color: Constants.kPrimaryColor
                    //                         .withAlpha(50),
                    //                     padding: const EdgeInsets.all(8.0),
                    //                     alignment: Alignment.centerLeft,
                    //                     child: Text(
                    //                       "Image",
                    //                       style: TextStyle(
                    //                         color: Colors.black,
                    //                         fontSize: fontSettings.fontSize,
                    //                         fontWeight: fontSettings.fontWeight,
                    //                       ),
                    //                     ),
                    //                   ),
                    //                   Padding(
                    //                     padding: const EdgeInsets.all(8.0),
                    //                     child: entry.menImage2.isNotEmpty
                    //                         ? GestureDetector(
                    //                             onTap: () {
                    //                               showDialog(
                    //                                 context: context,
                    //                                 barrierDismissible: true,
                    //                                 builder: (_) => Dialog(
                    //                                   backgroundColor:
                    //                                       Colors.transparent,
                    //                                   child: Image.memory(
                    //                                     base64Decode(
                    //                                       entry.menImage2,
                    //                                     ),
                    //                                     fit: BoxFit.contain,
                    //                                   ),
                    //                                 ),
                    //                               );
                    //                             },
                    //                             child: Image.memory(
                    //                               base64Decode(entry.menImage2),
                    //                               fit: BoxFit.contain,
                    //                             ),
                    //                           )
                    //                         : GestureDetector(
                    //                             onTap: () {
                    //                               showDialog(
                    //                                 context: context,
                    //                                 barrierDismissible: true,
                    //                                 builder: (_) => Dialog(
                    //                                   backgroundColor:
                    //                                       Colors.transparent,
                    //                                   child: Image.asset(
                    //                                     'assets/images/placeholder_image.jpg',
                    //                                     fit: BoxFit.contain,
                    //                                   ),
                    //                                 ),
                    //                               );
                    //                             },
                    //                             child: Image.asset(
                    //                               'assets/images/placeholder_image.jpg',
                    //                               fit: BoxFit.contain,
                    //                             ),
                    //                           ),
                    //                   ),
                    //                 ],
                    //               ),
                    //               ..._buildGuestRows(entry, fontSettings),
                    //             ],
                    //           )
                    //           .expand((x) => x)
                    //           .toList(),
                    //     ),
                    //   ),
                    // ),
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
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          color: Constants.kPrimaryColor
                                              .withAlpha(50),
                                          padding: const EdgeInsets.all(8.0),
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            "Image",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: entry.menImage2.isNotEmpty
                                              ? GestureDetector(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      barrierDismissible: true,
                                                      builder: (_) => Dialog(
                                                        backgroundColor:
                                                            Colors.transparent,
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
                                                      barrierDismissible: true,
                                                      builder: (_) => Dialog(
                                                        backgroundColor:
                                                            Colors.transparent,
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
                                      ],
                                    ),
                                    ..._buildGuestRows(entry, fontSettings),
                                  ],
                                ),
                                // Red separator line after each guest table (except the last one)
                                if (index < guests.length - 1)
                                  Container(
                                    height: 10,
                                    // margin: const EdgeInsets.symmetric(
                                    //   vertical: 16.0,
                                    // ),
                                    color: Colors.red,
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
          if (showSpinner) const Center(child: CircularProgressIndicator()),
          const Watermark(),
        ],
      ),
    );
  }

  List<TableRow> _buildGuestRows(DailyWalkingGuest entry, fontSettings) {
    return [
      _buildRow(
        "Member ID",
        entry.mId,
        fontSettings,
        isMemberId: true,
        guest: entry,
      ),
      _buildRow("Member Name", entry.mname, fontSettings),
      _buildRow("Country", entry.country, fontSettings),
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
    bool isMemberId = false,
    DailyWalkingGuest? guest,
  }) {
    bool isMemberName = label == "Member Name";
    return TableRow(
      children: [
        Container(
          width: double.infinity,
          //height: 66,
          height: isMemberName ? 90 : null,
          color: Constants.kPrimaryColor.withAlpha(50),
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
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: isPhone && value.isNotEmpty
              ? GestureDetector(
                  onTap: () => _launchPhone(value),
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                )
              : isMemberId && value.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    if (guest != null) _goToGuestPerformance(guest);
                  },
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
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
      ],
    );
  }
}
