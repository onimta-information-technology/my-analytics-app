import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
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
import 'package:ballys_reservation_app/providers/birthday_gift_provider.dart';
import 'package:ballys_reservation_app/utils/formatter.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class ViewSpecificGiftRequest extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;
  final SpecialGiftRequest? gift;
  final bool isPending;
  final bool isApproved;
  final bool isChecked;
  const ViewSpecificGiftRequest({
    super.key,
    required this.giftsRepository,
    this.gift,
    this.isPending = false,
    this.isApproved = false,
    this.isChecked = false,
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
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _whatsappNumberController =
      TextEditingController();

  String? _selectedGift;
  String? _chipType;
  String _remarks = "";
  String? userName = "";
  bool _hasGiftAppPermission = false;
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
  int? _selectedValidDays;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final bool _showGuestData = false;
  bool _isEditable = false;

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    _checkGiftAppPermission();

    if (widget.gift != null) {
      final g = widget.gift!;
      _memberIdController.text = g.mid ?? "";
      _memberNameController.text = g.mname ?? "";
      _fromDateController.text = _formatDateandTime(g.dateFrom) ?? "";
      _toDateController.text = _formatDateandTime(g.dateTo);
      _arrivalDateController.text = _formatDate(g.arrDate);
      _departureDateController.text = _formatDate(g.dptDate);
      _selectedGift = g.cashierPayType ?? "";
      _chipController.text = g.chipType.replaceAll("_", " ");
      _amountController.text = formatNumber(g.giftDesc.toString()) ?? "";
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

      // ── Pre-fill valid days from the gift's validDates field ──────────────
      if (g.validDates != null && g.validDates!.isNotEmpty) {
        final parsed = int.tryParse(g.validDates!);
        if (parsed == 30 || parsed == 60 || parsed == 90) {
          _selectedValidDays = parsed;
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadGuestDataForCard();
        _loadWhatsAppNumber();
      });
    }

    Future.microtask(() {
      ref.read(giftProvider.notifier).getGiftForList();
    });
  }

  @override
  void dispose() {
    _memberIdController.dispose();
    _memberNameController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _arrivalDateController.dispose();
    _departureDateController.dispose();
    _chipController.dispose();
    _remarksController.dispose();
    _amountController.dispose();
    _whatsappNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadWhatsAppNumber() async {
    if (_memberIdController.text.isEmpty) return;
    try {
      await ref.read(birthdayGiftProvider.notifier).fetchGiftData(
            _memberIdController.text,
          );
      final giftState = ref.read(birthdayGiftProvider);
      if (giftState.giftData != null &&
          giftState.giftData!.mobile.isNotEmpty) {
        setState(() {
          _whatsappNumberController.text = giftState.giftData!.mobile;
        });
      }
    } catch (e) {
      print('Error loading WhatsApp number: $e');
    }
  }

  Future<void> _checkGiftAppPermission() async {
    final giftApp = await StorageUtil.getGiftApp();
    setState(() {
      _hasGiftAppPermission = giftApp ?? false;
    });
  }

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                      color: Colors.red.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.lock_outline,
                      size: 50, color: Colors.red.shade400),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Access Denied",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text("Got It",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadGuestDataForCard() async {
    if (_memberIdController.text.isEmpty) return;
    try {
      setState(() => _isLoading = true);
      GuestRepository guestRepository =
          GuestRepository(ApiService(const FlutterSecureStorage()));
      List<GuestSearchResponse> guests =
          await guestRepository.searchGuest(9021, _memberIdController.text);
      if (guests.isNotEmpty) {
        final guestResponse = guests.first;
        ref.read(selectedGuestProvider.notifier).setSelectedGuest(
              Guest(
                mid: guestResponse.mid ?? _memberIdController.text,
                memberName:
                    guestResponse.mName ?? _memberNameController.text,
                country: "",
                lastVisitDate: guestResponse.lvd?.toString() ?? "",
                age: 0,
                gRating: guestResponse.gRating ?? "",
                mGroup: guestResponse.mGroup,
                gName: guestResponse.gName ?? "",
                memImage2: guestResponse.memImage2,
              ),
            );
      }
      setState(() => _isLoading = false);
    } catch (e) {
      print("Error loading guest data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserCredentials() async {
    final name = await StorageUtil.getUserName();
    setState(() => userName = name);
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
    if (number == null) return value.toString();
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
    final TimeOfDay? time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    final DateTime dateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    controller.text =
        "${dateTime.day}/${dateTime.month}/${dateTime.year} ${time.format(context)}";
  }

  TextStyle _inputTextStyle(FontSettings fontSettings) => TextStyle(
        fontSize: fontSettings.fontSize+2,
        fontWeight: fontSettings.fontWeight,
      );

  TextStyle _inputTextStylefroammount(FontSettings fontSettings) => TextStyle(
        fontSize: fontSettings.fontSize + 5,
        fontWeight:  fontSettings.fontWeight,
      );

  // ─── Valid-days dropdown (editable) ─────────────────────────────────────────
  Widget _buildValidDaysDropdown(FontSettings fontSettings) {
    return DropdownButtonFormField<int>(
      value: _selectedValidDays,
      style: TextStyle(
        fontSize: fontSettings.fontSize + 2,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        labelText: "Valid Days",
        labelStyle: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(
            value: 30,
            child:
                Text("30 Days", style: TextStyle(fontWeight: FontWeight.bold))),
        DropdownMenuItem(
            value: 60,
            child:
                Text("60 Days", style: TextStyle(fontWeight: FontWeight.bold))),
        DropdownMenuItem(
            value: 90,
            child:
                Text("90 Days", style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      onChanged: (value) => setState(() => _selectedValidDays = value),
      validator: (value) =>
          value == null ? "Please select valid days" : null,
    );
  }

  // ─── Valid-days read-only display (Approved / Rejected tabs) ─────────────────
  Widget _buildValidDaysReadOnly(FontSettings fontSettings) {
    final validDates = widget.gift?.validDates;
    if (validDates == null || validDates.isEmpty) return const SizedBox.shrink();
    return TextFormField(
      readOnly: true,
      initialValue: '$validDates days',
      decoration: InputDecoration(
        labelText: "Valid Days",
        labelStyle: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIcon:
            const Icon(Icons.calendar_today, color: Colors.deepPurple),
      ),
      style: TextStyle(
        fontSize: fontSettings.fontSize + 2,
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple,
      ),
    );
  }

  // ─── Reverse button (Approved & Rejected only) ────────────────────────────────
  Widget _buildReverseButton(FontSettings fontSettings, bool isRejected) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton.icon(
        onPressed: () async {
          if (!_hasGiftAppPermission) {
            _showAccessDeniedDialog();
            return;
          }
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Reverse Gift'),
              content: const Text(
                  'Are you sure you want to reverse this gift?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: const Text('Reverse'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          setState(() => _isLoading = true);
          try {
            final success = isRejected
                ? await ref
                    .read(giftProvider.notifier)
                    .reverseSpecialGiftFromUIrejcted(
                      reqid: widget.gift!.idNo,
                      userName: userName ?? "",
                    )
                : await ref
                    .read(giftProvider.notifier)
                    .reverseSpecialGiftFromUI(
                      reqid: widget.gift!.idNo,
                      userName: userName ?? "",
                    );
            setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(success
                  ? 'Gift reversed successfully'
                  : 'Failed to reverse gift'),
              backgroundColor: success ? Colors.green : Colors.red,
            ));
            if (success) Navigator.of(context).pop(true);
          } catch (e) {
            setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
          }
        },
        icon: const Icon(Icons.undo, size: 20),
        label: Text('Reverse Gift',
            style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
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

    final bool showPendingButtons = widget.isPending;
    final bool showCheckedButtons = widget.isChecked;
    final bool showApprovedSection = widget.isApproved;
    final bool showRejectedReverse =
        !widget.isApproved && !widget.isPending && !widget.isChecked;

    final bool canEditFields = widget.isPending || widget.isChecked || _isEditable;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
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
                      // ── Reverse button: Approved tab ──────────────────────
                      if (showApprovedSection)
                        _buildReverseButton(fontSettings, false),

                      // ── Reverse button: Rejected tab ──────────────────────
                      if (showRejectedReverse)
                        _buildReverseButton(fontSettings, true),

                      // ── NO reverse button for Checked tab ─────────────────

                      const SizedBox(height: 5.0),
                      TextFormField(
                        controller: _fromDateController,
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
                              horizontal: 12.0, vertical: -5.0),
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
                              horizontal: 12.0, vertical: -5.0),
                        ),
                      ),
                      const SizedBox(height: 5.0),

                      GuestDisplayCardSpecialGiftview(
                        memberIdText: _memberIdController.text,
                        memberNameText: _memberNameController.text,
                        showCard: _memberIdController.text.isNotEmpty &&
                            _memberNameController.text.isNotEmpty,
                        isLoading: _isLoading,
                        showLastVisitDate: true,
                      ),
                      const SizedBox(height: 16.0),

                      Row(
                        children: [
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
                                      GuestRepository guestRepository =
                                          GuestRepository(ApiService(
                                              const FlutterSecureStorage()));
                                      List<GuestSearchResponse> guests =
                                          await guestRepository.searchGuest(
                                              9021, _memberIdController.text);
                                      setState(() => _isLoading = false);
                                      if (guests.isNotEmpty) {
                                        final guestResponse = guests.first;
                                        ref
                                            .read(
                                                selectedGuestProvider.notifier)
                                            .setSelectedGuest(Guest(
                                              mid: guestResponse.mid ??
                                                  _memberIdController.text,
                                              memberName: guestResponse.mName ??
                                                  _memberNameController.text,
                                              country: "",
                                              lastVisitDate:
                                                  guestResponse.lvd?.toString() ??
                                                      "",
                                              age: 0,
                                              gRating:
                                                  guestResponse.gRating ?? "",
                                              mGroup: guestResponse.mGroup,
                                              gName: guestResponse.gName ?? "",
                                              memImage2: guestResponse.memImage2,
                                            ));
                                        context.push('/home/profile');
                                      } else {
                                        ref
                                            .read(
                                                selectedGuestProvider.notifier)
                                            .setSelectedGuest(Guest(
                                              mid: _memberIdController.text,
                                              memberName:
                                                  _memberNameController.text,
                                              country: "",
                                              lastVisitDate: "1990-01-01",
                                              age: 0,
                                              gRating: "",
                                              mGroup: "",
                                              gName: "",
                                            ));
                                        context.push('/home/profile');
                                      }
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
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final memberId =
                                    _memberIdController.text.trim();
                                if (memberId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Please enter a Member ID")),
                                  );
                                  return;
                                }
                                context.push(
                                    '/gifts/special-gift-requests/prv-gifts/$memberId', extra: {'iid': 88940});
                              },
                              icon: const Icon(Icons.card_giftcard),
                              label: Text("Pending Gift",
                                  style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                           const SizedBox(width: 5),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final memberId =
                                    _memberIdController.text.trim();
                                if (memberId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Please enter a Member ID")),
                                  );
                                  return;
                                }
                                context.push(
                                    '/gifts/special-gift-requests/prv-gifts/$memberId', extra: {'iid': 8888},);
                                    
                              },
                              icon: const Icon(Icons.card_giftcard),
                              label: Text("Issued Gift",
                                  style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          "Guest Gift Data",
                          style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final rows = [
                            {"Field": "Drop (Est)", "Value": drop},
                            {"Field": "Cash Out (Est)", "Value": cashout},
                            {"Field": "Result (Est)", "Value": res},
                            {"Field": "Actual Drop (Est)", "Value": actdrop},
                            {"Field": "Coupons (Est)", "Value": mcoupen},
                            {"Field": "Commission Paid (Est)", "Value": paidcom},
                            {"Field": "Points (Est)", "Value": gpoints},
                            {"Field": "Flush Coupon (Est)", "Value": gflushcoupen},
                            {"Field": "Total Coupon (Est)", "Value": tcoupon},
                            {"Field": "Flush Actual Drop (Est)", "Value": flushactdrop},
                            {"Field": "Avg Bet (Est)", "Value": avgbet},
                          ];
                          return Container(
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DataTable(
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              headingRowColor: WidgetStateProperty.all(
                                  Colors.amber.shade100),
                              border:
                                  TableBorder.all(color: Colors.grey.shade300),
                              columns: [
                                DataColumn(
                                    label: Text("Field",
                                        style: TextStyle(
                                            fontSize: fontSettings.fontSize,
                                            fontWeight:
                                                fontSettings.fontWeight))),
                                DataColumn(
                                    label: Text("Value",
                                        style: TextStyle(
                                            fontSize: fontSettings.fontSize,
                                            fontWeight:
                                                fontSettings.fontWeight))),
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
                                      child: Text(row["Field"].toString(),
                                          style: TextStyle(
                                              fontSize: fontSettings.fontSize+2,
                                              fontWeight: shouldHighlight
                                                  ? FontWeight.bold
                                                  : fontSettings.fontWeight)),
                                    )),
                                    DataCell(Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                          formatNumber(row["Value"]),
                                          style: TextStyle(
                                              fontSize: fontSettings.fontSize+2,
                                              fontWeight: shouldHighlight
                                                  ? fontSettings.fontWeight
                                                  : fontSettings.fontWeight,
                                              fontFamily: 'monospace',
                                              fontFeatures: const [
                                                FontFeature.tabularFigures()
                                              ])),
                                    )),
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
                                    fontSize: fontSettings.fontSize+1,
                                    fontWeight: fontSettings.fontWeight),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: -5.0),
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
                                    fontWeight: fontSettings.fontWeight),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: -5.0),
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
                                text: _selectedGift?.replaceAll("_", "")),
                            decoration: InputDecoration(
                              labelText: "Gift For",
                              labelStyle: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: -5.0),
                            ),
                            style: _inputTextStyle(fontSettings),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _chipController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: "Chip Type",
                              labelStyle: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: -5.0),
                            ),
                            style: _inputTextStyle(fontSettings),
                          ),
