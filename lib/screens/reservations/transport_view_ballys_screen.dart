import 'package:ballys_reservation_app/models/transport/transport_reservation_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/transport_provider_ballys.dart';
import 'package:ballys_reservation_app/screens/reservations/transport_ballys_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Read-only detail of one Bally's transport request: the master record,
/// approval trail, and every hire leg with its vehicles and guests.
class TransportViewBallysScreen extends ConsumerWidget {
  const TransportViewBallysScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryCard(reservation, fontSettings),
                _approvalCard(reservation, fontSettings),
                for (final detail in reservation.details)
                  _detailCard(detail, fontSettings),
              ],
            ),
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
          _row('Category', approver.authorizationCategory, fontSettings),
          _row('Level', approver.authorizationLevel.toString(), fontSettings),
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
