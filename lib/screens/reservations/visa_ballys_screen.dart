import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/visa/visa_request_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/visa_provider_ballys.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Status chip colour, shared with the view screen.
Color visaStatusBallysColor(VisaStatusBallys status) {
  switch (status) {
    case VisaStatusBallys.pending:
      return Colors.orange;
    case VisaStatusBallys.checked:
      return Colors.blue;
    case VisaStatusBallys.approved:
      return Colors.green;
    case VisaStatusBallys.rejected:
      return Colors.red;
  }
}

IconData visaStatusBallysIcon(VisaStatusBallys status) {
  switch (status) {
    case VisaStatusBallys.pending:
      return Icons.hourglass_bottom;
    case VisaStatusBallys.checked:
      return Icons.fact_check;
    case VisaStatusBallys.approved:
      return Icons.check_circle;
    case VisaStatusBallys.rejected:
      return Icons.cancel;
  }
}

/// Bally's visa requests from `VisaRequest/Get`, one tab per status plus
/// "All". The API already scopes the list — AD001 / ResApp / ResChk see
/// everything, everyone else by marketing code — so nothing is filtered here.
class VisaBallysScreen extends ConsumerStatefulWidget {
  const VisaBallysScreen({super.key});

  @override
  ConsumerState<VisaBallysScreen> createState() => _VisaBallysScreenState();
}

class _VisaBallysScreenState extends ConsumerState<VisaBallysScreen>
    with TickerProviderStateMixin, ConnectivityMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void onConnectivityRestored() {
    _loadVisaData();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: VisaStatusBallys.values.length + 1,
      vsync: this,
    );
    // Deferred: mutating provider state during initState throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVisaData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVisaData() async {
    await ref.read(visaProviderBallys.notifier).getVisaRequests();
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
    final visaState = ref.watch(visaProviderBallys);

    final requests = visaState.requests.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.userName.toLowerCase().contains(_searchQuery) ||
          r.masterId.toLowerCase().contains(_searchQuery) ||
          r.guests.any((g) =>
              g.bmNumber.toLowerCase().contains(_searchQuery) ||
              g.guestName.toLowerCase().contains(_searchQuery));
    }).toList();

    final byStatus = {
      for (final status in VisaStatusBallys.values)
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
                  hintText: 'Search by guest, BM number...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color.fromARGB(179, 0, 0, 0)),
                ),
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
              )
            : const Text('Visa'),
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
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: _loadVisaData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _buildTab('All', requests.length, Colors.teal),
            for (final status in VisaStatusBallys.values)
              _buildTab(
                status.label,
                byStatus[status]!.length,
                visaStatusBallysColor(status),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildVisaList(
                requests,
                showStatusBorder: true,
                isLoading: visaState.isLoading,
              ),
              for (final status in VisaStatusBallys.values)
                _buildVisaList(
                  byStatus[status]!,
                  showStatusBorder: false,
                  isLoading: visaState.isLoading,
                ),
            ],
          ),
          if (visaState.isLoading)
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
  Widget _buildVisaList(
    List<VisaRequestBallys> requests, {
    required bool showStatusBorder,
    required bool isLoading,
  }) {
    return RefreshIndicator(
      onRefresh: _loadVisaData,
      child: requests.isEmpty && !isLoading
          ? ListView(
              children: const [
                SizedBox(height: 200),
                Center(child: Text('No visa requests available.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: requests.length,
              itemBuilder: (context, index) => _buildVisaCard(
                requests[index],
                showStatusBorder: showStatusBorder,
              ),
            ),
    );
  }

  Widget _buildVisaCard(
    VisaRequestBallys request, {
    required bool showStatusBorder,
  }) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final fontSize = fontSettings.fontSize + 1;
    final fontWeight = fontSettings.fontWeight;
    final lead = request.leadGuest;
    final otherGuests = request.guests.length - 1;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: showStatusBorder
            ? BorderSide(
                color: visaStatusBallysColor(request.status), width: 2)
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
                  : '${lead.bmNumber} - ${lead.guestName}'
                      '${otherGuests > 0 ? '  (+$otherGuests)' : ''}',
              style: TextStyle(
                color: Colors.black,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            ),
            const SizedBox(height: 8),
            _iconRow(
              Icons.flight_land,
              'Arrival: ${_formatDate(request.arrivalDate)}',
              fontSize,
              fontWeight,
              Colors.blueGrey,
            ),
            const SizedBox(height: 4),
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
                    color: visaStatusBallysColor(request.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        visaStatusBallysIcon(request.status),
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
                    '${request.noOfGuests} guest'
                    '${request.noOfGuests == 1 ? '' : 's'} · '
                    '${request.passportImages.length} passport'
                    '${request.passportImages.length == 1 ? '' : 's'}',
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
          ref.read(selectedVisaBallysProvider.notifier).state = request;
          context.push('/reservationMain/visa-ballys/visa-view');
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
