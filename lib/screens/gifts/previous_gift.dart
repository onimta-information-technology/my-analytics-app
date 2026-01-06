import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/special_gift_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class PrvGiftScreen extends ConsumerStatefulWidget {
  final String memberId;
  final GiftsRepository giftsRepository;

  const PrvGiftScreen({
    super.key,
    required this.memberId,
    required this.giftsRepository,
  });

  @override
  ConsumerState<PrvGiftScreen> createState() => _PrvGiftScreenState();
}

class _PrvGiftScreenState extends ConsumerState<PrvGiftScreen> {
  bool _isHorizontal = false; // false = vertical, true = horizontal

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

  String _parseBool(
    bool? value, {
    String trueText = "Yes",
    String falseText = "No",
  }) {
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

  List<Map<String, String>> _getGiftData(dynamic gift) {
    return [
    
      {"field": "Date From", "value": _formatDateAndTime(gift.dateFrom)},
      {"field": "Date To", "value": _formatDateAndTime(gift.dateTo)},
      {"field": "Arrival Date", "value": _formatDate(gift.arrDate)},
      {"field": "Departure Date", "value": _formatDate(gift.dptDate)},
      {"field": "Gift", "value": _parseString(gift.cashierPayType)},
      {"field": "Cashier Pay Type", "value": _parseString(gift.cashierPayType)},
   
      {"field": "Category", "value": _parseString(gift.giftCategory)},
      {"field": "Gift Type", "value": _formatDate(gift.gType)},
         {
        "field": "Chip Type",
        "value": _parseString(gift.chipType?.replaceAll("_", " ")),
      },
      {
        "field": "Amount",
        "value":
            (gift.chipType == null || gift.chipType.toString().trim().isEmpty)
            ? "N/A"
            : _parseString(gift.giftDesc),
      },
  {"field": "Marketing Person", "value": _parseString(gift.mktPer)},
      {"field": "Drop", "value": _parseNumberFormat(gift.mDrop)},
      {"field": "Cash Out", "value": _parseNumberFormat(gift.cashout)},
      {"field": "Result", "value": _parseNumberFormat(gift.res)},
      {"field": "Actual Drop", "value": _parseNumberFormat(gift.actDrop)},
      {"field": "Coupon", "value": _parseNumberFormat(gift.mCoupon)},
      {"field": "Avg Bet", "value": _parseNumberFormat(gift.avgBet)},
      {"field": "HH", "value": _parseNumberFormat(gift.ghh)},
      {"field": "MM", "value": _parseNumberFormat(gift.gmm)},
      {"field": "Paid Commission", "value": _parseNumberFormat(gift.paidComm)},
      {"field": "Points", "value": _parseNumberFormat(gift.gPoints)},
      {"field": "SerialNo", "value": _parseString(gift.serialNo)},
      {
        "field": "Approve Status",
        "value": _parseBool(
          gift.isActive,
          trueText: "Approved",
          falseText: "Not Approved",
        ),
      },
      {
        "field": "Cashier Status",
        "value": _parseBool(
          gift.isPaid,
          trueText: "Issued",
          falseText: "Not Issued",
        ),
      },
      {"field": "Pit Approved By", "value": _parseString(gift.pitAppBy)},
      {"field": "Pit Approved Time", "value": _formatDate(gift.pitAppTime)},
      {"field": "Insert Date", "value": _formatDateAndTime(gift.insertDate)},
      {"field": "Req By", "value": _parseString(gift.reqBy)},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Previous Gifts for ${widget.memberId}"),
        actions: [
          // Rotation buttons
          IconButton(
            onPressed: () {
              setState(() {
                _isHorizontal = false;
              });
            },
            icon: Icon(
              Icons.table_rows,
              color: !_isHorizontal ? Colors.blue : Colors.grey,
            ),
            tooltip: "Vertical View",
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isHorizontal = true;
              });
            },
            icon: Icon(
              Icons.view_column,
              color: _isHorizontal ? Colors.blue : Colors.grey,
            ),
            tooltip: "Horizontal View",
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder(
            future: ref.read(giftProvider.notifier).getprvGift(widget.memberId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final prvgifts = ref.watch(
                giftProvider.select((s) => s.prvgiftList),
              );

              if (prvgifts.isEmpty) {
                return const Center(child: Text("No gifts found"));
              }

              return _isHorizontal
                  ? _buildHorizontalView(prvgifts, fontSettings)
                  : _buildVerticalView(prvgifts, fontSettings);
            },
          ),
          const Watermark(),
        ],
      ),
    );
  }

  // Widget _buildVerticalView(List<dynamic> prvgifts, FontSettings fontSettings) {
  //   return ListView.builder(
  //     padding: const EdgeInsets.all(12.0),
  //     itemCount: prvgifts.length,
  //     itemBuilder: (context, index) {
  //       final gift = prvgifts[index];
  //       final giftData = _getGiftData(gift);

  //       return Padding(
  //         padding: const EdgeInsets.only(bottom: 16.0),
  //         child: Table(
  //           border: TableBorder.all(),
  //           columnWidths: const {
  //             0: FractionColumnWidth(0.5),
  //             1: FractionColumnWidth(0.5),
  //           },
  //           children: [
  //             const TableRow(
  //               decoration: BoxDecoration(
  //                 color: Color.fromARGB(47, 181, 225, 250),
  //               ),
  //               children: [
  //                 Padding(
  //                   padding: EdgeInsets.all(8.0),
  //                   child: Text(
  //                     "Field",
  //                     style: TextStyle(fontWeight: FontWeight.bold),
  //                   ),
  //                 ),
  //                 Padding(
  //                   padding: EdgeInsets.all(8.0),
  //                   child: Text(
  //                     "Details",
  //                     style: TextStyle(fontWeight: FontWeight.bold),
  //                     textAlign: TextAlign.end,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             ...giftData.map(
  //               (data) =>
  //                   _buildRow(data["field"]!, data["value"]!, fontSettings),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }
