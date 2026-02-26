import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
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
    
    // Immediately clear previous guest data and load fresh data
    Future.microtask(() {
      // Clear any previous guest state first
      ref.read(selectedGuestProvider.notifier).clearGuest();
      ref.read(giftProvider.notifier).getGiftForList();
      // Fetch complete guest data including image
      _fetchCompleteGuestData();
    });
  }

  Future<void> _fetchCompleteGuestData() async {
    setState(() {
      _isLoadingGuestCard = true;
      _showGuestCard = true;
    });

    try {
      // First, set the basic guest data with all available information
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
          memImage2: null, // Will be updated by getGuestImage
        ),
      );
      
      // Then fetch and update the image
      await ref.read(selectedGuestProvider.notifier).getGuestImage(
        9021,
        widget.birthday.mid,
      );
      
      setState(() {
        _isLoadingGuestCard = false;
      });
    } catch (e) {
      // If fetching image fails, guest data is already set above
      print("Error fetching guest image: $e");
      setState(() {
        _isLoadingGuestCard = false;
      });
    }
  }

  void _initializeMemberData() {
    // Auto-fill member ID and name from birthday object
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

  // Future<void> _pickDate(
  //   BuildContext context,
  //   TextEditingController controller,
  // ) async {
  //   final DateTime? date = await showDatePicker(
  //     context: context,
  //     initialDate: DateTime.now(),
  //     firstDate: DateTime(2000),
  //     lastDate: DateTime(2101),
  //   );

  //   if (date != null) {
  //     controller.text = "${date.day}/${date.month}/${date.year}";
  //   }
  // }
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
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
              style: TextStyle(
                fontSize: 18,
                color: Colors.blue,
              ),
            ),
          ),
          const Divider(height: 1),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(
                fontSize: 18,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}
  // Future<void> _pickDateTime(
  //   BuildContext context,
  //   TextEditingController controller,
  // ) async {
  //   final DateTime? date = await showDatePicker(
  //     context: context,
  //     initialDate: DateTime.now(),
  //     firstDate: DateTime(2000),
  //     lastDate: DateTime(2101),
  //   );

  //   if (date == null) return;

  //   final TimeOfDay? time = await showTimePicker(
  //     context: context,
  //     initialTime: TimeOfDay.now(),
  //   );

  //   if (time == null) return;

  //   final DateTime dateTime = DateTime(
  //     date.year,
  //     date.month,
  //     date.day,
  //     time.hour,
  //     time.minute,
  //   );

  //   controller.text =
  //       "${dateTime.day}/${dateTime.month}/${dateTime.year} ${time.format(context)}";
  // }
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
        "January", "February", "March", "April",
        "May", "June", "July", "August",
        "September", "October", "November", "December"
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Center highlight bar
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
                        // Day Column
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
                        // Month Column
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
                        // Year Column
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
      // Convert to 12-hour format
      int hour = selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Center highlight bar
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
                        // Hour Column (1-12)
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
                        // Colon separator
                        const Text(
                          ":",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Minute Column (0-59)
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
                        // AM/PM Column
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
                  // Convert back to 24-hour format
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

  // Step 3: Format with AM/PM and set to controller
  final hour12 = selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
  final minuteStr = selectedTime.minute.toString().padLeft(2, '0');
  final periodStr = selectedTime.period == DayPeriod.am ? "AM" : "PM";

  controller.text =
      "${selectedDate.day}/${selectedDate.month}/${selectedDate.year} "
      "${hour12.toString().padLeft(2, '0')}:$minuteStr $periodStr";
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
        // Clear guest data when user navigates back
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
                        // Guest Display Card
                        GuestDisplayCardSpecialGiftview(
                          memberIdText: _memberIdController.text,
                          memberNameText: _memberNameController.text,
                          showCard: _showGuestCard,
                          isLoading: _isLoadingGuestCard,
                          showLastVisitDate: true,
                        ),

                        const SizedBox(height: 16.0),

                        // Current Gift Value Card
                        Card(
                          elevation: 2,
                          color: Colors.green.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.card_giftcard,
                                  color: Colors.green.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Gift Value:',
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize - 2,
                                        color: const Color.fromARGB(255, 0, 0, 0),
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

                        // From Date & Time
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
                              horizontal: 12.0,
                              vertical: -5.0,
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? "From Date & Time required"
                              : null,
                          onTap: () =>
                              _pickDateTime(context, _fromDateController),
                        ),

                        const SizedBox(height: 10.0),

                        // To Date & Time
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
                              horizontal: 12.0,
                              vertical: -5.0,
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? "To Date & Time required"
                              : null,
                          onTap: () => _pickDateTime(context, _toDateController),
                        ),

                        const SizedBox(height: 10.0),

                        // ── Profile + Guest Data + Prv Gift buttons ──────────
                        Row(
                          children: [
                            // Profile navigation button (same as ViewSpecificGiftRequest)
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
                                            .read(selectedGuestProvider.notifier)
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
                                          strokeWidth: 2, color: Colors.white))
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
                                    vertical: 16,
                                  ),
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
                                        final memberId = _memberIdController
                                            .text
                                            .trim();

                                        if (memberId.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Please enter a Member ID",
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        // Navigate to PrvGift page with MID as parameter
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
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10.0),

                        // Guest Gift Data Display
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
                                  "Value": data.guestDrop,
                                },
                                {
                                  "Field": "Cash Out (Est)",
                                  "Value": data.tmpCashout,
                                },
                                {"Field": "Result (Est)", "Value": data.res},
                                {
                                  "Field": "Actual Drop (Est)",
                                  "Value": data.actD,
                                },
                                {
                                  "Field": "Coupons (Est)",
                                  "Value": data.guestCoupon,
                                },
                                {
                                  "Field": "Commission Paid (Est)",
                                  "Value": data.tmpCommpaid,
                                },
                                {
                                  "Field": "Points (Est)",
                                  "Value": data.tmpPoint,
                                },
                                {
                                  "Field": "Flush Coupon (Est)",
                                  "Value": data.flushCoupon,
                                },
                                {
                                  "Field": "Total Coupon (Est)",
                                  "Value": data.guestCoupon + data.flushCoupon,
                                },
                                {
                                  "Field": "Flush Actual Drop (Est)",
                                  "Value": data.flushActDrop,
                                },
                                {
                                  "Field": "Avg Bet (Est)",
                                  "Value": data.tmpAvgBet,
                                },
                              ];

                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade400,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        Colors.amber.shade100,
                                      ),
                                      border: TableBorder.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      columns: [
                                        DataColumn(
                                          label: Text(
                                            "Field",
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Value",
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
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
                                                  Color(0xFFCCFFCC),
                                                )
                                              : null,
                                          cells: [
                                            DataCell(
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  row["Field"].toString(),
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    fontWeight: shouldHighlight
                                                        ? FontWeight.bold
                                                        : fontSettings
                                                              .fontWeight,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  formatNumber(row["Value"]),
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    fontWeight: shouldHighlight
                                                        ? FontWeight.bold
                                                        : fontSettings
                                                              .fontWeight,
                                                    fontFamily: 'monospace',
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
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
                                    horizontal: 12.0,
                                    vertical: -5.0,
                                  ),
                                  suffixIcon: const Icon(Icons.calendar_today),
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
                                    horizontal: 12.0,
                                    vertical: -5.0,
                                  ),
                                  suffixIcon: const Icon(Icons.calendar_today),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? "Departure Date required"
                                    : null,
                                onTap: () =>
                                    _pickDate(context, _departureDateController),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10.0),
                        // Gift For Dropdown - Filtered to show only Birthday Gift
                        Consumer(
                          builder: (context, ref, child) {
                            final giftState = ref.watch(giftProvider);

                            // Filter to show only Birthday Gift
                            final birthdayGifts = giftState.giftForList
                                .where((gift) =>
                                    gift.code
                                        .toUpperCase()
                                        .contains('BIRTHDAY') ||
                                    gift.code.toUpperCase().contains('B_DAY') ||
                                    gift.code.toUpperCase() == 'BIRTHDAY_GIFT')
                                .toList();

                            // If no birthday gifts found, show all as fallback
                            final giftsToShow = birthdayGifts.isNotEmpty
                                ? birthdayGifts
                                : giftState.giftForList;

                            final uniqueGiftList = {
                              for (var gift in giftsToShow) gift.code: gift,
                            }.values.toList();

                            final currentValue = uniqueGiftList.any(
                              (gift) => gift.code == _selectedGift,
                            )
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
                                  horizontal: 12.0,
                                  vertical: -5.0,
                                ),
                                prefixIcon: const Icon(
                                  Icons.cake,
                                  color: Colors.pink,
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? "Gift required"
                                  : null,
                            );
                          },
                        ),

                        const SizedBox(height: 10.0),

                        // Chip Type
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
                              horizontal: 12.0,
                              vertical: -5.0,
                            ),
                          ),
                          value: _chipType,
                          items: const [
                            DropdownMenuItem(
                              value: "OTP Chips",
                              child: Text(
                                "OTP Chips",
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            DropdownMenuItem(
                              value: "NC Chips",
                              child: Text(
                                "NC Chips",
                                style: TextStyle(color: Colors.black),
                              ),
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
                        Card(
                          elevation: 2,
                          color: Colors.green.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.card_giftcard,
                                  color: Colors.green.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Gift Value:',
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize - 2,
                                        color: const Color.fromARGB(255, 0, 0, 0),
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

                        // New Amount (Requested Increase)
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
                              horizontal: 12.0,
                              vertical: -5.0,
                            ),
                            prefixIcon: const Icon(
                              Icons.trending_up,
                              color: Colors.orange,
                            ),
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

                        // Remarks
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

                        // Submit Button
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
                                            mid: _memberIdController.text.trim(),
                                            memberName: _memberNameController.text.trim(),
                                            fromDateTime: _fromDateController.text.trim(),
                                            toDateTime: _toDateController.text.trim(),
                                            arrivalDate: _arrivalDateController.text.trim(),
                                            departureDate: _departureDateController.text.trim(),
                                            giftForCode: _selectedGift ?? "BIRTHDAY_GIFT",
                                            chipTypeUI: _chipType ?? "OTP Chips",
                                            amountUI: _newAmountController.text,
                                            previousGiftPrice: widget.birthday.gift, 
                                            remarks: _remarks.trim(),
                                            userName: userName ?? "",
                                          );

                                      setState(() => _isLoading = false);

                                      if (!mounted) return;
                                      if (ok) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Birthday gift price increase request sent successfully",
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        Navigator.of(context).pop(true);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Failed to send gift price increase request",
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setState(() => _isLoading = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Error: $e"),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
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
                                vertical: 16,
                                horizontal: 20,
                              ),
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
    // Clear guest data when disposing the screen
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