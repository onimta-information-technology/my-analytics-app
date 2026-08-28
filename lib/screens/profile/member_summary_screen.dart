import 'dart:convert';

import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/member_summary_provider.dart';
import 'package:ballys_reservation_app/providers/profile_date_filter_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MemberSummaryScreen extends ConsumerStatefulWidget {
  final MemberProfileRepository memberProfileRepository;

  const MemberSummaryScreen({required this.memberProfileRepository, super.key});

  @override
  ConsumerState<MemberSummaryScreen> createState() => _GuestPerformanceState();
}

class _GuestPerformanceState extends ConsumerState<MemberSummaryScreen>
    with ConnectivityMixin {
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final ValueNotifier<DateTime?> startDateNotifier = ValueNotifier<DateTime?>(
    null,
  );
  final ValueNotifier<DateTime?> endDateNotifier = ValueNotifier<DateTime?>(
    null,
  );

  bool _isLoading = false;
  // Text zoom level for this screen only (1x / 2x / 3x).
  double _textScale = 1.0;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _getGuestImage();
    String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _startDateController.text = formattedDate;
    _endDateController.text = formattedDate;
  }

  Future<void> _getGuestImage() async {
    final guest = ref.read(selectedGuestProvider);
    if (guest == null || guest.memImage2 != null) return;
    await ref
        .read(selectedGuestProvider.notifier)
        .getGuestImage(9021, guest.mid);
  }

  // Future<void> _selectArrivalDate(BuildContext context) async {
  //   final DateTime? selectedArrivalDate = await showDatePicker(
  //     context: context,
  //     initialDate: _dateFrom ?? DateTime.now(),
  //     firstDate: DateTime(2000),
  //     lastDate: DateTime(2101),
  //   );
  //   if (selectedArrivalDate != null && selectedArrivalDate != _dateFrom) {
  //     ref.read(dateFilterProvider.notifier).setDateFrom(selectedArrivalDate);
  //   }
  // }

  // Future<void> _selectDepartureDate(BuildContext context) async {
  //   final DateTime? selectedDepartureDate = await showDatePicker(
  //     context: context,
  //     initialDate: _dateTo ?? _dateFrom ?? DateTime.now(),
  //     firstDate: _dateFrom ?? DateTime.now(),
  //     lastDate: DateTime(2101),
  //   );
  //   if (selectedDepartureDate != null && selectedDepartureDate != _dateTo) {
  //     ref.read(dateFilterProvider.notifier).setDateTo(selectedDepartureDate);
  //   }
  // }
  Future<void> _selectArrivalDate(BuildContext context) async {
    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    DateTime selectedDate = _dateFrom ?? now;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Select Start Date",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                minimumDate: DateTime(2000),
                maximumDate: DateTime(2101),
                onDateTimeChanged: (DateTime newDate) {
                  selectedDate = newDate;
                },
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () {
                ref.read(dateFilterProvider.notifier).setDateFrom(selectedDate);
                setState(() {
                  _dateFrom = selectedDate;
                  startDateNotifier.value = selectedDate;
                  _startDateController.text = DateFormat(
                    'yyyy-MM-dd',
                  ).format(selectedDate);
                  // Reset end date if before new start date
                  if (_dateTo != null && _dateTo!.isBefore(selectedDate)) {
                    _dateTo = null;
                    endDateNotifier.value = null;
                    _endDateController.text = '';
                    ref
                        .read(dateFilterProvider.notifier)
                        .setDateTo(selectedDate);
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text(
                "Confirm",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Future<void> _selectDepartureDate(BuildContext context) async {
    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    DateTime selectedDate = _dateTo ?? _dateFrom ?? now;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Select End Date",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                minimumDate: DateTime(2000),
                maximumDate: DateTime(2101),
                onDateTimeChanged: (DateTime newDate) {
                  selectedDate = newDate;
                },
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () {
                // Validate end date is after start date
                if (_dateFrom != null && selectedDate.isBefore(_dateFrom!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End date must be after start date'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                ref.read(dateFilterProvider.notifier).setDateTo(selectedDate);
                setState(() {
                  _dateTo = selectedDate;
                  endDateNotifier.value = selectedDate;
                  _endDateController.text = DateFormat(
                    'yyyy-MM-dd',
                  ).format(selectedDate);
                });
                Navigator.of(context).pop();
              },
              child: const Text(
                "Confirm",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Future<void> _getLoyalitySummary() async {
    try {
      if (_startDateController.text.isEmpty ||
          _endDateController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select start and end dates.")),
        );
        return;
      }

      final guest = ref.read(selectedGuestProvider);
      setState(() => _isLoading = true);

      await ref
          .read(memberSummaryProvider.notifier)
          .getMemberSummary(
            playerId: guest!.mid,
            dateFrom: startDateNotifier.value != null
                ? DateFormat('yyyy-MM-dd').format(startDateNotifier.value!)
                : '',
            dateTo: endDateNotifier.value != null
                ? DateFormat('yyyy-MM-dd').format(endDateNotifier.value!)
                : '',
          );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // String formatDate(String dateString) {
  //   final date = DateTime.parse(dateString);
  //   return DateFormat('dd MMM yyyy').format(date);
  // }
  String formatDate(String dateString) {
    if (dateString.isEmpty || dateString == "1990-01-01") {
      return "N/A";
    }
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return "N/A";
    }
  }

  String _formatAmount(double value) {
    final formatter = NumberFormat('#,##0.##');
    return formatter.format(value);
  }

  // final Map<String, String> ratingImageMap = {
  //   "CLASSIC": "assets/images/ratings/CLASSIC.png",
  //   "DIAMOND": "assets/images/ratings/DIAMOND.png",
  //   "GOLD": "assets/images/ratings/GOLD.png",
  //   "INFINITY": "assets/images/ratings/INFINITY.png",
  //   "PLATINUM": "assets/images/ratings/PLATINUM.png",
  //   "SILVER": "assets/images/ratings/SILVER.png",
  // };
  Color _getRatingColorBallys(String? rating) {
    switch ((rating ?? '').toUpperCase()) {
      case 'GOLD':
        return const Color(0xFFDAA520);
      case 'PLATINUM':
        return const Color(0xFF707070);
      case 'DIAMOND':
        return const Color(0xFF1565C0);
      case 'SILVER':
        return const Color(0xFF9E9E9E);
      case 'INFINITY':
        return const Color(0xFF4A148C);
      case 'CLASSIC':
        return const Color(0xFF5D4037);
      case 'PREMIER':
        return const Color(0xFF1B5E20);
      case 'RAFFELS CLUB':
        return const Color(0xFF880E4F);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final guest = ref.watch(selectedGuestProvider);
    final memberSummaryResult = ref.watch(memberSummaryProvider);
    final memberSummary = memberSummaryResult.table;
    final table1 = memberSummaryResult.table1;

    if (guest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Guest Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final dateFilter = ref.watch(dateFilterProvider);
    String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (dateFilter.dateFrom == null) {
      startDateNotifier.value = DateTime.parse(formattedDate);
      _dateFrom = DateTime.parse(formattedDate);
    } else {
      startDateNotifier.value = dateFilter.dateFrom;
      _dateFrom = dateFilter.dateFrom;
    }

    if (dateFilter.dateTo == null) {
      endDateNotifier.value = DateTime.parse(formattedDate);
      _dateTo = DateTime.parse(formattedDate);
    } else {
      endDateNotifier.value = dateFilter.dateTo;
      _dateTo = dateFilter.dateTo;
    }

    // final String? imagePath = ratingImageMap[guest.gRating];

    return Scaffold(
      appBar: AppBar(title: const Text("Member Summary")),
      body: Stack(
        children: [
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(_textScale)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 15.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Text size selector (1x / 2x / 3x) ─────────────────────
                    MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.noScaling),
                      child: _buildTextScaleSelector(),
                    ),

                    const SizedBox(height: 12.0),

                    // ── Profile Card ──────────────────────────────────────────
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
                                  child: GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return Dialog(
                                            backgroundColor: Colors.transparent,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Hero(
                                                  tag: "guest-image",
                                                  child: guest.memImage2 != null
                                                      ? Image.memory(
                                                          base64Decode(
                                                            guest.memImage2!,
                                                          ),
                                                          fit: BoxFit.contain,
                                                        )
                                                      : Image.asset(
                                                          'assets/images/placeholder_image.jpg',
                                                          fit: BoxFit.contain,
                                                        ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
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
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    "${guest.mid} -  ${guest.memberName}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Center(
                                  child: Text(
                                    "M P - ${guest.gName}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Color.fromARGB(255, 158, 0, 148),
                                      fontWeight: FontWeight.w900,
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
                                    Flexible(
                                      child: Text(
                                        "Last Visit on -  ${formatDate(guest.lastVisitDate ?? '')}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                          // child: Card(
                          //   elevation: 5,
                          //   shape: RoundedRectangleBorder(
                          //     borderRadius: BorderRadius.circular(6),
                          //   ),
                          child:
                              // Padding(
                              //   padding: const EdgeInsets.all(0),
                              //   child: SizedBox(
                              //     width: 80,
                              //     height: 30,
                              //     child: Hero(
                              //       tag: "rating-image",
                              //       child: Image.asset(
                              //         imagePath ??
                              //             "assets/images/ratings/CLASSIC.png",
                              //         fit: BoxFit.contain,
                              //       ),
                              //     ),
                              //   ),
                              // ),
                              Hero(
                                tag: "rating-image-${guest.mid}",
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRatingColorBallys(guest.gRating),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    guest.gRating ?? 'N/A',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                        ),
                        //  ),
                      ],
                    ),

                    const SizedBox(height: 16.0),

                    // ── Date Pickers ──────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<DateTime?>(
                            valueListenable: startDateNotifier,
                            builder: (context, value, child) {
                              return TextFormField(
                                controller: TextEditingController(
                                  text: value != null
                                      ? DateFormat('yyyy-MM-dd').format(value)
                                      : '',
                                ),
                                readOnly: true,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Start Date",
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: () =>
                                        _selectArrivalDate(context),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ValueListenableBuilder<DateTime?>(
                            valueListenable: endDateNotifier,
                            builder: (context, value, child) {
                              return TextFormField(
                                controller: TextEditingController(
                                  text: value != null
                                      ? DateFormat('yyyy-MM-dd').format(value)
                                      : '',
                                ),
                                readOnly: true,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  labelText: "End Date",
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: () =>
                                        _selectDepartureDate(context),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Search Button ─────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _getLoyalitySummary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.kSecondaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "Search",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // ── Summary Card (from Table1) ────────────────────────────
                    memberSummary.isEmpty
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
                                    // Total Cash In
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            "Total Cash In (Est):",
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            table1 != null
                                                ? _formatAmount(table1.mDrop)
                                                : "N/A",
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                              fontSize:
                                                  fontSettings.fontSize + 2,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                              fontFamily: 'monospace',
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8.0),

                                    // Total Cash Out
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            "Total Cash Out (Est):",
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            table1 != null
                                                ? _formatAmount(table1.cashOut)
                                                : "N/A",
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                              fontSize:
                                                  fontSettings.fontSize + 1,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                              fontFamily: 'monospace',
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8.0),

                                    // Win / Loss
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            table1 != null && table1.res >= 0
                                                ? "Win (Est):"
                                                : "Loss (Est):",
                                            style: TextStyle(
                                              fontSize:
                                                  fontSettings.fontSize + 2,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                              color:
                                                  table1 != null &&
                                                      table1.res >= 0
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            table1 != null
                                                ? _formatAmount(
                                                    table1.res.abs(),
                                                  )
                                                : "N/A",
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                              fontSize:
                                                  fontSettings.fontSize + 2,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                              fontFamily: 'monospace',
                                              color:
                                                  table1 != null &&
                                                      table1.res >= 0
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                    // ── Detail Table (from Table) ─────────────────────────────
                    if (memberSummary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Table(
                            border: TableBorder.all(),
                            columnWidths: const {
                              0: IntrinsicColumnWidth(),
                              1: IntrinsicColumnWidth(),
                              2: IntrinsicColumnWidth(),
                              3: IntrinsicColumnWidth(),
                              4: IntrinsicColumnWidth(),
                              5: IntrinsicColumnWidth(),
                              6: IntrinsicColumnWidth(),
                              7: IntrinsicColumnWidth(),
                            },
                            children: [
                              // Header Row
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Constants.kPrimaryColor.withAlpha(50),
                                ),
                                children:
                                    [
                                          "DESCRIPTION",
                                          "IN",
                                          "OUT",
                                          "TDATE",
                                          "TTIME",
                                          "CURRENCY",
                                          "INSERT DATE",
                                          "RN",
                                        ]
                                        .map(
                                          (header) => Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              header,
                                              style: TextStyle(
                                                fontSize: fontSettings.fontSize,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),

                              // Data Rows
                              ...memberSummary.map((entry) {
                                return TableRow(
                                  children: [
                                    _tableCell(
                                      entry.descrip.isNotEmpty
                                          ? entry.descrip
                                          : "N/A",
                                      fontSettings,
                                      align: TextAlign.start,
                                    ),
                                    _tableCell(
                                      entry.inAmount.isNotEmpty
                                          ? entry.inAmount
                                          : "N/A",
                                      fontSettings,
                                      align: TextAlign.end,
                                      mono: true,
                                    ),
                                    _tableCell(
                                      entry.outAmount.isNotEmpty
                                          ? entry.outAmount
                                          : "N/A",
                                      fontSettings,
                                      align: TextAlign.end,
                                      mono: true,
                                    ),
                                    _tableCell(
                                      entry.tDate.isNotEmpty
                                          ? entry.tDate
                                          : "N/A",
                                      fontSettings,
                                      align: TextAlign.end,
                                      mono: true,
                                    ),
                                    _tableCell(
                                      entry.tTime.isNotEmpty
                                          ? entry.tTime
                                          : "N/A",
                                      fontSettings,
                                      align: TextAlign.end,
                                      mono: true,
                                    ),
                                    _tableCell(
                                      entry.cur.isNotEmpty ? entry.cur : "N/A",
                                      fontSettings,
                                      align: TextAlign.end,
                                    ),
                                    _tableCell(
                                      entry.insertDate.isNotEmpty
                                          ? entry.insertDate
                                          : "N/A",
                                      fontSettings,
                                      align: TextAlign.end,
                                      mono: true,
                                    ),
                                    _tableCell(
                                      entry.rn.toString(),
                                      fontSettings,
                                      align: TextAlign.end,
                                      mono: true,
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Loading Overlay ───────────────────────────────────────────────
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

  // ── Text scale (1x / 2x / 3x) selector ────────────────────────────────────
  Widget _buildTextScaleSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          "Text Size",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        const SizedBox(width: 10),
        ...[1.0, 1.2, 1.3].map((scale) {
          final bool selected = _textScale == scale;
          return Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _textScale = scale),
              child: Container(
                width: 44,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? Constants.kSecondaryColor
                      : Colors.transparent,
                  border: Border.all(color: Constants.kSecondaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${scale.toDouble()}x",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : Constants.kSecondaryColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Helper: Table Cell ────────────────────────────────────────────────────
  Widget _tableCell(
    String text,
    fontSettings, {
    TextAlign align = TextAlign.start,
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
          fontFamily: mono ? 'monospace' : null,
          fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
        ),
      ),
    );
  }
}
