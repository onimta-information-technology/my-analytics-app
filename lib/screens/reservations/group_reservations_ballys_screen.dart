import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/group_reservation_repository.dart';
import 'package:ballys_reservation_app/models/group_reservation.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/group_reservation_provider.dart';
import 'package:ballys_reservation_app/screens/reservations/transport_view_screen.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Saved Group Reservations (Ballys only).
///
/// The read side of [GroupReservationBallysScreen]: every group from
/// `GroupReservation/Get` — the lead guest, the uploaded guest sheet and the
/// passport pages for the party — in the same four-tab workflow the Ballys
/// reservation and amendment lists use: Pending & Checked → For Approval →
/// Approved → Rejected.
class GroupReservationsBallysScreen extends ConsumerStatefulWidget {
  const GroupReservationsBallysScreen({super.key});

  @override
  ConsumerState<GroupReservationsBallysScreen> createState() =>
      _GroupReservationsBallysScreenState();
}

class _GroupReservationsBallysScreenState
    extends ConsumerState<GroupReservationsBallysScreen>
    with SingleTickerProviderStateMixin {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  /// One tab per status, in workflow order.
  static const List<String> _tabStatuses = [
    'Pending',
    'Checked',
    'Approved',
    'Rejected',
  ];

  late final TabController _tabController =
      TabController(length: _tabStatuses.length, vsync: this);

  /// Group reservations follow the reservation permissions: `ResChk` checks
  /// and rejects a pending group, `ResApp` approves or rejects a checked one.
  bool _hasResChk = false;
  bool _hasResApp = false;

  /// AD001, checkers and approvers see every group; everyone else sees only
  /// the groups they saved themselves.
  bool _canSeeAll = false;
  String _currentUserName = '';

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final salesCode = await StorageUtil.getSalesCode();
    final resChk = await StorageUtil.getResChk();
    final resApp = await StorageUtil.getResApp();
    final userName = await StorageUtil.getUserName();
    if (!mounted) return;
    setState(() {
      _hasResChk = resChk == true;
      _hasResApp = resApp == true;
      _canSeeAll =
          (salesCode != null && salesCode.trim().toUpperCase() == 'AD001') ||
              _hasResChk ||
              _hasResApp;
      _currentUserName = userName?.trim().toLowerCase() ?? '';
    });
  }

  /// The tab a row belongs in. Anything the backend sends that is not one of
  /// the later stages is still waiting, so it lands in the first tab.
  static String _bucketOf(String status) {
    switch (status.trim().toLowerCase()) {
      case 'checked':
        return 'Checked';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  List<GroupReservationRecord> _visible(
    List<GroupReservationRecord> reservations,
    String tabStatus,
  ) {
    return reservations.where((r) {
      if (_bucketOf(r.status) != tabStatus) return false;
      if (!_canSeeAll && r.userName.trim().toLowerCase() != _currentUserName) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _refresh() async {
    ref.invalidate(groupReservationsProvider);
    await ref.read(groupReservationsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final reservationsAsync = ref.watch(groupReservationsProvider);
    final all = reservationsAsync.valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Group Reservations'),
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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(groupReservationsProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.pink,
          tabAlignment: TabAlignment.start,
          tabs: [
            _buildTab('Pending & Checked',
                _visible(all, 'Pending').length, Colors.orange),
            _buildTab(
                'For Approval', _visible(all, 'Checked').length, Colors.blue),
            _buildTab(
                'Approved', _visible(all, 'Approved').length, Colors.green),
            _buildTab(
                'Rejected', _visible(all, 'Rejected').length, Colors.red),
          ],
        ),
      ),
      // The write side lives on its own screen; pushed (not `go`) so coming
      // back lands on this list again.
      floatingActionButton: FloatingActionButton(
        tooltip: 'New group reservation',
        backgroundColor: const Color.fromARGB(255, 103, 58, 183),
        onPressed: () async {
          await context.push('/reservationMain/group-reservation-ballys');
          if (!mounted) return;
          // A group may have been saved while we were away.
          ref.invalidate(groupReservationsProvider);
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final status in _tabStatuses)
                  _reservationList(fontSettings, reservationsAsync, status),
              ],
            ),
          ),
          if (_isSubmitting)
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

  Widget _reservationList(
    FontSettings fontSettings,
    AsyncValue<List<GroupReservationRecord>> reservationsAsync,
    String tabStatus,
  ) {
    return reservationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _placeholder(
        fontSettings,
        Icons.error_outline,
        'Could not load group reservations',
        action: TextButton.icon(
          onPressed: () => ref.invalidate(groupReservationsProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
      data: (reservations) {
        final visible = _visible(reservations, tabStatus);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: visible.isEmpty
              // Still a scrollable, so pull-to-refresh works on an empty tab.
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    _placeholder(
                      fontSettings,
                      Icons.inbox_outlined,
                      'No group reservations available.',
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Room at the bottom so the last card clears the FAB.
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: visible.length,
                  itemBuilder: (context, index) =>
                      _reservationCard(fontSettings, visible[index]),
                ),
        );
      },
    );
  }

  Widget _reservationCard(FontSettings fontSettings, GroupReservationRecord r) {
    final status = _bucketOf(r.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusChip(fontSettings, r.status),
              ],
            ),
            const SizedBox(height: 8),
            // The lead guest — the rest of the party is in the sheet.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.groups, size: 20, color: Constants.kPrimaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.guestName.isEmpty ? 'Unknown guest' : r.guestName,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (r.bmNumber.isNotEmpty)
                        Text(
                          r.bmNumber,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize - 5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            if (r.guestSheetPath.isNotEmpty) ...[
              _guestSheetTile(fontSettings, r),
              const SizedBox(height: 10),
            ],
            if (r.passportImages.isNotEmpty) ...[
              Text(
                'Passports (${r.passportImages.length})',
                style: TextStyle(
                  fontSize: fontSettings.fontSize - 3,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              _passportTiles(fontSettings, r.passportImages),
            ],
            if (r.remarks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.remarks,
                  style: TextStyle(fontSize: fontSettings.fontSize),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Who saved the group, on its own line above when they did.
            if (r.userName.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.account_circle_outlined,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Requested by: ${r.userName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  r.createdDate == null
                      ? '—'
                      : _dateFormat.format(r.createdDate!),
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            // When it last moved — only once somebody has actioned it.
            if (status != 'Pending' && r.modifiedDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(_statusIcon(status),
                      size: 14, color: _statusColor(status)),
                  const SizedBox(width: 4),
                  Text(
                    '$status: ${_dateFormat.format(r.modifiedDate!)}',
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      color: _statusColor(status),
                    ),
                  ),
                ],
              ),
            ],
            _actionButtons(fontSettings, r),
          ],
        ),
      ),
    );
  }

  /// Pending needs `ResChk` (check / reject); Checked needs `ResApp`
  /// (approve / reject). Approved and Rejected are read-only.
  Widget _actionButtons(FontSettings fontSettings, GroupReservationRecord r) {
    final status = _bucketOf(r.status);
    final isPending = status == 'Pending';
    if (!isPending && status != 'Checked') return const SizedBox.shrink();

    final canAct = isPending ? _hasResChk : _hasResApp;
    if (!canAct) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPending
                    ? 'You do not have permission to check this group reservation.'
                    : 'You do not have permission to approve this group reservation.',
                style: TextStyle(fontSize: fontSettings.fontSize - 5),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              fontSettings,
              label: isPending ? 'Check' : 'Approve',
              icon: isPending ? Icons.fact_check : Icons.check_circle,
              color: isPending ? Colors.blue : Colors.green,
              onPressed: () => _submit(r, isPending ? 'Checked' : 'Approved'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionButton(
              fontSettings,
              label: 'Reject',
              icon: Icons.cancel,
              color: Colors.red,
              onPressed: () => _submit(r, 'Rejected'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    FontSettings fontSettings, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: _isSubmitting ? null : onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: TextStyle(
          fontSize: fontSettings.fontSize - 3,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _submit(GroupReservationRecord r, String status) async {
    final confirmed = await _confirmStatusChange(r, status);
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    GroupReservationResult result;
    try {
      result = await ref.read(groupReservationRepositoryProvider).updateStatus(
            masterId: r.masterId,
            status: status,
            log: (label, payload) => debugPrint('$label: $payload'),
          );
    } catch (e) {
      result = GroupReservationResult(
        success: false,
        message: 'Could not update the group reservation: $e',
      );
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Group reservation ${status.toLowerCase()}.'
              : (result.message ?? 'Could not update the group reservation.'),
        ),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
    // The row moves to its new tab on the refetch.
    if (result.success) ref.invalidate(groupReservationsProvider);
  }

  Future<bool?> _confirmStatusChange(GroupReservationRecord r, String status) {
    final fontSettings = ref.read(fontSettingsProvider);
    final (actionLabel, color) = switch (status) {
      'Checked' => ('Check', Colors.blue),
      'Approved' => ('Approve', Colors.green),
      _ => ('Reject', Colors.red),
    };
    final guest = [
      if (r.guestName.isNotEmpty) r.guestName,
      if (r.bmNumber.isNotEmpty) '(${r.bmNumber})',
    ].join(' ');

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$actionLabel Group Reservation',
          style: TextStyle(
            fontSize: fontSettings.fontSize - 1,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          guest.isEmpty
              ? 'Mark this group reservation as $status?'
              : 'Mark the group reservation for $guest as $status?',
          style: TextStyle(fontSize: fontSettings.fontSize - 3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  /// The uploaded Excel sheet — tapping hands it to whatever app opens it.
  Widget _guestSheetTile(FontSettings fontSettings, GroupReservationRecord r) {
    final name = r.guestSheetName.isNotEmpty
        ? r.guestSheetName
        : r.guestSheetPath.split('/').last;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openFile(r.guestSheetPath, name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.table_chart, color: Colors.green.shade700, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSettings.fontSize - 3),
              ),
            ),
            Icon(Icons.open_in_new, size: 18, color: Colors.green.shade700),
          ],
        ),
      ),
    );
  }

  Widget _passportTiles(
    FontSettings fontSettings,
    List<GroupReservationPassportImage> files,
  ) {
    final host = ref.watch(groupReservationFileHostProvider).valueOrNull;

    if (host == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: files.map((file) {
        final url = groupReservationFileUrl(host, file.filePath);
        final name = file.fileName.isNotEmpty ? file.fileName : 'Passport';

        if (url == null) return _missingTile();
        if (file.isPdf) {
          return _pdfTile(() => _openFile(file.filePath, name));
        }
        return _imageTile(url, () {
          showDialog(
            context: context,
            barrierColor: Colors.black87,
            builder: (_) => PassportImageDialog(url: url, fileName: name),
          );
        });
      }).toList(),
    );
  }

  Future<void> _openFile(String filePath, String fileName) async {
    final host = ref.read(groupReservationFileHostProvider).valueOrNull ??
        await ref.read(groupReservationFileHostProvider.future);
    final url = host == null ? null : groupReservationFileUrl(host, filePath);

    final opened = url != null &&
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open $fileName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static const double _tileSize = 64;

  Widget _imageTile(String url, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: _tileSize,
          height: _tileSize,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: _tileSize,
              height: _tileSize,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            width: _tileSize,
            height: _tileSize,
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, color: Colors.black45),
          ),
        ),
      ),
    );
  }

  Widget _pdfTile(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _tileSize,
        height: _tileSize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
      ),
    );
  }

  Widget _missingTile() {
    return Container(
      width: _tileSize,
      height: _tileSize,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported, color: Colors.black45),
    );
  }

  /// Same colours and icons as the amendment list.
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

  Widget _statusChip(FontSettings fontSettings, String rawStatus) {
    final status = _bucketOf(rawStatus);
    final color = _statusColor(status);
    final label = rawStatus.isEmpty ? 'Pending' : rawStatus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSettings.fontSize - 6,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(
    FontSettings fontSettings,
    IconData icon,
    String message, {
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSettings.fontSize - 3,
                color: Colors.grey.shade600,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }
}
