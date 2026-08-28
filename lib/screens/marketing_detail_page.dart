import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/providers/marketing_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class MarketingDetailPage extends ConsumerStatefulWidget {
  final String smCode;
  final String smName;
  final int currentTabIndex;
  final double winSpecificMember;
  final double? mDrop; // NEW: Optional MDrop
  final double? cashOut; // NEW: Optional CashOut
  final MarketingViewType viewType; // NEW: which view tab opened this page

  const MarketingDetailPage({
    super.key,
    required this.smCode,
    required this.smName,
    required this.currentTabIndex,
    required this.winSpecificMember,
    this.mDrop,
    this.cashOut,
    this.viewType = MarketingViewType.performance,
  });

  @override
  ConsumerState<MarketingDetailPage> createState() =>
      _MarketingDetailPageState();
}

enum MemberTypeFilter { both, newMembers, oldMembers, packageMembers }

class _MarketingDetailPageState extends ConsumerState<MarketingDetailPage> with ConnectivityMixin{
  List<MarketingDetailedData> allMembers = [];
  List<MarketingDetailedData> filteredMembers = [];
  MemberTypeFilter _memberFilter = MemberTypeFilter.both;
  String? currentLoadingMember;
  Set<String> expandedCards = {};
  bool? _memProfSH;
  String? _userMarketingCode;
  String? _userSalesCode;

  @override
  void initState() {
    super.initState();
    _loadMemberDetails();
    _loadAccessSettings();
  }

  Future<void> _loadAccessSettings() async {
    final memProfSH = await StorageUtil.getMemProfSH();
    final userMarketingCode = await StorageUtil.getMarketingCode();
    final userSalesCode = await StorageUtil.getSalesCode();
    if (mounted) {
      setState(() {
        _memProfSH = memProfSH;
        _userMarketingCode = userMarketingCode;
        _userSalesCode = userSalesCode;
      });
    }
  }

  bool _hasPermissionToViewMember(MarketingDetailedData member) {
    // Sales code AD001 can view every member profile.
    if (_userSalesCode == 'AD001') {
      return true;
    }

    // When memProfSH is null or true, every member is accessible.
    // if (_memProfSH == null || _memProfSH == true ) {
    //   return true;
    // }

    // When memProfSH is false, only members in the logged-in user's
    // marketing group can be opened.
    if (_userSalesCode != "AD001") {
      return _userMarketingCode != null &&
          member.sm.isNotEmpty &&
          _userMarketingCode == member.sm;
    }

    return true;
  }

  void _loadMemberDetails() {
    final notifier = ref.read(marketingProvider.notifier);
    allMembers = notifier.getDetailedDataForSM(widget.smCode);
    _applyFilter();
    setState(() {});
  }

  void _applyFilter() {
    switch (_memberFilter) {
      case MemberTypeFilter.both:
        filteredMembers = List.of(allMembers);
        break;
      case MemberTypeFilter.newMembers:
        filteredMembers = allMembers.where((m) => m.isNewMember).toList();
        break;
      case MemberTypeFilter.oldMembers:
        filteredMembers = allMembers.where((m) => !m.isNewMember).toList();
        break;
      case MemberTypeFilter.packageMembers:
        filteredMembers = allMembers.where((m) => m.hasPackage).toList();
        break;
    }
  }

  void _onFilterChanged(MemberTypeFilter filter) {
    setState(() {
      _memberFilter = filter;
      _applyFilter();
    });
  }

  String _getTabTitle() {
    switch (widget.currentTabIndex) {
      case 0:
        return "Today";
      case 1:
        return "Yesterday";
      case 2:
        return "Monthly";
      case 3:
        return "Last Month";
      default:
        return "Today";
    }
  }

  // Label of the view tab (Performance / Result / Target) this page came from.
  String _getViewTitle() {
    switch (widget.viewType) {
      case MarketingViewType.performance:
        return "Performance";
      case MarketingViewType.result:
        return "Result";
      case MarketingViewType.target:
        return "Target";
    }
  }

  // Same accent colours as the view type toggle on the marketing card.
  Color _getViewColor() {
    switch (widget.viewType) {
      case MarketingViewType.performance:
        return Colors.blue;
      case MarketingViewType.result:
        return Colors.blue;
      case MarketingViewType.target:
        return Colors.deepPurple;
    }
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return '0';
    return NumberFormat("#,##0").format(amount);
  }

  Color _getAmountColor(double amount) {
    if (amount == 0) return Colors.red;
    if (amount > 0) return Colors.red;
    if (amount < 0) return Colors.green;
    return Colors.black87;
  }

