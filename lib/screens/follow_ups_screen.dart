// lib/screens/follow_ups_screen.dart

import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/follow_up_item.dart';
import 'package:ballys_reservation_app/providers/follow_up_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Lists every follow-up saved through the CRM, newest first.
class FollowUpsScreen extends ConsumerStatefulWidget {
  const FollowUpsScreen({super.key});

  @override
  ConsumerState<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends ConsumerState<FollowUpsScreen>
    with ConnectivityMixin {
  static const String _kUnknownUser = 'Unknown';

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// The "Followed by" user being drilled into; null shows the user summary.
  String? _selectedUser;

  /// Text size multiplier picked from the 1x / 1.2x / 1.3x selector.
  double _textScale = 1.0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _userOf(FollowUpItem item) {
    final user = item.loginBy?.trim() ?? '';
    return user.isEmpty ? _kUnknownUser : user;
  }

  /// Follow-up count per user, busiest first, filtered by the search query.
  List<MapEntry<String, int>> _userCounts(List<FollowUpItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      counts.update(_userOf(item), (c) => c + 1, ifAbsent: () => 1);
    }
    final q = _query.toLowerCase();
    return counts.entries
        .where((e) => q.isEmpty || e.key.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
  }

  void _selectUser(String? user) {
    _searchController.clear();
    setState(() {
      _selectedUser = user;
      _query = '';
    });
  }

  /// Only the user who created a follow-up may unfollow it.
  static bool _isMine(FollowUpItem item, String? currentUser) {
    final me = currentUser?.trim().toLowerCase() ?? '';
    final owner = item.loginBy?.trim().toLowerCase() ?? '';
    return me.isNotEmpty && me == owner;
  }

  Future<void> _confirmUnfollow(FollowUpItem item) async {
    final result = await showDialog<({String reason, String remarks})>(
      context: context,
      builder: (context) => _UnfollowDialog(item: item),
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(followUpListProvider.notifier)
          .unfollow(item, reason: result.reason, remarks: result.remarks);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unfollow: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unfollowed'),
        backgroundColor: Colors.green,
      ),
    );
  }

