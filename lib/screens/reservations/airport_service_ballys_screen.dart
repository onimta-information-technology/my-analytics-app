import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/airport_service/airport_service_ballys.dart';
import 'package:ballys_reservation_app/providers/airport_service_provider_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Status chip colour, shared with the view screen.
Color airportServiceStatusBallysColor(AirportServiceStatusBallys status) {
  switch (status) {
    case AirportServiceStatusBallys.pending:
      return Colors.orange;
    case AirportServiceStatusBallys.checked:
      return Colors.blue;
    case AirportServiceStatusBallys.approved:
      return Colors.green;
    case AirportServiceStatusBallys.rejected:
      return Colors.red;
  }
}

IconData airportServiceStatusBallysIcon(AirportServiceStatusBallys status) {
  switch (status) {
    case AirportServiceStatusBallys.pending:
      return Icons.hourglass_bottom;
    case AirportServiceStatusBallys.checked:
      return Icons.fact_check;
    case AirportServiceStatusBallys.approved:
      return Icons.check_circle;
    case AirportServiceStatusBallys.rejected:
      return Icons.cancel;
  }
}

/// Bally's airport service requests from `AirportService/Get`, one tab per
/// status plus "All". The API already scopes the list — AD001 / ResApp /
/// ResChk see everything, everyone else by marketing code — so nothing is
/// filtered here.
class AirportServiceBallysScreen extends ConsumerStatefulWidget {
  const AirportServiceBallysScreen({super.key});

  @override
  ConsumerState<AirportServiceBallysScreen> createState() =>
      _AirportServiceBallysScreenState();
}

class _AirportServiceBallysScreenState
    extends ConsumerState<AirportServiceBallysScreen>
    with TickerProviderStateMixin, ConnectivityMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void onConnectivityRestored() {
    _loadData();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AirportServiceStatusBallys.values.length + 1,
      vsync: this,
    );
    // Deferred: mutating provider state during initState throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await ref.read(airportServiceProviderBallys.notifier).getAirportServices();
  }

  Future<void> _openAdd() async {
    final saved = await context.push<bool>(
      '/reservationMain/airport-service-ballys/airport-service-add',
    );
    if (saved == true && mounted) _loadData();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final hourStr = hour12.toString().padLeft(2, '0');
    return '${_formatDate(dt)}  $hourStr:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final serviceState = ref.watch(airportServiceProviderBallys);

    final requests = serviceState.requests.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.userName.toLowerCase().contains(_searchQuery) ||
          r.masterId.toLowerCase().contains(_searchQuery) ||
          r.guests.any((g) =>
              g.mid.toLowerCase().contains(_searchQuery) ||
              g.guestName.toLowerCase().contains(_searchQuery) ||
              g.serviceType.toLowerCase().contains(_searchQuery));
    }).toList();

    final byStatus = {
      for (final status in AirportServiceStatusBallys.values)
        status: requests.where((r) => r.status == status).toList(),
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
                  hintText: 'Search by guest, MID...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color.fromARGB(179, 0, 0, 0)),
                ),
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
              )
            : const Text('Airport Services'),
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
            tooltip: 'Add Airport Service',
            onPressed: _openAdd,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _buildTab('All', requests.length, Colors.teal),
            for (final status in AirportServiceStatusBallys.values)
              _buildTab(
                status.label,
                byStatus[status]!.length,
                airportServiceStatusBallysColor(status),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildList(
                requests,
                showStatusBorder: true,
                isLoading: serviceState.isLoading,
              ),
              for (final status in AirportServiceStatusBallys.values)
                _buildList(
                  byStatus[status]!,
                  showStatusBorder: false,
                  isLoading: serviceState.isLoading,
                ),
            ],
          ),
          if (serviceState.isLoading)
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

  /// [showStatusBorder] is set on the "All" tab, where each card is outlined
  /// in its status colour so the mix of statuses is readable at a glance.
  Widget _buildList(
    List<AirportServiceBallys> requests, {
    required bool showStatusBorder,
    required bool isLoading,
  }) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: requests.isEmpty && !isLoading
          ? ListView(
              children: const [
                SizedBox(height: 200),
                Center(child: Text('No airport service requests available.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: requests.length,
              itemBuilder: (context, index) => _buildCard(
                requests[index],
                showStatusBorder: showStatusBorder,
              ),
            ),
    );
  }

  Widget _buildCard(
    AirportServiceBallys request, {
    required bool showStatusBorder,
  }) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final fontSize = fontSettings.fontSize + 1;
    final fontWeight = fontSettings.fontWeight;
    final lead = request.leadGuest;
    final otherGuests = request.guests.length - 1;
    final serviceTypes =
        request.guests.map((g) => g.serviceType).where((s) => s.isNotEmpty);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: showStatusBorder
            ? BorderSide(
                color: airportServiceStatusBallysColor(request.status),
                width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              lead == null
                  ? request.masterId
                  : '${lead.mid} - ${lead.guestName}'
                      '${otherGuests > 0 ? '  (+$otherGuests)' : ''}',
              style: TextStyle(
                color: Colors.black,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            ),
            const SizedBox(height: 8),
            if (serviceTypes.isNotEmpty) ...[
              _iconRow(
                Icons.local_airport,
                'Service: ${serviceTypes.toSet().join(', ')}',
                fontSize,
                fontWeight,
                Colors.blueGrey,
              ),
              const SizedBox(height: 4),
            ],
            if (request.approvePerson != null) ...[
              _iconRow(
                Icons.verified_user_outlined,
                'Approver: ${request.approvePerson!.authorizationPerson}',
                fontSize,
                fontWeight,
                Colors.deepPurple,
              ),
              const SizedBox(height: 4),
            ],
            _iconRow(
              Icons.person_outline,
              'Requested by: ${request.userName}',
              fontSize,
              fontWeight,
              Colors.blue,
            ),
            const SizedBox(height: 4),
            _iconRow(
              Icons.schedule,
              'Requested: ${_formatDateTime(request.createdDate)}',
              fontSize,
              fontWeight,
              Colors.blueGrey,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: airportServiceStatusBallysColor(request.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        airportServiceStatusBallysIcon(request.status),
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          request.status.label,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${request.guests.length} guest'
                    '${request.guests.length == 1 ? '' : 's'} · '
                    '${request.totalPax} pax',
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          ref.read(selectedAirportServiceBallysProvider.notifier).state =
              request;
          context.push(
              '/reservationMain/airport-service-ballys/airport-service-view');
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
