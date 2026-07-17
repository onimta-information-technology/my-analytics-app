import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_transport_provider.dart';
import 'package:ballys_reservation_app/providers/transport_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TransportScreen extends ConsumerStatefulWidget {
  const TransportScreen({super.key});

  @override
  ConsumerState<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends ConsumerState<TransportScreen>
    with TickerProviderStateMixin, ConnectivityMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void onConnectivityRestored() {
    _loadTransportData();
  }

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: TransportStatus.values.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransportData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransportData() async {
    await ref.read(transportProvider.notifier).getTransportData();
  }

  String _formatDateTime(DateTime? dt) {
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

  Color _getStatusColor(TransportStatus status) {
    switch (status) {
      case TransportStatus.transportAssigned:
        return Colors.blue;
      case TransportStatus.pendingTransport:
        return Colors.purple;
      case TransportStatus.rejected:
        return Colors.red;
      case TransportStatus.requested:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(TransportStatus status) {
    switch (status) {
      case TransportStatus.transportAssigned:
        return Icons.fact_check;
      case TransportStatus.pendingTransport:
        return Icons.event_available;
      case TransportStatus.rejected:
        return Icons.cancel;
      case TransportStatus.requested:
        return Icons.hourglass_bottom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transportState = ref.watch(transportProvider);

    final reservations = transportState.reservations.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.mid.toLowerCase().contains(_searchQuery) ||
          r.guestName.toLowerCase().contains(_searchQuery) ||
          r.userName.toLowerCase().contains(_searchQuery) ||
          r.contactNumber.toLowerCase().contains(_searchQuery);
    }).toList();

    final byStatus = {
      for (final status in TransportStatus.values)
        status: reservations.where((r) => r.status == status).toList(),
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/reservationMain');
            }
          },
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name, ID, or contact...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color.fromARGB(179, 0, 0, 0)),
                ),
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
              )
            : const Text('Transport'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, size: 28),
            tooltip: _isSearching ? 'Close Search' : 'Search',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 30),
            tooltip: 'Add Transport',
            onPressed: () =>
                context.push('/reservationMain/transport/transport-add'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: _loadTransportData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final status in TransportStatus.values)
              _buildTab(
                status.label,
                byStatus[status]!.length,
                _getStatusColor(status),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              for (final status in TransportStatus.values)
                _buildTransportList(byStatus[status]!,
                    isLoading: transportState.isLoading),
            ],
          ),
          if (transportState.isLoading)
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

  Widget _buildTab(String title, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: Text(
              count.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportList(
    List<TransportReservation> reservations, {
    required bool isLoading,
  }) {
    return RefreshIndicator(
      onRefresh: _loadTransportData,
      child: reservations.isEmpty && !isLoading
          ? ListView(
              children: const [
                SizedBox(height: 200),
                Center(child: Text('No transport requests available.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: reservations.length,
              itemBuilder: (context, index) =>
                  _buildTransportCard(reservations[index]),
            ),
    );
  }

  Widget _buildTransportCard(TransportReservation reservation) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${reservation.mid} - ${reservation.guestName}',
              style: TextStyle(
                color: Colors.black,
                fontSize: fontSettings.fontSize + 1,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
            const SizedBox(height: 8),
            _iconRow(
              Icons.event,
              'Pickup: ${_formatDateTime(reservation.pickupDate)}',
              fontSettings.fontSize + 1,
              fontSettings.fontWeight,
              Colors.blueGrey,
            ),
            const SizedBox(height: 4),
            _iconRow(
              Icons.phone,
              reservation.contactNumber,
              fontSettings.fontSize + 1,
              fontSettings.fontWeight,
              Colors.green,
            ),
            const SizedBox(height: 4),
            _iconRow(
              Icons.person_outline,
              'Requested by: ${reservation.userName}',
              fontSettings.fontSize + 1,
              fontSettings.fontWeight,
              Colors.blue,
            ),
            const SizedBox(height: 4),
            _iconRow(
              Icons.schedule,
              'Requested: ${_formatDateTime(reservation.createdDate)}',
              fontSettings.fontSize + 1,
              fontSettings.fontWeight,
              Colors.blueGrey,
            ),

            // ✅ Show taxi/driver assignment only in the Assigned tab
            if (reservation.isAssigned) ...[
              if ((reservation.receivedBy ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                _iconRow(
                  Icons.person_outline,
                  'Received by: ${reservation.receivedBy!.trim()}',
                  fontSettings.fontSize + 1,
                  fontSettings.fontWeight,
                  Colors.blue,
                ),
              ],
              if (reservation.receivedDate != null) ...[
                const SizedBox(height: 4),
                _iconRow(
                  Icons.fact_check,
                  'Received: ${_formatDateTime(reservation.receivedDate)}',
                  fontSettings.fontSize + 1,
                  fontSettings.fontWeight,
                  Colors.blue,
                ),
              ],
              if ((reservation.taxiPlateNumber ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                _iconRow(
                  Icons.local_taxi,
                  'Taxi plate: ${reservation.taxiPlateNumber!.trim()}',
                  fontSettings.fontSize + 1,
                  fontSettings.fontWeight,
                  Colors.indigo,
                ),
              ],
              if ((reservation.driverName ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                _iconRow(
                  Icons.badge_outlined,
                  'Driver: ${reservation.driverName!.trim()}',
                  fontSettings.fontSize + 1,
                  fontSettings.fontWeight,
                  Colors.indigo,
                ),
              ],
              if ((reservation.driverPhoneNumber ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                _iconRow(
                  Icons.phone_in_talk,
                  'Driver phone: ${reservation.driverPhoneNumber!.trim()}',
                  fontSettings.fontSize + 1,
                  fontSettings.fontWeight,
                  Colors.green,
                ),
              ],
            ],

            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(reservation.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(reservation.status),
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            reservation.status.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${reservation.details.length} '
                      '${reservation.details.length == 1 ? 'trip' : 'trips'} · '
                      '${reservation.totalVehicles} veh · '
                      '${reservation.totalPassengers} pax',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          ref
              .read(selectedTransportProvider.notifier)
              .setSelectedTransport(reservation);
          context.push('/reservationMain/transport/transport-view');
        },
      ),
    );
  }

  Widget _iconRow(
    IconData icon,
    String text,
    double fontSize,
    FontWeight fontWeight,
    Color iconColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
