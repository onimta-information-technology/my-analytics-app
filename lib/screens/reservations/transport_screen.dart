import 'dart:async';
import 'dart:math' as math;

import 'package:ballys_reservation_app/components/airport_pickup_status_badge.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/transport/transport_reservation.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_transport_provider.dart';
import 'package:ballys_reservation_app/providers/transport_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TransportScreen extends ConsumerStatefulWidget {
  const TransportScreen({super.key, this.highlightMasterId});

  /// `master_id` of the request to reveal on open — set when the screen is
  /// reached from a transport push notification, so the user lands on the
  /// right tab with that request scrolled into view and highlighted.
  final String? highlightMasterId;

  @override
  ConsumerState<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends ConsumerState<TransportScreen>
    with TickerProviderStateMixin, ConnectivityMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearching = false;

  // ── Notification highlight ──
  // The request a push notification asked us to show. It is revealed once
  // (tab switch + scroll) and the highlight fades away a few seconds later.
  String? _highlightMasterId;
  bool _highlightRevealed = false;
  Timer? _highlightTimer;
  final Map<TransportStatus, ScrollController> _scrollControllers = {
    for (final status in TransportStatus.values) status: ScrollController(),
  };
  final Map<String, GlobalKey> _cardKeys = {};

  // ── Visibility gating ──
  // Sales code AD001 sees every transport request; everyone else only sees the
  // requests they raised themselves.
  String? _userSalesCode;
  String? _userName;
  bool _accessLoaded = false;

  @override
  void onConnectivityRestored() {
    _loadTransportData();
  }

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: TransportStatus.values.length, vsync: this);
    _highlightMasterId = _normaliseMasterId(widget.highlightMasterId);
    _loadAccessSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransportData();
    });
  }

  /// A second notification tap while the screen is already open reuses this
  /// route, so pick up the new master id and reveal that request instead.
  @override
  void didUpdateWidget(covariant TransportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = _normaliseMasterId(widget.highlightMasterId);
    if (incoming == null) return;
    // Same request tapped again is worth re-revealing once its highlight has
    // faded, but not while it is still lit up.
    if (incoming == _normaliseMasterId(oldWidget.highlightMasterId) &&
        incoming == _highlightMasterId) {
      return;
    }
    _highlightTimer?.cancel();
    setState(() {
      _highlightMasterId = incoming;
      _highlightRevealed = false;
      // A highlighted request must not stay hidden behind a stale search.
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadTransportData();
  }

  static String? _normaliseMasterId(String? masterId) {
    final trimmed = masterId?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _loadAccessSettings() async {
    final salesCode = await StorageUtil.getSalesCode();
    final userName = await StorageUtil.getUserName();
    if (!mounted) return;
    setState(() {
      _userSalesCode = salesCode;
      _userName = userName;
      _accessLoaded = true;
    });
    _revealHighlighted();
  }

  bool get _canSeeAllRequests =>
      (_userSalesCode ?? '').trim().toUpperCase() == 'AD001';

  /// AD001 sees everything; other users only see requests whose `user_name`
  /// matches their own login.
  bool _isVisibleToUser(TransportReservation reservation) {
    if (_canSeeAllRequests) return true;
    final loggedInUser = (_userName ?? '').trim().toLowerCase();
    print('Logged-in user: $loggedInUser, Reservation user: ${reservation.userName.trim().toLowerCase()}');
    if (loggedInUser.isEmpty) return false;
    return reservation.userName.trim().toLowerCase() == loggedInUser;
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransportData() async {
    await ref.read(transportProvider.notifier).getTransportData();
    if (!mounted) return;
    _revealHighlighted();
  }

  /// Opens the tab holding the notification's request and scrolls it into
  /// view. Does nothing until both the access settings and the transport data
  /// are in — whichever finishes last drives the reveal.
  void _revealHighlighted() {
    final masterId = _highlightMasterId;
    if (masterId == null || _highlightRevealed || !_accessLoaded) return;

    TransportReservation? target;
    for (final reservation in ref.read(transportProvider).reservations) {
      if (reservation.masterId == masterId && _isVisibleToUser(reservation)) {
        target = reservation;
        break;
      }
    }
    if (target == null) return; // Not loaded (or not ours) — nothing to show.

    _highlightRevealed = true;

    final tabIndex = TransportStatus.values.indexOf(target.status);
    if (tabIndex >= 0 && _tabController.index != tabIndex) {
      _tabController.animateTo(tabIndex);
    }

    final found = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToHighlighted(found);
    });
  }

  /// Brings the highlighted card on screen. The list is built lazily, so keep
  /// paging down until the card exists, then hand over to [Scrollable].
  Future<void> _scrollToHighlighted(TransportReservation target) async {
    final controller = _scrollControllers[target.status];
    final key = _cardKeys[target.masterId];
    if (controller == null || key == null) {
      _startHighlightTimer();
      return;
    }

    for (var attempt = 0; attempt < 15; attempt++) {
      if (!mounted) return;

      final cardContext = key.currentContext;
      if (cardContext != null && cardContext.mounted) {
        await Scrollable.ensureVisible(
          cardContext,
          alignment: 0.15,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
        break;
      }

      if (!controller.hasClients) {
        await Future.delayed(const Duration(milliseconds: 80));
        continue;
      }

      final position = controller.position;
      if (position.pixels >= position.maxScrollExtent) break;
      await controller.animateTo(
        math.min(
          position.pixels + position.viewportDimension * 0.8,
          position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }

    _startHighlightTimer();
  }

  /// The highlight is a pointer, not a state — drop it once it has been seen.
  void _startHighlightTimer() {
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _highlightMasterId = null);
    });
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

    // Hold everything back until the logged-in user's sales code is known, so a
    // non-AD001 user never sees other users' requests on the first frame.
    final visible = _accessLoaded
        ? transportState.reservations.where(_isVisibleToUser).toList()
        : const <TransportReservation>[];

    final reservations = visible.where((r) {
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
                    status: status,
                    isLoading: transportState.isLoading || !_accessLoaded),
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
    required TransportStatus status,
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
              controller: _scrollControllers[status],
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: reservations.length,
              itemBuilder: (context, index) =>
                  _buildTransportCard(reservations[index]),
            ),
    );
  }

  Widget _buildTransportCard(TransportReservation reservation) {
    final fontSettings = ref.watch(fontSettingsProvider);

    // The request a notification pointed us at wears a gold border and a warm
    // tint until the highlight times out.
    final isHighlighted = _highlightMasterId != null &&
        reservation.masterId == _highlightMasterId;
    final cardKey =
        _cardKeys.putIfAbsent(reservation.masterId, () => GlobalKey());

    return Card(
      key: cardKey,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: isHighlighted ? 8 : 4,
      color: isHighlighted ? const Color(0xFFFFF6E0) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isHighlighted
            ? const BorderSide(color: Constants.kPrimaryColor, width: 2)
            : BorderSide.none,
      ),
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

            // ✅ Airport pickup progress reported by transport staff
            if (reservation.hasAirportPickup) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AirportPickupStatusBadge(
                  status: reservation.airportPickupStage,
                  fontSettings: fontSettings,
                ),
              ),
            ],

            // ✅ Latest amendment note, so it's visible without opening the card
            if (reservation.hasAmendments) ...[
              const SizedBox(height: 8),
              _amendmentPreview(reservation, fontSettings),
            ],

            const SizedBox(height: 8),
            Row(
              children: [
                if (reservation.hasAmendments) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit_note,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${reservation.amendments.length}',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
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
                      // '${reservation.details.length/2} '
                      // '${reservation.details.length == 1 ? 'trip' : 'trips'} · '
                      // '${reservation.totalVehicles} veh · '
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

  /// Latest amendment note on the card, with a hint when there are older ones.
  Widget _amendmentPreview(
    TransportReservation reservation,
    FontSettings fontSettings,
  ) {
    final latest = reservation.latestAmendment!;
    final older = reservation.amendments.length - 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 248, 240),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepOrange.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.edit_note, size: 20, color: Colors.deepOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  latest.amendment.isEmpty ? 'N/A' : latest.amendment,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: fontSettings.fontWeight,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (latest.userName.isNotEmpty) latest.userName,
              _formatDateTime(latest.createdDate),
              if (older > 0) '+$older more',
            ].join('  •  '),
            style: TextStyle(
              fontSize: fontSettings.fontSize - 2,
              color: Colors.black54,
            ),
          ),
        ],
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
