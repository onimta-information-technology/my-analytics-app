import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/transport_provider_ballys.dart';
import 'package:ballys_reservation_app/screens/reservations/transport_ballys_screen.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Detail of one Bally's transport request: the master record, approval
/// trail, every hire leg with its vehicles and guests, and the check / approve
/// / reject actions the current user is allowed to take.
class TransportViewBallysScreen extends ConsumerStatefulWidget {
  const TransportViewBallysScreen({super.key});

  @override
  ConsumerState<TransportViewBallysScreen> createState() =>
      _TransportViewBallysScreenState();
}

class _TransportViewBallysScreenState
    extends ConsumerState<TransportViewBallysScreen> {
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
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final hourStr = hour12.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}  $hourStr:$minute $period';
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final reservation = ref.watch(selectedTransportBallysProvider);
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/reservationMain/transport-ballys');
            }
          },
        ),
        title: const Text('Transport Details'),
      ),
      body: reservation == null
          ? const Center(child: Text('No transport request selected.'))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _summaryCard(reservation, fontSettings),
                    _approvalCard(reservation, fontSettings),
                    for (final detail in reservation.details)
                      _detailCard(detail, fontSettings),
                    _actionButtons(reservation, fontSettings),
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
    TransportReservationBallys reservation,
    FontSettings fontSettings,
  ) {
    final isPending = reservation.status == TransportStatusBallys.pending;
    final isChecked = reservation.status == TransportStatusBallys.checked;
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
                _submit(reservation, isPending ? 'Checked' : 'Approved'),
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
            onPressed: () => _submit(reservation, 'Rejected'),
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

  Future<void> _submit(
    TransportReservationBallys reservation,
    String status,
  ) async {
    final remark = switch (status) {
      'Checked' => await _showRemarksDialog(
          'Check Transport',
          Colors.blue,
          Icons.fact_check_outlined,
        ),
      'Approved' => await _showRemarksDialog(
          'Approve Transport',
          Colors.green,
          Icons.check_circle_outline,
        ),
      _ => await _showRemarksDialog(
          'Reject Transport',
          Colors.red,
          Icons.cancel_outlined,
          required: true,
        ),
    };
    if (remark == null) return;

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(transportProviderBallys.notifier)
        .updateStatus(
          masterId: reservation.masterId,
          status: status,
          remark: remark,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Transport request ${status.toLowerCase()}.'
              : (result.message ?? 'Could not update the transport request.'),
        ),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
    if (result.success) context.pop(true);
  }

  /// Same design as the reservation view's remarks dialog. Remarks are
  /// mandatory on a reject, optional otherwise.
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
    TransportReservationBallys reservation,
    FontSettings fontSettings,
  ) {
    final color = transportStatusBallysColor(reservation.status);
    return _section(
      title: '${reservation.mid} - ${reservation.guestName}',
      fontSettings: fontSettings,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          reservation.status.label,
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      children: [
        _row('Pickup', _formatDateTime(reservation.pickupDate), fontSettings),
        _row('Contact', reservation.contactNumber, fontSettings),
        _row('Requested by', reservation.userName, fontSettings),
        _row('Sales code', reservation.salesCode, fontSettings),
        _row('Marketing code', reservation.marketingCode, fontSettings),
        _row('Requested', _formatDateTime(reservation.createdDate),
            fontSettings),
        _row(
          'Totals',
          '${reservation.totalVehicles} vehicles · '
              '${reservation.totalPassengers} pax',
          fontSettings,
        ),
      ],
    );
  }

  Widget _approvalCard(
    TransportReservationBallys reservation,
    FontSettings fontSettings,
  ) {
    final approver = reservation.approvePerson;
    return _section(
      title: 'Approval',
      fontSettings: fontSettings,
      children: [
        if (approver != null) ...[
          _row('Approver', approver.authorizationPerson, fontSettings),
          // _row('Category', approver.authorizationCategory, fontSettings),
          // _row('Level', approver.authorizationLevel.toString(), fontSettings),
        ],
        if (reservation.checkedBy != null) ...[
          _row('Checked by', reservation.checkedBy!, fontSettings),
          _row('Checked', _formatDateTime(reservation.checkedDate),
              fontSettings),
          if (reservation.checkedRemark != null)
            _row('Remark', reservation.checkedRemark!, fontSettings),
        ],
        if (reservation.approvedBy != null) ...[
          _row('Approved by', reservation.approvedBy!, fontSettings),
          _row('Approved', _formatDateTime(reservation.approvedDate),
              fontSettings),
          if (reservation.approvedRemark != null)
            _row('Remark', reservation.approvedRemark!, fontSettings),
        ],
        if (reservation.rejectedBy != null) ...[
          _row('Rejected by', reservation.rejectedBy!, fontSettings),
          _row('Rejected', _formatDateTime(reservation.rejectedDate),
              fontSettings),
          if (reservation.rejectedRemark != null)
            _row('Remark', reservation.rejectedRemark!, fontSettings),
        ],
      ],
    );
  }

  Widget _detailCard(TransportDetailBallys detail, FontSettings fontSettings) {
    return _section(
      title: 'Trip ${detail.rowId} · ${detail.hireType}',
      fontSettings: fontSettings,
      children: [
        _row('Guest', '${detail.mid} - ${detail.guestName}', fontSettings),
        _row(
          'Pickup',
          '${_formatDate(detail.pickupDate)}  ${detail.pickupTime}',
          fontSettings,
        ),
        if (detail.gate.isNotEmpty) _row('Gate', detail.gate, fontSettings),
        if (detail.flightNo.isNotEmpty)
          _row('Flight no', detail.flightNo, fontSettings),
        _row('From', detail.pickupLocation, fontSettings),
        _row('To', detail.dropLocation, fontSettings),
        _row('Contact', detail.contactNumber, fontSettings),
        _row('Vehicles', detail.noOfVehicles.toString(), fontSettings),
        for (var i = 0; i < detail.vehicles.length; i++)
          _row(
            '  Vehicle ${i + 1}',
            '${detail.vehicles[i].carType} · '
                '${detail.vehicles[i].noOfPassengers} pax',
            fontSettings,
          ),
        if (detail.accompanyingMembers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Accompanying members',
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          for (final member in detail.accompanyingMembers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${member.mid} - ${member.guestName}',
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

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