// ── Checked By & Check Date Card ──────────────────────────────────────────
if (!widget.isPending &&
    widget.gift != null &&
    widget.gift!.checkApp != null &&
    widget.gift!.checkApp!.isNotEmpty) ...[
  const SizedBox(height: 16),
  Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color.fromARGB(255, 92, 17, 255).withOpacity(0.08),
          const Color.fromARGB(255, 92, 17, 255).withOpacity(0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color.fromARGB(255, 92, 17, 255).withOpacity(0.4),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 92, 17, 255).withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 92, 17, 255),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.rule_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Checked Information",
                style: TextStyle(
                  fontSize: fontSettings.fontSize + 2,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 92, 17, 255),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(
            color: Color.fromARGB(80, 92, 17, 255),
            height: 1,
          ),
          const SizedBox(height: 12),

          // ── Checked By Row ───────────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                color: Color.fromARGB(255, 92, 17, 255),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "Checked By:",
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                   color: Color.fromARGB(255, 0, 0, 0)
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.gift!.checkApp!,
                  style: TextStyle(
                    fontSize: fontSettings.fontSize + 1,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 92, 17, 255),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Check Date Row ───────────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.schedule,
                color: Color.fromARGB(255, 92, 17, 255),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "Check Date:",
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                  color: Color.fromARGB(255, 0, 0, 0)           ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.gift!.checkAppByTime != null &&
                          widget.gift!.checkAppByTime!.isNotEmpty
                      ? _formatDateandTime(widget.gift!.checkAppByTime)
                      : 'N/A',
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 92, 17, 255),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
],
                          // ── Edit toggle: Pending tab ────────────────────────
                          if (widget.isPending)
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Amount & Remarks",
                                  style: TextStyle(
                                      fontSize: fontSettings.fontSize + 2,
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => setState(
                                      () => _isEditable = !_isEditable),
                                ),
                              ],
                            ),

                          // ── Edit toggle: Checked tab ────────────────────────
                          if (widget.isChecked)
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Amount & Remarks",
                                  style: TextStyle(
                                      fontSize: fontSettings.fontSize + 2,
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => setState(
                                      () => _isEditable = !_isEditable),
                                ),
                              ],
                            ),

                          const SizedBox(height: 16.0),
                          TextFormField(
                            controller: _amountController,
                            readOnly: !canEditFields,
                            style: _inputTextStylefroammount(fontSettings),
                            decoration: InputDecoration(
                              labelText: "Amount",
                              labelStyle: TextStyle(
                                  fontSize: fontSettings.fontSize + 2,
                                  fontWeight: fontSettings.fontWeight),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: -5.0),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              ThousandsSeparatorInputFormatter()
                            ],
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? "Please enter amount"
                                    : null,
                          ),
                        ],
                      ),

                      // ── Valid Days: editable dropdown (Pending & Checked tabs) ──
                      if (widget.isPending || widget.isChecked) ...[
                        const SizedBox(height: 16),
                        _buildValidDaysDropdown(fontSettings),
                      ],

                      // ── Valid Days: read-only display (Approved & Rejected tabs) ──
                      if (!widget.isPending && !widget.isChecked) ...[
                        const SizedBox(height: 16),
                        _buildValidDaysReadOnly(fontSettings),
                      ],

                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarksController,
                        readOnly: !canEditFields,
                        style: _inputTextStyle(fontSettings),
                        decoration: InputDecoration(
                          alignLabelWithHint: true,
                          labelText: "Remarks",
                          labelStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight),
                          hintText: "Enter additional details...",
                          hintStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                        ),
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        onChanged: (value) => _remarks = value,
                      ),
                      const SizedBox(height: 16.0),

                      // ════════════════════════════════════════════════════════
                      // PENDING TAB: "Check By" + "Reject" buttons
                      // ════════════════════════════════════════════════════════
                      if (showPendingButtons)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // CHECK BY button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (!_hasGiftAppPermission) {
                                    _showAccessDeniedDialog();
                                    return;
                                  }
                                  if (widget.gift == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Gift request not found")),
                                    );
                                    return;
                                  }
                                  if (_selectedValidDays == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text("Please select valid days"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  final reqid = widget.gift!.idNo;
                                  final remarks = _remarksController.text;
                                  final amount = _amountController.text;
                                  final uname = userName ?? "";

                                  setState(() => _isLoading = true);
                                  try {
                                    final success = await ref
                                        .read(giftProvider.notifier)
                                        .checkBySpecialGiftFromUI(
                                          reqid: reqid,
                                          remarks: remarks,
                                          amount: amount,
                                          userName: uname,
                                          validDates:
                                              _selectedValidDays.toString(),
                                        );
                                    if (success) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text(
                                            "Request Checked Successfully"),
                                        backgroundColor: Colors.blue,
                                      ));
                                      Navigator.of(context).pop(true);
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text("Check By Failed"),
                                        backgroundColor: Colors.red,
                                      ));
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text("Error: $e")));
                                  } finally {
                                    setState(() => _isLoading = false);
                                  }
                                },
                                icon: const Icon(Icons.rule_rounded),
                                label: const Text("CHECK BY"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // REJECT button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (!_hasGiftAppPermission) {
                                    _showAccessDeniedDialog();
                                    return;
                                  }
                                  if (widget.gift == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Gift request not found")),
                                    );
                                    return;
                                  }
                                  final reqid = widget.gift!.idNo;
                                  final uname = userName ?? "";
                                  setState(() => _isLoading = true);
                                  try {
                                    final success = await ref
                                        .read(giftProvider.notifier)
                                        .rejectSpecialGiftFromUI(
                                          reqid: reqid,
                                          userName: uname,
                                        );
                                    if (success) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text(
                                            "Request Rejected Successfully"),
                                        backgroundColor: Colors.red,
                                      ));
                                      await ref
                                          .read(giftProvider.notifier)
                                          .getGiftForList();
                                      Navigator.of(context).pop(true);
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text("Reject Failed")));
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text("Error: $e")));
                                  } finally {
                                    setState(() => _isLoading = false);
                                  }
                                },
                                icon: const Icon(Icons.close),
                                label: const Text("REJECT"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),

                      // ════════════════════════════════════════════════════════
                      // CHECKED TAB: "Approve" + "Reject" buttons
                      // ════════════════════════════════════════════════════════
                      if (showCheckedButtons)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // APPROVE button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (!_hasGiftAppPermission) {
                                    _showAccessDeniedDialog();
                                    return;
                                  }
                                  if (widget.gift == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Gift request not found")),
                                    );
                                    return;
                                  }
                                  if (_selectedValidDays == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text("Please select valid days"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  final reqid = widget.gift!.idNo;
                                  final remarks = _remarksController.text;
                                  final amount = _amountController.text;
                                  final uname = userName ?? "";

                                  setState(() => _isLoading = true);
                                  try {
                                    final success = await ref
                                        .read(giftProvider.notifier)
                                        .sendApprovedSpecialGiftFromUI(
                                          reqid: reqid,
                                          remarks: remarks,
                                          amount: amount,
                                          userName: uname,
                                          validDates:
                                              _selectedValidDays.toString(),
                                        );
                                    if (success) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text(
                                            "Request Approved Successfully"),
                                        backgroundColor: Colors.green,
                                      ));
                                      Navigator.of(context).pop(true);
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text("Approval Failed")));
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text("Error: $e")));
                                  } finally {
                                    setState(() => _isLoading = false);
                                  }
                                },
                                icon: const Icon(Icons.check),
                                label: const Text("APPROVE"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // REJECT button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (!_hasGiftAppPermission) {
                                    _showAccessDeniedDialog();
                                    return;
                                  }
                                  if (widget.gift == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Gift request not found")),
                                    );
                                    return;
                                  }
                                  final reqid = widget.gift!.idNo;
                                  final uname = userName ?? "";
                                  setState(() => _isLoading = true);
                                  try {
                                    final success = await ref
                                        .read(giftProvider.notifier)
                                        .rejectSpecialGiftFromUI(
                                          reqid: reqid,
                                          userName: uname,
                                        );
                                    if (success) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text(
                                            "Request Rejected Successfully"),
                                        backgroundColor: Colors.red,
                                      ));
                                      await ref
                                          .read(giftProvider.notifier)
                                          .getGiftForList();
                                      Navigator.of(context).pop(true);
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text("Reject Failed")));
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text("Error: $e")));
                                  } finally {
                                    setState(() => _isLoading = false);
                                  }
                                },
                                icon: const Icon(Icons.close),
                                label: const Text("REJECT"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),

                      // ════════════════════════════════════════════════════════
                      // APPROVED TAB: WhatsApp section
                      // ════════════════════════════════════════════════════════
                      if (showApprovedSection)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Container(
                              color: Colors.green[10],
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Send Gift Details via WhatsApp",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.refresh,
                                            color: Colors.green),
                                        onPressed: () async {
                                          await _loadWhatsAppNumber();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content: Text(
                                                'WhatsApp number refreshed'),
                                            duration:
                                                Duration(seconds: 1),
                                          ));
                                        },
                                        tooltip: 'Refresh WhatsApp Number',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.green.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.card_giftcard,
                                            color: Colors.green, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Amount: ${_amountController.text}",
                                            style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _whatsappNumberController,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Colors.green, width: 2.0),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Colors.green, width: 2.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Colors.green, width: 2.5),
                                      ),
                                      labelText: "WhatsApp Number",
                                      hintText:
                                          "Enter WhatsApp number with country code",
                                      helperText: "e.g., 94712345678",
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Image.asset(
                                          'assets/images/others/whatsapp.png',
                                          width: 24,
                                          height: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Note: Please enter the WhatsApp number with the country code",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color.fromARGB(255, 0, 0, 0),
                                        fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final whatsappNumber =
                                            _whatsappNumberController.text
                                                .trim();
                                        if (whatsappNumber.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content: Text(
                                                'Please enter a WhatsApp number'),
                                            backgroundColor: Colors.red,
                                          ));
                                          return;
                                        }
                                        if (widget.gift == null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content: Text(
                                                'Gift details not available'),
                                            backgroundColor: Colors.red,
                                          ));
                                          return;
                                        }
                                        try {
                                          EasyLoading.show(
                                              status:
                                                  'Sending gift details...');
                                          final cleanAmount =
                                              _amountController.text
                                                  .replaceAll(',', '')
                                                  .trim();
                                          final chipType = _chipController
                                              .text
                                              .replaceAll(' ', '')
                                              .toUpperCase();
                                          final giftFor = _selectedGift
                                                  ?.replaceAll('_', ' ') ??
                                              'SPECIAL GIFT';
                                          final result = await ref
                                              .read(giftProvider.notifier)
                                              .sendSpecialGiftWhatsapp(
                                                whatsappNumber:
                                                    whatsappNumber,
                                                bmNumber:
                                                    _memberIdController.text,
                                                memberName:
                                                    _memberNameController
                                                        .text,
                                                giftValue: cleanAmount,
                                                chipType: chipType,
                                                giftFor: giftFor,
                                                createdBy: userName ?? '',
                                              );
                                          EasyLoading.dismiss();
                                          if (result == "Success") {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Gift details sent successfully via WhatsApp!'),
                                              backgroundColor: Colors.green,
                                              duration:
                                                  Duration(seconds: 3),
                                            ));
                                          } else if (result ==
                                              "WhatsApp not available") {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'WhatsApp is not installed or available on this device'),
                                              backgroundColor: Colors.orange,
                                              duration:
                                                  Duration(seconds: 3),
                                            ));
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  'Failed to send: $result'),
                                              backgroundColor: Colors.orange,
                                              duration:
                                                  const Duration(seconds: 3),
                                            ));
                                          }
                                        } catch (e) {
                                          EasyLoading.dismiss();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                            duration:
                                                const Duration(seconds: 3),
                                          ));
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16, horizontal: 16),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/images/others/whatsapp.png',
                                            width: 24,
                                            height: 24,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 12),
                                          const Flexible(
                                            child: Text(
                                              "Send Gift Details via WhatsApp",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight:
                                                      FontWeight.bold),
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
                    ],
                  ),
                ),
              ),
            ),
            // if (_isLoading)
            //   Positioned.fill(
            //     child: Container(
            //       color: const Color.fromARGB(135, 117, 115, 115),
            //       child: const Center(
            //         child: RefreshProgressIndicator(
            //           valueColor: AlwaysStoppedAnimation<Color>(
            //               Constants.kSecondaryColor),
            //         ),
            //       ),
            //     ),
            //   ),
            const Watermark(),
          ],
        ),
      ),
    );
  }
}