  Future<void> _handleMemberIdTap(MarketingDetailedData member) async {
    final memberId = member.memId;

    if (!_hasPermissionToViewMember(member)) {
      _showAccessDeniedDialog();
      return;
    }

    if (currentLoadingMember == memberId || currentLoadingMember != null) {
      return;
    }

    setState(() {
      currentLoadingMember = memberId;
    });

    try {
      await ref
          .read(selectedGuestProvider.notifier)
          .setSelectedGuestWithId(memberId);

      if (mounted) {
        context.push('/home/profile', extra: {'fromMarketing': true});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading member details: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          currentLoadingMember = null;
        });
      }
    }
  }

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 50,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Access Denied",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Got It",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_getTabTitle()} Marketing Details'),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getViewColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_getViewTitle()} View',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getViewColor(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          allMembers.isEmpty
              ? const Center(
                  child: Text(
                    'No member details found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFilterBar(),
                      const SizedBox(height: 8),
                      // Top Card Section
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                widget.smName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Show MDrop and CashOut if provided (from Result view)
                              if (widget.mDrop != null &&
                                  widget.cashOut != null) ...[
                                _buildSummaryItem(
                                  title: "TOTAL DROP",
                                  value: _formatCurrency(widget.mDrop!),
                                  color: Colors.blue,
                                  fontSettings: fontSettings,
                                ),
                                const SizedBox(height: 12),
                                _buildSummaryItem(
                                  title: "TOTAL CASH OUT",
                                  value: _formatCurrency(widget.cashOut!),
                                  color: Colors.purple,
                                  fontSettings: fontSettings,
                                ),
                                const SizedBox(height: 12),
                              ] else ...[
                                // Calculate from detailed data if not provided (from Performance view)
                                _buildSummaryItem(
                                  title: "TOTAL DROP",
                                  value: _formatCurrency(
                                    filteredMembers.fold(
                                      0.0,
                                      (sum, m) => sum + m.mDrop,
                                    ),
                                  ),
                                  color: Colors.blue,
                                  fontSettings: fontSettings,
                                ),
                                const SizedBox(height: 12),
                                _buildSummaryItem(
                                  title: "TOTAL CASH OUT",
                                  value: _formatCurrency(
                                    filteredMembers.fold(
                                      0.0,
                                      (sum, m) => sum + m.cashOut,
                                    ),
                                  ),
                                  color: Colors.purple,
                                  fontSettings: fontSettings,
                                ),
                                const SizedBox(height: 12),
                              ],

                              _buildSummaryItem(
                                title: widget.winSpecificMember > 0
                                    ? "LOSS"
                                    : widget.winSpecificMember < 0
                                    ? "WIN"
                                    : "N/A",
                                value: NumberFormat("#,##0.##").format(
                                  widget.winSpecificMember.toDouble(),
                                ),
                                color: _getAmountColor(
                                  widget.winSpecificMember.toDouble(),
                                ),
                                fontSettings: fontSettings,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Member Cards
                      if (filteredMembers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(
                            child: Text(
                              'No members match this filter',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        ...filteredMembers.map(
                          (member) => _buildMemberCard(member, fontSettings),
                        ),
                    ],
                  ),
                ),
          const Watermark(),
        ],
      ),
    );
  }

  Widget _buildMemberCard(MarketingDetailedData member, fontSettings) {
    final isExpanded = expandedCards.contains(member.memId);
    final isLoading = currentLoadingMember == member.memId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Main visible section
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  expandedCards.remove(member.memId);
                } else {
                  expandedCards.add(member.memId);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Top strip of the card: G_Rating on the left, package badge
                  // on the right. Rendered whenever either side has something
                  // to show.
                  if (member.ratingDisplay != null || member.hasPackage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (member.ratingDisplay != null)
                            _buildRatingBadge(member.ratingDisplay!)
                          else
                            const SizedBox.shrink(),
                          if (member.hasPackage)
                            _buildPackageBadge()
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: isLoading
                                  ? null
                                  : () => _handleMemberIdTap(member),
                              child: Row(
                                children: [
                                  if (isLoading) ...[
                                    const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  // Flexible(
                                  //   child:
                                  //    Text(
                                  //     member.memId,
                                  //     style: TextStyle(
                                  //       fontSize: fontSettings.fontSize + 2,
                                  //       fontWeight: FontWeight.bold,
                                  //       color: isLoading
                                  //           ? Colors.grey
                                  //           : Colors.blue,
                                  //     ),
                                       
                                  //   ),
                                   
                                  // ),
                                  if (!isLoading) ...[
  const SizedBox(width: 6),
  const Icon(
    Icons.touch_app,
    size: 20,
    color: Color.fromARGB(255, 230, 0, 0),
  ),
],
                                  Expanded(
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: [
                                        Text(
                                          member.memId,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: fontSettings.fontSize + 2,
                                            fontWeight: FontWeight.bold,
                                            color: isLoading
                                                ? Colors.grey
                                                : Colors.blue,
                                          ),
                                        ),
                                        if (member.isNewMember)
                                          _buildNewMemberBadge(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              member.mName.isNotEmpty ? member.mName : 'N/A',
                              style: TextStyle(
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                           member.winLost > 0 ? 'LOSS' : member.winLost < 0 ? 'WIN' : 'N/A',
                            style: TextStyle(
                              fontSize: fontSettings.fontSize - 1,
                              fontWeight: fontSettings.fontWeight,
                              color: const Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member.winLost == 0
                                ? '0'
                                : _formatCurrency(member.winLost),
                            style: TextStyle(
                         
                              fontSize: fontSettings.fontSize + 2,
                              fontWeight: FontWeight.bold,
                              color: _getAmountColor(member.winLost),
                              fontFamily: 'monospace',
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expandable details section
          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  if (member.gActDrop != null)
                    _buildDetailItem(
                      'Actual Drop',
                      _formatCurrency(member.gActDrop!),
                      fontSettings,
                      valueColor: const Color.fromARGB(255, 189, 20, 255),
                    ),
                  _buildDetailItem(
                    'MDrop',
                    _formatCurrency(member.mDrop),
                    fontSettings,
                  ),
                  _buildDetailItem(
                    'Cash Out',
                    member.cashOut == 0
                        ? '0'
                        : _formatCurrency(member.cashOut),
                    fontSettings,
                  ),
                  _buildDetailItem(
                    'Commission',
                    _formatCurrency(member.comm),
                    fontSettings,
                    valueColor: _getAmountColor(member.comm),
                  ),
                  _buildDetailItem(
                    'Paid Commission',
                    _formatCurrency(member.paidComm),
                    fontSettings,
                  ),
                  _buildDetailItem(
                    'Balance Commission',
                    _formatCurrency(member.balanceComm),
                    fontSettings,
                    valueColor: _getAmountColor(member.balanceComm),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Segmented filter to show new members, old members, package or all.
  Widget _buildFilterBar() {
    final newCount = allMembers.where((m) => m.isNewMember).length;
    final oldCount = allMembers.length - newCount;
    final packageCount = allMembers.where((m) => m.hasPackage).length;

    return SegmentedButton<MemberTypeFilter>(
      segments: [
        ButtonSegment(
          value: MemberTypeFilter.both,
          label: Text(
            'All-${allMembers.length}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ButtonSegment(
          value: MemberTypeFilter.newMembers,
          label: Text(
            'New-$newCount',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ButtonSegment(
          value: MemberTypeFilter.oldMembers,
          label: Text(
            'Old-$oldCount',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ButtonSegment(
          value: MemberTypeFilter.packageMembers,
          label: Text(
            'Pkg-$packageCount',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
      selected: {_memberFilter},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => _onFilterChanged(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Constants.kPrimaryColor;
          }
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return null;
        }),
      ),
    );
  }

  // "NEW" badge shown when the member's G_Status == 1.
  Widget _buildNewMemberBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Tier colour for `G_Rating`, matching the rating badges on the members /
  // inactive-members / profile screens.
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

  // Rating pill from `G_Rating`, shown on the left of the package badge row.
  Widget _buildRatingBadge(String rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getRatingColor(rating),
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
        rating,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Small pill shown next to the member name when PKG_Status == "Y".
  Widget _buildPackageBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 12, 24, 162),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.card_giftcard, size: 13, color: const Color.fromARGB(255, 255, 255, 255)),
          const SizedBox(width: 4),
          Text(
            'PACKAGE',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: const Color.fromARGB(255, 255, 255, 255),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    fontSettings, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: fontSettings.fontWeight,
                color: valueColor ?? Colors.black,
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildSummaryItem({
  required String title,
  required String value,
  required Color color,
  required fontSettings,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    decoration: BoxDecoration(
      border: Border.all(color: color.withOpacity(0.3)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: fontSettings.fontSize + 4,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSettings.fontSize + 2,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'monospace',
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
