import 'package:ballys_reservation_app/components/watermark.dart'; 
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/special_gift_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class PrvGiftScreen extends ConsumerWidget {
  final String memberId;
  final GiftsRepository giftsRepository;

  const PrvGiftScreen({
    super.key,
    required this.memberId,
    required this.giftsRepository,
  });

  String _parseString(String? value) {
    if (value == null || value.isEmpty) return "N/A";
    return value;
  }

  String _parseNumberFormat(double? value) {
    if (value == null || value == 0) return "0.00";
    final formatter = NumberFormat('#,##0');
    return formatter.format(value);
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return dateString;
    }
  }

  String _parseBool(bool? value, {String trueText = "Yes", String falseText = "No"}) {
    if (value == null) return "N/A";
    return value ? trueText : falseText;
  }

  String _formatDateAndTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm a').format(date);
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text("Previous Gifts for $memberId")),
      body: Stack(
        children: [
          FutureBuilder(
            future: ref.read(giftProvider.notifier).getprvGift(memberId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final prvgifts = ref.watch(giftProvider.select((s) => s.prvgiftList));

              if (prvgifts.isEmpty) {
                return const Center(child: Text("No gifts found"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12.0),
                itemCount: prvgifts.length,
                itemBuilder: (context, index) {
                  final gift = prvgifts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Table(
                      border: TableBorder.all(),
                      columnWidths: const {
                        0: FractionColumnWidth(0.5),
                        1: FractionColumnWidth(0.5),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                              color: Color.fromARGB(47, 181, 225, 250)),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Field",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Details",
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                        _buildRow("Mkt Person", _parseString(gift.mktPer), fontSettings),
                        _buildRow("Date From", _formatDateAndTime(gift.dateFrom), fontSettings),
                        _buildRow("Date To", _formatDateAndTime(gift.dateTo), fontSettings),
                        _buildRow("Arrival Date", _formatDate(gift.arrDate), fontSettings),
                        _buildRow("Departure date", _formatDate(gift.dptDate), fontSettings),
                        _buildRow("Gift", _parseString(gift.cashierPayType), fontSettings),
                        _buildRow("cashier pay Type", _parseString(gift.cashierPayType), fontSettings),
                        _buildRow("Chip type", _parseString(gift.chipType?.replaceAll("_", " ")), fontSettings),
                        _buildRow("Category", _parseString(gift.giftCategory), fontSettings),
                        _buildRow("Gift Type", _formatDate(gift.gType), fontSettings),
                        _buildRow("Amount", _parseString(gift.giftDesc), fontSettings),
                        _buildRow("Drop", _parseNumberFormat(gift.mDrop), fontSettings),
                        _buildRow("Cash Out", _parseNumberFormat(gift.cashout), fontSettings),
                        _buildRow("Result", _parseNumberFormat(gift.res), fontSettings),
                        _buildRow("Actual Drop", _parseNumberFormat(gift.actDrop), fontSettings),
                        _buildRow("Coupon", _parseNumberFormat(gift.mCoupon), fontSettings),
                        _buildRow("Avg Bet", _parseNumberFormat(gift.avgBet), fontSettings),
                        _buildRow("HH", _parseNumberFormat(gift.ghh), fontSettings),
                        _buildRow("MM", _parseNumberFormat(gift.gmm), fontSettings),
                        _buildRow("Paid Commission", _parseNumberFormat(gift.paidComm), fontSettings),
                        _buildRow("Points", _parseNumberFormat(gift.gPoints), fontSettings),
                        _buildRow("SerialNo", _parseString(gift.serialNo), fontSettings),
                        _buildRow("Approve Status", _parseBool(gift.isActive, trueText: "Approved", falseText: "Not Approved"), fontSettings),
                        _buildRow("Cashier Status", _parseBool(gift.isPaid, trueText: "Issued", falseText: "Not Issued"), fontSettings),
                        _buildRow("Pit Approved By", _parseString(gift.pitAppBy), fontSettings),
                        _buildRow("Pit Approved Time", _formatDate(gift.pitAppTime), fontSettings),
                        _buildRow("Insert Date", _formatDateAndTime(gift.insertDate), fontSettings),
                        _buildRow("Req By", _parseString(gift.reqBy), fontSettings),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const Watermark(),
        ],
      ),
    );
  }

  TableRow _buildRow(String label, String value, FontSettings fontSettings) {
    final isAmount = label == "Amount";

    return TableRow(
      decoration: isAmount
          ? const BoxDecoration(color: Color(0xFFCCFFCC))
          : null,
      children: [
        Container(
          color: Constants.kPrimaryColor.withAlpha(50),
          padding: const EdgeInsets.all(8.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isAmount ? fontSettings.fontSize + 4 : fontSettings.fontSize,
              fontWeight: isAmount ? FontWeight.bold : fontSettings.fontWeight,
              color: isAmount ? Colors.black : null,
            ),
          ),
        ),
      ],
    );
  }
}
