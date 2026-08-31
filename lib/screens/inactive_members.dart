import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/inactive_members_repository.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/inactive_member_group.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class InactiveMembersScreen extends ConsumerStatefulWidget {
  final InactiveMembersRepository inactiveMembersRepository;

  const InactiveMembersScreen({
    super.key,
    required this.inactiveMembersRepository,
  });

  @override
  ConsumerState<InactiveMembersScreen> createState() =>
      _InactiveMembersScreenState();
}

class _InactiveMembersScreenState extends ConsumerState<InactiveMembersScreen> with ConnectivityMixin{
  String selectedDateOption = "1";
  String selectedBuyInOption = "1";
  bool _isLoading = false;

  /// Text size multiplier picked with the on-screen selector, mirroring the
  /// Ballys reservation view screen.
  double _textScale = 1.0;

  List<Guest> originalMembers = [];
  List<Guest> inactiveMembers = [];

  /// Ballys returns a marketing-group summary (Table1) and is browsed group
  /// first, then member. Bellagio keeps the single flat member list.
  bool _isBallys = false;
  List<InactiveMemberGroup> originalGroups = [];
  List<InactiveMemberGroup> groups = [];
  InactiveMemberGroup? _selectedGroup;

  /// Rating chip currently filtering the member list; null means "All".
  String? _selectedRating;

  final TextEditingController _searchController = TextEditingController();

  int _requestId = 0;

  /// The filter is part of the screen (no dialog). It occupies the body until a
  /// filter is applied, after which the search bar and the list take over.
  bool _isFilterPanelOpen = true;

  /// The filter values the currently displayed data was fetched with. Null
  /// until the first fetch, so nothing is claimed before a filter is applied.
  String? _appliedDateOption;
  String? _appliedBuyInOption;

  static const Map<String, String> _dateOptionLabels = {
    '1': '1 Month',
    '2': '03 Months',
    '3': '06 Months',
    '4': '12 Months',
  };

  static const Map<String, String> _buyInOptionLabels = {
    '1': '1M',
    '2': '2.5M',
    '3': '5M',
    '4': '10M',
    '5': '20M',
    '6': '100M',
  };

  /// True while the Ballys group list is on screen (no group picked yet).
  bool get _showingGroups => _isBallys && _selectedGroup == null;

  @override
  void initState() {
    super.initState();
    // ADD THIS BLOCK
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppMode();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeAppMode() async {
    try {
      final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
      if (mounted) {
        setState(() => _isBallys = !apiUrl.contains('bty.world'));
      }
      final salesCode = await StorageUtil.getSalesCode();
      if (salesCode != null) {
        ref.read(appmodeSettingsProvider.notifier).setSalesCode(salesCode);
      }
    } catch (e) {

    }
  }

  void _applyFilter() async {
    // Only the newest request is allowed to write results, so an app-mode
    // change mid-fetch can't be overwritten by the older call.
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _isFilterPanelOpen = false;
    });
    final appMode = ref.read(appmodeSettingsProvider).appMode;
    final salesCode = await StorageUtil.getSalesCode();
    final marketingCode = await StorageUtil.getMarketingCode();
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    final isBellagio = apiUrl.contains('bty.world');

