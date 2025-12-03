import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/trip_information_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TripInformationWidget extends ConsumerWidget {
  const TripInformationWidget({super.key});
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final tripHistory = ref.watch(tripHistoryProvider);
    return Center(
      child: Column(
        children: [
          const Text(
            "Trip Information",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6.0),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: tripHistory.isEmpty
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
                        ...tripHistory
                            .asMap()
                            .entries
                            .map((mapEntry) {
                              final index = mapEntry.key;
                              final entry = mapEntry.value;
                              final isLastEntry =
                                  index == tripHistory.length - 1;
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Consecutive Dates",
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Arrival Date",
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Departure Date",
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Drop (Est)",
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Cash Out (Est)",
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Result (Est)",
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
                                        _parseNumberFormat(entry.tripResult),
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
                                          "Commision (Est)",
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
                                  children: [
                                    Container(
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Actual Drop (Est)",
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Total Coupon (Est)",
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "HH",
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
                                        entry.tripHour.toInt().toString(),
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
                                          "MM",
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
                                TableRow(
                                  children: [
                                    Container(
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "DTL",
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
                                          "DTL Description",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                      Container(
                                        color: Colors.white,
                                      child:Padding(
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
                                                    "DTL : ${NumberFormat('#,###').format(dtl.dtl.toInt())}",
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
                                                    "Game : ${dtl.gameType}",
                                                    style: TextStyle(
                                                      fontSize:
                                                          fontSettings
                                                              .fontSize -
                                                          3,
                                                      fontWeight: fontSettings
                                                          .fontWeight,
                                                    ),
                                                  ),
                                                  Text(
                                                    "Date : ${dtl.gDate.split('T').first}",
                                                    style: TextStyle(
                                                      fontSize:
                                                          fontSettings
                                                              .fontSize -
                                                          4,
                                                      fontWeight: fontSettings
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
                                      color: Constants.kPrimaryColor.withAlpha(
                                        50,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "ADT",
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
                                        _parseNumberFormat(entry.adtM),
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
                                          "TTL",
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
                                        _parseNumberFormat(entry.ttlm),
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
                                          "ATT",
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
                                        _parseNumberFormat(entry.attm),
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
                                      Container(height: 10, color: Colors.red),
                                      Container(height: 10, color: Colors.red),
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
