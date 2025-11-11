import 'package:ballys_reservation_app/components/bottom_sheets/member_search-new_sheet.dart';
import 'package:ballys_reservation_app/components/special_gift_pdf.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/member_search_provider.dart';
import 'package:ballys_reservation_app/providers/new_reservation_provider.dart';
import 'package:ballys_reservation_app/providers/special_gift_provider.dart';
import 'package:ballys_reservation_app/utils/formatter.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:ballys_reservation_app/components/bottom_sheets/member_search_by_mid_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NewGiftRequest extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;

  const NewGiftRequest({super.key, required this.giftsRepository});

  @override
  ConsumerState<NewGiftRequest> createState() => _NewGiftRequestState();
}

class _NewGiftRequestState extends ConsumerState<NewGiftRequest> {
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _arrivalDateController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _memberIdNumberController =
      TextEditingController();

  String? _selectedGift;
  String? _chipType;
  String _remarks = "";
  String? userName = "";
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showGuestData = false;
  bool _isMemberSelected = false;

  String _selectedPrefix = "BM";
  @override
  void initState() {
    super.initState();
    //_loadUserName();
    _loadUserCredentials();
    Future.microtask(() {
      ref.read(giftProvider.notifier).getGiftForList();
    });
  }

  Future<void> _loadUserCredentials() async {
    final name = await StorageUtil.getUserName();

    setState(() {
      userName = name;
    });
  }

