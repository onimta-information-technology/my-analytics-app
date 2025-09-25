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
  String? currentLoadingMember; // Track single loading member

  @override
  void initState() {
    super.initState();
    _loadMemberDetails();
  }

  void _loadMemberDetails() {
    final notifier = ref.read(marketingProvider.notifier);
    filteredMembers = notifier.getDetailedDataForSM(widget.smCode);

    print('=== MarketingDetailPage ===');
    print('SM Code: ${widget.smCode}');
    print('SM Name: ${widget.smName}');
    print('Tab Index: ${widget.currentTabIndex}');
    print('Filtered members count: ${filteredMembers.length}');

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
    if (amount > 0) return Colors.red; // N/A values are red
    if (amount < 0) return Colors.green; // Negative amounts are green
    return Colors.black87; // Positive amounts are black
  }

  // Handle member ID click with loading state
  Future<void> _handleMemberIdTap(String memberId) async {
    // Prevent multiple clicks for the same user or if already loading
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
        context.push('/home/profile');
      }
    } catch (error) {
      // Handle error if needed
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
                      // 🔹 Top Card Section
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

                      Table(
                        border: TableBorder.all(),
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(1.5),
                        },
                        children: filteredMembers
                            .map(
                              (member) =>
                                  _buildMemberRows(member, fontSettings),
                            )
                            .expand((rows) => rows)
                            .toList(),
                      ),
                    ],
                  ),
                ),
          const Watermark(),
        ],
      ),
    );
  }

  List<TableRow> _buildMemberRows(MarketingDetailedData member, fontSettings) {
    return [
      // Header row for each member
      TableRow(
        decoration: const BoxDecoration(
          color: Color.fromARGB(47, 181, 225, 250),
        ),
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              '',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            // child: Center(
            child: Text(
              'Detail',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSettings.fontSize + 1,
                fontWeight: FontWeight.w900,
              ),
              //  ),
            ),
          ),
        ],
      ),
      // Member data rows
      _buildDetailRow(
        'Member ID',
        member.memId,
        fontSettings,
        isLink: true,
        isLoading: currentLoadingMember == member.memId,
        onTap: () => _handleMemberIdTap(member.memId),
      ),
      _buildDetailRow(
        'Member Name',
        member.mName.isNotEmpty ? member.mName : 'N/A',
        fontSettings,
      ),
      _buildDetailRow('MDrop', _formatCurrency(member.mDrop), fontSettings),
      _buildDetailRow(
        'Cash Out',
        member.cashOut == 0 ? 'N/A' : _formatCurrency(member.cashOut),
        fontSettings,
      ),
      _buildDetailRow(
        'Commission',
        _formatCurrency(member.comm),
        fontSettings,
        valueColor: _getAmountColor(member.comm),
      ),
      _buildDetailRow(
        'Paid Commission',
        _formatCurrency(member.paidComm),
        fontSettings,
      ),
      _buildDetailRow(
        'Balance Commission',
        _formatCurrency(member.balanceComm),
        fontSettings,
        valueColor: _getAmountColor(member.balanceComm),
      ),
      _buildDetailRow(
        'Win/Lost',
        member.winLost == 0 ? 'N/A' : _formatCurrency(member.winLost),
        fontSettings,
        isBold: true,
        valueColor: _getAmountColor(member.winLost),
      ),
    ];
  }

  TableRow _buildDetailRow(
    String label,
    String value,
    fontSettings, {
    bool isLink = false,
    bool isLoading = false,
    Color? valueColor,
    VoidCallback? onTap,
    bool isBold = false,
  }) {
    return TableRow(
      children: [
        Container(
          width: double.infinity,
          color: Constants.kPrimaryColor.withAlpha(50),
          padding: const EdgeInsets.all(8.0),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: isLink
              ? GestureDetector(
                  onTap: isLoading ? null : onTap, // Disable tap when loading
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading) ...[
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: isLoading ? Colors.grey : Colors.blue,
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                            // decoration: isLoading
                            //     ? null
                            //     : TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: valueColor ?? Colors.black,
                    fontSize: fontSettings.fontSize,
                    fontWeight: fontSettings.fontWeight,
                  ),
                ),
        ),
      ],
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
            fontSize: fontSettings.fontSize + 4, // 👈 dynamic font size
            fontWeight: FontWeight.bold, // 👈 dynamic weight
            // color: Colors.black,
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
