import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/models/last_three_months.dart';
import 'package:ballys_reservation_app/providers/last_three_months_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

/// Member-level breakdown for one SM within the "Last 3 Months" report.
/// Mirrors MarketingDetailPage's layout, summary card, expandable member
/// cards, and tap-to-view-profile behavior.
class LastThreeMonthsDetailPage extends ConsumerStatefulWidget {
  final String smCode;
  final String smName;
  final double winSpecificMember;

  const LastThreeMonthsDetailPage({
    super.key,
    required this.smCode,
    required this.smName,
    required this.winSpecificMember,
  });

  @override
  ConsumerState<LastThreeMonthsDetailPage> createState() =>
      _LastThreeMonthsDetailPageState();
}

class _LastThreeMonthsDetailPageState
    extends ConsumerState<LastThreeMonthsDetailPage> with ConnectivityMixin {
  List<LastThreeMonthsDetailedData> filteredMembers = [];
  String? currentLoadingMember;
  Set<String> expandedCards = {};
  bool? _memProfSH;
  String? _userMarketingCode;

  @override
  void initState() {
    super.initState();
    _loadMemberDetails();
    _loadAccessSettings();
  }

  Future<void> _loadAccessSettings() async {
    final memProfSH = await StorageUtil.getMemProfSH();
    final userMarketingCode = await StorageUtil.getMarketingCode();
    if (mounted) {
      setState(() {
        _memProfSH = memProfSH;
        _userMarketingCode = userMarketingCode;
      });
    }
  }

  bool _hasPermissionToViewMember(LastThreeMonthsDetailedData member) {
    // When memProfSH is null or true, every member is accessible.
    if (_memProfSH == null || _memProfSH == true) {
      return true;
    }

    // When memProfSH is false, only members in the logged-in user's
    // marketing group can be opened.
    if (_memProfSH == false) {
      return _userMarketingCode != null &&
          member.sm.isNotEmpty &&
          _userMarketingCode == member.sm;
    }

    return true;
  }

  void _loadMemberDetails() {
    final notifier = ref.read(lastThreeMonthsProvider.notifier);
    filteredMembers = notifier.getDetailedDataForSM(widget.smCode);
    setState(() {});
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return 'N/A';
    return NumberFormat("#,##0").format(amount);
  }

  Color _getAmountColor(double amount) {
    if (amount == 0) return Colors.red;
    if (amount > 0) return Colors.red;
    if (amount < 0) return Colors.green;
    return Colors.black87;
  }

  Future<void> _handleMemberIdTap(LastThreeMonthsDetailedData member) async {
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
      appBar: AppBar(title: const Text('Last 3 Months Details')),
      body: Stack(
        children: [
          filteredMembers.isEmpty
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

                              // Totals always computed from the loaded
                              // member rows (no separate Result table here).
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

                              _buildSummaryItem(
                                title: widget.winSpecificMember > 0
                                    ? "LOSS"
                                    : widget.winSpecificMember < 0
                                        ? "WIN"
                                        : "N/A",
                                value: NumberFormat("#,##0.##").format(
                                  widget.winSpecificMember,
                                ),
                                color: _getAmountColor(
                                  widget.winSpecificMember,
                                ),
                                fontSettings: fontSettings,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Member Cards
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

  // "NEW" badge shown when the member's G_Status == 1.
  Widget _buildNewMemberBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon(Icons.fiber_new, size: 14, color: Colors.white),
         // SizedBox(width: 3),
          Text(
            'NEW',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(LastThreeMonthsDetailedData member, fontSettings) {
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
                            member.winLost > 0
                                ? 'LOSS'
                                : member.winLost < 0
                                    ? 'WIN'
                                    : 'N/A',
                            style: TextStyle(
                              fontSize: fontSettings.fontSize - 1,
                              fontWeight: fontSettings.fontWeight,
                              color: const Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member.winLost == 0
                                ? 'N/A'
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
                  _buildDetailItem(
                    'MDrop',
                    _formatCurrency(member.mDrop),
                    fontSettings,
                  ),
                  _buildDetailItem(
                    'Cash Out',
                    member.cashOut == 0
                        ? 'N/A'
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