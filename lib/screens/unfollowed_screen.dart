// lib/screens/unfollowed_screen.dart

import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/unfollow_item.dart';
import 'package:ballys_reservation_app/providers/follow_up_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Lists every unfollowed member from `GetAllUnfollowup`, newest first.
class UnfollowedScreen extends ConsumerStatefulWidget {
  const UnfollowedScreen({super.key});

  @override
  ConsumerState<UnfollowedScreen> createState() => _UnfollowedScreenState();
}

class _UnfollowedScreenState extends ConsumerState<UnfollowedScreen>
    with ConnectivityMixin {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// Text size multiplier picked from the 1x / 1.2x / 1.3x selector.
  double _textScale = 1.0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UnfollowItem> _visible(List<UnfollowItem> items) {
    final sorted = [...items]
      ..sort((a, b) {
        final aDate = a.createdDate;
        final bDate = b.createdDate;
        if (aDate != null && bDate != null) return bDate.compareTo(aDate);
        return b.unfollowupId.compareTo(a.unfollowupId);
      });
    if (_query.isEmpty) return sorted;

    final q = _query.toLowerCase();
    return sorted
        .where(
          (item) =>
              item.memberName.toLowerCase().contains(q) ||
              item.memberId.toLowerCase().contains(q) ||
              (item.loginBy?.toLowerCase().contains(q) ?? false) ||
              item.reason.toLowerCase().contains(q),
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
    final asyncItems = ref.watch(unfollowListProvider);
    // Keep the last-known list on screen while a refresh runs.
    final all = asyncItems.valueOrNull ?? const <UnfollowItem>[];
    final visible = _visible(all);
    final bool hasError = asyncItems.hasError && all.isEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Unfollowed'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
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
                  ref.read(unfollowListProvider.notifier).refresh(),
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
                          hintText: 'Search member, user or reason',
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
                    if (all.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${visible.length} unfollowed member'
                            '${visible.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
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
                                    'Failed to load.\n${asyncItems.error}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => ref
                                        .read(unfollowListProvider.notifier)
                                        .refresh(),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : visible.isEmpty
                          ? Center(
                              child: Text(
                                asyncItems.isLoading
                                    ? ''
                                    : _query.isEmpty
                                    ? 'No unfollowed members'
                                    : 'No results for "$_query"',
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => ref
                                  .read(unfollowListProvider.notifier)
                                  .refresh(),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8.0),
                                itemCount: visible.length,
                                itemBuilder: (context, index) =>
                                    _UnfollowCard(item: visible[index]),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            if (asyncItems.isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color.fromARGB(134, 0, 0, 0),
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
      ),
    );
  }
}

/// One unfollowed member: why and when they were unfollowed, plus a short
/// summary of the original follow-up. Tapping opens that follow-up.
class _UnfollowCard extends StatelessWidget {
  final UnfollowItem item;

  const _UnfollowCard({required this.item});

  static final DateFormat _dateTime = DateFormat('dd MMM yyyy  hh:mm a');
  static final DateFormat _date = DateFormat('dd MMM yyyy');

  /// e.g. "Followed for 2 days" — from the follow-up date to the unfollow.
  String? get _followedForLabel {
    final from = item.followUp?.createdDate;
    final to = item.createdDate;
    if (from == null || to == null) return null;
    final days = DateTime(
      to.year,
      to.month,
      to.day,
    ).difference(DateTime(from.year, from.month, from.day)).inDays;
    if (days <= 0) return 'Unfollowed same day';
    return days == 1 ? 'Followed for 1 day' : 'Followed for $days days';
  }

  @override
  Widget build(BuildContext context) {
    final followUp = item.followUp;
    final remarks = item.remarks?.trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: followUp == null
            ? null
            : () => context.push(
                '/inctiveMemberMain/followups/view',
                extra: followUp,
              ),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Colors.red, width: 5)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _UnfollowedBadge(),
                    const SizedBox(height: 6),
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
                    if (item.createdDate != null)
                      _InfoRow(
                        icon: Icons.event_busy,
                        text:
                            'Unfollowed: ${_dateTime.format(item.createdDate!)}',
                      ),
                    if (item.loginBy?.isNotEmpty ?? false)
                      _InfoRow(
                        icon: Icons.person_remove_outlined,
                        text: 'Unfollowed by: ${item.loginBy}',
                      ),

                    // ── Reason / remarks ────────────────────────────────
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Reason: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: item.reason.isEmpty ? '-' : item.reason,
                                ),
                              ],
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          if (remarks.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Remarks: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: remarks),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Original follow-up ──────────────────────────────
                    if (followUp != null) ...[
                      const SizedBox(height: 8),
                      if (followUp.loginBy?.isNotEmpty ?? false)
                        _InfoRow(
                          icon: Icons.person_outline,
                          text: 'Followed by: ${followUp.loginBy}',
                        ),
                      if (followUp.createdDate != null)
                        _InfoRow(
                          icon: Icons.access_time,
                          text:
                              'Followed on: ${_date.format(followUp.createdDate!)}',
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (_followedForLabel != null)
                            _Chip(
                              label: _followedForLabel!,
                              color: Colors.blueGrey,
                            ),
                          if (followUp.contactStatus.isNotEmpty)
                            _Chip(
                              label: followUp.contactStatus,
                              color: Constants.kPrimaryColor,
                            ),
                          if (followUp.responseType?.isNotEmpty ?? false)
                            _Chip(
                              label: followUp.responseType!,
                              color: followUp.isPositive
                                  ? Colors.green
                                  : followUp.isNegative
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (followUp != null)
                const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}

/// Solid red "UNFOLLOWED" badge so the status stands out on every card.
class _UnfollowedBadge extends StatelessWidget {
  const _UnfollowedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_remove, size: 18, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'UNFOLLOWED',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: Colors.black),
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
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}
