import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import '../models/air_ticket.dart';
import '../providers/air_ticket_provider.dart';

class AirTicketScreen extends ConsumerStatefulWidget {
  const AirTicketScreen({super.key});

  @override
  ConsumerState<AirTicketScreen> createState() => _AirTicketScreenState();
}

class _AirTicketScreenState extends ConsumerState<AirTicketScreen>
    with SingleTickerProviderStateMixin,ConnectivityMixin {
  late TabController _outerTabController;
  bool _isLoading = false;
  bool _isRefreshing = false;
@override
  void onConnectivityRestored() {
   _refresh(); 
  }
  @override
  void initState() {
    super.initState();
    // Outer tabs: Past | Recent
    _outerTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 1,
    );
    _outerTabController.addListener(() => setState(() {}));
    _loadData();
  }

  Future<void> _loadData() async {
    final currentState = ref.read(airTicketProvider);
    final isEmpty = currentState.recent.isEmpty && currentState.past.isEmpty;

    if (isEmpty) {
      setState(() => _isLoading = true);
      await ref.read(airTicketProvider.notifier).fetchAll();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await ref.read(airTicketProvider.notifier).fetchAll();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  void dispose() {
    _outerTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketState = ref.watch(airTicketProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/menu');
            }
          },
        ),
        title: const Text('Package Guest', style: TextStyle(fontSize: 20.0)),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.fromARGB(255, 114, 6, 100),
                      ),
                    ),
                  )
                : const Icon(Icons.refresh, size: 28),
            onPressed: _isRefreshing ? null : _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _outerTabController,
          indicatorColor: const Color.fromARGB(255, 235, 0, 0),
          tabs: const [
            Tab(child: Text('Past', style: TextStyle(fontSize: 17.0,fontWeight: FontWeight.w900))),
            Tab(child: Text('Recent', style: TextStyle(fontSize: 17.0,fontWeight: FontWeight.w900))),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _outerTabController,
            children: [
              _VisitStatusTabView(
                tickets: ticketState.past,
                showPending: false,
              ),
              _VisitStatusTabView(tickets: ticketState.recent),
            ],
          ),
          if (_isLoading || _isRefreshing)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color.fromARGB(135, 117, 115, 115),
                ),
                child: const Center(
                  child: RefreshProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Constants.kSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          const Watermark(),
        ],
      ),
    );
  }
}

// ── Inner tab view: Pending | Not Visited | Visited ────────────────────────

class _VisitStatusTabView extends StatefulWidget {
  final List<AirTicket> tickets;
  final bool showPending;
  const _VisitStatusTabView({required this.tickets, this.showPending = true});

  @override
  State<_VisitStatusTabView> createState() => _VisitStatusTabViewState();
}

class _VisitStatusTabViewState extends State<_VisitStatusTabView>
    with SingleTickerProviderStateMixin {
  late TabController _innerTabController;

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(
      length: widget.showPending ? 3 : 2,
      vsync: this,
    );
    _innerTabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _innerTabController.dispose();
    super.dispose();
  }

  List<AirTicket> get _pending =>
      widget.tickets.where((t) => t.isPending).toList();
  List<AirTicket> get _notVisited =>
      widget.tickets.where((t) => t.isNotVisited).toList();
  List<AirTicket> get _visited =>
      widget.tickets.where((t) => t.isVisited).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Inner tab bar
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _innerTabController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: Constants.kSecondaryColor,
            labelColor: Constants.kSecondaryColor,
            unselectedLabelColor: const Color.fromARGB(255, 0, 0, 0),
            labelStyle: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.w900,
            ),
            tabs: [
               Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 15),
                    const SizedBox(width: 4),
                    Text('Visited (${_visited.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel_outlined, size: 15),
                    const SizedBox(width: 4),
                    Text('Not Visited (${_notVisited.length})'),
                  ],
                ),
              ),
            
               if (widget.showPending)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_empty, size: 15),
                      const SizedBox(width: 4),
                      Text('Pending (${_pending.length})'),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTabController,
            children: [
             _AirTicketList(
                tickets: _visited,
                statusColor: Colors.green,
                emptyMessage: 'No visited reservations',
              ),
              _AirTicketList(
                tickets: _notVisited,
                statusColor: Constants.kSecondaryColor,
                emptyMessage: 'No unvisited reservations',
              ),
             
                if (widget.showPending)
                _AirTicketList(
                  tickets: _pending,
                  statusColor: Colors.orange,
                  emptyMessage: 'No pending reservations',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── List of air ticket cards ───────────────────────────────────────────────

class _AirTicketList extends ConsumerWidget {
  final List<AirTicket> tickets;
  final Color statusColor;
  final String emptyMessage;

  const _AirTicketList({
    required this.tickets,
    required this.statusColor,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);

    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.airplane_ticket_outlined,
              size: 64,
              color: Color.fromARGB(255, 0, 0, 0),
            ),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: tickets.length,
      itemBuilder: (context, index) => _AirTicketCard(
        ticket: tickets[index],
        statusColor: statusColor,
        ref: ref,
        fontSettings: fontSettings,
      ),
    );
  }
}

