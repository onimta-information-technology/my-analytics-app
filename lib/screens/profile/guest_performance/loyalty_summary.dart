import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/loyalty_summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class LoyaltySummaryWidget extends ConsumerWidget {
  const LoyaltySummaryWidget({super.key});

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

  String? _parseNumberFormat(int? value) {
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
    final loyaltySummary = ref.watch(loyaltySummaryProvider);
    return Center(
      child: Column(
        children: [
          const Text("Loyalty Summary",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(
            height: 16.0,
          ),
          Card(
            elevation: 4,
            margin: const EdgeInsets.all(0.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Points:",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                       fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _parseNumberFormat(loyaltySummary.totalPoints)!,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Ballys Rupees (Est):",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                         fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _parseNumberFormat(loyaltySummary.ballysRuppes)!,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ballys Rupees Expire:",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                     fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _parseString(loyaltySummary.ballysRuppesExpireMessage),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Message:",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _parseString(""),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Ballys Coins:",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                       fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _parseNumberFormat(loyaltySummary.ballysCoins)!,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Ballys Coins Expire:",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _parseString(""),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Message:",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _parseString(""),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Last Update At:",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                         fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _parseString(loyaltySummary.lastUpdateDateTime),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Last Redeem Type:",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _parseString(loyaltySummary.lastRedeemType),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Last Redeem Amount (Est):",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _parseNumberFormat(loyaltySummary.lastRedeemAmount)!,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Last Redeem Date:",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                       fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _formatDate2(loyaltySummary.lastRedeemDate),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Last Redeem Time:",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      Text(
                        _timeFormat(loyaltySummary.lastRedeemTime),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
