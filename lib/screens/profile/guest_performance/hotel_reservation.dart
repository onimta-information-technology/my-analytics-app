import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/hotel_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HotelReservationWidget extends ConsumerWidget {
  const HotelReservationWidget({super.key});

  String _formatDate2(String dateString) {
    if (dateString == "") return "N/A";
    final date = DateTime.parse(dateString);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _parseString(String value) {
    if (value == "") return "N/A";
    return value;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final hotelHistory = ref.watch(hotelHistoryProvider);
    return Center(
      child: Column(
        children: [
          const Align(
            child: Text(
              "Hotel Reservations",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
          ),
          const SizedBox(height: 6.0),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: hotelHistory.isEmpty
                ? Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: const Text(
                      "No data available",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Container(
                    color: Colors.white,
                    child: Table(
                      border: TableBorder.all(),
                      columnWidths: const {
                        0: FractionColumnWidth(0.5),
                        1: FractionColumnWidth(0.5),
                      },
                      children: [
                        ...hotelHistory
                          //  .map((entry) {
                           .asMap()
                              .entries
                              .map((mapEntry) {
                                final index = mapEntry.key;
                                final entry = mapEntry.value;
                                final isLastEntry =
                                    index == hotelHistory.length - 1;
                              return [
                                TableRow(
                                  decoration: const BoxDecoration(
                                    color: Color.fromARGB(47, 181, 225, 250),
                                  ),
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            "",
                                            style: TextStyle(
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
                                            "Details",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: fontSettings.fontSize,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    Container(
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Res.No",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.resNo),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Hotel",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.hotel),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Check In For",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.checkInFor),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Check Out For",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.checkOutFor),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "PayIns",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.payIns),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Special",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.special),
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
                                  decoration: BoxDecoration(
                                    color: Constants.kPrimaryColor.withAlpha(
                                      50,
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        "Remarks",
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
                                        child: Text(
                                          _parseString(entry.rem),
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
                                ),
                                TableRow(
                                  children: [
                                    Container(
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Check In",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _formatDate2(entry.checkIn),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Check Out",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _formatDate2(entry.checkOut),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Request By",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.requestBy),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Status",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.status),
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
                                  decoration: BoxDecoration(
                                    color: Constants.kPrimaryColor.withAlpha(
                                      50,
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        "Extra",
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
                                        child: Text(
                                          _parseString(entry.extra),
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
                                ),
                                TableRow(
                                  children: [
                                    Container(
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Cat Name",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.catName),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Room Type",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.roomType),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Meal Plan",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.mealPlan),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Rooms",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.rooms.toString()),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Nights",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.nights.toString()),
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Adults",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _parseString(entry.adults.toString()),
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
          ),
        ],
      ),
    );
  }
}
