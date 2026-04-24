import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/components/birthday_gift_increase_pdf.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/models/gift/birthday_gift_request.dart';
import 'package:ballys_reservation_app/providers/BirthdayGiftIncreesNotifier.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/special_gift_provider.dart';
import 'package:ballys_reservation_app/utils/formatter.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:ballys_reservation_app/models/birthday.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';

import 'package:intl/intl.dart';

class BirthdayGiftPriceIncreaseScreen extends ConsumerStatefulWidget {
  final Birthday birthday;
  final GiftsRepository giftsRepository;

  const BirthdayGiftPriceIncreaseScreen({
    super.key,
    required this.birthday,
    required this.giftsRepository,
  });

  @override
  ConsumerState<BirthdayGiftPriceIncreaseScreen> createState() =>
      _BirthdayGiftPriceIncreaseScreenState();
}

class _BirthdayGiftPriceIncreaseScreenState
    extends ConsumerState<BirthdayGiftPriceIncreaseScreen> {
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _arrivalDateController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _currentGiftValueController =
      TextEditingController();
  final TextEditingController _newAmountController = TextEditingController();

  String? _selectedGift;
  String? _chipType;
  String _remarks = "";
  String? userName = "";
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showGuestData = false;
  bool _showGuestCard = false;
  bool _isLoadingGuestCard = true;

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    _initializeMemberData();

    Future.microtask(() {
      ref.read(selectedGuestProvider.notifier).clearGuest();
      ref.read(giftProvider.notifier).getGiftForList();
      _fetchCompleteGuestData();
    });
  }

  Future<void> _fetchCompleteGuestData() async {
    setState(() {
      _isLoadingGuestCard = true;
      _showGuestCard = true;
    });

    try {
      ref.read(selectedGuestProvider.notifier).setSelectedGuest(
        Guest(
          mid: widget.birthday.mid,
          memberName: widget.birthday.mname,
          country: widget.birthday.country,
          lastVisitDate: widget.birthday.lvd?.toString() ?? "N/A",
          age: widget.birthday.age,
          gRating: widget.birthday.gRating,
          mGroup: widget.birthday.mGroup,
          gName: widget.birthday.gName,
          gift: widget.birthday.gift,
          mobile: widget.birthday.mobile,
          memImage2: null,
        ),
      );

      await ref.read(selectedGuestProvider.notifier).getGuestImage(
            9021,
            widget.birthday.mid,
          );

      setState(() {
        _isLoadingGuestCard = false;
      });
    } catch (e) {
      print("Error fetching guest image: $e");
      setState(() {
        _isLoadingGuestCard = false;
      });
    }
  }

  void _initializeMemberData() {
    _memberIdController.text = widget.birthday.mid;
    _memberNameController.text = widget.birthday.mname;
    _currentGiftValueController.text = widget.birthday.gift;
  }

  Future<void> _loadUserCredentials() async {
    final name = await StorageUtil.getUserName();
    setState(() {
      userName = name;
    });
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // ── Date picker (date only) ────────────────────────────────────────────────
  Future<void> _pickDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    DateTime selectedDate = DateTime.now();

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
                "Select date",
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
                controller.text =
                    "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}";
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

    // ✅ FIX: rebuild so _areRequiredFieldsFilled re-evaluates → button colors update
    setState(() {});
  }

  // ── Date + Time picker ────────────────────────────────────────────────────
  Future<void> _pickDateTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    // Step 1: Pick Date
    final datePicked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        int day = selectedDate.day;
        int month = selectedDate.month;
        int year = selectedDate.year;

        final FixedExtentScrollController dayController =
            FixedExtentScrollController(initialItem: day - 1);
        final FixedExtentScrollController monthController =
            FixedExtentScrollController(initialItem: month - 1);
        final FixedExtentScrollController yearController =
            FixedExtentScrollController(initialItem: year - 2000);

        final List<String> monthNames = [
          "January",
          "February",
          "March",
          "April",
          "May",
          "June",
          "July",
          "August",
          "September",
          "October",
          "November",
          "December",
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "Select Date",
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: dayController,
                              itemExtent: 40,
                              perspective: 0.005,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                day = index + 1;
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 31,
                                builder: (context, index) {
                                  return Center(
                                    child: Text(
                                      "${index + 1}",
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: ListWheelScrollView.useDelegate(
                              controller: monthController,
                              itemExtent: 40,
                              perspective: 0.005,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                month = index + 1;
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 12,
                                builder: (context, index) {
                                  return Center(
                                    child: Text(
                                      monthNames[index],
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: ListWheelScrollView.useDelegate(
                              controller: yearController,
                              itemExtent: 40,
                              perspective: 0.005,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                year = 2000 + index;
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 102,
                                builder: (context, index) {
                                  return Center(
                                    child: Text(
                                      "${2000 + index}",
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                TextButton(
                  onPressed: () {
                    final maxDay = DateTime(year, month + 1, 0).day;
                    final validDay = day > maxDay ? maxDay : day;
                    Navigator.of(context).pop(DateTime(year, month, validDay));
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
      },
    );

    if (datePicked == null) return;
    selectedDate = datePicked;

    // Step 2: Pick Time with AM/PM
    final timePicked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        int hour =
            selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
        int minute = selectedTime.minute;
        DayPeriod period = selectedTime.period;

        final FixedExtentScrollController hourController =
            FixedExtentScrollController(initialItem: hour - 1);
        final FixedExtentScrollController minuteController =
            FixedExtentScrollController(initialItem: minute);
        final FixedExtentScrollController periodController =
            FixedExtentScrollController(
                initialItem: period == DayPeriod.am ? 0 : 1);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "Select Time",
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ListWheelScrollView.useDelegate(
                              controller: hourController,
                              itemExtent: 40,
                              perspective: 0.005,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                hour = index + 1;
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 12,
                                builder: (context, index) {
                                  return Center(
                                    child: Text(
                                      (index + 1).toString().padLeft(2, '0'),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const Text(
                            ":",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: ListWheelScrollView.useDelegate(
                              controller: minuteController,
                              itemExtent: 40,
                              perspective: 0.005,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                minute = index;
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 60,
                                builder: (context, index) {
                                  return Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: periodController,
                              itemExtent: 40,
                              perspective: 0.005,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                period =
                                    index == 0 ? DayPeriod.am : DayPeriod.pm;
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 2,
                                builder: (context, index) {
                                  return Center(
                                    child: Text(
                                      index == 0 ? "AM" : "PM",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                TextButton(
                  onPressed: () {
                    int hour24;
                    if (period == DayPeriod.am) {
                      hour24 = hour == 12 ? 0 : hour;
                    } else {
                      hour24 = hour == 12 ? 12 : hour + 12;
                    }
                    Navigator.of(context).pop(
                      TimeOfDay(hour: hour24, minute: minute),
                    );
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
      },
    );

    if (timePicked == null) return;
    selectedTime = timePicked;

    final hour12 =
        selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
    final minuteStr = selectedTime.minute.toString().padLeft(2, '0');
    final periodStr =
        selectedTime.period == DayPeriod.am ? "AM" : "PM";

    controller.text =
        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year} "
        "${hour12.toString().padLeft(2, '0')}:$minuteStr $periodStr";

    // ✅ FIX: rebuild so _areRequiredFieldsFilled re-evaluates → button colors update
    setState(() {});
  }

  TextStyle _inputTextStyle(FontSettings fontSettings) {
    return TextStyle(
      fontSize: fontSettings.fontSize,
      fontWeight: fontSettings.fontWeight,
    );
  }

  TextStyle _inputTextStyleForAmount(FontSettings fontSettings) {
    return TextStyle(
      fontSize: fontSettings.fontSize + 3,
      fontWeight: FontWeight.bold,
    );
  }

  String formatNumber(dynamic value) {
    if (value == null) return "";
    final num? number = num.tryParse(value.toString());
    if (number == null) return value.toString();
    return NumberFormat.decimalPattern().format(number);
  }

  bool get _areRequiredFieldsFilled {
    return _fromDateController.text.isNotEmpty &&
        _toDateController.text.isNotEmpty &&
        _memberIdController.text.isNotEmpty &&
        _memberNameController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return PopScope(
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        ref.read(selectedGuestProvider.notifier).clearGuest();
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Birthday Gift Price Increase',
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Guest Card ────────────────────────────────────
                        GuestDisplayCardSpecialGiftview(
                          memberIdText: _memberIdController.text,
                          memberNameText: _memberNameController.text,
                          showCard: _showGuestCard,
                          isLoading: _isLoadingGuestCard,
                          showLastVisitDate: true,
                        ),

                        const SizedBox(height: 16.0),

                        // ── Current Gift Value Card (top) ─────────────────
                        Card(
                          elevation: 2,
                          color: Colors.green.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Icon(Icons.card_giftcard,
                                    color: Colors.green.shade700, size: 24),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Gift Value:',
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize - 2,
                                        color:
                                            const Color.fromARGB(255, 0, 0, 0),
                                      ),
                                    ),
                                    Text(
                                      widget.birthday.gift,
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize + 4,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16.0),

                        // ── From Date & Time ──────────────────────────────
                        TextFormField(
                          controller: _fromDateController,
                          readOnly: true,
                          style: _inputTextStyle(fontSettings),
                          decoration: InputDecoration(
                            labelText: "From Date & Time *",
                            labelStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: -5.0),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? "From Date & Time required"
                              : null,
                          onTap: () =>
                              _pickDateTime(context, _fromDateController),
                        ),

                        const SizedBox(height: 10.0),

                        // ── To Date & Time ────────────────────────────────
                        TextFormField(
                          controller: _toDateController,
                          readOnly: true,
                          style: _inputTextStyle(fontSettings),
                          decoration: InputDecoration(
                            labelText: "To Date & Time *",
                            labelStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: -5.0),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? "To Date & Time required"
                              : null,
                          onTap: () =>
                              _pickDateTime(context, _toDateController),
                        ),

                        const SizedBox(height: 10.0),

                        // ── Action Buttons Row ────────────────────────────
                        Row(
                          children: [
                            // Profile button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      final selectedGuest =
                                          ref.read(selectedGuestProvider);
                                      if (selectedGuest != null &&
                                          selectedGuest.mid ==
                                              _memberIdController.text) {
                                        context.push('/home/profile');
                                        return;
                                      }
                                      try {
                                        setState(() => _isLoading = true);
                                        ref
                                            .read(
                                                selectedGuestProvider.notifier)
                                            .setSelectedGuest(Guest(
                                              mid: widget.birthday.mid,
                                              memberName: widget.birthday.mname,
                                              country: widget.birthday.country,
                                              lastVisitDate:
                                                  widget.birthday.lvd
                                                          ?.toString() ??
                                                      "",
                                              age: widget.birthday.age,
                                              gRating: widget.birthday.gRating,
                                              mGroup: widget.birthday.mGroup,
                                              gName: widget.birthday.gName,
                                            ));
                                        setState(() => _isLoading = false);
                                        context.push('/home/profile');
                                      } catch (e) {
                                        setState(() => _isLoading = false);
                                      }
                                    },
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(Icons.person_search, size: 25),
                            ),

                            const SizedBox(width: 5),

                            // Guest Data button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _areRequiredFieldsFilled
                                    ? () async {
                                        setState(() {
                                          _dismissKeyboard();
                                          _isLoading = true;
                                          _showGuestData = false;
                                        });

                                        await ref
                                            .read(giftProvider.notifier)
                                            .getGestgiftGift(
                                              8886,
                                              _fromDateController.text,
                                              _toDateController.text,
                                              _memberIdController.text,
                                              _fromDateController.text,
                                              _toDateController.text,
                                            );

                                        setState(() {
                                          _isLoading = false;
                                          _showGuestData = true;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.person),
                                label: Text(
                                  "Guest Data",
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _areRequiredFieldsFilled
                                      ? Colors.orange
                                      : Colors.grey.shade300,
                                  foregroundColor: _areRequiredFieldsFilled
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                ),
                              ),
                            ),

                            const SizedBox(width: 7),

                            // Prv Gift button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _areRequiredFieldsFilled
                                    ? () {
                                        _dismissKeyboard();
                                        final memberId =
                                            _memberIdController.text.trim();

                                        if (memberId.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content: Text(
                                                "Please enter a Member ID"),
                                          ));
                                          return;
                                        }
                                        context.push(
                                          '/gifts/special-gift-requests/prv-gifts/$memberId',
                                          extra: {'iid': 8888},
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.card_giftcard),
                                label: Text(
                                  "Prv Gift",
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _areRequiredFieldsFilled
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                                  foregroundColor: _areRequiredFieldsFilled
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10.0),

                        // ── Guest Gift Data Table ─────────────────────────
                        if (_showGuestData) ...[
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              "Guest Gift Data",
                              style: TextStyle(
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Builder(
                            builder: (context) {
                              final giftState = ref.watch(giftProvider);
                              if (giftState.guestGiftData.isEmpty) {
                                return Text(
                                  "No guest gift data found",
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                );
                              }
                              final data = giftState.guestGiftData.first;

                              final rows = [
                                {
                                  "Field": "Drop (Est)",
                                  "Value": data.guestDrop
                                },
                                {
                                  "Field": "Cash Out (Est)",
                                  "Value": data.tmpCashout
                                },
                                {"Field": "Result (Est)", "Value": data.res},
                                {
                                  "Field": "Actual Drop (Est)",
                                  "Value": data.actD
                                },
                                {
                                  "Field": "Coupons (Est)",
                                  "Value": data.guestCoupon
                                },
                                {
                                  "Field": "Commission Paid (Est)",
                                  "Value": data.tmpCommpaid
                                },
                                {
                                  "Field": "Points (Est)",
                                  "Value": data.tmpPoint
                                },
                                {
                                  "Field": "Flush Coupon (Est)",
                                  "Value": data.flushCoupon
                                },
                                {
                                  "Field": "Total Coupon (Est)",
                                  "Value": data.guestCoupon + data.flushCoupon,
                                },
                                {
                                  "Field": "Flush Actual Drop (Est)",
                                  "Value": data.flushActDrop
                                },
                                {
                                  "Field": "Avg Bet (Est)",
                                  "Value": data.tmpAvgBet
                                },
                              ];

                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                          Colors.amber.shade100),
                                      border: TableBorder.all(
                                          color: Colors.grey.shade300),
                                      columns: [
                                        DataColumn(
                                          label: Text("Field",
                                              style: TextStyle(
                                                fontSize: fontSettings.fontSize,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                              )),
                                        ),
                                        DataColumn(
                                          label: Text("Value",
                                              style: TextStyle(
                                                fontSize: fontSettings.fontSize,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                              )),
                                        ),
                                      ],
                                      rows: rows.map((row) {
                                        final shouldHighlight = [
                                          "Actual Drop (Est)",
                                          "Result (Est)",
                                          "Coupons (Est)",
                                          "Points (Est)",
                                          "Avg Bet (Est)",
                                        ].contains(row["Field"]);
                                        return DataRow(
                                          color: shouldHighlight
                                              ? WidgetStateProperty.all(
                                                  const Color(0xFFCCFFCC))
                                              : null,
                                          cells: [
                                            DataCell(Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                row["Field"].toString(),
                                                style: TextStyle(
                                                  fontSize:
                                                      fontSettings.fontSize,
                                                  fontWeight: shouldHighlight
                                                      ? FontWeight.bold
                                                      : fontSettings.fontWeight,
                                                ),
                                              ),
                                            )),
                                            DataCell(Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                formatNumber(row["Value"]),
                                                style: TextStyle(
                                                  fontSize:
                                                      fontSettings.fontSize,
                                                  fontWeight: shouldHighlight
                                                      ? FontWeight.bold
                                                      : fontSettings.fontWeight,
                                                  fontFamily: 'monospace',
                                                  fontFeatures: const [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                            )),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const Watermark(),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10.0),
                        ],

                        // ── Arrival / Departure Row ───────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _arrivalDateController,
                                readOnly: true,
                                style: _inputTextStyle(fontSettings),
                                decoration: InputDecoration(
                                  labelText: "Arrival Date *",
                                  labelStyle: TextStyle(
                                    fontSize: fontSettings.fontSize - 2,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: -5.0),
                                  suffixIcon:
                                      const Icon(Icons.calendar_today),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? "Arrival Date required"
                                    : null,
                                onTap: () =>
                                    _pickDate(context, _arrivalDateController),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _departureDateController,
                                readOnly: true,
                                style: _inputTextStyle(fontSettings),
                                decoration: InputDecoration(
                                  labelText: "Departure Date *",
                                  labelStyle: TextStyle(
                                    fontSize: fontSettings.fontSize - 2,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: -5.0),
                                  suffixIcon:
                                      const Icon(Icons.calendar_today),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? "Departure Date required"
                                    : null,
                                onTap: () => _pickDate(
                                    context, _departureDateController),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10.0),

                        // ── Gift Dropdown ────────────────────────────────
                        Consumer(
                          builder: (context, ref, child) {
                            final giftState = ref.watch(giftProvider);

                            final birthdayGifts = giftState.giftForList
                                .where((gift) =>
                                    gift.code
                                        .toUpperCase()
                                        .contains('BIRTHDAY') ||
                                    gift.code
                                        .toUpperCase()
                                        .contains('B_DAY') ||
                                    gift.code.toUpperCase() ==
                                        'BIRTHDAY_GIFT')
                                .toList();

                            final giftsToShow = birthdayGifts.isNotEmpty
                                ? birthdayGifts
                                : giftState.giftForList;

                            final uniqueGiftList = {
                              for (var gift in giftsToShow) gift.code: gift,
                            }.values.toList();

                            final currentValue = uniqueGiftList.any(
                                    (gift) => gift.code == _selectedGift)
                                ? _selectedGift
                                : null;

                            return DropdownButtonFormField<String>(
                              value: currentValue,
                              items: uniqueGiftList.map((gift) {
                                return DropdownMenuItem<String>(
                                  value: gift.code,
                                  child: Text(
                                    gift.code.replaceAll("_", " "),
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedGift = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: "Gift For (Birthday Gift) *",
                                labelStyle: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: -5.0),
                                prefixIcon: const Icon(Icons.cake,
                                    color: Colors.pink),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? "Gift required"
                                  : null,
                            );
                          },
                        ),

                        const SizedBox(height: 10.0),

                        // ── Chip Type Dropdown ───────────────────────────
                        DropdownButtonFormField<String>(
                          style: _inputTextStyle(fontSettings),
                          decoration: InputDecoration(
                            labelText: "Chip Type *",
                            labelStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: -5.0),
                          ),
                          value: _chipType,
                          items: const [
                            DropdownMenuItem(
                              value: "OTP Chips",
                              child: Text("OTP Chips",
                                  style: TextStyle(color: Colors.black)),
                            ),
                            DropdownMenuItem(
                              value: "NC Chips",
                              child: Text("NC Chips",
                                  style: TextStyle(color: Colors.black)),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _chipType = value;
                            });
                          },
                          validator: (v) => v == null || v.isEmpty
                              ? "Chip Type required"
                              : null,
                        ),

                        const SizedBox(height: 10.0),

                        // ── Current Gift Value Card (bottom) ─────────────
                        Card(
                          elevation: 2,
                          color: Colors.green.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Icon(Icons.card_giftcard,
                                    color: Colors.green.shade700, size: 24),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Gift Value:',
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize - 2,
                                        color:
                                            const Color.fromARGB(255, 0, 0, 0),
                                      ),
                                    ),
                                    Text(
                                      widget.birthday.gift,
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize + 4,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10.0),

                        // ── New Amount ───────────────────────────────────
                        TextFormField(
                          controller: _newAmountController,
                          style: _inputTextStyleForAmount(fontSettings),
                          decoration: InputDecoration(
                            labelText: "New Amount (Requested) *",
                            labelStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: -5.0),
                            prefixIcon: const Icon(Icons.trending_up,
                                color: Colors.orange),
                            helperText: 'Enter the increased gift amount',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            ThousandsSeparatorInputFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter new amount";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 10.0),

                        // ── Remarks ──────────────────────────────────────
                        TextFormField(
                          style: _inputTextStyle(fontSettings),
                          decoration: InputDecoration(
                            alignLabelWithHint: true,
                            labelText: "Remarks",
                            labelStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                            hintText:
                                "Enter reason for price increase request...",
                            hintStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          onChanged: (value) => _remarks = value,
                        ),

                        const SizedBox(height: 16.0),

                        // ── Submit Button ────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _showGuestData
                                ? () async {
                                    _dismissKeyboard();
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }

                                    setState(() => _isLoading = true);
                                    try {
                                      final ok = await ref
                                          .read(giftProvider.notifier)
                                          .increaceBirtdayGiftFromUI(
                                            mid: _memberIdController.text
                                                .trim(),
                                            memberName: _memberNameController
                                                .text
                                                .trim(),
                                            fromDateTime: _fromDateController
                                                .text
                                                .trim(),
                                            toDateTime: _toDateController.text
                                                .trim(),
                                            arrivalDate:
                                                _arrivalDateController.text
                                                    .trim(),
                                            departureDate:
                                                _departureDateController.text
                                                    .trim(),
                                            giftForCode: _selectedGift ??
                                                "BIRTHDAY_GIFT",
                                            chipTypeUI:
                                                _chipType ?? "OTP Chips",
                                            amountUI: _newAmountController.text,
                                            previousGiftPrice:
                                                widget.birthday.gift,
                                            remarks: _remarks.trim(),
                                            userName: userName ?? "",
                                          );

                                      setState(() => _isLoading = false);

                                      if (!mounted) return;
                                      final currentGiftState = ref.read(giftProvider);
final returnSerial = currentGiftState.lastReturnSerial;

// ── Already has a pending birthday gift ──────────────────────────
if (!ok && returnSerial == "0") {
  final mid = _memberIdController.text.trim();

  await showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      bool isLoadingGift = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text('Pending Gift Exists'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                  'This member already has a pending birthday gift price increase request.',
                  style: TextStyle(fontSize: 20),
                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (isLoadingGift)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              // ── OK button ────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: isLoadingGift
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, size: 18),
                label: Text('OK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 0, 0),
                  foregroundColor: Colors.white,
                ),
              ),
              // ── Show button ──────────────────────────────────────
              ElevatedButton.icon(
                onPressed: isLoadingGift
                    ? null
                    : () async {
                        setDialogState(() => isLoadingGift = true);
                        try {
                          final resp = await widget.giftsRepository
                              .getPendingBirthdayGiftIdByMember(mid);

                          BirthdayIncressGiftRequest? foundGift;

                          if (resp['CommonResult'] != null &&
                              resp['CommonResult']['Table'] is List &&
                              (resp['CommonResult']['Table'] as List)
                                  .isNotEmpty) {
                            final row = Map<String, dynamic>.from(
                                (resp['CommonResult']['Table'] as List)
                                    .first);
                            final idNoRaw = row['Id_No'];
                            if (idNoRaw != null) {
                              final idNo = (idNoRaw is num)
                                  ? idNoRaw.toDouble()
                                  : double.tryParse(
                                          idNoRaw.toString()) ??
                                      0;

                              // Search in already-loaded pending gifts
                              final pendingGifts = ref
                                  .read(birthdayGiftIncreesProvider)
                                  .pendingBirthdayGift;
                              try {
                                foundGift = pendingGifts.firstWhere(
                                  (g) => g.idNo == idNo,
                                );
                              } catch (_) {
                                foundGift = null;
                              }

                              // If not found, refresh from API then retry
                              if (foundGift == null) {
                                final salesCode =
                                    await StorageUtil.getSalesCode();
                                if (salesCode != null) {
                                  await ref
                                      .read(birthdayGiftIncreesProvider
                                          .notifier)
                                      .getBirthdayGiftData(
                                          98890, salesCode);
                                  final refreshed = ref
                                      .read(birthdayGiftIncreesProvider)
                                      .pendingBirthdayGift;
                                  try {
                                    foundGift = refreshed.firstWhere(
                                      (g) => g.idNo == idNo,
                                    );
                                  } catch (_) {
                                    foundGift = null;
                                  }
                                }
                              }
                            }
                          }

                          setDialogState(() => isLoadingGift = false);
                          if (!mounted) return;
                          Navigator.of(context).pop(); // close dialog

                          if (foundGift != null) {
                            await context.push(
                              '/menu/approve-reject/birthday-gifts/view-birthday-gift-request',
                              extra: {
                                'gift': foundGift,
                                'isPending': false,
                                'isApproved': false,
                                'isChecked': false,
                                'isIssued': false,
                                'isViewOnly': true,
                              },
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Could not load gift details'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isLoadingGift = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                icon: Icon(Icons.visibility, size: 18),
                label: Text('Show'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );
    },
  );
  ref.read(giftProvider.notifier).clearLastApiResponse();
  return;
}
                                      if (ok) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                            "Birthday gift price increase request sent successfully",
                                          ),
                                          backgroundColor: Colors.green,
                                        ));

                                        // Build guestDataMap
                                        final giftState =
                                            ref.read(giftProvider);
                                        Map<String, dynamic> guestDataMap = {};

                                        if (giftState
                                            .guestGiftData.isNotEmpty) {
                                          final data =
                                              giftState.guestGiftData.first;
                                          guestDataMap = {
                                            'guestDrop': data.guestDrop,
                                            'tmpCashout': data.tmpCashout,
                                            'res': data.res,
                                            'actD': data.actD,
                                            'guestCoupon': data.guestCoupon,
                                            'tmpCommpaid': data.tmpCommpaid,
                                            'tmpPoint': data.tmpPoint,
                                            'flushCoupon': data.flushCoupon,
                                            'flushActDrop': data.flushActDrop,
                                            'tmpAvgBet': data.tmpAvgBet,
                                          };
                                        }

                                        // Share dialog
                                        final shareOption =
                                            await showDialog<String>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: Row(
                                                children: const [
                                                  Icon(Icons.share,
                                                      color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text('Share Gift Request'),
                                                ],
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Choose how to share the PDF document:',
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green
                                                          .shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                          color: Colors.green
                                                              .shade200),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                                Icons
                                                                    .check_circle,
                                                                color:
                                                                    Colors.green,
                                                                size: 16),
                                                            const SizedBox(
                                                                width: 4),
                                                            Text(
                                                              'RECOMMENDED',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .green
                                                                    .shade700,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        const Text(
                                                          'Share with Apps - PDF automatically attached',
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop('cancel'),
                                                  child:
                                                      const Text('Cancel'),
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop('system'),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.blue,
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                  icon: const Icon(
                                                      Icons.share),
                                                  label: const Text(
                                                      'Share with Apps'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        // Trigger PDF share
                                        if (shareOption == 'system') {
                                          try {
                                            final currentGiftState =
                                                ref.read(giftProvider);
                                            final returnSerial =
                                                currentGiftState
                                                    .lastReturnSerial;

                                            await BirthdayGiftIncreasePdfService
                                                .shareDirectlyToWhatsApp(
                                              memberName:
                                                  _memberNameController.text
                                                      .trim(),
                                              memberId: _memberIdController
                                                  .text
                                                  .trim(),
                                              fromDateTime: _fromDateController
                                                  .text
                                                  .trim(),
                                              toDateTime: _toDateController
                                                  .text
                                                  .trim(),
                                              arrivalDate:
                                                  _arrivalDateController.text
                                                      .trim(),
                                              departureDate:
                                                  _departureDateController.text
                                                      .trim(),
                                              giftFor: _selectedGift ??
                                                  "BIRTHDAY_GIFT",
                                              chipType:
                                                  _chipType ?? "OTP Chips",
                                              previousGiftPrice:
                                                  widget.birthday.gift,
                                              newAmount:
                                                  _newAmountController.text,
                                              remarks: _remarks,
                                              userName: userName ?? "",
                                              guestData: guestDataMap,
                                              returnSerial:
                                                  returnSerial ?? "",
                                            );

                                            if (mounted) {
                                              final serialInfo = returnSerial !=
                                                          null &&
                                                      returnSerial.isNotEmpty
                                                  ? " (Serial: $returnSerial)"
                                                  : "";
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(
                                                  "PDF ready$serialInfo! Select WhatsApp from the share options.",
                                                ),
                                                duration: const Duration(
                                                    seconds: 3),
                                              ));
                                            }

                                            ref
                                                .read(giftProvider.notifier)
                                                .clearLastApiResponse();
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(
                                                    "Error sharing PDF: $e"),
                                                backgroundColor: Colors.red,
                                                duration: const Duration(
                                                    seconds: 4),
                                              ));
                                            }
                                          }
                                        }

                                        Navigator.of(context).pop(true);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                            "Failed to send gift price increase request",
                                          ),
                                          backgroundColor: Colors.red,
                                        ));
                                      }
                                    } catch (e) {
                                      setState(() => _isLoading = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text("Error: $e"),
                                          backgroundColor: Colors.red,
                                        ));
                                      }
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _showGuestData
                                  ? Colors.orange
                                  : Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.trending_up, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  "Submit Price Increase Request",
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Global Loading Overlay ──────────────────────────────────
              if (_isLoading)
                Positioned.fill(
                  child: Container(
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ref.read(selectedGuestProvider.notifier).clearGuest();

    _memberIdController.dispose();
    _memberNameController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _arrivalDateController.dispose();
    _departureDateController.dispose();
    _currentGiftValueController.dispose();
    _newAmountController.dispose();
    super.dispose();
  }
}