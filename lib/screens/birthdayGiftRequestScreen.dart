import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/models/gift/birthday_gift_request.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:ballys_reservation_app/providers/BirthdayGiftIncreesNotifier.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/birthday_gift_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BirthdayGiftRequestScreen extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;
  final bool hideAddButton;
  const BirthdayGiftRequestScreen({
    super.key,
    required this.giftsRepository,
    this.hideAddButton = false,
  });

  @override
  ConsumerState<BirthdayGiftRequestScreen> createState() =>
      _BirthdayGiftRequestScreenState();
}

class _BirthdayGiftRequestScreenState
    extends ConsumerState<BirthdayGiftRequestScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Checked':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle;
      case 'Rejected':
        return Icons.cancel;
      case 'Checked':
        return Icons.fact_check;
      default:
        return Icons.hourglass_bottom;
    }
  }

  // Filter birthday gifts based on user permissions
  Future<List<BirthdayIncressGiftRequest>> _filterGifts(
      List<BirthdayIncressGiftRequest> gifts) async {
    final salesCode = await StorageUtil.getSalesCode();
    if (salesCode != null && salesCode.trim().toUpperCase() == 'AD001') {
      return gifts;
    }
 final bgChk = await StorageUtil.getBgChk();
  final bgApp = await StorageUtil.getBgApp();
  if (bgChk == true || bgApp == true) {
    return gifts;
  }
    final currentUserName = await StorageUtil.getUserName();
    if (currentUserName == null) return [];

    return gifts.where((gift) {
      return gift.reqBy.trim().toLowerCase() ==
          currentUserName.trim().toLowerCase();
    }).toList();
  }

  // Check access permission for detail view
  // Future<bool> _canAccessGiftDetails(BirthdayIncressGiftRequest gift) async {
  //   final giftApp = await StorageUtil.getGiftApp();
  //   if (giftApp == true) return true;

  //   final currentUserName = await StorageUtil.getUserName();
  //   if (currentUserName != null &&
  //       gift.reqBy.isNotEmpty &&
  //       currentUserName.trim().toLowerCase() ==
  //           gift.reqBy.trim().toLowerCase()) {
  //     return true;
  //   }

  //   return false;
  // }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