Widget _buildVerticalView(List<dynamic> prvgifts, FontSettings fontSettings) {
    return ListView.builder(
     padding: const EdgeInsets.all(12.0),
      itemCount: prvgifts.length,
      itemBuilder: (context, index) {
        final gift = prvgifts[index];
        final giftData = _getGiftData(gift);
        final isLastEntry = index == prvgifts.length - 1;

        return Padding(
          padding: const EdgeInsets.only(bottom: 0.0),
          child: Table(
            border: TableBorder.all(),
            columnWidths: const {
              0: FractionColumnWidth(0.5),
              1: FractionColumnWidth(0.5),
            },
            children: [
              const TableRow(
                decoration: BoxDecoration(
                  color: Color.fromARGB(47, 181, 225, 250),
                ),
                children: [
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
              ...giftData.map(
                (data) =>
                    _buildRow(data["field"]!, data["value"]!, fontSettings),
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
            ],
          ),
        );
      },
    );
  }
  // Widget _buildHorizontalView(
  //   List<dynamic> prvgifts,
  //   FontSettings fontSettings,
  // ) {
  //   if (prvgifts.isEmpty) return const SizedBox();

  //   final allGiftData = prvgifts.map((gift) => _getGiftData(gift)).toList();
  //   final fieldNames = allGiftData.first.map((data) => data["field"]!).toList();

  //   return SingleChildScrollView(
  //     scrollDirection: Axis.horizontal,
  //     child: SingleChildScrollView(
  //       child: Padding(
  //         padding: const EdgeInsets.all(12.0),
  //         child: Table(
  //           border: TableBorder.all(),
  //           defaultColumnWidth: const IntrinsicColumnWidth(),
  //           children: [
  //             // Header row with field names as columns
  //             TableRow(
  //               decoration: const BoxDecoration(
  //                 color: Color.fromARGB(47, 181, 225, 250),
  //               ),
  //               children: fieldNames.map((fieldName) {
  //                 final isAmount = fieldName == "Amount";
  //                 return Container(
  //                   color: isAmount ? const Color(0xFFCCFFCC) : null,
  //                   padding: const EdgeInsets.all(8.0),
  //                   child: Text(
  //                     fieldName,
  //                     style: TextStyle(
  //                       fontSize: fontSettings.fontSize,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                     textAlign: TextAlign.center,
  //                   ),
  //                 );
  //               }).toList(),
  //             ),
  //             // Data rows - each gift as a row
  //             ...allGiftData.map((giftData) {
  //               return TableRow(
  //                 children: giftData.map((data) {
  //                   final fieldName = data["field"]!;
  //                   final value = data["value"]!;
  //                   final isAmount = fieldName == "Amount";

  //                   return Container(
  //                     color: isAmount ? const Color(0xFFCCFFCC) : null,
  //                     padding: const EdgeInsets.all(8.0),
  //                     child: Text(
  //                       value,
  //                       textAlign: TextAlign.center,
  //                       style: TextStyle(
  //                         fontSize: isAmount
  //                             ? fontSettings.fontSize + 4
  //                             : fontSettings.fontSize,
  //                         fontWeight: isAmount
  //                             ? FontWeight.bold
  //                             : fontSettings.fontWeight,
  //                         color: isAmount ? Colors.black : null,
  //                         fontFamily: 'monospace',
  //                         fontFeatures: const [FontFeature.tabularFigures()],
  //                       ),
  //                     ),
  //                   );
  //                 }).toList(),
  //               );
  //             }),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
Widget _buildHorizontalView(
    List<dynamic> prvgifts,
    FontSettings fontSettings,
  ) {
    if (prvgifts.isEmpty) return const SizedBox();

    final allGiftData = prvgifts.map((gift) => _getGiftData(gift)).toList();
    final fieldNames = allGiftData.first.map((data) => data["field"]!).toList();

    return Center(
      child: RotatedBox(
        quarterTurns: 1, // Rotate 90 degrees clockwise
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Table(
                border: TableBorder.all(),
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  // Header row with field names as columns
                  TableRow(
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(47, 181, 225, 250),
                    ),
                    children: fieldNames.map((fieldName) {
                      final isAmount = fieldName == "Amount" || fieldName == "Gift Type" || fieldName == "Category"|| fieldName == "Chip Type"|| fieldName == "Cashier Pay Type"|| fieldName == "Gift";
                      final isMarketingPerson = fieldName == "Marketing Person";
                      return Container(
                        color: isAmount ? const Color(0xFFCCFFCC): isMarketingPerson ? const Color.fromARGB(255, 255, 240, 24) : null,
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          fieldName,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }).toList(),
                  ),
                  // Data rows - each gift as a row
                  ...allGiftData.map((giftData) {
                    return TableRow(
                     
                      children: giftData.map((data) {
                        final fieldName = data["field"]!;
                        final value = data["value"]!;
                        final isAmount = fieldName == "Amount" || fieldName == "Gift Type" || fieldName == "Category"|| fieldName == "Chip Type"|| fieldName == "Cashier Pay Type"|| fieldName == "Gift";
                        //final isSpecialRow = fieldName == "Amount" || fieldName == "Gift Type" || fieldName == "Category"|| fieldName == "Chip type"|| fieldName == "cashier pay Type"|| fieldName == "Gift";
                        final isMarketingPerson = fieldName == "Marketing Person";
                        return Container(
                          color: isAmount ? const Color(0xFFCCFFCC) : isMarketingPerson ? const Color.fromARGB(255, 255, 240, 24) : null,
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isAmount
                                  ? fontSettings.fontSize + 4
                                  : fontSettings.fontSize,
                              fontWeight: isAmount
                                  ? FontWeight.bold
                                  : fontSettings.fontWeight,
                              color: isAmount ? Colors.black : null,
                              fontFamily: 'monospace',
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


//   TableRow _buildRow(String label, String value, FontSettings fontSettings) {
//     final isSpecialRow = label == "Amount" || label == "Gift Type" || label == "Category"|| label == "Chip Type"|| label == "Cashier Pay Type"|| label == "Gift";
//   final isAmount = label == "Amount";
//   final isMarketingPerson = label == "Marketing Person";

//     return TableRow(
//       decoration: isSpecialRow
//           ? const BoxDecoration(color: Color(0xFFCCFFCC))
//           :  BoxDecoration(color :Constants.kPrimaryColor.withAlpha(50),
// ),
//       children: [
        
//         Container(
//          // color: Constants.kPrimaryColor.withAlpha(50),
//            //  color: Colors.white,
//           padding: const EdgeInsets.all(8.0),
//           child: Text(
//             label,
//             style: TextStyle(
//               fontSize: fontSettings.fontSize-1,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//          Container(
//             color:isSpecialRow ?  Color(0xFFCCFFCC) : Colors.white ,
//        child : Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: Text(
//             value,
//             textAlign: TextAlign.end,
//             style: TextStyle(
//               fontSize: isAmount
//                   ? fontSettings.fontSize + 4
//                   : fontSettings.fontSize,
//               fontWeight: isAmount ? FontWeight.bold : fontSettings.fontWeight,
//               color: isAmount ? Colors.black : null,
//               fontFamily: 'monospace',
//               fontFeatures: const [FontFeature.tabularFigures()],
//             ),
//           ),
//         ),
//          ),
//       ],
//     );
TableRow _buildRow(String label, String value, FontSettings fontSettings) {
  final isSpecialRow = label == "Amount" ||
      label == "Gift Type" ||
      label == "Category" ||
      label == "Chip Type" ||
      label == "Cashier Pay Type" ||
      label == "Gift";

  final isAmount = label == "Amount";
  final isMarketingPerson = label == "Marketing Person";

  return TableRow(
    decoration: BoxDecoration(
      color: isMarketingPerson
          ? const Color.fromARGB(255, 255, 240, 24) 
          : isSpecialRow
              ? const Color(0xFFCCFFCC)
              : Constants.kPrimaryColor.withAlpha(50),
    ),
    children: [
      // LABEL
      Container(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSettings.fontSize - 1,
            fontWeight: FontWeight.bold,
          
          ),
        ),
      ),

      // VALUE
      Container(
        color: isMarketingPerson
            ?const Color.fromARGB(255, 255, 240, 24) 
            : isSpecialRow
                ? const Color(0xFFCCFFCC)
                : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isAmount
                  ? fontSettings.fontSize + 4
                  : fontSettings.fontSize,
              fontWeight: isMarketingPerson
                  ? FontWeight.w600
                  : isAmount
                      ? FontWeight.bold
                      : fontSettings.fontWeight,
              
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    ],
  );
}

  
}
