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

  /// Groups trip legs by `mid` so a member with several vehicle/car-type
  /// entries under the same `mid` renders as a single card instead of one
  /// card per array entry.
  static List<List<TransportDetail>> _groupDetailsByMid(
    List<TransportDetail> details,
  ) {
    final order = <String>[];
    final groups = <String, List<TransportDetail>>{};
    for (final d in details) {
      final key = d.mid;
      if (!groups.containsKey(key)) {
        order.add(key);
        groups[key] = [];
      }
      groups[key]!.add(d);
    }
    return order.map((key) => groups[key]!).toList();
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
    final groupedDetails = transport == null
        ? const <List<TransportDetail>>[]
        : _groupDetailsByMid(transport.details);

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
                      'Trips (${groupedDetails.length})',
                      style: TextStyle(
                        fontSize: fontSettings.fontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (groupedDetails.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No trip details for this request.'),
                        ),
                      )
                    else
                      ...groupedDetails.asMap().entries.map(
                            (entry) => _TripCard(
                              index: entry.key + 1,
                              details: entry.value,
                              fontSettings: fontSettings,
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
                  if (transport.isAssigned) ...[
                    const Divider(height: 20),
                    _infoRow(
                      Icons.person_outline,
                      'Received by',
                      transport.receivedBy ?? '',
                      Colors.blue,
                      fontSettings,
                    ),
                    _infoRow(
                      Icons.fact_check,
                      'Received',
                      _formatDateTime(transport.receivedDate),
                      Colors.blue,
                      fontSettings,
                    ),
                    _infoRow(
                      Icons.local_taxi,
                      'Taxi plate',
                      transport.taxiPlateNumber ?? '',
                      Colors.indigo,
                      fontSettings,
                    ),
                    _infoRow(
                      Icons.badge_outlined,
                      'Driver',
                      transport.driverName ?? '',
                      Colors.indigo,
                      fontSettings,
                    ),
                    _infoRow(
                      Icons.phone_in_talk,
                      'Driver phone',
                      transport.driverPhoneNumber ?? '',
                      Colors.green,
                      fontSettings,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _infoRow(
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

/// One card per unique `mid`. `details` holds every leg the API returned for
/// that `mid` — usually one, but sometimes several that only differ by
/// vehicle/car type, which are listed together instead of duplicating the
/// card.
class _TripCard extends StatefulWidget {
  const _TripCard({
    required this.index,
    required this.details,
    required this.fontSettings,
  });

  final int index;
  final List<TransportDetail> details;
  final FontSettings fontSettings;

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final base = details.first;
    final fontSettings = widget.fontSettings;
    final totalVehicles =
        details.fold<int>(0, (sum, d) => sum + d.noOfVehicles);
    final multipleVehicleTypes = details.length > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
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
                          '${widget.index}',
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
                          '${base.mid} - ${base.guestName}',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize + 1,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                         
                             base.hireType,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.expand_more,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  if (!_expanded) ...[
                    const SizedBox(height: 10),
                    _collapsedSummary(base, fontSettings),
                  ],
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 20),
                        TransportViewScreen._infoRow(
                          Icons.event,
                          'Pickup date',
                          TransportViewScreen._formatDate(base.pickupDate),
                          Colors.blueGrey,
                          fontSettings,
                        ),
                        TransportViewScreen._infoRow(
                          Icons.access_time,
                          'Pickup time',
                          base.pickupTime,
                          Colors.blueGrey,
                          fontSettings,
                        ),
                        TransportViewScreen._infoRow(
                          Icons.trip_origin,
                          'From',
                          base.pickupLocation,
                          Colors.green,
                          fontSettings,
                        ),
                        TransportViewScreen._infoRow(
                          Icons.location_on,
                          'To',
                          base.dropLocation,
                          Colors.red,
                          fontSettings,
                        ),
                        TransportViewScreen._infoRow(
                          Icons.people,
                          'No. of passengers',
                          '${details.fold<int>(0, (sum, d) => sum + d.noOfPassengers)}',
                          Colors.indigo,
                          fontSettings,
                        ),
                        TransportViewScreen._infoRow(
                          Icons.phone,
                          'Contact',
                          base.contactNumber,
                          Colors.green,
                          fontSettings,
                        ),
                        const Divider(height: 20),
                        Text(
                          multipleVehicleTypes ? 'Vehicles' : 'Vehicle',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...details.map(
                          (d) => _vehicleEntry(d, fontSettings),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _vehicleEntry(TransportDetail detail, FontSettings fontSettings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 250, 244, 232),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, size: 18, color: Colors.indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  detail.carType.isEmpty ? 'N/A' : detail.carType,
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              // Text(
              //   'x${detail.noOfVehicles}',
              //   style: TextStyle(
              //     fontSize: fontSettings.fontSize,
              //     fontWeight: FontWeight.bold,
              //     color: Colors.indigo,
              //   ),
              // ),
              const SizedBox(width: 10),
              Icon(Icons.people, size: 16, color: Colors.black45),
              const SizedBox(width: 4),
              Text(
                '${detail.noOfPassengers}',
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          if (detail.hasDriverInfo) ...[
            const SizedBox(height: 6),
            TransportViewScreen._infoRow(
              Icons.person_outline,
              'Received by',
              detail.receivedBy ?? '',
              Colors.blue,
              fontSettings,
            ),
            TransportViewScreen._infoRow(
              Icons.fact_check,
              'Received',
              TransportViewScreen._formatDateTime(detail.receivedDate),
              Colors.blue,
              fontSettings,
            ),
            TransportViewScreen._infoRow(
              Icons.local_taxi,
              'Taxi plate',
              detail.taxiPlateNumber ?? '',
              Colors.indigo,
              fontSettings,
            ),
            TransportViewScreen._infoRow(
              Icons.badge_outlined,
              'Driver',
              detail.driverName ?? '',
              Colors.indigo,
              fontSettings,
            ),
            TransportViewScreen._infoRow(
              Icons.phone_in_talk,
              'Driver phone',
              detail.driverPhoneNumber ?? '',
              Colors.green,
              fontSettings,
            ),
          ],
        ],
      ),
    );
  }

  Widget _collapsedSummary(TransportDetail detail, FontSettings fontSettings) {
    final route = [
      detail.pickupLocation.isEmpty ? 'N/A' : detail.pickupLocation,
      detail.dropLocation.isEmpty ? 'N/A' : detail.dropLocation,
    ].join('  →  ');
    final when = [
      TransportViewScreen._formatDate(detail.pickupDate),
      if (detail.pickupTime.isNotEmpty) detail.pickupTime,
    ].join('  •  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.alt_route, size: 18, color: Colors.black45),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                route,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.schedule, size: 18, color: Colors.black45),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                when,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSettings.fontSize - 1,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
