import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/gift/birthday_gift_request.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/BirthdayGiftIncreesNotifier.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/formatter.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ViewBirthdayGiftRequest extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;
  final BirthdayIncressGiftRequest? gift;
  final bool isPending;
  final bool isApproved;
  final bool isChecked;

  const ViewBirthdayGiftRequest({
    super.key,
    required this.giftsRepository,
    this.gift,
    this.isPending = false,
    this.isApproved = false,
    this.isChecked = false,
  });

  @override
  ConsumerState<ViewBirthdayGiftRequest> createState() =>
      _ViewBirthdayGiftRequestState();
}

class _ViewBirthdayGiftRequestState
    extends ConsumerState<ViewBirthdayGiftRequest> {
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
  final TextEditingController _previousGiftAmountController =
      TextEditingController();

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
  int? _selectedValidDays;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditable = false;

  // ── Permission state ────────────────────────────────────────────────────────
  bool _canReverseApproved = false;
  bool _canReverseRejected = false;

  /// Pending tab: bgChk == true
  bool _canCheckOrRejectPending = false;

  /// Checked tab: bgApp == true
  bool _canApproveOrRejectChecked = false;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    _loadAllPermissions();

    if (widget.gift != null) {
      final g = widget.gift!;
      _memberIdController.text = g.mid ?? "";
      _memberNameController.text = g.mname ?? "";
      _fromDateController.text = _formatDateandTime(g.dateFrom) ?? "";
      _toDateController.text = _formatDateandTime(g.dateTo);
      _arrivalDateController.text = _formatDate(g.arrDate);
      _departureDateController.text = _formatDate(g.dptDate);
      _chipController.text = g.chipType.replaceAll("_", " ");
      _amountController.text = formatNumber(g.giftDesc.toString()) ?? "";
      _remarksController.text = g.giftCategory ?? "";
      _previousGiftAmountController.text = g.prvGiftAmount ?? "0";

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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadGuestDataForCard();
      });
    }
  }

  // ── Permission helpers ──────────────────────────────────────────────────────

  Future<void> _loadAllPermissions() async {
    final salesCode = await StorageUtil.getSalesCode();
    final isAdmin =
        salesCode != null && salesCode.trim().toUpperCase() == 'AD001';

    final currentUser =
        (await StorageUtil.getUserName())?.trim().toLowerCase() ?? '';
    final approvedBy =
        (widget.gift?.firstAppBy ?? '').trim().toLowerCase();
    final rejectedBy =
        (widget.gift?.deleteUser ?? '').trim().toLowerCase();

    final bgChk = await StorageUtil.getBgChk();
    final bgApp = await StorageUtil.getBgApp();

    setState(() {
      // Reverse permissions
      _canReverseApproved = bgChk == true || bgApp == true;
      _canReverseRejected = bgChk == true || bgApp == true;

      // Pending tab → Check & Reject buttons
      _canCheckOrRejectPending = bgChk == true;

      // Checked tab → Approve & Reject buttons
      _canApproveOrRejectChecked = bgApp == true;
    });
  }

  // ── Guest data ──────────────────────────────────────────────────────────────

  Future<void> _loadGuestDataForCard() async {
    if (_memberIdController.text.isEmpty) return;
    try {
      setState(() => _isLoading = true);
      GuestRepository guestRepository =
          GuestRepository(ApiService(const FlutterSecureStorage()));
      List<GuestSearchResponse> guests =
          await guestRepository.searchGuest(9021, _memberIdController.text);
      if (guests.isNotEmpty) {
        final gr = guests.first;
        ref.read(selectedGuestProvider.notifier).setSelectedGuest(
              Guest(
                mid: gr.mid ?? _memberIdController.text,
                memberName: gr.mName ?? _memberNameController.text,
                country: "",
                lastVisitDate: gr.lvd?.toString() ?? "",
                age: 0,
                gRating: gr.gRating ?? "",
                mGroup: gr.mGroup,
                gName: gr.gName ?? "",
                memImage2: gr.memImage2,
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

  // ── Formatters ──────────────────────────────────────────────────────────────

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(dateString));
    } catch (_) {
      return dateString;
    }
  }

  String _formatDateandTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      return DateFormat('yyyy-MM-dd HH:mm a').format(DateTime.parse(dateString));
    } catch (_) {
      return dateString;
    }
  }

  String formatNumber(dynamic value) {
    if (value == null) return "";
    final num? number = num.tryParse(value.toString());
    if (number == null) return value.toString();
    return NumberFormat.decimalPattern().format(number);
  }

  // ── Text styles ─────────────────────────────────────────────────────────────

  TextStyle _inputTextStyle(FontSettings fontSettings) => TextStyle(
        fontSize: fontSettings.fontSize,
        fontWeight: fontSettings.fontWeight,
      );

  TextStyle _inputTextStyleForAmount(FontSettings fontSettings) => TextStyle(
        fontSize: fontSettings.fontSize + 5,
        fontWeight: FontWeight.bold,
        color: const Color.fromARGB(255, 255, 0, 0),
      );

  // ── Validation ──────────────────────────────────────────────────────────────

  bool _validateValidDays() {
    if (_selectedValidDays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select valid days"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  // ── Action handlers ─────────────────────────────────────────────────────────

  Future<void> _doCheck() async {
    if (widget.gift == null) return;
    if (!_validateValidDays()) return;

    setState(() => _isLoading = true);
    try {
      final success = await ref
          .read(birthdayGiftIncreesProvider.notifier)
          .checkBirthdayGiftincreesFromUI(
            reqid: widget.gift!.idNo,
            remarks: _remarksController.text,
            amount: _amountController.text,
            userName: userName ?? "",
            validDates: _selectedValidDays.toString(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(success ? "Request Checked Successfully" : "Check Failed"),
        backgroundColor: success ? Colors.blue : Colors.red,
      ));
      if (success) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _doApprove() async {
    if (widget.gift == null) return;
    if (!_validateValidDays()) return;

    setState(() => _isLoading = true);
    try {
      final success = await ref
          .read(birthdayGiftIncreesProvider.notifier)
          .sendApprovedBirthdayGiftFromUI(
            reqid: widget.gift!.idNo,
            remarks: _remarksController.text,
            amount: _amountController.text,
            userName: userName ?? "",
            validDates: _selectedValidDays.toString(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            success ? "Request Approved Successfully" : "Approval Failed"),
      ));
      if (success) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _doReject() async {
    if (widget.gift == null) return;

    setState(() => _isLoading = true);
    try {
      final success = await ref
          .read(birthdayGiftIncreesProvider.notifier)
          .rejectBirthdayGiftFromUI(
            reqid: widget.gift!.idNo,
            userName: userName ?? "",
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(success ? "Request Rejected Successfully" : "Rejection Failed"),
      ));
      if (success) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _doReverse({required bool isRejected}) async {
    if (widget.gift == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reverse Gift'),
        content: Text(
          isRejected
              ? 'Are you sure you want to reverse this rejected birthday gift?'
              : 'Are you sure you want to reverse this birthday gift?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
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
              .read(birthdayGiftIncreesProvider.notifier)
              .reverseBirthdayGiftFromUIRejected(
                reqid: widget.gift!.idNo,
                userName: userName ?? "",
              )
          : await ref
              .read(birthdayGiftIncreesProvider.notifier)
              .reverseBirthdayGiftFromUI(
                reqid: widget.gift!.idNo,
                userName: userName ?? "",
              );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Birthday gift reversed successfully'
            : 'Failed to reverse birthday gift'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
      if (success) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Access Denied Dialog ────────────────────────────────────────────────────

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

  // ── Shared: Pending Gift & Issued Gift buttons ──────────────────────────────

  Widget _buildPendingIssuedGiftButtons(FontSettings fs) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              final memberId = _memberIdController.text.trim();
              if (memberId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a Member ID")),
                );
                return;
              }
              context.push(
                '/gifts/special-gift-requests/prv-gifts/$memberId',
                extra: {'iid': 988908},
              );
            },
            icon: const Icon(Icons.hourglass_empty, size: 18),
            label: Text(
              "Pending Gift",
              style: TextStyle(
                  fontSize: fs.fontSize, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              final memberId = _memberIdController.text.trim();
              if (memberId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a Member ID")),
                );
                return;
              }
              context.push(
                '/gifts/special-gift-requests/prv-gifts/$memberId',
                extra: {'iid': 8888},
              );
            },
            icon: const Icon(Icons.card_giftcard, size: 18),
            label: Text(
              "Issued Gift",
              style: TextStyle(
                  fontSize: fs.fontSize, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Section builders ────────────────────────────────────────────────────────

  Widget _buildTopSection(FontSettings fs) {
    if (widget.isApproved) {
      if (!_canReverseApproved) return const SizedBox.shrink();
      return _reverseBtn(isRejected: false, fs: fs);
    }

    if (!widget.isPending && !widget.isApproved && !widget.isChecked) {
      if (!_canReverseRejected) return const SizedBox.shrink();
      return _reverseBtn(isRejected: true, fs: fs);
    }

    return const SizedBox.shrink();
  }

  Widget _reverseBtn({required bool isRejected, required FontSettings fs}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        child: ElevatedButton.icon(
          onPressed: () => _doReverse(isRejected: isRejected),
          icon: const Icon(Icons.undo, size: 20),
          label: Text(
            'Reverse Gift',
            style:
                TextStyle(fontSize: fs.fontSize, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _buildBottomSection(FontSettings fs) {
    // ── Pending tab: Check & Reject + Pending/Issued Gift ──────────────────
    if (widget.isPending) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!_canCheckOrRejectPending) {
                      _showAccessDeniedDialog();
                      return;
                    }
                    _doCheck();
                  },
                  icon: const Icon(Icons.fact_check),
                  label: const Text("CHECK"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!_canCheckOrRejectPending) {
                      _showAccessDeniedDialog();
                      return;
                    }
                    _doReject();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text("REJECT"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPendingIssuedGiftButtons(fs),
        ],
      );
    }

    // ── Checked tab: Approve & Reject + Pending/Issued Gift ────────────────
    if (widget.isChecked) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!_canApproveOrRejectChecked) {
                      _showAccessDeniedDialog();
                      return;
                    }
                    _doApprove();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text("APPROVE"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canApproveOrRejectChecked ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!_canApproveOrRejectChecked) {
                      _showAccessDeniedDialog();
                      return;
                    }
                    _doReject();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text("REJECT"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canApproveOrRejectChecked ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPendingIssuedGiftButtons(fs),
        ],
      );
    }

    // ── Approved tab: Reverse button (bottom) + Pending/Issued Gift ────────
    if (widget.isApproved) {
      return Column(
        children: [
          if (_canReverseApproved) ...[
            _reverseBtn(isRejected: false, fs: fs),
            const SizedBox(height: 1),
          ],
          _buildPendingIssuedGiftButtons(fs),
        ],
      );
    }

    // ── Rejected tab: Reverse button (bottom) + Pending/Issued Gift ────────
    if (!widget.isPending && !widget.isApproved && !widget.isChecked) {
      return Column(
        children: [
          if (_canReverseRejected) ...[
            _reverseBtn(isRejected: true, fs: fs),
            const SizedBox(height: 1),
          ],
          _buildPendingIssuedGiftButtons(fs),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) context.pop();
            else context.go('/menu');
          },
        ),
      //   title: Text(
      //     'Birthday Gift Request',
      //     style: TextStyle(
      //         fontSize: fontSettings.fontSize,
      //         fontWeight: fontSettings.fontWeight),
      //   ),
      // ),
       title: Row(
          children: [
            Text(
              'Birthday Gift Request',
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.isApproved
                    ? Colors.green
                    : widget.isChecked
                    ? const Color.fromARGB(255, 92, 17, 255)
                    : widget.isPending
                    ? Colors.orange
                    : Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isApproved
                        ? Icons.check_circle
                        : widget.isChecked
                        ? Icons.rule_rounded
                        : widget.isPending
                        ? Icons.hourglass_bottom
                        : Icons.cancel,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isApproved
                        ? 'Approved'
                        : widget.isChecked
                        ? 'Checked'
                        : widget.isPending
                        ? 'Pending'
                        : 'Rejected',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  children: [
                    // ── Reverse button at TOP (Approved / Rejected tabs) ────
                    _buildTopSection(fontSettings),

                    // ── From / To Date ──────────────────────────────────────
                    TextFormField(
                      controller: _fromDateController,
                      readOnly: true,
                      style: _inputTextStyle(fontSettings),
                      decoration: InputDecoration(
                        labelText: "From Date & Time",
                        labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight),
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
                            fontWeight: fontSettings.fontWeight),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: -5.0),
                      ),
                    ),

                    // ── Guest card ──────────────────────────────────────────
                    const SizedBox(height: 5.0),
                    GuestDisplayCardSpecialGiftview(
                      memberIdText: _memberIdController.text,
                      memberNameText: _memberNameController.text,
                      showCard: _memberIdController.text.isNotEmpty &&
                          _memberNameController.text.isNotEmpty,
                      isLoading: _isLoading,
                      showLastVisitDate: true,
                    ),

                    // ── Profile / Previous Gift buttons ─────────────────────
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
                                      final gr = guests.first;
                                      ref
                                          .read(
                                              selectedGuestProvider.notifier)
                                          .setSelectedGuest(Guest(
                                            mid: gr.mid ??
                                                _memberIdController.text,
                                            memberName: gr.mName ??
                                                _memberNameController.text,
                                            country: "",
                                            lastVisitDate:
                                                gr.lvd?.toString() ?? "",
                                            age: 0,
                                            gRating: gr.gRating ?? "",
                                            mGroup: gr.mGroup,
                                            gName: gr.gName ?? "",
                                            memImage2: gr.memImage2,
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
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
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
                                      content:
                                          Text("Please enter a Member ID")),
                                );
                                return;
                              }
                              context.push(
                                '/gifts/special-gift-requests/prv-gifts/$memberId',
                                extra: {'iid': 988908},
                              );
                            },
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
                                      content:
                                          Text("Please enter a Member ID")),
                                );
                                return;
                              }
                              context.push(
                                '/gifts/special-gift-requests/prv-gifts/$memberId',
                                extra: {'iid': 8888},
                              );
                            },
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

                    // ── Guest Gift Data table ───────────────────────────────
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: Text("Guest Gift Data",
                          style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight)),
                    ),
                    const SizedBox(height: 10),
                    Builder(builder: (context) {
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
                        {
                          "Field": "Flush Actual Drop (Est)",
                          "Value": flushactdrop
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
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: shouldHighlight
                                              ? FontWeight.bold
                                              : fontSettings.fontWeight)),
                                )),
                                DataCell(Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                      formatNumber(row["Value"]),
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: shouldHighlight
                                            ? FontWeight.bold
                                            : fontSettings.fontWeight,
                                        fontFamily: 'monospace',
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      )),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    }),

                    // ── Arrival / Departure ─────────────────────────────────
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

                    // ── Gift For / Chip Type ────────────────────────────────
                    const SizedBox(height: 16),
                    TextFormField(
                      readOnly: true,
                      controller:
                          TextEditingController(text: "Birthday Gift"),
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

                    // ── Checked By & Check Date Card ────────────────────────
                    if (!widget.isPending &&
                        widget.gift != null &&
                        widget.gift!.checkApp != null &&
                        widget.gift!.checkApp!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color.fromARGB(255, 92, 17, 255)
                                  .withOpacity(0.08),
                              const Color.fromARGB(255, 92, 17, 255)
                                  .withOpacity(0.03),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color.fromARGB(255, 92, 17, 255)
                                .withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(255, 92, 17, 255)
                                  .withOpacity(0.08),
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                          255, 92, 17, 255),
                                      borderRadius:
                                          BorderRadius.circular(8),
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
                                      color: const Color.fromARGB(
                                          255, 92, 17, 255),
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
                              Row(
                                children: [
                                  const Icon(Icons.person_outline,
                                      color:
                                          Color.fromARGB(255, 92, 17, 255),
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Checked By:",
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                      color:
                                          const Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.gift!.checkApp!,
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize + 1,
                                        fontWeight: FontWeight.bold,
                                        color: const Color.fromARGB(
                                            255, 92, 17, 255),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      color:
                                          Color.fromARGB(255, 92, 17, 255),
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Check Date:",
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                      color:
                                          const Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.gift!.checkAppByTime != null &&
                                              widget.gift!.checkAppByTime!
                                                  .isNotEmpty
                                          ? _formatDateandTime(
                                              widget.gift!.checkAppByTime)
                                          : 'N/A',
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: FontWeight.bold,
                                        color: const Color.fromARGB(
                                            255, 92, 17, 255),
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
// ── Approved Information Card ───────────────────────────────────────────
if (widget.isApproved &&
    widget.gift != null &&
    widget.gift!.firstAppBy != null &&
    widget.gift!.firstAppBy!.isNotEmpty) ...[
  const SizedBox(height: 16),
  Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.green.withOpacity(0.10),
          Colors.green.withOpacity(0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.green.withOpacity(0.5),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.green.withOpacity(0.08),
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
          // ── Header ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Approved Information",
                style: TextStyle(
                  fontSize: fontSettings.fontSize + 2,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.green.withOpacity(0.35), height: 1),
          const SizedBox(height: 12),

          // ── Approved By ───────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.person_outline,
                  color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                "Approved By:",
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.gift!.firstAppBy!,
                  style: TextStyle(
                    fontSize: fontSettings.fontSize + 1,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // ── Approved At ───────────────────────────────────────────
          if (widget.gift!.firstAppTime != null &&
              widget.gift!.firstAppTime!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule,
                    color: Colors.green.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  "Approved At:",
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: fontSettings.fontWeight,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDateandTime(widget.gift!.firstAppTime),
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  ),
],
                    // ── Previous Gift Amount ────────────────────────────────
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _previousGiftAmountController,
                      readOnly: true,
                      style: _inputTextStyleForAmount(fontSettings),
                      decoration: InputDecoration(
                        labelText: "Previous Gift Amount",
                        labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize + 2,
                            fontWeight: fontSettings.fontWeight),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: -5.0),
                      ),
                    ),

                    // ── Edit toggle (pending & checked only) ───────────────
                    if (widget.isPending || widget.isChecked)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Amount & Remarks",
                              style: TextStyle(
                                  fontSize: fontSettings.fontSize + 2,
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                            icon:
                                const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () =>
                                setState(() => _isEditable = !_isEditable),
                          ),
                        ],
                      ),

                    // ── Amount ─────────────────────────────────────────────
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _amountController,
                      readOnly: !_isEditable,
                      style: _inputTextStyleForAmount(fontSettings),
                      decoration: InputDecoration(
                        labelText: "Increase gift Amount",
                        labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize + 2,
                            fontWeight: fontSettings.fontWeight),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: -5.0),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter amount";
                        }
                        return null;
                      },
                    ),

                    // ── Valid Days (pending & checked only) ────────────────
                    if (widget.isPending || widget.isChecked) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _selectedValidDays,
                        style: TextStyle(
                            fontSize: fontSettings.fontSize + 2,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                        decoration: InputDecoration(
                          labelText: "Valid Days",
                          labelStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 30,
                              child: Text("30 Days",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold))),
                          DropdownMenuItem(
                              value: 60,
                              child: Text("60 Days",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold))),
                          DropdownMenuItem(
                              value: 90,
                              child: Text("90 Days",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold))),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedValidDays = value),
                        validator: (value) => value == null
                            ? "Please select valid days"
                            : null,
                      ),
                    ],

                    // ── Remarks ────────────────────────────────────────────
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarksController,
                      readOnly: !_isEditable,
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

                    // ── Bottom action section ───────────────────────────────
                    // Shows: action buttons (Check/Reject or Approve/Reject or Reverse)
                    // + Pending Gift & Issued Gift buttons for ALL tabs
                    const SizedBox(height: 10.0),
                    _buildBottomSection(fontSettings),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
          const Watermark(),
        ],
      ),
    );
  }
}