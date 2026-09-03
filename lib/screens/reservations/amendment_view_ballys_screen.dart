import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/amendment_ballys.dart';
import 'package:ballys_reservation_app/providers/amendment_provider_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// One raised amendment in full — the request header, every amended row with
/// only the detail its own category asked for, and the check / approve / reject
/// actions the current user is allowed to take.
class AmendmentViewBallysScreen extends ConsumerStatefulWidget {
  const AmendmentViewBallysScreen({super.key, required this.amendment});

  final AmendmentBallys amendment;

  @override
  ConsumerState<AmendmentViewBallysScreen> createState() =>
      _AmendmentViewBallysScreenState();
}

class _AmendmentViewBallysScreenState
    extends ConsumerState<AmendmentViewBallysScreen> {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy  hh:mm a');

  // Text zoom level for this screen only (1x / 1.2x / 1.3x).
  double _textScale = 1.0;

  /// Amendments follow the reservation permissions: `ResChk` checks and
  /// rejects a pending request, `ResApp` approves or rejects a checked one.
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

  AmendmentBallys get _amendment => widget.amendment;

  /// The user's own text size / weight, applied to every line on this screen.
  /// Read straight off the provider so a change in Settings redraws the page —
  /// every helper here runs inside [build].
  FontSettings get _fonts => ref.watch(fontSettingsProvider);

  bool get _isPending => _amendment.status == 'Pending';
  bool get _isChecked => _amendment.status == 'Checked';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('${_amendment.kindLabel} Amendment'),
      ),
      body: Stack(
        children: [
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(_textScale)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Text size selector (1x / 1.2x / 1.3x) ────────────────
                MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.noScaling),
                  child: _buildTextScaleSelector(),
                ),
                const SizedBox(height: 12),
                _buildHeaderCard(),
                const SizedBox(height: 12),
                if (_amendment.isHotel)
                  ..._amendment.rooms.map(_buildRoomCard)
                else
                  ..._amendment.tickets.map(_buildTicketCard),
                if (_amendment.actionRemark != null ||
                    _amendment.actionBy != null) ...[
                  const SizedBox(height: 4),
                  _buildActionCard(),
                ],
                const SizedBox(height: 12),
                _buildActionButtons(),
              ],
            ),
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
          // Sits above everything, so a screenshot of the detail carries the
          // name of whoever took it.
          const Watermark(),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    final guests = _amendment.allGuests;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _amendment.isHotel ? Icons.hotel : Icons.flight,
                color: Constants.kPrimaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reservation ${_amendment.reservationNo}',
                  style: TextStyle(
                    fontSize: _fonts.fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _statusBadge(_amendment.status),
            ],
          ),
          const Divider(height: 20),
          _row('Requested by ', _amendment.userName),
          if (_amendment.createdDate != null)
            _row(
              'Requested on ',
              _dateTimeFormat.format(_amendment.createdDate!),
            ),
          _row(
            _amendment.isHotel ? 'Rooms amended' : 'Tickets amended',
            '${_amendment.lineCount}',
          ),
          if (guests.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Guests',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: _fonts.fontSize - 3,
              ),
            ),
            const SizedBox(height: 6),
            ...guests.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${g.bmNumber} - ${g.guestName}',
                        style: TextStyle(
                          fontSize: _fonts.fontSize - 3,
                          fontWeight: _fonts.fontWeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Air ticket rows ───────────────────────────────────────────────────────

  Widget _buildTicketCard(AmendmentAirTicket ticket) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lineHeader(
            'Ticket ${ticket.ticketNo}',
            ticket.amendmentCategory,
            ticket.amendmentType,
          ),
          const Divider(height: 20),

          // The routes as they stand today.
          if (ticket.departureRoute.isNotEmpty)
            _row('Departure route ', ticket.departureRoute),
          if (ticket.returnRoute.isNotEmpty)
            _row('Return route', ticket.returnRoute),

          if (ticket.guests.isNotEmpty)
            _row(
              'For',
              ticket.guests
                  .map((g) => '${g.bmNumber} - ${g.guestName}')
                  .join('\n'),
            ),

          // Only the detail this ticket's own type carries.
          if (ticket.newDepartureDate != null)
            _row(
              'New departure date',
              _dateFormat.format(ticket.newDepartureDate!),
              highlight: true,
            ),
          if (ticket.newArrivalDate != null)
            _row(
              'New arrival date',
              _dateFormat.format(ticket.newArrivalDate!),
              highlight: true,
            ),
          if (ticket.refundMethod.isNotEmpty)
            _row('Refund method', ticket.refundMethod, highlight: true),
          if (ticket.ticketValidityNote.isNotEmpty)
            _row('Ticket validity', ticket.ticketValidityNote),
          if (ticket.routeLeg.isNotEmpty)
            _row('Route leg', ticket.routeLeg, highlight: true),
          if (ticket.isMultiSector) _row('Multi sector', 'Yes'),

          if (ticket.changesDeparture)
            _legBlock(
              'New departure leg',
              ticket.departureFrom,
              ticket.departureTo,
              ticket.departureSectors,
            ),
          if (ticket.changesReturn)
            _legBlock(
              'New return leg',
              ticket.returnFrom,
              ticket.returnTo,
              ticket.returnSectors,
            ),

          if (ticket.classes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'New cabin classes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: _fonts.fontSize - 3,
              ),
            ),
            const SizedBox(height: 4),
            ...ticket.classes.map(
              (c) => _row(c.className, '${c.count} pax', highlight: true),
            ),
          ],

          if (ticket.reason.isNotEmpty) _row('Reason', ticket.reason),
          if (ticket.additionalRemark.isNotEmpty)
            _row('Additional remark', ticket.additionalRemark),
        ],
      ),
    );
  }

  /// The new from/to for one leg, plus its transit stops when multi-sector.
  Widget _legBlock(
    String title,
    AmendmentAirportRef? from,
    AmendmentAirportRef? to,
    List<AmendmentTicketSector> sectors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: _fonts.fontSize,
          ),
        ),
        const SizedBox(height: 4),
        if (from != null) _row('From', from.label, highlight: true),
        if (to != null) _row('To', to.label, highlight: true),
        if (sectors.isNotEmpty)
          _row(
            'Stops',
            sectors
                .map(
                  (s) =>
                      '${s.seqNo}. ${s.label}'
                      '${s.sectorDate == null ? '' : '  (${_dateFormat.format(s.sectorDate!)})'}',
                )
                .join('\n'),
            highlight: true,
          ),
      ],
    );
  }

  // ── Hotel rows ────────────────────────────────────────────────────────────

  Widget _buildRoomCard(AmendmentHotelRoom room) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lineHeader('Room ${room.roomNo}', room.amendmentCategory, ''),
          const Divider(height: 20),

          // What the room holds today.
          if (room.hotelName.isNotEmpty) _row('Hotel', room.hotelName),
          if (room.roomCategoryName.isNotEmpty)
            _row('Room category', room.roomCategoryName),
          if (room.roomTypeName.isNotEmpty)
            _row('Room type', room.roomTypeName),
          if (room.arrivalDate != null)
            _row('Arrival', _dateFormat.format(room.arrivalDate!)),
          if (room.departureDate != null)
            _row('Departure', _dateFormat.format(room.departureDate!)),
          _row(
            'Occupancy',
            '${room.guestCount} adult(s), ${room.childrenCount} child(ren), '
                '${room.roomCount} room(s)',
          ),

          if (room.guests.isNotEmpty)
            _row(
              'For',
              room.guests
                  .map((g) => '${g.bmNumber} - ${g.guestName}')
                  .join('\n'),
            ),

          // What it moves to — a blank half means that part is unchanged.
          if (room.newArrivalDate != null)
            _row(
              'New arrival',
              _dateFormat.format(room.newArrivalDate!),
              highlight: true,
            ),
          if (room.newDepartureDate != null)
            _row(
              'New departure',
              _dateFormat.format(room.newDepartureDate!),
              highlight: true,
            ),
          if (room.newHotelName.isNotEmpty)
            _row('New hotel', room.newHotelName, highlight: true),
          if (room.newRoomCategoryName.isNotEmpty)
            _row(
              'New room category',
              room.newRoomCategoryName,
              highlight: true,
            ),
          if (room.newRoomTypeName.isNotEmpty)
            _row('New room type', room.newRoomTypeName, highlight: true),
          if (room.newGuestCount != null ||
              room.newChildrenCount != null ||
              room.newRoomCount != null)
            _row(
              'New occupancy',
              '${room.newGuestCount ?? room.guestCount} adult(s), '
                  '${room.newChildrenCount ?? room.childrenCount} child(ren), '
                  '${room.newRoomCount ?? room.roomCount} room(s)',
              highlight: true,
            ),
          if (room.extras.isNotEmpty)
            _row('Extras', room.extras, highlight: true),
        ],
      ),
    );
  }

  // ── Action trail & buttons ────────────────────────────────────────────────

  Widget _buildActionCard() {
    final color = _statusColor(_amendment.status);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_statusIcon(_amendment.status), color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_amendment.status} details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _fonts.fontSize - 2,
                  color: color,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          if (_amendment.actionBy != null) _row('By', _amendment.actionBy!),
          if (_amendment.actionDate != null)
            _row('On', _dateTimeFormat.format(_amendment.actionDate!)),
          if (_amendment.actionRemark != null)
            _row('Remark', _amendment.actionRemark!),
        ],
      ),
    );
  }

  /// Pending needs `ResChk` (check / reject); Checked needs `ResApp`
  /// (approve / reject). Approved and Rejected are read-only.
  Widget _buildActionButtons() {
    if (!_isPending && !_isChecked) return const SizedBox.shrink();

    final canAct = _isPending ? _hasResChk : _hasResApp;
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
                _isPending
                    ? 'You do not have permission to check this amendment.'
                    : 'You do not have permission to approve this amendment.',
                style: TextStyle(
                  fontSize: _fonts.fontSize - 4,
                  fontWeight: _fonts.fontWeight,
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
            onPressed: () => _submit(_isPending ? 'Checked' : 'Approved'),
            icon: Icon(_isPending ? Icons.fact_check : Icons.check_circle),
            label: Text(
              _isPending ? 'Check' : 'Approve',
              style: TextStyle(
                fontSize: _fonts.fontSize - 3,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPending ? Colors.blue : Colors.green,
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
            onPressed: () => _submit('Rejected'),
            icon: const Icon(Icons.cancel),
            label: Text(
              'Reject',
              style: TextStyle(
                fontSize: _fonts.fontSize - 3,
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

  Future<void> _submit(String status) async {
    final remarks = await _showRemarksDialog(status);
    if (remarks == null) return;

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(amendmentBallysProvider.notifier)
        .updateAmendmentStatus(
          amendment: _amendment,
          status: status,
          remarks: remarks,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Amendment ${status.toLowerCase()}.'
              : (result.message ?? 'Could not update the amendment.'),
        ),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
    if (result.success) context.pop(true);
  }

  /// Remarks are mandatory on a reject, optional otherwise — the same rule the
  /// reservation view follows.
  Future<String?> _showRemarksDialog(String status) {
    final controller = TextEditingController();
    final isReject = status == 'Rejected';
    // Held outside the builder so it survives the dialog's own rebuilds.
    String? error;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                '$status Amendment',
                style: TextStyle(
                  fontSize: _fonts.fontSize - 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    style: TextStyle(fontSize: _fonts.fontSize - 3),
                    decoration: InputDecoration(
                      labelText: isReject ? 'Remarks *' : 'Remarks',
                      hintText: 'Enter your remarks here...',
                      errorText: error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReject
                        ? Colors.red
                        : Constants.kPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (isReject && controller.text.trim().isEmpty) {
                      setDialogState(
                        () => error = 'Please provide remarks to continue.',
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(controller.text.trim());
                  },
                  child: Text(status),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Small shared pieces ───────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _lineHeader(String title, String category, String type) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: _fonts.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (category.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Constants.kPrimaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _fonts.fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (type.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                type,
                style: TextStyle(
                  fontSize: _fonts.fontSize,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Label/value line. [highlight] marks the values the amendment moves to, so
  /// what changes stands apart from what the booking holds now.
  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // Widens with the text size so a long label still fits.
            width: 130 + (_fonts.fontSize - 18) * 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: _fonts.fontSize,
                fontWeight: _fonts.fontWeight,
                color: const Color.fromARGB(255, 147, 8, 112),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: _fonts.fontSize - 3,
                color: highlight ? Colors.green.shade800 : Colors.black,
                fontWeight: highlight ? FontWeight.bold : _fonts.fontWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Text scale (1x / 1.2x / 1.3x) selector ────────────────────────────────
  Widget _buildTextScaleSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          "Text Size",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
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

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: Colors.white,
              fontSize: _fonts.fontSize - 5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Checked':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle;
      case 'Rejected':
        return Icons.cancel;
      case 'Checked':
        return Icons.fact_check;
      default:
        return Icons.hourglass_bottom;
    }
  }
}