Future<bool> _canAccessGiftDetails(
  BirthdayIncressGiftRequest gift, {
  required bool isPending,
  required bool isApproved,
  required bool isChecked,
}) async {
  final salesCode = await StorageUtil.getSalesCode();

  // AD001 can access everything
  if (salesCode != null && salesCode.trim().toUpperCase() == 'AD001') {
    return true;
  }

  final currentUserName = (await StorageUtil.getUserName())?.trim().toLowerCase() ?? '';
  final reqBy = gift.reqBy.trim().toLowerCase();
  final checkedBy = (gift.checkApp ?? '').trim().toLowerCase();
  final approvedBy = (gift.firstAppBy ?? '').trim().toLowerCase();
  final rejectedBy = (gift.deleteUser ?? '').trim().toLowerCase();

  if (isPending) {
    // Pending: otgiChk == true OR loginUser == reqBy
    final bgChk = await StorageUtil.getBgChk();
    return bgChk == true || currentUserName == reqBy;
  }

  if (isChecked) {
    // Checked: otgiApp == true OR loginUser == reqBy OR loginUser == checkedBy
    final bgApp = await StorageUtil.getBgApp();
    return bgApp == true ||
        currentUserName == reqBy ||
        currentUserName == checkedBy;
  }

  if (isApproved) {
    // Approved: otgiApp == true OR loginUser == reqBy OR loginUser == approvedBy
    final bgApp = await StorageUtil.getBgApp();
    return bgApp == true ||
        currentUserName == reqBy ||
        currentUserName == approvedBy;
  }

  // Rejected: loginUser == reqBy OR loginUser == rejectedBy
  return currentUserName == reqBy || currentUserName == rejectedBy;
}
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final birthdayGiftSp = ref.read(birthdayGiftIncreesProvider);

      if (birthdayGiftSp.pendingBirthdayGift.isNotEmpty ||
          birthdayGiftSp.checkedBirthdayGift.isNotEmpty ||
          birthdayGiftSp.approvedBirthdayGift.isNotEmpty ||
          birthdayGiftSp.rejectBirthdayGift.isNotEmpty) {
        return;
      }

      String? salesCode = await StorageUtil.getSalesCode();
      if (salesCode != null && salesCode.isNotEmpty) {
        _loadBirthdayGiftData(salesCode);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try {
      final dateTime = DateTime.parse(dateStr);
      return DateFormat("yyyy-MM-dd hh:mm a").format(dateTime);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatAmount(String? amount) {
    if (amount == null || amount.isEmpty) return "N/A";
    try {
      String cleanAmount = amount.replaceAll(RegExp(r'[^0-9.]'), '');
      double value = double.parse(cleanAmount);
      final formatter = NumberFormat('#,##0', 'en_US');
      return formatter.format(value);
    } catch (e) {
      return amount;
    }
  }

  Future<void> _loadBirthdayGiftData(String salesCode) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(birthdayGiftIncreesProvider.notifier)
          .getBirthdayGiftData(98890, salesCode); // pending
      await ref
          .read(birthdayGiftIncreesProvider.notifier)
          .getBirthdayGiftData(788790, salesCode); // checked
      await ref
          .read(birthdayGiftIncreesProvider.notifier)
          .getBirthdayGiftData(98891, salesCode); // approved
      await ref
          .read(birthdayGiftIncreesProvider.notifier)
          .getBirthdayGiftData(98893, salesCode); // rejected
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Assets ─────────────────────────────────────────────────────────────────

  final Map<String, String> ratingImageMap = {
    "CLASSIC": "assets/images/ratings/CLASSIC.png",
    "DIAMOND": "assets/images/ratings/DIAMOND.png",
    "GOLD": "assets/images/ratings/GOLD.png",
    "INFINITY": "assets/images/ratings/INFINITY.png",
    "PLATINUM": "assets/images/ratings/PLATINUM.png",
    "SILVER": "assets/images/ratings/SILVER.png",
  };

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final birthdayGiftsp = ref.watch(birthdayGiftIncreesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Birthday Gift Request'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: () async {
              String? salesCode = await StorageUtil.getSalesCode();
              if (salesCode != null && salesCode.isNotEmpty) {
                _loadBirthdayGiftData(salesCode);
              }
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _buildTab(
                'Pending', birthdayGiftsp.pendingBirthdayGift.length, Colors.orange),
            _buildTab(
                'Checked', birthdayGiftsp.checkedBirthdayGift.length, Colors.blue),
            _buildTab(
                'Approved', birthdayGiftsp.approvedBirthdayGift.length, Colors.green),
            _buildTab(
                'Rejected', birthdayGiftsp.rejectBirthdayGift.length, Colors.red),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildGiftList(
                birthdayGiftsp.pendingBirthdayGift,
                isPending: true,
                isApproved: false,
                isChecked: false,
              ),
              _buildGiftList(
                birthdayGiftsp.checkedBirthdayGift,
                isPending: false,
                isApproved: false,
                isChecked: true,
              ),
              _buildGiftList(
                birthdayGiftsp.approvedBirthdayGift,
                isPending: false,
                isApproved: true,
                isChecked: false,
              ),
              _buildGiftList(
                birthdayGiftsp.rejectBirthdayGift,
                isPending: false,
                isApproved: false,
                isChecked: false,
              ),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: const Color.fromARGB(135, 117, 115, 115),
                child: const Center(
                  child: RefreshProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Constants.kSecondaryColor),
                  ),
                ),
              ),
            ),
       //   const Watermark(),
        ],
      ),
    );
  }

  // ── Tab ────────────────────────────────────────────────────────────────────

  Widget _buildTab(String title, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: Text(
              count.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gift List ──────────────────────────────────────────────────────────────

  Widget _buildGiftList(
    List<BirthdayIncressGiftRequest> gifts, {
    required bool isPending,
    required bool isApproved,
    required bool isChecked,
  }) {
    final fontSettings = ref.watch(fontSettingsProvider);

    // Derive status label once
    final String statusLabel = isApproved
        ? 'Approved'
        : isPending
            ? 'Pending'
            : isChecked
                ? 'Checked'
                : 'Rejected';

    return FutureBuilder<List<BirthdayIncressGiftRequest>>(
      future: _filterGifts(gifts),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Constants.kSecondaryColor),
            ),
          );
        }

        final filteredGifts = snapshot.data ?? [];
        if (filteredGifts.isEmpty) {
          return const Center(child: Text("No birthday gifts found"));
        }

        return ListView.builder(
          itemCount: filteredGifts.length,
          itemBuilder: (context, index) {
            final gift = filteredGifts[index];

            // ── Action row (Approved By / Rejected By / Checked By) ──────────
            String? actionBy;
            String? actionLabel;
            Color? actionColor;

            if (!isPending) {
              // FIX: Show "Checked By" on both Checked tab AND Approved tab
              if ((isChecked || isApproved) &&
                  gift.checkApp != null &&
                  gift.checkApp!.isNotEmpty) {
                actionBy = gift.checkApp;
                actionLabel = 'Checked By';
                actionColor = Colors.blue;
              } else if (gift.firstAppBy != null &&
                  gift.firstAppBy!.isNotEmpty) {
                actionBy = gift.firstAppBy;
                actionLabel = 'Approved By';
                actionColor = Colors.green;
              } else if (gift.deleteUser != null &&
                  gift.deleteUser!.isNotEmpty) {
                actionBy = gift.deleteUser;
                actionLabel = 'Rejected By';
                actionColor = Colors.red;
              }
            }

            return Stack(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                  final canAccess = await _canAccessGiftDetails(
    gift,
    isPending: isPending,
    isApproved: isApproved,
    isChecked: isChecked,
  );
                    if (!canAccess) {
                      if (mounted) _showAccessDeniedDialog();
                      return;
                    }

                    final result = await context.push(
                      '/menu/approve-reject/birthday-gifts/view-birthday-gift-request',
                      extra: {
                        'gift': gift,
                        'isPending': isPending,
                        'isApproved': isApproved,
                        'isChecked': isChecked,
                      },
                    );
                    if (result == true) {
                      String? salesCode = await StorageUtil.getSalesCode();
                      if (salesCode != null && salesCode.isNotEmpty) {
                        _loadBirthdayGiftData(salesCode);
                      }
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      title: Text(
                        '${gift.mid} - ${gift.mname}',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize + 1,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Birthday Gift label
                          Row(
                            children: [
                              const Icon(Icons.cake,
                                  color: Colors.pink, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Birthday Gift',
                                  style: TextStyle(
                                    color: Colors.pink,
                                    fontSize: fontSettings.fontSize + 2,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Insert Date
                          // Row(
                          //   children: [
                          //     const Icon(Icons.access_time,
                          //         color: Color.fromARGB(255, 0, 0, 0),
                          //         size: 16),
                          //     const SizedBox(width: 6),
                          //     Text(
                          //       _formatDate(gift.insertDate),
                          //       style: TextStyle(
                          //         color: const Color.fromARGB(255, 2, 2, 2),
                          //         fontSize: fontSettings.fontSize + 2,
                          //         fontWeight: fontSettings.fontWeight,
                          //       ),
                          //     ),
                          //   ],
                          // ),
                           Row(
                            children: [
                             const Icon(Icons.access_time,
                                 color: Color.fromARGB(255, 0, 0, 0),
                                  size: 16),
                            const SizedBox(width: 6),
                              Text('Requested: ',
                                  style: TextStyle(
                                        color: Colors.black87,
                                      fontSize: fontSettings.fontSize+1,
                                      fontWeight: fontSettings.fontWeight)),
                              Expanded(
                                child: Text(
                                   _formatDate(gift.insertDate),
                                  style: TextStyle(
                                    color: const Color.fromARGB(225, 0, 0, 0),
                                    fontSize: fontSettings.fontSize+2,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Requested By
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  color: Colors.blue, size: 16),
                              const SizedBox(width: 6),
                              Text('Requested By: ',
                                  style: TextStyle(
                                        color: Colors.black87,
                                      fontSize: fontSettings.fontSize+2,
                                      fontWeight: fontSettings.fontWeight)),
                              Expanded(
                                child: Text(
                                  gift.reqBy.isNotEmpty ? gift.reqBy : 'N/A',
                                  style: TextStyle(
                                    color: const Color.fromARGB(225, 0, 0, 0),
                                    fontSize: fontSettings.fontSize+2,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // Checked By / Approved By / Rejected By
                          if (actionBy != null && actionLabel != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  actionLabel == 'Approved By'
                                      ? Icons.check_circle_outline
                                      : actionLabel == 'Checked By'
                                          ? Icons.fact_check_outlined
                                          : Icons.cancel_outlined,
                                  color: actionColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text('$actionLabel: ',
                                    style: TextStyle(
                                         color: Colors.black87,
                                        fontSize: fontSettings.fontSize+2,
                                        fontWeight: fontSettings.fontWeight)),
                                Expanded(
                                  child: Text(
                                    actionBy,
                                    style: TextStyle(
                                        color: actionColor,
                                        fontSize: fontSettings.fontSize+2,
                                        fontWeight: fontSettings.fontWeight),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // FIX: Show "Checked At" on both Checked tab AND Approved tab
                          if ((isChecked || isApproved) &&
                              gift.checkAppByTime != null &&
                              gift.checkAppByTime!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.schedule,
                                    color: Colors.blue, size: 16),
                                const SizedBox(width: 6),
                                Text('Checked At: ',
                                    style: TextStyle(
                                         color: Colors.black87,
                                        fontSize: fontSettings.fontSize+2,
                                        fontWeight: fontSettings.fontWeight)),
                                Expanded(
                                  child: Text(
                                    _formatDate(gift.checkAppByTime!),
                                    style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Previous Gift Amount
                          if (gift.prvGiftAmount != null &&
                              gift.prvGiftAmount!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.attach_money,
                                    color: Colors.orange, size: 16),
                                const SizedBox(width: 6),
                                Text('Previous Gift: ',
                                    style: TextStyle(
                                      color: const Color.fromARGB(
                                          255, 44, 55, 255),
                                      fontSize: fontSettings.fontSize+2,
                                      fontWeight: fontSettings.fontWeight,
                                    )),
                                Expanded(
                                  child: Text(
                                    _formatAmount(gift.prvGiftAmount),
                                    style: TextStyle(
                                      color: const Color.fromARGB(
                                          255, 44, 55, 255),
                                      fontSize: fontSettings.fontSize + 5,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Requested Gift Amount
                          Row(
                            children: [
                              const Icon(Icons.attach_money,
                                  color: Colors.orange, size: 16),
                              const SizedBox(width: 6),
                              Text('Requested Gift: ',
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                        255, 0, 0, 0),
                                    fontSize: fontSettings.fontSize+2,
                                    fontWeight: fontSettings.fontWeight,
                                  )),
                              Expanded(
                                child: Text(
                                  _formatAmount(gift.giftDesc.toString()),
                                  style: TextStyle(
                                     color: const Color.fromARGB(
                                        255, 0, 0, 0),
                                    fontSize: fontSettings.fontSize + 5,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // FIX: Valid For — correct parentheses to avoid operator precedence bug
                          if ((isChecked || isApproved) &&
                              gift.validDates != null &&
                              gift.validDates!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: Colors.deepPurple, size: 16),
                                const SizedBox(width: 6),
                                Text('Valid For: ',
                                    style: TextStyle(
                                        fontSize: fontSettings.fontSize+2,
                                        fontWeight: fontSettings.fontWeight)),
                                Expanded(
                                  child: Text(
                                    '${gift.validDates} days',
                                    style: TextStyle(
                                        color: Colors.deepPurple,
                                        fontSize: fontSettings.fontSize+2,
                                        fontWeight: fontSettings.fontWeight),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // ── Status Badge ───────────────────────────────────
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(statusLabel),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(statusLabel),
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Rating image badge
                Positioned(
                  top: 10,
                  right: 15,
                  child: SizedBox(
                    width: 90,
                    height: 30,
                    child: Image.asset(
                      ratingImageMap[gift.gRating] ??
                          "assets/images/ratings/CLASSIC.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Access Denied Dialog ───────────────────────────────────────────────────

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      color: Colors.red.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.lock_outline,
                      size: 50, color: Colors.red.shade400),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Access Denied",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50)),
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
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text("Got It",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}