// ── Individual card ────────────────────────────────────────────────────────

class _AirTicketCard extends StatelessWidget {
  final AirTicket ticket;
  final Color statusColor;
  final WidgetRef ref;
  final FontSettings fontSettings;

  const _AirTicketCard({
    required this.ticket,
    required this.statusColor,
    required this.ref,
    required this.fontSettings,
  });

  String _formatDate(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);

  String _formatCost(double cost) =>
      NumberFormat('#,##0.00', 'en_US').format(cost);

  Color get _visitBadgeColor {
    if (ticket.isPending) return Colors.orange;
    if (ticket.isVisited) return Colors.green;
    return Constants.kSecondaryColor;
  }

  String get _visitBadgeLabel {
    if (ticket.isPending) return 'Pending';
    if (ticket.isVisited) return 'Visited';
    return 'Not Visited';
  }

  Future<void> _navigateToProfile(BuildContext context) async {
    final mid = ticket.mid.trim();
    if (mid.isEmpty) return;

    // Member-ID format differs per location: prefixed (BM/BL/BN) on Ballys,
    // numeric (no prefix) on Bellagio. Only enforce the BM prefix on prefixed
    // locations so numeric-id locations can navigate too.
    final location = await StorageUtil.getCurrentLocation();
    final code = location?.code.split('_').first ?? '';
    final isNumeric = ["BELLAGIO"].contains(code);
    if (!isNumeric && !mid.toUpperCase().startsWith('BM')) return;

    if (!context.mounted) return;

    ref
        .read(selectedGuestProvider.notifier)
        .setSelectedGuest(
          Guest(
            mid: ticket.mid,
            memberName: ticket.mname ?? ticket.mid,
            country: '',
            lastVisitDate: ticket.lvd?.toString() ?? '',
            age: 0,
            gRating:ticket.gRating,
            mGroup: '',
            gName: ticket.mktPerson ?? 'N/A',
            mobile: '',
          ),
        );
    context.push('/home/profile');
  }

