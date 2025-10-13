import 'package:ballys_reservation_app/components/watermark.dart';

import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/member_search_provider.dart';
import 'package:ballys_reservation_app/providers/new_reservation_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
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

class ViewSpecificGiftRequest extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;
  final SpecialGiftRequest? gift;
  final bool isPending;
  const ViewSpecificGiftRequest({
    super.key,
    required this.giftsRepository,
    this.gift,
    this.isPending = false,
  });

  @override
  ConsumerState<ViewSpecificGiftRequest> createState() =>
      _NewGiftRequestState();
}

class _NewGiftRequestState extends ConsumerState<ViewSpecificGiftRequest> {
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _arrivalDateController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _chipController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  //final TextEditingController _giftForController = TextEditingController();
  String? _selectedGift;
  String? _chipType;
  String _remarks = "";
  String? userName = "";
  double drop = 0.0;
  double cashout = 0.0;
  double res = 0.0;
  double actdrop = 0.0;
  double mcoupen = 0.0;
  double paidcom = 0.0;
  double gpoints = 0.0;
  double gflushcoupen = 0.0;
  double tcoupon = 0.0;
  double flushactdrop = 0.0;
  double avgbet = 0.0;

  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final bool _showGuestData = false;
  bool _isEditable = false;

  @override
  @override
  void initState() {
    super.initState();
    _loadUserCredentials();

    if (widget.gift != null) {
      final g = widget.gift!;
      print(" Prefilling with: $g");

      _memberIdController.text = g.mid ?? "";
      _memberNameController.text = g.mname ?? "";
      _fromDateController.text = _formatDateandTime(g.dateFrom) ?? "";
      _toDateController.text = _formatDateandTime(g.dateTo);
      _arrivalDateController.text = _formatDate(g.arrDate);
      _departureDateController.text = _formatDate(g.dptDate);
      _selectedGift = g.cashierPayType ?? "";
      _chipController.text = g.chipType.replaceAll("_", " ");
      _amountController.text = g.giftDesc.toString() ?? "";
      _remarksController.text = g.giftCategory ?? "";
      drop = g.mdrop;
      cashout = g.cashout;
      res = g.res;
      actdrop = g.actDrop;
      mcoupen = g.mCoupon;
      paidcom = g.paidComm;
      gpoints = g.gPoints;
      gflushcoupen = g.flushCoupon;
      tcoupon = g.mCoupon + g.flushCoupon;
      flushactdrop = g.flushActDrop;
      avgbet = g.avebet;
    } else {
      print(" Gift is null inside ViewSpecificGiftRequest");
    }

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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return dateString;
    }
  }

  String _formatDateandTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm a').format(date);
    } catch (_) {
      return dateString;
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

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final newReservation = ref.watch(memberSearchProvider);

    if (newReservation.mid != "" &&
        _memberIdController.text != newReservation.mid) {
      _memberIdController.text = newReservation.mid;
      _memberNameController.text = newReservation.memberName;
    }

    return Scaffold(
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
                        controller: (_fromDateController),
                        readOnly: true,

                        style: _inputTextStyle(fontSettings),
                        decoration: InputDecoration(
                          labelText: "From Date & Time",
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
                      ),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _toDateController,
                        readOnly: true,
                        style: _inputTextStyle(fontSettings),
                        decoration: InputDecoration(
                          labelText: "To Date & Time",
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
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              keyboardType:
                                  const TextInputType.numberWithOptions(),
                              autofocus: false,
                              readOnly: true,
                              controller: _memberIdController,
                              style: _inputTextStyle(fontSettings),
                              decoration: InputDecoration(
                                labelText: "Member ID",
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
                              onChanged: (value) {
                                _memberNameController.text = '';
                                ref
                                    .read(memberSearchProvider.notifier)
                                    .resetState();
                              },
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black, // Black background
                              foregroundColor: Colors.white, // White text/icon
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    try {
                                      setState(() {
                                        _isLoading = true;
                                      });

                                      GuestRepository guestRepository =
                                          GuestRepository(
                                            ApiService(
                                              const FlutterSecureStorage(),
                                            ),
                                          );

                                      // Search for guest by MID
                                      List<GuestSearchResponse> guests =
                                          await guestRepository.searchGuest(
                                            9021,
                                            _memberIdController.text,
                                          );

                                      setState(() {
                                        _isLoading = false;
                                      });

                                      if (guests.isNotEmpty) {
                                        final guestResponse = guests.first;
                                        ref
                                            .read(
                                              selectedGuestProvider.notifier,
                                            )
                                            .setSelectedGuest(
                                              Guest(
                                                mid:
                                                    guestResponse.mid ??
                                                    _memberIdController.text,
                                                memberName:
                                                    guestResponse.mName ??
                                                    _memberNameController.text,
                                                country: "",
                                                lastVisitDate:
                                                    guestResponse.lvd
                                                        ?.toString() ??
                                                    "",
                                                gift: "",
                                                age: 0,
                                                gRating:
                                                    guestResponse.gRating ?? "",
                                                mGroup: "",
                                                gName:
                                                    guestResponse.gName ?? "",
                                              ),
                                            );
                                        context.push('/home/profile');
                                      } else {
                                        // fallback guest
                                        ref
                                            .read(
                                              selectedGuestProvider.notifier,
                                            )
                                            .setSelectedGuest(
                                              Guest(
                                                mid: _memberIdController.text,
                                                memberName:
                                                    _memberNameController.text,
                                                country: "",
                                                lastVisitDate: "1990-01-01",
                                                gift: "",
                                                age: 0,
                                                gRating: "",
                                                mGroup: "",
                                                gName: "",
                                              ),
                                            );
                                        context.push('/home/profile');
                                      }
                                    } catch (e) {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                      print("Error searching guest: $e");
                                    }
                                  },
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.person_search, size: 25),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16.0),
                      TextFormField(
                        autofocus: false,
                        readOnly: true,
                        controller: _memberNameController,
                        style: _inputTextStyle(fontSettings),
                        decoration: InputDecoration(
                          labelText: "Member Name",
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
                        onChanged: (value) {
                          _memberIdController.text = '';
                          ref.read(memberSearchProvider.notifier).resetState();
                        },
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final memberId = _memberIdController.text
                                    .trim();

                                if (memberId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Please enter a Member ID"),
                                    ),
                                  );
                                  return;
                                }

                                // Navigate to PrvGift page with MID as parameter
                                context.push(
                                  '/gifts/special-gift-requests/prv-gifts/$memberId',
                                );
                              },
                              icon: const Icon(Icons.card_giftcard),
                              label: Text(
                                "PrvGift",
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
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

                      // const SizedBox(height: 16.0),

                      // Replace the _showGuestData block with this:
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final giftState = ref.watch(giftProvider);

                          final rows = [
                            {"Field": "Drop (Est)", "Value": drop},
                            {"Field": "Cash Out (Est)", "Value": cashout},
                            {"Field": "Result (Est)", "Value": res},
                            {"Field": "Actual Drop (Est)", "Value": actdrop},
                            {"Field": "Coupons (Est)", "Value": mcoupen},
                            {
                              "Field": "Commission Paid (Est)",
                              "Value": paidcom,
                            },
                            {"Field": "Points (Est)", "Value": gpoints},
                            {
                              "Field": "Flush Coupon (Est)",
                              "Value": gflushcoupen,
                            },
                            {"Field": "Total Coupon (Est)", "Value": tcoupon},
                            {
                              "Field": "Flush Actual Drop (Est)",
                              "Value": flushactdrop,
                            },
                            {"Field": "Avg Bet (Est)", "Value": avgbet},
                          ];

                          return Container(
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DataTable(
                              dataRowMinHeight:
                                  48,
                              dataRowMaxHeight: 56,
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
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Value",
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
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
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          formatNumber(row["Value"]),
                                          style: TextStyle(
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16.0),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _arrivalDateController,
                              readOnly: true,
                              style: _inputTextStyle(fontSettings),
                              decoration: InputDecoration(
                                labelText: "Arrival Date",
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
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _departureDateController,
                              readOnly: true,
                              style: _inputTextStyle(fontSettings),
                              decoration: InputDecoration(
                                labelText: "Departure Date",
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
                            ),
                          ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),

                          TextFormField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: _selectedGift?.replaceAll("_", ""),
                            ),
                            decoration: InputDecoration(
                              labelText: "Gift For",
                              labelStyle: TextStyle(
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: -5.0,
                              ),
                            ),
                            style: _inputTextStyle(fontSettings),
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _chipController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: "Chip Type ",
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

                            inputFormatters: <TextInputFormatter>[],
                            style: _inputTextStyle(fontSettings),
                          ),
                          if (widget.isPending)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Amount & Remarks",
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize + 2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    setState(() {
                                      _isEditable =
                                          !_isEditable; // toggle edit mode
                                    });
                                  },
                                ),
                              ],
                            ),
                          const SizedBox(height: 16.0),

                          TextFormField(
                            controller: _amountController,
                            readOnly: !_isEditable,
                            style: _inputTextStylefroammount(fontSettings),
                            decoration: InputDecoration(
                              labelText: "Amount",
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

                          const SizedBox(height: 16),
                        ],
                      ),

                      TextFormField(
                        controller: _remarksController,
                        readOnly: !_isEditable,
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
                      if (widget.isPending)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (widget.gift == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Gift request not found"),
                                      ),
                                    );
                                    return;
                                  }

                                  final reqid = widget.gift!.idNo;
                                  final remarks = _remarksController.text;
                                  final amount = _amountController.text;
                                  final uname = userName ?? "";

                                  setState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    final success = await ref
                                        .read(giftProvider.notifier)
                                        .sendApprovedSpecialGiftFromUI(
                                          reqid: reqid,
                                          remarks: remarks,
                                          amount: amount,
                                          userName: uname,
                                        );

                                    if (success) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Request Approved Successfully ",
                                          ),
                                        ),
                                      );
                                      Navigator.of(context).pop(true);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Approval Failed "),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: $e")),
                                    );
                                  } finally {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.check),
                                label: const Text("APPROVE"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (widget.gift == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Gift request not found"),
                                      ),
                                    );
                                    return;
                                  }

                                  final reqid = widget.gift!.idNo;

                                  final uname = userName ?? "";

                                  setState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    final success = await ref
                                        .read(giftProvider.notifier)
                                        .rejectSpecialGiftFromUI(
                                          reqid: reqid,
                                          userName: uname,
                                        );

                                    if (success) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Request Reject Successfully ",
                                          ),
                                        ),
                                      );
                                      Navigator.of(context).pop(true);
                                      // go back after approval
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Reject Failed "),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: $e")),
                                    );
                                  } finally {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.close),
                                label: const Text("REJECT"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
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
                    ],
                  ),
                ),
              ),
            ),

            const Watermark(),
          ],
        ),
      ),
    );
  }
}