  List<FollowUpItem> _visible(List<FollowUpItem> items) {
    // Newest first — by created date when the API sends one, otherwise by id.
    final sorted = [...items]
      ..sort((a, b) {
        final aDate = a.createdDate;
        final bDate = b.createdDate;
        if (aDate != null && bDate != null) return bDate.compareTo(aDate);
        return b.followupId.compareTo(a.followupId);
      });
    if (_query.isEmpty) return sorted;

    final q = _query.toLowerCase();
    return sorted
        .where(
          (item) =>
              item.memberName.toLowerCase().contains(q) ||
              item.memberId.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── Text scale (1x / 1.2x / 1.3x) selector ──────────────────────────────
  Widget _buildTextScaleSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          "Text Size",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        const SizedBox(width: 10),
        ...[1.0, 1.2, 1.3].map((scale) {
          final bool selected = _textScale == scale;
          return Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _textScale = scale),
              child: Container(
                width: 44,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? Constants.kSecondaryColor
                      : Colors.transparent,
                  border: Border.all(color: Constants.kSecondaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${scale.toDouble()}x",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : Constants.kSecondaryColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncFollowUps = ref.watch(followUpListProvider);
    // Keep the last-known list on screen while a refresh runs, so the loading
    // overlay sits on top of the cards instead of replacing them.
    final all = asyncFollowUps.valueOrNull ?? const <FollowUpItem>[];
    final currentUser = ref.watch(currentUserNameProvider).valueOrNull;
    final selectedUser = _selectedUser;
    final visible = selectedUser == null
        ? const <FollowUpItem>[]
        : _visible(all.where((i) => _userOf(i) == selectedUser).toList());
    final userCounts = selectedUser == null
        ? _userCounts(all)
        : const <MapEntry<String, int>>[];
    final bool isEmpty = selectedUser == null
        ? userCounts.isEmpty
        : visible.isEmpty;
    final bool hasError = asyncFollowUps.hasError && all.isEmpty;

    return PopScope(
      canPop: selectedUser == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectUser(null);
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              selectedUser == null ? 'Followed' : 'Followed by: $selectedUser',
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (selectedUser != null) {
                  _selectUser(null);
                } else if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/inctiveMemberMain');
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 30),
                onPressed: () =>
                    ref.read(followUpListProvider.notifier).refresh(),
              ),
            ],
          ),
          body: Stack(
            children: [
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(_textScale)),
                  child: Column(
                    children: [
                      MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.noScaling),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: _buildTextScaleSelector(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _query = value.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: hasError
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Failed to load.\n${asyncFollowUps.error}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => ref
                                          .read(followUpListProvider.notifier)
                                          .refresh(),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : isEmpty
                            ? Center(
                                child: Text(
                                  _query.isEmpty
                                      ? 'No follow-ups available'
                                      : 'No follow-ups match "$_query"',
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () => ref
                                    .read(followUpListProvider.notifier)
                                    .refresh(),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: selectedUser == null
                                      ? ListView.builder(
                                          itemCount: userCounts.length,
                                          itemBuilder: (context, index) {
                                            final entry = userCounts[index];
                                            return _FollowedByCard(
                                              user: entry.key,
                                              count: entry.value,
                                              onTap: () =>
                                                  _selectUser(entry.key),
                                            );
                                          },
                                        )
                                      : ListView.builder(
                                          itemCount: visible.length,
                                          itemBuilder: (context, index) {
                                            final item = visible[index];
                                            return _FollowUpCard(
                                              item: item,
                                              onUnfollow:
                                                  _isMine(item, currentUser)
                                                  ? () => _confirmUnfollow(item)
                                                  : null,
                                            );
                                          },
                                        ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (asyncFollowUps.isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(134, 0, 0, 0),
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
              // const Watermark(),
            ],
          ),
        ),
      ),
    );
  }
}

/// One "Followed by" user and how many follow-ups they saved.
class _FollowedByCard extends StatelessWidget {
  final String user;
  final int count;
  final VoidCallback onTap;

  const _FollowedByCard({
    required this.user,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 24, color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  user,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 0, 0, 0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact summary row. Tapping it opens the read-only detail view.
class _FollowUpCard extends StatelessWidget {
  final FollowUpItem item;

  /// Shown as an Unfollow button only when non-null, i.e. for the user who
  /// created the follow-up.
  final VoidCallback? onUnfollow;

  const _FollowUpCard({required this.item, this.onUnfollow});

  /// Whole calendar days since the follow-up was saved. Null when the API
  /// sent no created date.
  int? get _daysSince {
    final created = item.createdDate;
    if (created == null) return null;
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(created.year, created.month, created.day)).inDays;
  }

  /// e.g. "Today", "1 day ago", "12 days ago".
  String? get _daysSinceLabel {
    final days = _daysSince;
    if (days == null) return null;
    if (days <= 0) return 'Today';
    return days == 1 ? '1 day ago' : '$days days ago';
  }

  /// Green up to 15 days, red once the follow-up is older than that.
  Color get _daysSinceColor =>
      (_daysSince ?? 0) > 15 ? Colors.red : Colors.green;

  /// e.g. "Range: 1 Month | Buy-in: 1M". Null when neither was saved.
  String? get _rangeLabel {
    final parts = <String>[
      if (item.dateRange?.isNotEmpty ?? false) 'Range: ${item.dateRange}',
      if (item.buyInRange?.isNotEmpty ?? false) 'Buy-in: ${item.buyInRange}',
    ];
    return parts.isEmpty ? null : parts.join('  |  ');
  }

  Color get _responseColor {
    if (item.isPositive) return Colors.green;
    if (item.isNegative) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final photo = item.photoBytes;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push('/inctiveMemberMain/followups/view', extra: item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ── Thumbnail (or initial when there's no photo) ─────────────
              // ClipRRect(
              //   borderRadius: BorderRadius.circular(8),
              //   child: SizedBox(
              //     height: 56,
              //     width: 56,
              //     child: photo != null
              //         ? Image.memory(
              //             photo,
              //             fit: BoxFit.cover,
              //             errorBuilder: (_, __, ___) => _initialAvatar(),
              //           )
              //         : _initialAvatar(),
              //   ),
              // ),
              // const SizedBox(width: 12),

              // ── Member + statuses ────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.memberId} - ${item.memberName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (item.createdDate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat(
                              'dd MMM yyyy  hh:mm a',
                            ).format(item.createdDate!),
                            style: const TextStyle(
                              fontSize: 17,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (item.loginBy != null && item.loginBy!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "Followed by: ${item.loginBy!}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_rangeLabel != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.filter_alt_outlined,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _rangeLabel!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (item.contactStatus.isNotEmpty)
                          _Chip(
                            label: item.contactStatus,
                            color: Constants.kPrimaryColor,
                          ),
                        if (item.responseType != null &&
                            item.responseType!.isNotEmpty)
                          _Chip(
                            label: item.responseType!,
                            color: _responseColor,
                          ),
                      ],
                    ),
                    // ── Days since + Unfollow, side by side ─────────────
                    if (_daysSinceLabel != null || onUnfollow != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_daysSinceLabel != null)
                            _DaysBadge(
                              label: _daysSinceLabel!,
                              color: _daysSinceColor,
                            ),
                          const Spacer(),
                          if (onUnfollow != null)
                            OutlinedButton.icon(
                              onPressed: onUnfollow,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.person_remove_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Unfollow',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initialAvatar() {
    final name = item.memberName.trim();
    return Container(
      color: Constants.kPrimaryColor.withOpacity(0.12),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Constants.kPrimaryColor,
        ),
      ),
    );
  }
}

/// "12 days ago"-style badge, sized to sit beside the Unfollow button.
class _DaysBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DaysBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timelapse, size: 18, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

/// Asks for the unfollow reason (required) and optional remarks. Pops a
/// `(reason, remarks)` record on confirm, or null on cancel.
class _UnfollowDialog extends StatefulWidget {
  final FollowUpItem item;

  const _UnfollowDialog({required this.item});

  @override
  State<_UnfollowDialog> createState() => _UnfollowDialogState();
}

class _UnfollowDialogState extends State<_UnfollowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _remarksController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      reason: _reasonController.text.trim(),
      remarks: _remarksController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unfollow'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unfollow ${widget.item.memberId} - ${widget.item.memberName}?',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a reason'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(backgroundColor: Colors.red),
          child: const Text(
            'Unfollow',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
