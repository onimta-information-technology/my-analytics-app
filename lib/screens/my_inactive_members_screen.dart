// lib/screens/my_inactive_members_screen.dart

import 'package:ballys_reservation_app/components/app_loader.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/my_inactive_member.dart';
import 'package:ballys_reservation_app/providers/my_inactive_members_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The logged-in user's own inactive members (Ballys, iid 885263), highest
/// G_RatingID first; members with the same rating keep the SP order (latest
/// last visit first).
class MyInactiveMembersScreen extends ConsumerStatefulWidget {
  const MyInactiveMembersScreen({super.key});

  @override
  ConsumerState<MyInactiveMembersScreen> createState() =>
      _MyInactiveMembersScreenState();
}

class _MyInactiveMembersScreenState
    extends ConsumerState<MyInactiveMembersScreen> with ConnectivityMixin {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// Rating chip currently filtering the list; null means "All".
  String? _selectedRating;

  /// Text size multiplier picked from the 1x / 1.2x / 1.3x selector.
  double _textScale = 1.0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _ratingKey(MyInactiveMember m) =>
      m.rating.isEmpty ? 'N/A' : m.rating;

  /// Highest G_RatingID first. Ties fall back to the original index because
  /// List.sort is not stable.
  List<MyInactiveMember> _byRating(List<MyInactiveMember> items) {
    final indexed = items.asMap().entries.toList()
      ..sort((a, b) {
        final byRating = b.value.ratingId.compareTo(a.value.ratingId);
        return byRating != 0 ? byRating : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  List<MyInactiveMember> _searched(List<MyInactiveMember> items) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items
        .where(
          (m) =>
              m.memberName.toLowerCase().contains(q) ||
              m.mid.toLowerCase().contains(q) ||
              m.country.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Per-rating tally for the chip row, highest rating first.
  List<MapEntry<String, int>> _ratingCounts(List<MyInactiveMember> items) {
    final counts = <String, int>{};
    final ids = <String, int>{};
    for (final m in items) {
      final key = _ratingKey(m);
      counts.update(key, (v) => v + 1, ifAbsent: () => 1);
      ids[key] = m.ratingId;
    }
    return counts.entries.toList()
      ..sort((a, b) => (ids[b.key] ?? 0).compareTo(ids[a.key] ?? 0));
  }

  static Color ratingColor(String rating) {
    switch (rating.toUpperCase()) {
      case 'GOLD':
        return const Color(0xFFDAA520);
      case 'PLATINUM':
        return const Color(0xFF707070);
      case 'DIAMOND':
        return const Color(0xFF1565C0);
      case 'SILVER':
        return const Color(0xFF9E9E9E);
      case 'INFINITY':
        return const Color(0xFF4A148C);
      case 'PREMIER':
        return const Color(0xFF1B5E20);
      case 'RAFFELS CLUB':
        return const Color(0xFF880E4F);
      default:
        return const Color(0xFF5D4037);
    }
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

  Widget _buildRatingChips(List<MyInactiveMember> searched) {
    final counts = _ratingCounts(searched);
    Widget chip(String? rating, String label, int count) {
      final selected = _selectedRating == rating;
      final color = rating == null
          ? Constants.kSecondaryColor
          : ratingColor(rating);
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text('$label ($count)'),
          selected: selected,
          showCheckmark: false,
          selectedColor: color,
          backgroundColor: color.withOpacity(0.1),
          side: BorderSide(color: color),
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : color,
          ),
          onSelected: (_) => setState(
            () => _selectedRating = _selectedRating == rating ? null : rating,
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          chip(null, 'All', searched.length),
          for (final e in counts) chip(e.key, e.key, e.value),
        ],
      ),
    );
  }

  Future<void> _openProfile(MyInactiveMember member) async {
    // The SP's GCode / GName is the marketing person shown on the profile;
    // fall back to the logged-in user when it comes back blank.
    final marketingCode = await StorageUtil.getMarketingCode();
    final userName = await StorageUtil.getUserName();
    if (!mounted) return;
    ref
        .read(selectedGuestProvider.notifier)
        .setSelectedGuest(
          member.toGuest(
            fallbackMGroup: marketingCode,
            fallbackGName: userName,
          ),
        );
    context.push('/home/profile', extra: {'showFollowButton': true});
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(myInactiveMembersProvider);
    // Keep the last-known list on screen while a refresh runs.
    final all = _byRating(asyncItems.valueOrNull ?? const <MyInactiveMember>[]);
    final searched = _searched(all);
    final visible = _selectedRating == null
        ? searched
        : searched.where((m) => _ratingKey(m) == _selectedRating).toList();
    final bool hasError = asyncItems.hasError && all.isEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Inactive Members'),
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
                  ref.read(myInactiveMembersProvider.notifier).refresh(),
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
                          hintText: 'Search member ID, name or country',
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
                    if (all.isNotEmpty) ...[
                      _buildRatingChips(searched),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${visible.length} inactive member'
                            '${visible.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
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
                                        .read(
                                          myInactiveMembersProvider.notifier,
                                        )
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
                                    : _query.isEmpty && _selectedRating == null
                                    ? 'No inactive members'
                                    : 'No matching members',
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => ref
                                  .read(myInactiveMembersProvider.notifier)
                                  .refresh(),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8.0),
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final member = visible[index];
                                  return _MyInactiveCard(
                                    key: ValueKey(member.mid),
                                    member: member,
                                    onTap: () => _openProfile(member),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            if (asyncItems.isLoading) const AppLoader(),
              // Positioned.fill(
              //   child: Container(
              //     color: const Color.fromARGB(134, 0, 0, 0),
              //     child: const Center(
              //       child: RefreshProgressIndicator(
              //         valueColor: AlwaysStoppedAnimation<Color>(
              //           Constants.kSecondaryColor,
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
          ],
        ),
      ),
    );
  }
}

/// One inactive member: ID, name, country, last visit and rating badge.
/// Tapping opens the member profile.
class _MyInactiveCard extends StatelessWidget {
  final MyInactiveMember member;
  final VoidCallback onTap;

  const _MyInactiveCard({super.key, required this.member, required this.onTap});

  static final DateFormat _date = DateFormat('dd MMM yyyy');

  /// e.g. "45 days ago", counted from the last visit to today.
  String? get _sinceLabel {
    final lvd = member.lastVisitDate;
    if (lvd == null) return null;
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(lvd.year, lvd.month, lvd.day))
        .inDays;
    if (days <= 0) return null;
    return days == 1 ? '1 day ago' : '$days days ago';
  }

  @override
  Widget build(BuildContext context) {
    final rating = member.rating.isEmpty ? 'N/A' : member.rating;
    final color = _MyInactiveMembersScreenState.ratingColor(member.rating);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${member.mid} - ${member.memberName}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            rating,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (member.country.isNotEmpty)
                      _InfoRow(icon: Icons.public, text: member.country),
                    if (member.lastVisitDate != null)
                      _InfoRow(
                        icon: Icons.calendar_today,
                        text:
                            'Last visit on ${_date.format(member.lastVisitDate!)}'
                            '${_sinceLabel == null ? '' : '  ($_sinceLabel)'}',
                      ),
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
