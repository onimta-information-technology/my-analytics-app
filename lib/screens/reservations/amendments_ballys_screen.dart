import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/amendment_ballys.dart';
import 'package:ballys_reservation_app/providers/amendment_provider_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Which feed the list is showing.
enum _AmendmentFilter { all, airTicket, hotel }

/// The raised amendments, in the same four-tab workflow the Ballys reservation
/// list uses: Pending & Checked → For Approval → Approved → Rejected.
///
/// Air ticket and hotel amendments come from two endpoints but read as one
/// queue here — the person clearing it works through both — with a filter for
/// when only one type matters.
class AmendmentsBallysScreen extends ConsumerStatefulWidget {
  const AmendmentsBallysScreen({super.key});

  @override
  ConsumerState<AmendmentsBallysScreen> createState() =>
      _AmendmentsBallysScreenState();
}

class _AmendmentsBallysScreenState extends ConsumerState<AmendmentsBallysScreen>
    with SingleTickerProviderStateMixin, ConnectivityMixin {
  late TabController _tabController;
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  _AmendmentFilter _filter = _AmendmentFilter.all;

  /// Resolved once on open, then reused by every card — the visibility rules
  /// are per user, not per row.
  bool _canSeeAll = false;
  String _currentUserName = '';

  @override
  void onConnectivityRestored() {
    _loadAmendments();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _resolveVisibility();
      final amendments = ref.read(amendmentBallysProvider);
      final hasData = amendments.values.any((list) => list.isNotEmpty);
      if (hasData) return;
      await _loadAmendments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// AD001, checkers and approvers see the whole queue; everyone else sees only
  /// the amendments they raised themselves.
  Future<void> _resolveVisibility() async {
    final salesCode = await StorageUtil.getSalesCode();
    final resChk = await StorageUtil.getResChk();
    final resApp = await StorageUtil.getResApp();
    final userName = await StorageUtil.getUserName();
    if (!mounted) return;
    setState(() {
      _canSeeAll =
          (salesCode != null && salesCode.trim().toUpperCase() == 'AD001') ||
          resChk == true ||
          resApp == true;
      _currentUserName = userName?.trim().toLowerCase() ?? '';
    });
  }

  Future<void> _loadAmendments() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(amendmentBallysProvider.notifier).getAmendments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load amendments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AmendmentBallys> _visible(List<AmendmentBallys> amendments) {
    return amendments.where((amendment) {
      if (!_canSeeAll &&
          amendment.userName.trim().toLowerCase() != _currentUserName) {
        return false;
      }

      switch (_filter) {
        case _AmendmentFilter.airTicket:
          if (amendment.isHotel) return false;
          break;
        case _AmendmentFilter.hotel:
          if (!amendment.isHotel) return false;
          break;
        case _AmendmentFilter.all:
          break;
      }

      if (_searchQuery.isEmpty) return true;
      final haystack = [
        amendment.reservationNo,
        amendment.masterId,
        amendment.userName,
        amendment.kindLabel,
        ...amendment.categories,
        ...amendment.allGuests.map((g) => '${g.bmNumber} ${g.guestName}'),
      ].join(' ').toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList();
  }

  /// "DD/MM/YYYY  HH:MM AM/PM" — the same stamp the reservation list shows.
  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${dt.year}  ${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final amendments = ref.watch(amendmentBallysProvider);

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
                  hintText: 'Search by reservation no, guest, or requester...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color.fromARGB(179, 0, 0, 0)),
                ),
                style: const TextStyle(color: Colors.black),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
              )
            : const Text('Amendments'),
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
            onPressed: _loadAmendments,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.pink,
          tabAlignment: TabAlignment.start,
          tabs: [
            _buildTab(
              'Pending & Checked',
              _visible(amendments['Pending'] ?? []).length,
              Colors.orange,
            ),
            _buildTab(
              'For Approval',
              _visible(amendments['Checked'] ?? []).length,
              Colors.blue,
            ),
            _buildTab(
              'Approved',
              _visible(amendments['Approved'] ?? []).length,
              Colors.green,
            ),
            _buildTab(
              'Rejected',
              _visible(amendments['Rejected'] ?? []).length,
              Colors.red,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAmendmentList(amendments['Pending'] ?? []),
                    _buildAmendmentList(amendments['Checked'] ?? []),
                    _buildAmendmentList(amendments['Approved'] ?? []),
                    _buildAmendmentList(amendments['Rejected'] ?? []),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
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

  Widget _buildTab(String label, int count, Color bubbleColor) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(width: 6),
          if (count > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: count > 9 ? 6 : 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(15),
              ),
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
                maxWidth: 30,
                maxHeight: 30,
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  /// Air ticket / hotel filter. Both feeds share the queue, so this is the only
  /// way to look at one of them on its own.
  Widget _buildFilterBar() {
    final fontSettings = ref.watch(fontSettingsProvider);

    Widget chip(String label, _AmendmentFilter value, IconData icon) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(
            icon,
            size: 18,
            color: selected ? Colors.white : Colors.black54,
          ),
          label: Text(label),
          selected: selected,
          selectedColor: Constants.kPrimaryColor,
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: fontSettings.fontSize - 4,
            fontWeight: selected ? FontWeight.bold : fontSettings.fontWeight,
          ),
          onSelected: (_) => setState(() => _filter = value),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          chip('All', _AmendmentFilter.all, Icons.all_inbox),
          chip('Air Ticket', _AmendmentFilter.airTicket, Icons.flight),
          chip('Hotel', _AmendmentFilter.hotel, Icons.hotel),
        ],
      ),
    );
  }

  Widget _buildAmendmentList(List<AmendmentBallys> amendments) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final visible = _visible(amendments);

    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAmendments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                'No amendments available.',
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAmendments,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final amendment = visible[index];
          final guests = amendment.allGuests;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),

                  // Which feed it came from, and the reservation it belongs to.
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: amendment.isHotel
                              ? Colors.teal
                              : Colors.indigo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              amendment.isHotel ? Icons.hotel : Icons.flight,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              amendment.kindLabel,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: fontSettings.fontSize - 1,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Res No: ${amendment.reservationNo}',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: fontSettings.fontSize + 1,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Who it is for.
                  if (guests.isNotEmpty)
                    Text(
                      guests.length == 1
                          ? '${guests.first.bmNumber} - ${guests.first.guestName}'
                          : '${guests.first.bmNumber} - ${guests.first.guestName}  +${guests.length - 1} more',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: fontSettings.fontSize + 1,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                  const SizedBox(height: 6),

                  // What was asked for, so the card is readable unopened.
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final category in amendment.categories)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: fontSettings.fontSize - 1,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          amendment.isHotel
                              ? '${amendment.lineCount} room(s)'
                              : '${amendment.lineCount} ticket(s)',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize - 1,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 20,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Requested by: ',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize + 2,
                          fontWeight: fontSettings.fontWeight,
                          color: Colors.black,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          amendment.userName,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize + 2,
                            fontWeight: fontSettings.fontWeight,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  if (amendment.createdDate != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 20,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Requested: ${_formatDateTime(amendment.createdDate!)}',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize + 1,
                            color: Colors.black,
                            fontWeight: fontSettings.fontWeight,
                          ),
                        ),
                      ],
                    ),

                  // Who actioned it — only once somebody has.
                  if (amendment.actionBy != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _statusIcon(amendment.status),
                          size: 20,
                          color: _statusColor(amendment.status),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${amendment.status} by: ${amendment.actionBy}',
                            style: TextStyle(
                              fontSize: fontSettings.fontSize + 2,
                              fontWeight: fontSettings.fontWeight,
                              color: _statusColor(amendment.status),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (amendment.actionDate != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          _statusIcon(amendment.status),
                          size: 20,
                          color: _statusColor(amendment.status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${amendment.status}: ${_formatDateTime(amendment.actionDate!)}',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize + 1,
                            color: _statusColor(amendment.status),
                            fontWeight: fontSettings.fontWeight,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(amendment.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _statusIcon(amendment.status),
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          amendment.status,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () async {
                final result = await context.push(
                  '/reservationMain/amendments-ballys/amendment-view-ballys',
                  extra: amendment,
                );
                if (result == true) await _loadAmendments();
              },
            ),
          );
        },
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
