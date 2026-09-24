import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/airport_service/airport_service_ballys.dart';
import 'package:ballys_reservation_app/providers/airport_service_provider_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/screens/reservations/airport_service_ballys_screen.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Detail of one Bally's airport service request: the master record, its
/// nominated approver, the approval trail, every guest, and the check /
/// approve / reject actions the current user is allowed to take.
class AirportServiceViewBallysScreen extends ConsumerStatefulWidget {
  const AirportServiceViewBallysScreen({super.key});

  @override
  ConsumerState<AirportServiceViewBallysScreen> createState() =>
      _AirportServiceViewBallysScreenState();
}

class _AirportServiceViewBallysScreenState
    extends ConsumerState<AirportServiceViewBallysScreen> {
  /// Same permissions as the reservation screens: `ResChk` checks or rejects a
  /// pending request, `ResApp` approves or rejects a checked one.
  bool _hasResChk = false;
  bool _hasResApp = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final resChk = await StorageUtil.getResChk();
    final resApp = await StorageUtil.getResApp();
    if (!mounted) return;
    setState(() {
      _hasResChk = resChk == true;
      _hasResApp = resApp == true;
    });
  }

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final hourStr = hour12.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}  $hourStr:$minute $period';
  }

  static String _formatAmount(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$whole.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(selectedAirportServiceBallysProvider);
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/reservationMain/airport-service-ballys');
            }
          },
        ),
        title: const Text('Airport Service Details'),
      ),
      body: request == null
          ? const Center(child: Text('No airport service request selected.'))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _summaryCard(request, fontSettings),
                    _approvalCard(request, fontSettings),
                    for (final guest in request.guests)
                      _guestCard(guest, fontSettings),
                    _actionButtons(request, fontSettings),
                  ],
                ),
                if (_isSubmitting)
                  Positioned.fill(
                    child: Container(
                      color: const Color.fromARGB(135, 117, 115, 115),
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
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Pending Check needs `ResChk` (check / reject); Pending Approval needs
  /// `ResApp` (approve / reject). Approved and Rejected are read-only.
  Widget _actionButtons(
    AirportServiceBallys request,
    FontSettings fontSettings,
  ) {
    final isPending = request.status == AirportServiceStatusBallys.pending;
    final isChecked = request.status == AirportServiceStatusBallys.checked;
    if (!isPending && !isChecked) return const SizedBox.shrink();

    final canAct = isPending ? _hasResChk : _hasResApp;
    if (!canAct) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPending
                    ? 'You do not have permission to check this request.'
                    : 'You do not have permission to approve this request.',
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () =>
                _submit(request, isPending ? 'Checked' : 'Approved'),
            icon: Icon(isPending ? Icons.fact_check : Icons.check_circle),
            label: Text(
              isPending ? 'Check' : 'Approve',
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPending ? Colors.blue : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _submit(request, 'Rejected'),
            icon: const Icon(Icons.cancel),
            label: Text(
              'Reject',
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(AirportServiceBallys request, String status) async {
    final remark = switch (status) {
      'Checked' => await _showRemarksDialog(
          'Check Airport Service',
          Colors.blue,
          Icons.fact_check_outlined,
        ),
      'Approved' => await _showRemarksDialog(
          'Approve Airport Service',
          Colors.green,
          Icons.check_circle_outline,
        ),
      _ => await _showRemarksDialog(
          'Reject Airport Service',
          Colors.red,
          Icons.cancel_outlined,
          required: true,
        ),
    };
    if (remark == null) return;

    setState(() => _isSubmitting = true);
    final result =
        await ref.read(airportServiceProviderBallys.notifier).updateStatus(
              masterId: request.masterId,
              status: status,
              remark: remark,
            );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Airport service request ${status.toLowerCase()}.'
              : (result.message ??
                  'Could not update the airport service request.'),
        ),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
    if (result.success) context.pop(true);
  }

  /// Same design as the visa view's remarks dialog. Remarks are mandatory on a
  /// reject, optional otherwise.
  Future<String?> _showRemarksDialog(
    String title,
    Color accentColor,
    IconData icon, {
    bool required = false,
  }) {
    final remarksController = TextEditingController();
    // Held outside the builder so it survives the dialog's own rebuilds.
    String? error;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return GestureDetector(
              onTap: () => FocusScope.of(dialogContext).unfocus(),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 38, color: accentColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please provide remarks to continue.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: remarksController,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Enter your remarks here...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          errorText: error,
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: accentColor, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final text = remarksController.text.trim();
                                if (required && text.isEmpty) {
                                  setDialogState(() => error =
                                      'Please provide remarks to continue.');
                                  return;
                                }
                                Navigator.of(dialogContext).pop(text);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
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
            );
          },
        );
      },
    );
  }

  Widget _summaryCard(
    AirportServiceBallys request,
    FontSettings fontSettings,
  ) {
    final color = airportServiceStatusBallysColor(request.status);
    final lead = request.leadGuest;
    return _section(
      title: lead == null ? request.masterId : '${lead.mid} - ${lead.guestName}',
      fontSettings: fontSettings,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          request.status.label,
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      children: [
        _row('Guests', request.guests.length.toString(), fontSettings),
        _row('Total pax', request.totalPax.toString(), fontSettings),
        _row('Requested by', request.userName, fontSettings),
        _row('Sales code', request.salesCode, fontSettings),
        _row('Marketing code', request.marketingCode, fontSettings),
        _row('Requested', _formatDateTime(request.createdDate), fontSettings),
        if (request.remarks != null)
          _row('Remarks', request.remarks!, fontSettings),
      ],
    );
  }

  Widget _approvalCard(
    AirportServiceBallys request,
    FontSettings fontSettings,
  ) {
    final approver = request.approvePerson;
    final hasTrail = request.checkedBy != null ||
        request.approvedBy != null ||
        request.rejectedBy != null;
    if (approver == null && !hasTrail) return const SizedBox.shrink();

    return _section(
      title: 'Approval',
      fontSettings: fontSettings,
      children: [
        if (approver != null) ...[
          _row('Approver', approver.authorizationPerson, fontSettings),
         // _row('Category', approver.authorizationCategory, fontSettings),
          //_row('Level', approver.authorizationLevel.toString(), fontSettings),
        ],
        if (request.checkedBy != null) ...[
          _row('Checked by', request.checkedBy!, fontSettings),
          _row('Checked', _formatDateTime(request.checkedDate), fontSettings),
          if (request.checkedRemark != null)
            _row('Remark', request.checkedRemark!, fontSettings),
        ],
        if (request.approvedBy != null) ...[
          _row('Approved by', request.approvedBy!, fontSettings),
          _row('Approved', _formatDateTime(request.approvedDate),
              fontSettings),
          if (request.approvedRemark != null)
            _row('Remark', request.approvedRemark!, fontSettings),
        ],
        if (request.rejectedBy != null) ...[
          _row('Rejected by', request.rejectedBy!, fontSettings),
          _row('Rejected', _formatDateTime(request.rejectedDate),
              fontSettings),
          if (request.rejectedRemark != null)
            _row('Remark', request.rejectedRemark!, fontSettings),
        ],
      ],
    );
  }

  Widget _guestCard(
    AirportServiceGuestBallys guest,
    FontSettings fontSettings,
  ) {
    return _section(
      title: '${guest.mid} - ${guest.guestName}',
      fontSettings: fontSettings,
      children: [
        _row('Service', guest.serviceType, fontSettings),
        _row(
          'Package',
          '${guest.currencyType} ${_formatAmount(guest.packageAmount)}',
          fontSettings,
        ),
        _row('Pax', guest.noOfPax.toString(), fontSettings),
        _row(
          'Accompanied',
          guest.hasAccompanyingMembers ? 'Yes' : 'No',
          fontSettings,
        ),
        if (guest.hasAccompanyingMembers) ...[
          _row('Wife', guest.hasWife ? 'Yes' : 'No', fontSettings),
          _row('Children', guest.noOfChildren.toString(), fontSettings),
          _row('Friends', guest.noOfFriends.toString(), fontSettings),
        ],
      ],
    );
  }

  // ── Layout helpers ────────────────────────────────────────────────────────

  Widget _section({
    required String title,
    required FontSettings fontSettings,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize + 2,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, FontSettings fontSettings) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: fontSettings.fontWeight,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