    try {
      final result = await widget.inactiveMembersRepository.getInactiveMembers(
        selectedDateOption,
        selectedBuyInOption,
        appMode,
        salesCode!,
      );
      final filtered = _applyGroupFilter(
        result.members,
        salesCode,
        marketingCode,
        isBellagio,
      );
      if (!mounted || requestId != _requestId) return;
      _searchController.clear();
      setState(() {
        _appliedDateOption = selectedDateOption;
        _appliedBuyInOption = selectedBuyInOption;
        _isBallys = !isBellagio;
        originalMembers = filtered;
        inactiveMembers = List<Guest>.from(originalMembers);
        originalGroups = result.groups;
        groups = List<InactiveMemberGroup>.from(originalGroups);
        _selectedGroup = null;
        _selectedRating = null;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _appliedDateOption = selectedDateOption;
        _appliedBuyInOption = selectedBuyInOption;
        originalMembers = [];
        inactiveMembers = [];
        originalGroups = [];
        groups = [];
        _selectedGroup = null;
        _selectedRating = null;
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Drills into one marketing group: shows only the members of that mGroup.
  void _openGroup(InactiveMemberGroup group) {
    _searchController.clear();
    setState(() {
      _selectedGroup = group;
      _selectedRating = null;
      inactiveMembers = _filteredMembers();
    });
  }

  /// Returns from a group's member list to the group list.
  void _closeGroup() {
    _searchController.clear();
    setState(() {
      _selectedGroup = null;
      _selectedRating = null;
      inactiveMembers = _filteredMembers();
      groups = List<InactiveMemberGroup>.from(originalGroups);
    });
  }

  void _onSearchChanged(String value) {
    final query = value.toLowerCase();
    setState(() {
      if (_showingGroups) {
        groups = query.isEmpty
            ? List<InactiveMemberGroup>.from(originalGroups)
            : originalGroups
                  .where(
                    (g) =>
                        g.gName.toLowerCase().contains(query) ||
                        g.mGroup.toLowerCase().contains(query),
                  )
                  .toList();
        return;
      }

      inactiveMembers = _filteredMembers();
    });
  }

  /// Members of the current scope (one marketing group once drilled in),
  /// before the rating chips and the search box narrow them further.
  List<Guest> get _scopedMembers => _selectedGroup == null
      ? List<Guest>.from(originalMembers)
      : originalMembers
            .where((g) => (g.mGroup ?? '') == _selectedGroup!.mGroup)
            .toList();

  /// Rating bucket a member falls in; blanks fold into 'N/A' so every member
  /// is counted exactly once.
  String _ratingKey(Guest guest) {
    final rating = (guest.gRating ?? '').trim();
    return rating.isEmpty ? 'N/A' : rating.toUpperCase();
  }

  /// Scope + search, with the rating chip deliberately left out: these are the
  /// numbers the chips show, so tapping one lands on exactly that many rows.
  List<Guest> _searchedMembers() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _scopedMembers;
    return _scopedMembers
        .where(
          (guest) =>
              guest.memberName.toLowerCase().contains(query) ||
              guest.mid.toLowerCase().contains(query),
        )
        .toList();
  }

  /// The list actually rendered: scope + search + the selected rating chip.
  List<Guest> _filteredMembers() {
    final searched = _searchedMembers();
    if (_selectedRating == null) return searched;
    return searched.where((g) => _ratingKey(g) == _selectedRating).toList();
  }

  /// Per-rating tally for the chip row, biggest bucket first.
  List<MapEntry<String, int>> _ratingCounts() {
    final counts = <String, int>{};
    for (final guest in _searchedMembers()) {
      counts.update(_ratingKey(guest), (value) => value + 1, ifAbsent: () => 1);
    }
    return counts.entries.toList()
      ..sort(
        (a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.compareTo(b.key),
      );
  }

  /// Taps a rating chip. Tapping the selected one clears back to 'All'.
  void _onRatingSelected(String? rating) {
    setState(() {
      _selectedRating = _selectedRating == rating ? null : rating;
      inactiveMembers = _filteredMembers();
    });
  }

  // Group gating only applies for Bellagio logins. For Ballys, every member is
  // shown. Within Bellagio, sales codes AD001 and "MKT CC" see every member;
  // otherwise only members in the logged-in user's marketing group are shown.
  List<Guest> _applyGroupFilter(
    List<Guest> list,
    String? salesCode,
    String? marketingCode,
    bool isBellagio,
  ) {
    if (!isBellagio) return list;
    if (salesCode == 'AD001' || salesCode == 'MKT CC') return list;
    return list
        .where(
          (g) =>
              marketingCode != null &&
              (g.mGroup ?? '').isNotEmpty &&
              marketingCode == g.mGroup,
        )
        .toList();
  }

  // final Map<String, String> ratingImageMap = {
  //   "CLASSIC": "assets/images/ratings/CLASSIC.png",
  //   "DIAMOND": "assets/images/ratings/DIAMOND.png",
  //   "GOLD": "assets/images/ratings/GOLD.png",
  //   "INFINITY": "assets/images/ratings/INFINITY.png",
  //   "PLATINUM": "assets/images/ratings/PLATINUM.png",
  //   "SILVER": "assets/images/ratings/SILVER.png",
  // };
  Color _getRatingColor(String? rating) {
    switch ((rating ?? '').toUpperCase()) {
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
      case 'CLASSIC':
        return const Color(0xFF5D4037);
      default:
        return const Color(0xFF5D4037);
    }
  }
  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    ref.listen<AppModeSettings>(appmodeSettingsProvider, (prev, next) {
      if (prev?.appMode != next.appMode) {
        _applyFilter();
      }
    });
    return PopScope(
      canPop: _selectedGroup == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeGroup();
      },
      child: GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(

        appBar: AppBar(title: Text(
          _selectedGroup?.gName ?? 'Inactive Members',
        ),
        leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      if (_selectedGroup != null) {
        _closeGroup();
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/menu');
      }
    },
  ),),

        body: Stack(
          children: [
            // Builder so the MediaQuery below is derived from a context
            // *inside* the Scaffold body: the outer context still carries the
            // status bar padding that Scaffold strips for the body, and
            // reinstating it makes ListView pad itself by that amount.
            Builder(
              builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(_textScale)),
              child: Column(
              children: [
                // ── Text size selector (1x / 1.2x / 1.3x) ──────────────
                MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.noScaling),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _buildTextScaleSelector(),
                  ),
                ),
                if (_isFilterPanelOpen)
                  _buildFilterPanel()
                else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: _showingGroups
                          ? 'Search marketing group'
                          : 'Search name or member ID',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            ),
                          IconButton(
                            tooltip: 'Change filter',
                            icon: const Icon(
                              Icons.tune,
                              color: Constants.kPrimaryColor,
                            ),
                            onPressed: _openFilterPanel,
                          ),
                        ],
                      ),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.08),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28.0),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28.0),
                        borderSide: const BorderSide(
                          color: Constants.kPrimaryColor,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28.0),
                      ),
                    ),
                  ),
                ),
                _buildAppliedFilterBar(),
                if (!_showingGroups && !_isLoading) _buildRatingCountBar(),
                if (_showingGroups)
                  Expanded(
                    child: groups.isEmpty
                        ? _buildEmptyState(
                            'No marketing groups found',
                            'Try a shorter period or a lower buy in.',
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListView.builder(
                              itemCount: groups.length,
                              itemBuilder: (context, index) =>
                                  _buildGroupCard(groups[index], fontSettings),
                            ),
                          ),
                  )
                else
                Expanded(
                  child: inactiveMembers.isEmpty
                      ? _buildEmptyState(
                          'No inactive members found',
                          'Try a shorter period or a lower buy in.',
                        )
                      : Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ListView.builder(
                            itemCount: inactiveMembers.length,
                            itemBuilder: (context, index) {
                              final guest = inactiveMembers[index];
                              return Stack(
                                children: [
                                  InkWell(
                                    key: ValueKey(guest.mid),
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                  onTap: () {
  ref
      .read(selectedGuestProvider.notifier)
      .setSelectedGuest(guest);
  context.push('/home/profile', extra: {'showFollowButton': true});
},
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 5.0,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.0,
                                        ),
                                      ),
                                      elevation: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 16.0,
                                          right: 16.0,
                                          top: 28.0,
                                          bottom: 16.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    "${guest.mid} - ${guest.memberName}",
                                                    style: TextStyle(
                                                      fontSize:
                                                          fontSettings.fontSize,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today,
                                                  color: Colors.grey,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Last visit on ${DateFormat('dd MMM yyyy').format(DateTime.parse(guest.lastVisitDate))}',
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    fontWeight:
                                                        fontSettings.fontWeight,
                                                    color: const Color.fromARGB(255, 8, 8, 8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 3,
                                    child: 
                                    // Padding(
                                    //   padding: const EdgeInsets.all(0),
                                    //   child: SizedBox(
                                    //     width: 80,
                                    //     height: 26,
                                    //     child:
                                    //         ratingImageMap[guest.gRating] !=
                                    //             null
                                    //         ? Hero(
                                    //             tag:
                                    //                 "rating-image-${guest.mid}",
                                    //             child: Image.asset(
                                    //               ratingImageMap[guest
                                    //                   .gRating]!,
                                    //               fit: BoxFit.contain,
                                    //             ),
                                    //           )
                                    //         : Hero(
                                    //             tag:
                                    //                 "rating-image-${guest.mid}",
                                    //             child: Image.asset(
                                    //               "assets/images/ratings/CLASSIC.png",
                                    //               fit: BoxFit.contain,
                                    //             ),
                                    //           ),
                                    //   ),
                                    // ),
                                     Hero(
                    tag: "rating-image-${guest.mid}",
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getRatingColor(guest.gRating),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        guest.gRating ?? 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                ),
                ],
              ],
              ),
            ),
            ),
            if (_isLoading)
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
            //const Watermark(),
          ],
        ),
      ),
    ),
    );
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

  /// Shows which filter the listed data was fetched with. Rendered on both the
  /// group list and a group's member list; empty until a filter is applied.
  Widget _buildAppliedFilterBar() {
    if (_appliedDateOption == null || _appliedBuyInOption == null) {
      return const SizedBox.shrink();
    }
    final dateLabel = _dateOptionLabels[_appliedDateOption] ?? '-';
    final buyInLabel = _buyInOptionLabels[_appliedBuyInOption] ?? '-';

    final count = _showingGroups ? groups.length : inactiveMembers.length;
    final countLabel = _showingGroups
        ? '$count ${count == 1 ? 'group' : 'groups'}'
        : '$count ${count == 1 ? 'member' : 'members'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildFilterChip(Icons.event_busy, dateLabel),
                    _buildFilterChip(
                      Icons.account_balance_wallet_outlined,
                      buyInLabel,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _openFilterPanel,
                style: TextButton.styleFrom(
                  foregroundColor: Constants.kPrimaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Change'),
              ),
            ],
          ),
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 2),
              child: Text(
                countLabel,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }

  /// Rating tally shown above the member cards. Each chip filters the list to
  /// that rating; tapping the selected chip (or 'All') clears the filter.
  Widget _buildRatingCountBar() {
    final counts = _ratingCounts();
    if (counts.isEmpty) return const SizedBox.shrink();

    final total = counts.fold<int>(0, (sum, entry) => sum + entry.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _buildRatingChip(
              label: 'ALL',
              count: total,
              color: Constants.kPrimaryColor,
              selected: _selectedRating == null,
              onTap: () => _onRatingSelected(null),
            ),
            for (final entry in counts)
              _buildRatingChip(
                label: entry.key,
                count: entry.value,
                color: _getRatingColor(entry.key),
                selected: _selectedRating == entry.key,
                onTap: () => _onRatingSelected(entry.key),
              ),
          ],
        ),
      ),
    );
  }

  /// One rating chip: the rating name with its count, filled while selected.
  Widget _buildRatingChip({
    required String label,
    required int count,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected ? color : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Friendly placeholder with a way out, instead of a bare line of text.
  Widget _buildEmptyState(String title, String hint) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openFilterPanel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Constants.kPrimaryColor,
                side: const BorderSide(color: Constants.kPrimaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Change filter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Constants.kPrimaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Constants.kPrimaryColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Constants.kPrimaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// One Table1 row: marketing group name with its inactive-member count.
  Widget _buildGroupCard(InactiveMemberGroup group, FontSettings fontSettings) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () => _openGroup(group),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.gName,
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // if (group.mGroup.isNotEmpty) ...[
                    //   const SizedBox(height: 4),
                    //   Text(
                    //     group.mGroup,
                    //     style: TextStyle(
                    //       fontSize: fontSettings.fontSize - 2,
                    //       fontWeight: fontSettings.fontWeight,
                    //       color: Colors.grey[600],
                    //     ),
                    //   ),
                    // ],
                  ],
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
                  '${group.count}',
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

  /// Re-opens the in-page filter, seeded with the values the list was fetched
  /// with so a cancel can put them back.
  void _openFilterPanel() {
    FocusScope.of(context).unfocus();
    setState(() {
      selectedDateOption = _appliedDateOption ?? selectedDateOption;
      selectedBuyInOption = _appliedBuyInOption ?? selectedBuyInOption;
      _isFilterPanelOpen = true;
    });
  }

  /// The filter rendered inside the screen instead of a dialog. It fills the
  /// body until the user taps 'Show Members', which hands over to the search
  /// bar and the result list.
  Widget _buildFilterPanel() {
    final hasAppliedFilter = _appliedDateOption != null;
    final dateLabel = _dateOptionLabels[selectedDateOption] ?? '-';
    final buyInLabel = _buyInOptionLabels[selectedBuyInOption] ?? '-';

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row(
            //   children: [
                // Container(
                //   padding: const EdgeInsets.all(10),
                //   decoration: BoxDecoration(
                //     color: Constants.kPrimaryColor.withOpacity(0.15),
                //     borderRadius: BorderRadius.circular(12),
                //   ),
                //   child: const Icon(
                //     Icons.tune,
                //     color: Constants.kPrimaryColor,
                //   ),
                // ),
                // const SizedBox(width: 12),
                // Expanded(
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       const Text(
                //         'Choose your filter',
                //         style: TextStyle(
                //           fontSize: 18,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //       const SizedBox(height: 2),
                //       Text(
                //         'Pick how long members have been away and their buy in level.',
                //         style: TextStyle(
                //           fontSize: 13,
                //           color: Colors.grey[600],
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
            //   ],
            // ),
            //const SizedBox(height: 20),
            _buildFilterSection(
              icon: Icons.event_busy,
              title: 'Not visited for',
              options: _dateOptionLabels,
              selectedValue: selectedDateOption,
              onChanged: (value) => setState(() => selectedDateOption = value),
            ),
            const SizedBox(height: 16),
            _buildFilterSection(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Buy in',
              options: _buyInOptionLabels,
              selectedValue: selectedBuyInOption,
              onChanged: (value) => setState(() => selectedBuyInOption = value),
            ),
            const SizedBox(height: 20),
            // Container(
            //   padding: const EdgeInsets.all(12),
            //   decoration: BoxDecoration(
            //     color: Colors.grey.withOpacity(0.12),
            //     borderRadius: BorderRadius.circular(12),
            //   ),
            //   child: Row(
            //     children: [
            //       Icon(Icons.info_outline, size: 18, color: Colors.grey[700]),
            //       const SizedBox(width: 8),
            //       Expanded(
            //         child: Text(
            //           'Showing members inactive for $dateLabel with $buyInLabel buy in.',
            //           style: TextStyle(
            //             fontSize: 13,
            //             color: Colors.grey[800],
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            // const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _applyFilter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.kPrimaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.search),
                label: const Text(
                  'Show Members',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (hasAppliedFilter) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      selectedDateOption = _appliedDateOption!;
                      selectedBuyInOption = _appliedBuyInOption!;
                      _isFilterPanelOpen = false;
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// One titled group of radio options in the in-page filter.
  Widget _buildFilterSection({
    required IconData icon,
    required String title,
    required Map<String, String> options,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // RadioGroup owns the selection, so each Radio only declares its value.
          RadioGroup<String>(
            groupValue: selectedValue,
            onChanged: (value) => onChanged(value!),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Two per row so a six-option list stays compact.
                final itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in options.entries)
                      SizedBox(
                        width: itemWidth,
                        child: _buildRadioOption(
                          value: entry.key,
                          label: entry.value,
                          isSelected: entry.key == selectedValue,
                          onTap: () => onChanged(entry.key),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// A radio button with its label, in a tappable row so the whole option is a
  /// touch target rather than just the small dot.
  Widget _buildRadioOption({
    required String value,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Constants.kPrimaryColor.withOpacity(0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Constants.kPrimaryColor
                  : Colors.grey.withOpacity(0.30),
            ),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: value,
                activeColor: Constants.kPrimaryColor,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Constants.kPrimaryColor
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