  // _loadUserName() async {
  //   final name = await StorageUtil.getUserName();
  //   setState(() {
  //     userName = name;
  //   });
  // }
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _openMemberSearchBottomSheet(int iid) async {
    GuestRepository guestRepository = GuestRepository(
      ApiService(const FlutterSecureStorage()),
    );

    String searchTerm = "";

    if (iid == 8002) {
      searchTerm = _memberIdController.text;
    } else {
      searchTerm = _memberNameController.text;
    }

    if (searchTerm.length < 3) {
      // Show modal with empty results and let user search from within modal
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext context) {
          return MemberNewSearchBottomSheet(
            guests: [], // Empty list initially
            initialSearchTerm: searchTerm,
            searchIid: iid,
            onSearch: (String term, int searchIid) async {
              await _performGuestSearch(term, searchIid);
            },
          );
        },
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<GuestSearchResponse> guests = await guestRepository.searchGuest(
        iid,
        searchTerm,
      );

      setState(() {
        _isLoading = false;
      });

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext context) {
          return MemberNewSearchBottomSheet(
            guests: guests,
            initialSearchTerm: searchTerm,
            searchIid: iid,
            onSearch: (String term, int searchIid) async {
              await _performGuestSearch(term, searchIid);
            },
          );
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _performGuestSearch(String searchTerm, int iid) async {
    if (searchTerm.length < 3) return;

    GuestRepository guestRepository = GuestRepository(
      ApiService(const FlutterSecureStorage()),
    );

    try {
      List<GuestSearchResponse> guests = await guestRepository.searchGuest(
        iid,
        searchTerm,
      );

      // Close current modal
      Navigator.of(context).pop();

      // Open new modal with updated results
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext context) {
          return MemberNewSearchBottomSheet(
            guests: guests,
            initialSearchTerm: searchTerm,
            searchIid: iid,
            onSearch: (String term, int searchIid) async {
              await _performGuestSearch(term, searchIid);
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching guests: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateMemberIdFields(String fullMemberId) {
    if (fullMemberId.isNotEmpty) {
      // Extract prefix and number from full member ID
      String prefix = '';
      String numberPart = '';

      if (fullMemberId.startsWith('BM')) {
        prefix = 'BM';
        numberPart = fullMemberId.substring(2);
      } else if (fullMemberId.startsWith('BL')) {
        prefix = 'BL';
        numberPart = fullMemberId.substring(2);
      } else if (fullMemberId.startsWith('BN')) {
        prefix = 'BN';
        numberPart = fullMemberId.substring(2);
      } else {
        // If no recognized prefix, treat as BM by default
        prefix = 'BM';
        numberPart = fullMemberId;
      }

      setState(() {
        _selectedPrefix = prefix;
        _memberIdNumberController.text = numberPart;
        _memberIdController.text = fullMemberId;
      });
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (date != null) {
      controller.text = "${date.day}/${date.month}/${date.year}";
    }
  }

  final Map<String, String> ratingImageMap = {
    "CLASSIC": "assets/images/ratings/CLASSIC.png",
    "DIAMOND": "assets/images/ratings/DIAMOND.png",
    "GOLD": "assets/images/ratings/GOLD.png",
    "INFINITY": "assets/images/ratings/INFINITY.png",
    "PLATINUM": "assets/images/ratings/PLATINUM.png",
    "SILVER": "assets/images/ratings/SILVER.png",
  };
  String formatNumber(dynamic value) {
    if (value == null) return "";
    final num? number = num.tryParse(value.toString());
    if (number == null) return value.toString(); // return as-is if not numeric
    return NumberFormat.decimalPattern().format(number);
  }

  Future<void> _pickDateTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    final DateTime dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    controller.text =
        "${dateTime.day}/${dateTime.month}/${dateTime.year} ${time.format(context)}";
  }

  TextStyle _inputTextStyle(FontSettings fontSettings) {
    return TextStyle(
      fontSize: fontSettings.fontSize,
      fontWeight: fontSettings.fontWeight,
    );
  }

  TextStyle _inputTextStylefroammount(FontSettings fontSettings) {
    return TextStyle(
      fontSize: fontSettings.fontSize + 3,
      fontWeight: FontWeight.bold,
    );
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
    final newReservation = ref.watch(memberSearchProvider);

    if (newReservation.mid != "" &&
        _memberIdController.text != newReservation.mid) {
      _memberIdController.text = newReservation.mid;
      _memberNameController.text = newReservation.memberName;
      _updateMemberIdFields(newReservation.mid);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isMemberSelected = true;
        });
      });
    }
    if (newReservation.mid == "" && _isMemberSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isMemberSelected = false;
        });
      });
    }

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside of text fields
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Special Gift Request',
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
            ),
          ),
        ),
        body: PopScope(
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            ref.read(newReservationProvider.notifier).resetState();
            ref.read(memberSearchProvider.notifier).resetState();
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 5.0),
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
                          onTap: () =>
                              _pickDateTime(context, _fromDateController),
                        ),
                        const SizedBox(height: 10.0),
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
                          onTap: () =>
                              _pickDateTime(context, _toDateController),
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                keyboardType:
                                    const TextInputType.numberWithOptions(),
                                autofocus: false,
                                controller: _memberIdNumberController,
                                style: _inputTextStyle(fontSettings),
                                decoration: InputDecoration(
                                  labelText: "Member ID *",
                                  labelStyle: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: -5.0,
                                  ),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      right: 4,
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedPrefix,
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: fontSettings.fontWeight,
                                          color: Colors.black,
                                        ),
                                        items: ["BM", "BL", "BN"].map((prefix) {
                                          return DropdownMenuItem(
                                            value: prefix,
                                            child: Text(
                                              prefix,
                                              style: TextStyle(
                                                fontSize: fontSettings.fontSize,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedPrefix = value!;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: () {
                                      _dismissKeyboard();
                                      FocusScope.of(context).unfocus();
                                      _memberIdController.text =
                                          '$_selectedPrefix${_memberIdNumberController.text}';
                                      _openMemberSearchBottomSheet(8002);
                                    },
                                  ),
                                ),

                                onChanged: (value) {
                                  _memberNameController.text = '';

                                  ref
                                      .read(memberSearchProvider.notifier)
                                      .resetState();
                                  setState(() {
                                    _isMemberSelected = false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            ElevatedButton(
                              onPressed: _isMemberSelected
                                  ? () {
                                      // Only navigate when member is selected
                                      context.push('/home/profile');
                                    }
                                  : null, // Disable button when no member selected
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isMemberSelected
                                    ? const Color.fromARGB(255, 70, 70, 70)
                                    : Colors
                                          .grey
                                          .shade300, // Different color when disabled
                                foregroundColor: _isMemberSelected
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 14,
                                ),
                              ),
                              child: Icon(
                                Icons.person_search,
                                size: 25,
                                color: _isMemberSelected
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        TextFormField(
                          autofocus: false,
                          controller: _memberNameController,
                          style: _inputTextStyle(fontSettings),
                          decoration: InputDecoration(
                            labelText: "Member Name *",
                            labelStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: -5.0,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                _dismissKeyboard();
                                FocusScope.of(
                                  context,
                                ).requestFocus(FocusNode());
                                _openMemberSearchBottomSheet(8003);
                              },
                            ),
                          ),
                          onChanged: (value) {
                            _memberIdController.text = '';
                            ref
                                .read(memberSearchProvider.notifier)
                                .resetState();
                            setState(() {
                              _isMemberSelected = false;
                            });
                          },
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
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
                            const SizedBox(width: 12),
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
                        if (_showGuestData) ...[
                          // const SizedBox(height: 20),
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
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  row["Field"].toString(),
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    fontWeight:
                                                        fontSettings.fontWeight,
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
                                                    fontWeight:
                                                        fontSettings.fontWeight,
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
                        ],
                        const SizedBox(height: 10.0),

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
                                onTap: () => _pickDate(
                                  context,
                                  _departureDateController,
                                ),
                              ),
                            ),
                          ],
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),

                            Consumer(
                              builder: (context, ref, child) {
                                final giftState = ref.watch(giftProvider);

                                final uniqueGiftList = {
                                  for (var gift in giftState.giftForList)
                                    gift.code: gift,
                                }.values.toList();

                                final currentValue =
                                    uniqueGiftList.any(
                                      (gift) => gift.code == _selectedGift,
                                    )
                                    ? _selectedGift
                                    : null;

                                return DropdownButtonFormField<String>(
                                  initialValue: currentValue,
                                  items: uniqueGiftList.map((gift) {
                                    return DropdownMenuItem<String>(
                                      value: gift.code,
                                      child: Text(
                                        gift.code.replaceAll("_", ""),
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
                                    labelText: "Gift For *",
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
                                  validator: (v) => v == null || v.isEmpty
                                      ? "Gift required"
                                      : null,
                                );
                              },
                            ),

                            const SizedBox(height: 10),
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
                              initialValue: _chipType,
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

                            TextFormField(
                              controller: _amountController,
                              style: _inputTextStylefroammount(fontSettings),
                              decoration: InputDecoration(
                                labelText: "Amount *",
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
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                ThousandsSeparatorInputFormatter(),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Please enter amount";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 10),
                          ],
                        ),

                        TextFormField(
                          style: _inputTextStyle(fontSettings),
                          decoration: InputDecoration(
                            alignLabelWithHint: true,
                            labelText: "Remarks",
                            labelStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                            hintText: "Enter additional details...",
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
                                          .sendSpecialGiftFromUI(
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
                                            arrivalDate: _arrivalDateController
                                                .text
                                                .trim(),
                                            departureDate:
                                                _departureDateController.text
                                                    .trim(),
                                            giftForCode:
                                                _selectedGift ?? "SPECIAL GIFT",
                                            chipTypeUI:
                                                _chipType ?? "OTP Chips",
                                            amountUI: _amountController.text,
                                            remarks: _remarks,
                                            userName: userName ?? "",
                                          );

                                      setState(() => _isLoading = false);

                                      // print(ok);

                                      if (!mounted) return;
                                      if (ok) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Gift request sent successfully",
                                            ),
                                          ),
                                        );
                                        final giftState = ref.read(
                                          giftProvider,
                                        );
                                        Map<String, dynamic> guestDataMap = {};

                                        if (giftState
                                            .guestGiftData
                                            .isNotEmpty) {
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

                                        final shareOption = await showDialog<String>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: Row(
                                                children: [
                                                  Icon(
                                                    Icons.share,
                                                    color: Colors.blue,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Share Gift Request'),
                                                ],
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Choose how to share the PDF document:',
                                                  ),
                                                  SizedBox(height: 16),
                                                  Container(
                                                    padding: EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.green.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .green
                                                            .shade200,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .check_circle,
                                                              color:
                                                                  Colors.green,
                                                              size: 16,
                                                            ),
                                                            SizedBox(width: 4),
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
                                                        SizedBox(height: 4),
                                                        Text(
                                                          'Share with Apps - PDF automatically attached',
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop('cancel'),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop('system'),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.blue,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                  icon: Icon(Icons.share),
                                                  label: const Text(
                                                    'Share with Apps',
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (shareOption == 'system') {
                                          try {
                                            // Use the direct
                                            final currentGiftState = ref.read(
                                              giftProvider,
                                            );
                                            final returnSerial =
                                                currentGiftState
                                                    .lastReturnSerial;

                                            // Debug print to verify we have the return serial

                                            await DirectWhatsAppPdfService.shareDirectlyToWhatsApp(
                                              memberName: _memberNameController
                                                  .text
                                                  .trim(),
                                              memberId: _memberIdController.text
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
                                              giftFor:
                                                  _selectedGift ??
                                                  "SPECIAL GIFT",
                                              chipType:
                                                  _chipType ?? "OTP Chips",
                                              amount: _amountController.text,
                                              remarks: _remarks,
                                              userName: userName ?? "",
                                              guestData: guestDataMap,
                                              returnSerial: returnSerial ?? "",
                                            );

                                            //     if (mounted) {
                                            //       ScaffoldMessenger.of(
                                            //         context,
                                            //       ).showSnackBar(
                                            //         const SnackBar(
                                            //           content: Text(
                                            //             "PDF ready! Select WhatsApp from the share options.",
                                            //           ),
                                            //           duration: Duration(seconds: 3),
                                            //         ),
                                            //       );
                                            //     }
                                            //   } catch (e) {
                                            //     if (mounted) {
                                            //       ScaffoldMessenger.of(
                                            //         context,
                                            //       ).showSnackBar(
                                            //         SnackBar(
                                            //           content: Text(
                                            //             "Error sharing PDF: $e",
                                            //           ),
                                            //           backgroundColor: Colors.red,
                                            //           duration: Duration(seconds: 4),
                                            //         ),
                                            //       );
                                            //     }
                                            //   }
                                            // }
                                            if (mounted) {
                                              final serialInfo =
                                                  returnSerial != null &&
                                                      returnSerial.isNotEmpty
                                                  ? " (Serial: $returnSerial)"
                                                  : "";
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "PDF ready$serialInfo! Select WhatsApp from the share options.",
                                                  ),
                                                  duration: Duration(
                                                    seconds: 3,
                                                  ),
                                                ),
                                              );
                                            }

                                            // Clear the API response data after using it
                                            ref
                                                .read(giftProvider.notifier)
                                                .clearLastApiResponse();
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "Error sharing PDF: $e",
                                                  ),
                                                  backgroundColor: Colors.red,
                                                  duration: Duration(
                                                    seconds: 4,
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                        // Reset providers
                                        ref
                                            .read(memberSearchProvider.notifier)
                                            .resetState();
                                        ref
                                            .read(
                                              newReservationProvider.notifier,
                                            )
                                            .resetState();

                                        // Navigate back and return success result
                                        Navigator.of(context).pop(
                                          true,
                                        ); // Pass true to indicate success
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Failed to send gift request",
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setState(() => _isLoading = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                                  ? Constants.kSecondaryColor
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
                                const Icon(Icons.done, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  "Send Request",
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
              // const Watermark(),
            ],
          ),
        ),
      ),
    );
  }
}
