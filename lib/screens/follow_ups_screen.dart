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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        .where((item) =>
            item.memberName.toLowerCase().contains(q) ||
            item.memberId.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final asyncFollowUps = ref.watch(followUpListProvider);
    // Keep the last-known list on screen while a refresh runs, so the loading
    // overlay sits on top of the cards instead of replacing them.
    final visible = _visible(asyncFollowUps.valueOrNull ?? const <FollowUpItem>[]);
    final bool hasError = asyncFollowUps.hasError && visible.isEmpty;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Followed'),
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
                  ref.read(followUpListProvider.notifier).refresh(),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
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
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
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
                      : visible.isEmpty
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
                                child: ListView.builder(
                                  itemCount: visible.length,
                                  itemBuilder: (context, index) =>
                                      _FollowUpCard(item: visible[index]),
                                ),
                              ),
                            ),
                ),
              ],
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
            const Watermark(),
          ],
        ),
      ),
    );
  }
}

/// Compact summary row. Tapping it opens the read-only detail view.
class _FollowUpCard extends StatelessWidget {
  final FollowUpItem item;

  const _FollowUpCard({required this.item});

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
        onTap: () => context.push(
          '/inctiveMemberMain/followups/view',
          extra: item,
        ),
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
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd MMM yyyy  hh:mm a')
                                .format(item.createdDate!),
                            style: const TextStyle(
                              fontSize: 17,
                              color: Color.fromARGB(255, 0, 0, 0),
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

