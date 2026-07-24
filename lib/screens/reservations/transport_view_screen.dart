import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_transport_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
                    if (transport.passportFiles.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _PassportFilesSection(
                        files: transport.passportFiles,
                        fontSettings: fontSettings,
                      ),
                    ],
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
                      '${transport.totalVehicles ~/ 2}',
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

/// Passport scans attached to the request. The API only returns server-relative
/// paths, so the host is taken from the configured API URL (Bellagio —
/// `https://bty.world` — being the fallback).
class _PassportFilesSection extends StatefulWidget {
  const _PassportFilesSection({
    required this.files,
    required this.fontSettings,
  });

  final List<TransportPassportFile> files;
  final FontSettings fontSettings;

  @override
  State<_PassportFilesSection> createState() => _PassportFilesSectionState();
}

class _PassportFilesSectionState extends State<_PassportFilesSection> {
  static const String _fallbackHost = 'https://bty.world';

  String? _host;

  @override
  void initState() {
    super.initState();
    _loadHost();
  }

  Future<void> _loadHost() async {
    String host = _fallbackHost;
    try {
      final apiUrl = await StorageUtil.getCurrentApiUrl();
      final uri = apiUrl == null ? null : Uri.tryParse(apiUrl);
      if (uri != null && uri.hasScheme && uri.hasAuthority) {
        host = '${uri.scheme}://${uri.authority}';
      }
    } catch (_) {
      // Fall back to the Bellagio host — transport is Bellagio-only anyway.
    }
    if (mounted) setState(() => _host = host);
  }

  Future<void> _openPdf(String url, String fileName) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open $fileName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openImage(String url, String fileName) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _PassportImageDialog(url: url, fileName: fileName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = widget.fontSettings;
    final host = _host;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passport (${widget.files.length})',
          style: TextStyle(
            fontSize: fontSettings.fontSize + 2,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        if (host == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.files.map((file) {
              final url = file.urlFrom(host);
              final name =
                  file.fileName.isNotEmpty ? file.fileName : 'Passport';

              if (url == null) return _missingTile();
              if (file.isPdf) {
                return _pdfTile(
                  name,
                  fontSettings,
                  () => _openPdf(url, name),
                );
              }
              return _imageTile(url, name, () => _openImage(url, name));
            }).toList(),
          ),
      ],
    );
  }

  Widget _imageTile(String url, String fileName, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 90,
              height: 90,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            width: 90,
            height: 90,
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, color: Colors.black45),
          ),
        ),
      ),
    );
  }

  Widget _pdfTile(
    String fileName,
    FontSettings fontSettings,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                fileName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSettings.fontSize - 3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missingTile() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported, color: Colors.black45),
    );
  }
}

/// Full-screen, zoomable preview of a passport image loaded over the network.
///
/// The phone stays locked to portrait, so a landscape scan is turned inside the
/// viewer instead: it opens already rotated a quarter turn, and the rotate
/// button turns it further.
class _PassportImageDialog extends StatefulWidget {
  const _PassportImageDialog({required this.url, required this.fileName});

  final String url;
  final String fileName;

  @override
  State<_PassportImageDialog> createState() => _PassportImageDialogState();
}

class _PassportImageDialogState extends State<_PassportImageDialog> {
  final TransformationController _transformation = TransformationController();
  int _quarterTurns = 0;

  @override
  void initState() {
    super.initState();
    _turnIfLandscape();
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  /// Reads the image's aspect ratio once it resolves. The listener can fire
  /// synchronously when the thumbnail already warmed the image cache, so the
  /// turn is applied after the frame rather than during initState.
  void _turnIfLandscape() {
    final stream =
        NetworkImage(widget.url).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final isLandscape = info.image.width > info.image.height;
      info.dispose();
      stream.removeListener(listener);
      if (!isLandscape) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _quarterTurns = 1);
      });
    }, onError: (_, __) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _transformation.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      widget.fileName.isNotEmpty
                          ? widget.fileName
                          : 'Passport',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Rotate',
                  icon: const Icon(
                    Icons.rotate_90_degrees_cw,
                    color: Colors.white,
                  ),
                  onPressed: _rotate,
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                transformationController: _transformation,
                maxScale: 5,
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: Image.network(
                    widget.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
