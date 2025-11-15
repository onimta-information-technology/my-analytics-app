import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/games_summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GamesSummaryWidget extends ConsumerWidget {
  const GamesSummaryWidget({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final gamesSummary = ref.watch(gamesSummaryProvider);
    return Center(
      child: Column(
        children: [
          const Align(
            child: Text(
              "Games Summary",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(height: 16.0),
          gamesSummary.gameDetails.isEmpty
              ? Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const Text(
                    "No data available",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: Card(
                    elevation: 4.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "Total Time Spent: ",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fontSettings.fontSize + 3,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      "${(gamesSummary.totalTimespent / 60).floor()} Hours ${(gamesSummary.totalTimespent % 60).round()} Minutes",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fontSettings.fontSize + 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "Most Played Game: ",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fontSettings.fontSize + 3,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: gamesSummary.mostPlayedGame,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fontSettings.fontSize + 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Container(
              color: Colors.white,
              child: Table(
                border: TableBorder.all(),
                columnWidths: const {
                  0: FractionColumnWidth(0.5),
                  1: FractionColumnWidth(0.5),
                },
                children: [
                  ...gamesSummary.gameDetails
                      // .map((entry) {
                       .asMap()
                              .entries
                              .map((mapEntry) {
                                final index = mapEntry.key;
                                final entry = mapEntry.value;
                                final isLastEntry =
                                    index == gamesSummary.gameDetails.length - 1;
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
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          TableRow(
                            decoration: BoxDecoration(
                              color: Constants.kPrimaryColor.withAlpha(50),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Game Type",
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
                                    _parseString(entry.gameType),
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
                                color: Constants.kPrimaryColor.withAlpha(50),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Play Time HH",
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
                                    entry.playTime.toDouble() / 60,
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
                                color: Constants.kPrimaryColor.withAlpha(50),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Play Time MM",
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
                                    entry.playTime.toDouble() % 60,
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
                                color: Constants.kPrimaryColor.withAlpha(50),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Date",
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
                                  _formatDate2(entry.playDate),
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
