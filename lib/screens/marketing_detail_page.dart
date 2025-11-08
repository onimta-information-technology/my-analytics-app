import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/providers/marketing_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MarketingDetailPage extends ConsumerStatefulWidget {
  final String smCode;
  final String smName;
  final int currentTabIndex;
  final double winSpecificMember;

  const MarketingDetailPage({
    super.key,
    required this.smCode,
    required this.smName,
    required this.currentTabIndex,
    required this.winSpecificMember,
  });

  @override
  ConsumerState<MarketingDetailPage> createState() =>
      _MarketingDetailPageState();
}

class _MarketingDetailPageState extends ConsumerState<MarketingDetailPage> {
  List<MarketingDetailedData> filteredMembers = [];
  String? currentLoadingMember;
  Set<String> expandedCards = {}; // Track which cards are expanded

  @override
  void initState() {
    super.initState();
    _loadMemberDetails();
  }

  void _loadMemberDetails() {
    final notifier = ref.read(marketingProvider.notifier);
    filteredMembers = notifier.getDetailedDataForSM(widget.smCode);
    setState(() {});
  }

  String _getTabTitle() {
    switch (widget.currentTabIndex) {
      case 0:
        return "Today";
      case 1:
        return "Yesterday";
      case 2:
        return "Monthly";
      default:
        return "Today";
    }
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return 'N/A';
    return NumberFormat("#,##0.##").format(amount);
  }

  Color _getAmountColor(double amount) {
    if (amount == 0) return Colors.red;
    if (amount > 0) return Colors.red;
    if (amount < 0) return Colors.green;
    return Colors.black87;
  }

  Future<void> _handleMemberIdTap(String memberId) async {
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

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${_getTabTitle()} Marketing Details')),
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
                                title: "WIN/LOST",
                                value: NumberFormat("#,##0.##").format(
                                  widget.winSpecificMember.toDouble() * 1000,
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
                                  : () => _handleMemberIdTap(member.memId),
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
                                  Flexible(
                                    child: Text(
                                      member.memId,
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize + 2,
                                        fontWeight: FontWeight.bold,
                                        color: isLoading
                                            ? Colors.grey
                                            : Colors.blue,
                                      ),
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
                            'Win/Lost',
                            style: TextStyle(
                              fontSize: fontSettings.fontSize - 1,
                              fontWeight: fontSettings.fontWeight,
                              color: Colors.grey[600],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Text(
            value,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
              color: valueColor ?? Colors.black,
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
          ),
        ),
      ],
    ),
  );
}
