import 'package:ballys_reservation_app/models/marketing.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MarketingTargetDetailPage extends ConsumerStatefulWidget {
  final String gcode;
  final String gName;
  final double actualDrop;
  final double mTarget;
  final double achievement;
  final List<MarketingTargetDetail> detailRows;
  final String tabTitle;

  const MarketingTargetDetailPage({
    super.key,
    required this.gcode,
    required this.gName,
    required this.actualDrop,
    required this.mTarget,
    required this.achievement,
    required this.detailRows,
    required this.tabTitle,
  });

  @override
  ConsumerState<MarketingTargetDetailPage> createState() =>
      _MarketingTargetDetailPageState();
}

class _MarketingTargetDetailPageState
    extends ConsumerState<MarketingTargetDetailPage> {
  String? _loadingMemberId;
  bool? _memProfSH;
  String? _userMarketingCode;

  @override
  void initState() {
    super.initState();
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

  bool _hasPermissionToViewMember(MarketingTargetDetail row) {
    // When memProfSH is null or true, every member is accessible.
    if (_memProfSH == null || _memProfSH == true) {
      return true;
    }

    // When memProfSH is false, only members in the logged-in user's
    // marketing group can be opened.
    if (_memProfSH == false) {
      return _userMarketingCode != null &&
          row.gcode.isNotEmpty &&
          _userMarketingCode == row.gcode;
    }

    return true;
  }

  String _formatNumber(double v) {
    if (v == 0) return '0';
    return NumberFormat("#,##0").format(v);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('dd MMM yyyy').format(d);
  }

  Future<void> _handleMemberIdTap(MarketingTargetDetail row) async {
    final memberId = row.mid;

    if (!_hasPermissionToViewMember(row)) {
      _showAccessDeniedDialog();
      return;
    }

    if (_loadingMemberId != null) return;
    setState(() => _loadingMemberId = memberId);
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
      if (mounted) setState(() => _loadingMemberId = null);
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
    final sorted = [...widget.detailRows]
      ..sort((a, b) {
        final mid = a.mid.compareTo(b.mid);
        if (mid != 0) return mid;
        return a.tripNo.compareTo(b.tripNo);
      });
final fontSettings = ref.watch(fontSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tabTitle} Target Details'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Summary card ──
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          widget.gName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        // Text(
                        //   'Code: ${widget.gcode}',
                        //   style: TextStyle(
                        //    fontSize: fontSettings.fontSize,
                        //    fontWeight: fontSettings.fontWeight,
                        //     color: Colors.grey[600],
                        //   ),
                        // ),
                        const SizedBox(height: 16),
                        _summaryTile(
                          label: 'ACTUAL DROP',
                          value: _formatNumber(widget.actualDrop),
                          color: Colors.blue,
                           fontSettings: fontSettings,
                        ),
                        const SizedBox(height: 10),
                        _summaryTile(
                          label: 'TARGET',
                          value: _formatNumber(widget.mTarget),
                          color: const Color.fromARGB(255, 34, 0, 255)!,
                          fontSettings: fontSettings,
                        ),
                        const SizedBox(height: 10),
                        _summaryTile(
                          label: 'ACHIEVEMENT',
                          value: '${widget.achievement.toStringAsFixed(2)}%',
                          color: Colors.black87,
                          fontSettings: fontSettings,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Member trip list ──
                if (sorted.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No member trip data found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Member Trips (${sorted.length})',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...sorted.map((row) => _buildTripCard(row,fontSettings)),
                ],
              ],
            ),
          ),
          const Watermark(),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required String label,
    required String value,
    required Color color,
      required fontSettings,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(  fontSize: fontSettings.fontSize + 4, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
             fontSize: fontSettings.fontSize + 2,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(MarketingTargetDetail row,fontSettings) {
    final isLoading = _loadingMemberId == row.mid;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: tappable member ID + trip badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Member ID — tappable to open profile
                GestureDetector(
                  onTap: isLoading ? null : () => _handleMemberIdTap(row),
                  child: Row(
                    children: [
                      if (isLoading) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ] else ...[
                        const Icon(
                          Icons.touch_app,
                          size: 20,
                          color: Color.fromARGB(255, 230, 0, 0),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        row.mid,
                        style: TextStyle(
                         fontSize: fontSettings.fontSize + 2,
                          fontWeight: FontWeight.bold,
                          color: isLoading ? Colors.grey : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trip badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[50],
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.deepPurple[200]!, width: 1),
                  ),
                  child: Text(
                    'Trip ${row.tripNo}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),

            // Row 2: member name
            const SizedBox(height: 4),
            Text(
              row.mName.isNotEmpty ? row.mName : 'N/A',
              style:  TextStyle( fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight, color: Colors.black87),
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Dates row
            Row(
              children: [
                Expanded(
                    child:
                        _detailRow('Arrival', _formatDate(row.arrivalDate),fontSettings)),
                const SizedBox(width: 8),
                Expanded(
                    child: _detailRow(
                        'Departure', _formatDate(row.departureDate),fontSettings)),
              ],
            ),
            const SizedBox(height: 6),

            // Actual Drop
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Actual Drop',
                    style:
                        TextStyle( fontSize: fontSettings.fontSize,fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 0, 0, 0))),
                Text(
                  _formatNumber(row.actualDrop),
                  style:  TextStyle(
                     fontSize: fontSettings.fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
           // const SizedBox(height: 4),

            // Group
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     Text('Group',
            //         style:
            //             TextStyle(fontSize: 13, color: Colors.grey[700])),
            //     Text(
            //       row.gName.isNotEmpty ? row.gName : row.gcode,
            //       style: const TextStyle(
            //           fontSize: 13, fontWeight: FontWeight.w500),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value,fontSettings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle( fontSize: fontSettings.fontSize, fontWeight: FontWeight.bold,color: const Color.fromARGB(255, 0, 0, 0))),
        const SizedBox(height: 2),
        Text(value,
            style:
                 TextStyle(fontSize: fontSettings.fontSize, fontWeight: FontWeight.bold)),
      ],
    );
  }
}