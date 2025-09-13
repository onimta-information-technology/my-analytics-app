import 'dart:convert';

import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/member_summary_provider.dart';
import 'package:ballys_reservation_app/providers/profile_date_filter_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MemberSummaryScreen extends ConsumerStatefulWidget {
  final MemberProfileRepository memberProfileRepository;

  const MemberSummaryScreen({required this.memberProfileRepository, super.key});

  @override
  ConsumerState<MemberSummaryScreen> createState() => _GuestPerformanceState();
}

class _GuestPerformanceState extends ConsumerState<MemberSummaryScreen> {

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final ValueNotifier<DateTime?> startDateNotifier =
      ValueNotifier<DateTime?>(null);
  final ValueNotifier<DateTime?> endDateNotifier =
      ValueNotifier<DateTime?>(null);

  @override
  void initState() {
    super.initState();
    _getGuestImage();
    String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _startDateController.text = formattedDate;
    _endDateController.text = formattedDate;
    
  }
   

  bool _isLoading = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  Future<void> _getGuestImage() async {
    final guest = ref.read(selectedGuestProvider);
    if (guest!.memImage2 != null) return;

    if (guest.memImage2 == null) {
      print("Fetching image for guest: ${guest.mid}");
      await ref
          .read(selectedGuestProvider.notifier)
          .getGuestImage(9021, guest.mid);
    } else {
      print("Image already loaded for guest: ${guest.memImage2}");
    }
  }

  Future<void> _selectArrivalDate(BuildContext context) async {
    final DateTime? selectedArrivalDate = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (selectedArrivalDate != null && selectedArrivalDate != _dateFrom) {
      ref.read(dateFilterProvider.notifier).setDateFrom(selectedArrivalDate);
    }
  }

  Future<void> _selectDepartureDate(BuildContext context) async {
    final DateTime? selectedDepartureDate = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? _dateFrom ?? DateTime.now(),
      firstDate: _dateFrom ?? DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (selectedDepartureDate != null && selectedDepartureDate != _dateTo) {
      ref.read(dateFilterProvider.notifier).setDateTo(selectedDepartureDate);
    }
  }

  Future<void> _getLoyalitySummary() async {
    try {
      if (_startDateController.text == "" || _endDateController.text == "") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select start and end dates.")),
        );
        return;
      }

      final guest = ref.watch(selectedGuestProvider);
      setState(() {
        _isLoading = true;
      });

      await ref.read(memberSummaryProvider.notifier).getMemberSummary(
          playerId: guest!.mid,
          dateFrom: startDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(startDateNotifier.value!)
              : '',
          dateTo: endDateNotifier.value != null
              ? DateFormat('yyyy-MM-dd').format(endDateNotifier.value!)
              : '');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching member summary: $e');
    }
  }

  String formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatDate2(String dateString) {
    if (dateString == "") return "N/A";
    final date = DateTime.parse(dateString);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _timeFormat(String dateString) {
    if (dateString == "") return "N/A";
    final date = DateTime.parse(dateString);
    return DateFormat('HH:mm:ss').format(date);
  }

  String _parseNumberFormat(double? value) {
    if (value == null || value == 0) return "0.00";
    final formatter = NumberFormat('#,##0');
    String formattedNumber = formatter.format(value);
    return formattedNumber;
  }

  final Map<String, String> ratingImageMap = {
    "CLASSIC": "assets/images/ratings/CLASSIC.png",
    "DIAMOND": "assets/images/ratings/DIAMOND.png",
    "GOLD": "assets/images/ratings/GOLD.png",
    "INFINITY": "assets/images/ratings/INFINITY.png",
    "PLATINUM": "assets/images/ratings/PLATINUM.png",
    "SILVER": "assets/images/ratings/SILVER.png",
  };
  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final guest = ref.watch(selectedGuestProvider);
    final memberSummary = ref.watch(memberSummaryProvider);
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

    final String? imagePath = ratingImageMap[guest.gRating];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Member Summary"),
      ),
      body: Stack(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Card(
                        elevation: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20.0, horizontal: 5.0),
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
                                child: Hero(
                                  tag: "guest-image",
                                  child: CircleAvatar(
                                    radius: 70,
                                    backgroundImage: guest.memImage2 != null
                                        ? MemoryImage(
                                            base64Decode(guest.memImage2!))
                                        : const AssetImage(
                                            'assets/images/placeholder_image.jpg'),
                                    backgroundColor: Colors.grey[200],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  "${guest.mid} -  ${guest.memberName}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                                const SizedBox(height: 5),
                              Center(
                                child: Text(
                                  "M P - ${guest.gName}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color.fromARGB(255, 158, 0, 148),
                                    fontWeight: FontWeight.bold,
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
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  Text(
                                    "Last Visit on -  ${formatDate(guest.lastVisitDate)}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.normal,
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
                        child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(0),
                            child: SizedBox(
                              width: 80,
                              height: 30,
                              child: imagePath != null
                                  ? Hero(
                                      tag: "rating-image",
                                      child: Image.asset(
                                        imagePath,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Hero(
                                      tag: "rating-image",
                                      child: Image.asset(
                                        "assets/images/ratings/CLASSIC.png",
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 16.0,
                  ),
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
                              decoration: InputDecoration(
                                labelText: "Start Date",
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () {
                                    _selectArrivalDate(context);
                                  },
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
                              decoration: InputDecoration(
                                labelText: "End Date",
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () {
                                    _selectDepartureDate(context);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 16.0,
                  ),
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
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Total Cash In (Est):",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        memberSummary
                                            .firstWhere(
                                              (entry) =>
                                                  entry.descrip == "TOTAL",
                                            )
                                            .inAmount,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: fontSettings.fontSize,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8.0),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Total Cash Out (Est):",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        memberSummary
                                            .firstWhere(
                                              (entry) =>
                                                  entry.descrip == "TOTAL",
                                            )
                                            .outAmount,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: fontSettings.fontSize,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8.0),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        memberSummary.last.descrip == "WIN"
                                            ? "Win Amount (Est):"
                                            : "Loss Amount (Est):",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        memberSummary.last.inAmount,
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
                        ),
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
                            TableRow(
                              decoration: BoxDecoration(
                                color: Constants.kPrimaryColor.withAlpha(50),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "DESCRIPTION",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "IN",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "OUT",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "TDATE",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "TTIME",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "CURRENCY",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "INSERT DATE",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "RN",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ...memberSummary.map((entry) {
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      entry.descrip ?? "N/A",
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      entry.inAmount ?? "N/A",
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      entry.outAmount ?? "N/A",
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      entry.tDate.toString(),
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      entry.tTime.toString(),
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      entry.cur ?? "N/A",
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      entry.insertDate.toString(),
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      entry.rn.toString(),
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
                            }),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              decoration: const BoxDecoration(
                color: Color.fromARGB(135, 117, 115, 115),
              ),
              child: const Center(
                child: RefreshProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Constants.kSecondaryColor),
                ),
              ),
            ),
             const Watermark(),
        ],
      ),
    );
  }
}
