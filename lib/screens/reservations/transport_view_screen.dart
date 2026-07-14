import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_transport_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TransportViewScreen extends ConsumerWidget {
  const TransportViewScreen({super.key});

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

  // static Color _statusColor(String status) {
  //   switch (status) {
  //     case 'Approved':
  //       return Colors.green;
  //     case 'Rejected':
  //       return Colors.red;
  //     case 'Checked':
  //       return Colors.blue;
  //     default:
  //       return Colors.orange;
  //   }
  // }

  // static IconData _statusIcon(String status) {
  //   switch (status) {
  //     case 'Approved':
  //       return Icons.check_circle;
  //     case 'Rejected':
  //       return Icons.cancel;
  //     case 'Checked':
  //       return Icons.fact_check;
  //     default:
  //       return Icons.hourglass_bottom;
  //   }
  // }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transport = ref.watch(selectedTransportProvider);
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Transport Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/reservationMain/transport');
            }
          },
        ),
      ),
      body: transport == null
          ? const Center(child: Text('No transport request selected.'))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(transport, fontSettings),
                    const SizedBox(height: 20),
                    Text(
                      'Trips (${transport.details.length})',
                      style: TextStyle(
                        fontSize: fontSettings.fontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (transport.details.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No trip details for this request.'),
                        ),
                      )
                    else
                      ...transport.details.asMap().entries.map(
                            (entry) => _buildDetailCard(
                              entry.key + 1,
                              entry.value,
                              fontSettings,
                            ),
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
    TransportReservation transport,
    FontSettings fontSettings,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Constants.kPrimaryColor.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Highlighted header band ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Constants.kPrimaryColor,
                    Color.fromARGB(255, 168, 116, 30),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car_filled,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${transport.guestName} - ${transport.mid}',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize + 2,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        // const SizedBox(height: 2),
                        // Text(
                        //   'Member ID: ${transport.mid}',
                        //   style: TextStyle(
                        //     fontSize: fontSettings.fontSize - 2,
                        //     color: Colors.white70,
                        //     fontWeight: FontWeight.w600,
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Stat strip ───────────────────────────────────────────────
            Container(
              color: const Color.fromARGB(255, 250, 244, 232),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _statTile(
                      Icons.local_taxi,
                      '${transport.totalVehicles}',
                      'Vehicles',
                      fontSettings,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statTile(
                      Icons.people,
                      '${transport.totalPassengers}',
                      'Passengers',
                      fontSettings,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statTile(
                      Icons.route,
                      '${transport.details.length}',
                      'Trips',
                      fontSettings,
                    ),
                  ),
                ],
              ),
            ),

            // ── Details body ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(
                    Icons.event,
                    'Pickup',
                    _formatDateTime(transport.pickupDate),
                    Colors.blueGrey,
                    fontSettings,
                  ),
                  _infoRow(
                    Icons.phone,
                    'Contact',
                    transport.contactNumber,
                    Colors.green,
                    fontSettings,
                  ),
                  _infoRow(
                    Icons.person_outline,
                    'Requested by',
                    transport.userName,
                    Colors.blue,
                    fontSettings,
                  ),
                  _infoRow(
                    Icons.badge_outlined,
                    'Sales code',
                    transport.salesCode,
                    Colors.indigo,
                    fontSettings,
                  ),
                  _infoRow(
                    Icons.schedule,
                    'Requested',
                    _formatDateTime(transport.createdDate),
                    Colors.blueGrey,
                    fontSettings,
                  ),
                  _infoRow(
                    Icons.confirmation_number_outlined,
                    'Request ID',
                    transport.masterId,
                    Colors.brown,
                    fontSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    int index,
    TransportDetail detail,
    FontSettings fontSettings,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Constants.kPrimaryColor,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${detail.mid} - ${detail.guestName}',
                    style: TextStyle(
                      fontSize: fontSettings.fontSize + 1,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    detail.hireType,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _infoRow(
              Icons.event,
              'Pickup date',
              _formatDate(detail.pickupDate),
              Colors.blueGrey,
              fontSettings,
            ),
            _infoRow(
              Icons.access_time,
              'Pickup time',
              detail.pickupTime,
              Colors.blueGrey,
              fontSettings,
            ),
            _infoRow(
              Icons.trip_origin,
              'From',
              detail.pickupLocation,
              Colors.green,
              fontSettings,
            ),
            _infoRow(
              Icons.location_on,
              'To',
              detail.dropLocation,
              Colors.red,
              fontSettings,
            ),
            _infoRow(
              Icons.directions_car,
              'Vehicle type',
              detail.carType,
              Colors.indigo,
              fontSettings,
            ),
            _infoRow(
              Icons.local_taxi,
              'No. of vehicles',
              '${detail.noOfVehicles}',
              Colors.indigo,
              fontSettings,
            ),
            _infoRow(
              Icons.people,
              'No. of passengers',
              '${detail.noOfPassengers}',
              Colors.indigo,
              fontSettings,
            ),
            _infoRow(
              Icons.phone,
              'Contact',
              detail.contactNumber,
              Colors.green,
              fontSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    Color iconColor,
    FontSettings fontSettings,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: fontSettings.fontWeight,
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

  Widget _statTile(
    IconData icon,
    String value,
    String label,
    FontSettings fontSettings,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Constants.kPrimaryColor.withOpacity(0.45)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: Constants.kPrimaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSettings.fontSize + 2,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSettings.fontSize - 4,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
