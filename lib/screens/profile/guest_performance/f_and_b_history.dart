import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/f_and_b_history_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class FAndBHistoryWidget extends ConsumerWidget {
  const FAndBHistoryWidget({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final fndbHistory = ref.watch(fAndBHistoryProvider);
    return Center(
      child: Column(
        children: [
          const Align(
            child: Text(
              "F & B History",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(
            height: 16.0,
          ),
          fndbHistory.nongameDetails.isEmpty
              ? Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const Text(
                    "No data available",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Container(
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
                                  text: "Most Ordered Beverage: ",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fontSettings.fontSize + 3,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                TextSpan(
                                  text: fndbHistory.mostOrderedBeverage,
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
                                  text: "Most Ordered Tobacco: ",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fontSettings.fontSize + 3,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                TextSpan(
                                  text: fndbHistory.mostOrderedTobacco,
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
                                  text: "Most Ordered Food: ",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fontSettings.fontSize + 3,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                TextSpan(
                                  text: fndbHistory.mostOrderedFood,
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
                                  text: "F & B Cost (Est): ",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: fontSettings.fontSize + 3,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                TextSpan(
                                  text: fndbHistory.nongameDetails.isNotEmpty
                                      ? _parseNumberFormat(fndbHistory
                                          .nongameDetails
                                          .fold<double>(
                                              0,
                                              (sum, item) =>
                                                  sum + (item.amount)))
                                      : '0.00',
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
                  ...fndbHistory.nongameDetails.map((entry) {
                    return [
                      TableRow(
                        decoration: const BoxDecoration(
                            color: Color.fromARGB(47, 181, 225, 250)),
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text(
                                  "",
                                  style: TextStyle(fontWeight: FontWeight.w900),
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
                        decoration: BoxDecoration(
                          color: Constants.kPrimaryColor.withAlpha(50),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Product",
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
                                _parseString(entry.product),
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
                                "Cost (Est)",
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
                              _parseNumberFormat(entry.amount),
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
                            color: Constants.kPrimaryColor.withAlpha(50),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Order Date",
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
                              _formatDate2(entry.orderDate),
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
                            color: Constants.kPrimaryColor.withAlpha(50),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Order Time",
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
                              _timeFormat(entry.orderTime),
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
                  }).expand((x) => x),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