  @override
  Widget build(BuildContext context) {
    // final isBmMember = ticket.mid.toUpperCase().startsWith('BM');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: Name + Visit badge ──────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.mname ?? ticket.mid,
                        style: TextStyle(
                          fontWeight: fontSettings.fontWeight,
                          fontSize: fontSettings.fontSize + 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ── Tappable BM number ─────────────────────────
                      GestureDetector(
                        onTap: () => _navigateToProfile(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Constants.kPrimaryColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Constants.kPrimaryColor.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_search,
                                size: 18,
                                color: const Color.fromARGB(255, 0, 0, 0),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ticket.mid,
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize + 2,
                                  fontWeight: fontSettings.fontWeight,
                                  //color: Constants.kPrimaryColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: const Color.fromARGB(255, 0, 0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Visit status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _visitBadgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _visitBadgeLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 16),

            // ── Reservation number & cost ───────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  size: 18,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Reservation No: ${ticket.reservNo}',
                    style: TextStyle(
                      fontSize: fontSettings.fontSize + 2,
                      fontWeight: fontSettings.fontWeight,
                      color: Color.fromARGB(255, 64, 0, 255),
                    ),
                  ),
                ),
                // Text(
                //   'LKR ${_formatCost(ticket.tktCost)}',
                //   style: TextStyle(
                //     fontWeight: fontSettings.fontWeight,
                //     fontSize: fontSettings.fontSize+2,
                //     color: statusColor,
                //   ),
                // ),
              ],
            ),
            Row(
              children: [
                const Icon(
                  Icons.money,
                  size: 18,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
                const SizedBox(width: 6),
                // Expanded(
                //   child: Text(
                //     'Reservation No: ${ticket.reservNo}',
                //     style: TextStyle(fontSize: fontSettings.fontSize+2,fontWeight: fontSettings.fontWeight),
                //   ),
                // ),
                Text(
                  'Cost:LKR ${_formatCost(ticket.tktCost)}',
                  style: TextStyle(
                    fontWeight: fontSettings.fontWeight,
                    fontSize: fontSettings.fontSize + 3,
                    color: Color.fromARGB(255, 255, 0, 0),
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
                    //color: statusColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ── Airline + Class + Sector ────────────────────────────────
            // Row(
            //   children: [
            //     const Icon(
            //       Icons.flight,
            //       size: 18,
            //       color: Color.fromARGB(255, 0, 0, 0),
            //     ),
            //     const SizedBox(width: 6),
            //     Text(
            //       '${ticket.airLine} · ${ticket.cls}',
            //       style: TextStyle(
            //         fontWeight: fontSettings.fontWeight,
            //         fontSize: fontSettings.fontSize + 2,
            //       ),
            //     ),
            //     const SizedBox(width: 8),
            //     Expanded(
            //       child: Text(
            //         ticket.sector,
            //         style: TextStyle(
            //           fontSize: fontSettings.fontSize + 2,
            //           fontWeight: fontSettings.fontWeight,
            //         ),
            //         overflow: TextOverflow.ellipsis,
            //       ),
            //     ),
            //   ],
            // ),
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Icon(
      Icons.flight,
      size: 18,
      color: Color.fromARGB(255, 0, 0, 0),
    ),
    const SizedBox(width: 6),
    Expanded(
      child: Text(
        '${ticket.airLine} · ${ticket.cls} · ${ticket.sector}',
        style: TextStyle(
          fontWeight: fontSettings.fontWeight,
          fontSize: fontSettings.fontSize + 2,
        ),
        softWrap: true,
      ),
    ),
  ],
),
            const SizedBox(height: 6),

            // ── Dates ───────────────────────────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
                const SizedBox(width: 6),
                Text(
                  'Arrival Date: ${_formatDate(ticket.arrDate)}',
                  style: TextStyle(
                    fontSize: fontSettings.fontSize + 1,
                    fontWeight: fontSettings.fontWeight,
                    color: Color.fromARGB(255, 64, 0, 255),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // const Icon(Icons.calendar_today, size: 18, color: Color.fromARGB(255, 0, 0, 0)),
                // const SizedBox(width: 6),
                // Text(
                //   'Arr: ${_formatDate(ticket.arrDate)}',
                //   style: TextStyle(fontSize: fontSettings.fontSize+1, fontWeight: fontSettings.fontWeight,),
                // ),
                // const SizedBox(width: 12),
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
                const SizedBox(width: 4),
                Text(
                  'Departure Date: ${_formatDate(ticket.depDate)}',
                  style: TextStyle(
                    fontSize: fontSettings.fontSize + 1,
                    fontWeight: fontSettings.fontWeight,
                    color: Color.fromARGB(255, 64, 0, 255),
                  ),
                ),
              ],
            ),

            if (ticket.lvd != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.history,
                    size: 18,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Last Visit: ${_formatDate(ticket.lvd!)}',
                    style: TextStyle(
                      fontSize: fontSettings.fontSize + 1,
                      fontWeight: fontSettings.fontWeight,
                      color: Color.fromARGB(255, 64, 0, 255),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 6),

            // ── Remarks ─────────────────────────────────────────────────
            if (ticket.remarks.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Remark: ${ticket.remarks}',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                          color: Color.fromARGB(255, 255, 0, 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // ── Footer: Requested by / Approved by ──────────────────────
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.person_outline,
                    label: 'Request By: ${ticket.requestBy}',
                    fontSettings: fontSettings,
                  ),
                ),
                // const SizedBox(width: 6),
                // Expanded(
                //   child: _InfoChip(
                //     icon: Icons.verified_user_outlined,
                //     label: 'Approve By: ${ticket.approvedBy}',
                //     fontSettings: fontSettings,
                //   ),
                // ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Expanded(
                //   child: _InfoChip(
                //     icon: Icons.person_outline,
                //     label: 'Request By: ${ticket.requestBy}',
                //     fontSettings: fontSettings,
                //   ),
                // ),
                // const SizedBox(width: 6),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.verified_user_outlined,
                    label: 'Approve By: ${ticket.approvedBy}',
                    fontSettings: fontSettings,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Expanded(
                //   child: _InfoChip(
                //     icon: Icons.person_outline,
                //     label: 'Request By: ${ticket.requestBy}',
                //     fontSettings: fontSettings,
                //   ),
                // ),
                // const SizedBox(width: 6),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.verified_user_outlined,
                    label: 'Marketing Person: ${ticket.mktPerson}',
                    fontSettings: fontSettings,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final FontSettings fontSettings;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.fontSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Color.fromARGB(255, 0, 0, 0)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
