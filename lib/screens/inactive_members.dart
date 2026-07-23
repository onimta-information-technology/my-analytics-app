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

  List<Guest> originalMembers = [];
  List<Guest> inactiveMembers = [];

  /// Ballys returns a marketing-group summary (Table1) and is browsed group
  /// first, then member. Bellagio keeps the single flat member list.
  bool _isBallys = false;
  List<InactiveMemberGroup> originalGroups = [];
  List<InactiveMemberGroup> groups = [];
  InactiveMemberGroup? _selectedGroup;

  final TextEditingController _searchController = TextEditingController();

  int _requestId = 0;

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
      inactiveMembers = originalMembers
          .where((g) => (g.mGroup ?? '') == group.mGroup)
          .toList();
    });
  }

  /// Returns from a group's member list to the group list.
  void _closeGroup() {
    _searchController.clear();
    setState(() {
      _selectedGroup = null;
      inactiveMembers = List<Guest>.from(originalMembers);
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

      final source = _selectedGroup == null
          ? originalMembers
          : originalMembers
                .where((g) => (g.mGroup ?? '') == _selectedGroup!.mGroup)
                .toList();
      inactiveMembers = query.isEmpty
          ? List<Guest>.from(source)
          : source
                .where(
                  (guest) =>
                      guest.memberName.toLowerCase().contains(query) ||
                      guest.mid.toLowerCase().contains(query),
                )
                .toList();
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
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: _showingGroups
                          ? 'Search marketing group'
                          : 'Search',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () => _showFilterDialog(context),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
                _buildAppliedFilterBar(),
                if (_showingGroups)
                  Expanded(
                    child: groups.isEmpty
                        ? const Center(child: Text("No marketing groups available"))
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
                      ? const Center(
                          child: Text("No inactive members available"),
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
            const Watermark(),
          ],
        ),
      ),
    ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildFilterChip('Date: $dateLabel'),
                _buildFilterChip('Buy In: $buyInLabel'),
                // if (_selectedGroup != null)
                //   _buildFilterChip('Group: ${_selectedGroup!.gName}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Constants.kSecondaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Constants.kSecondaryColor.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 24.0,
              ),
              title: const Text('Filter'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    // mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Date (Months)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            RadioListTile(
                              title: const Text('1'),
                              value: '1',
                              groupValue: selectedDateOption,
                              onChanged: (value) {
                                setState(() {
                                  selectedDateOption = value!;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text('03'),
                              value: '2',
                              groupValue: selectedDateOption,
                              onChanged: (value) {
                                setState(() {
                                  selectedDateOption = value!;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text('06'),
                              value: '3',
                              groupValue: selectedDateOption,
                              onChanged: (value) {
                                setState(() {
                                  selectedDateOption = value!;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text('12'),
                              value: '4',
                              groupValue: selectedDateOption,
                              onChanged: (value) {
                                setState(() {
                                  selectedDateOption = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Buy In',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            RadioListTile(
                              title: const Text('1M'),
                              value: '1',
                              groupValue: selectedBuyInOption,
                              onChanged: (value) {
                                setState(() {
                                  selectedBuyInOption = value!;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text('2.5M'),
                              value: '2',
                              groupValue: selectedBuyInOption,
                              onChanged: (value) {
                                setState(() {
                                  selectedBuyInOption = value!;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text('5M'),
                              value: '3',
                              groupValue: selectedBuyInOption,
                              onChanged: (value) {
                                setState(() {
                                  selectedBuyInOption = value!;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text('10M'),
                              value: '4',
                              groupValue: selectedBuyInOption,
                              onChanged: (value) {
                                setState(() {
                                  selectedBuyInOption = value!;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text('20M'),
                              value: '5',
                              groupValue: selectedBuyInOption,
                              onChanged: (value) {
                                setState(() {
                                  selectedBuyInOption = value!;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text('100M'),
                              value: '6',
                              groupValue: selectedBuyInOption,
                              onChanged: (value) {
                                setState(() {
                                  selectedBuyInOption = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedDateOption = "1";
                      selectedBuyInOption = "1";
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _applyFilter();
                  },
                  child: const Text('Apply Filter'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
