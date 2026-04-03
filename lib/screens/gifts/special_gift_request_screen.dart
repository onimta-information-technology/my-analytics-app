import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/special_gift_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SpecialGiftRequestScreen extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;
  final bool hideAddButton;
  const SpecialGiftRequestScreen({
    super.key,
    required this.giftsRepository,
    this.hideAddButton = false,
  });

  @override
  ConsumerState<SpecialGiftRequestScreen> createState() =>
      _SpecialGiftRequestScreenState();
}

class _SpecialGiftRequestScreenState
    extends ConsumerState<SpecialGiftRequestScreen>
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
        return const Color.fromARGB(255, 92, 17, 255);
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
        return Icons.rule_rounded;
      default:
        return Icons.hourglass_bottom;
    }
  }

  Future<List<SpecialGiftRequest>> _filterGifts(
    List<SpecialGiftRequest> gifts,
  ) async {
    final salesCode = await StorageUtil.getSalesCode();
    if (salesCode != null && salesCode.trim().toUpperCase() == 'AD001') {
      return gifts;
    }
    
    final otgiChk = await StorageUtil.getOtgiChk();
  final otgiApp = await StorageUtil.getOtgiApp();
  
  if (otgiChk == true || otgiApp == true) {
    return gifts;
  } print(  "Filtering otp for user. resChk: $otgiChk, resApp: $otgiApp");
    final currentUserName = await StorageUtil.getUserName();
    if (currentUserName == null) return [];
    return gifts
        .where(
          (gift) =>
              gift.reqBy.trim().toLowerCase() ==
              currentUserName.trim().toLowerCase(),
        )
        .toList();
  }

  Future<bool> _canAccessGiftDetails(
    SpecialGiftRequest gift, {
    required bool isPending,
    required bool isApproved,
    required bool isChecked,
  }) async {
    final salesCode = await StorageUtil.getSalesCode();

    if (salesCode != null && salesCode.trim().toUpperCase() == 'AD001') {
      return true;
    }

    final currentUserName =
        (await StorageUtil.getUserName())?.trim().toLowerCase() ?? '';
    final reqBy = gift.reqBy.trim().toLowerCase();
    final checkedBy = (gift.checkApp ?? '').trim().toLowerCase();
    final approvedBy = (gift.firstAppBy ?? '').trim().toLowerCase();
    final rejectedBy = (gift.deleteUser ?? '').trim().toLowerCase();

    if (isPending) {
      // Pending: otgiChk == true OR loginUser == reqBy
      final otgiChk = await StorageUtil.getOtgiChk();
      return otgiChk == true || currentUserName == reqBy;
    }

    if (isChecked) {
      // Checked: otgiApp == true OR loginUser == reqBy OR loginUser == checkedBy
      final otgiApp = await StorageUtil.getOtgiApp();
      return otgiApp == true ||
          currentUserName == reqBy ||
          currentUserName == checkedBy;
    }

    if (isApproved) {
      // Approved: otgiApp == true OR loginUser == reqBy OR loginUser == approvedBy
      final otgiApp = await StorageUtil.getOtgiApp();
      return otgiApp == true ||
          currentUserName == reqBy ||
          currentUserName == approvedBy;
    }

    // Rejected: loginUser == reqBy OR loginUser == rejectedBy
    return currentUserName == reqBy || currentUserName == rejectedBy;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final giftSp = ref.read(giftProvider);
      if (giftSp.pendinggift.isNotEmpty ||
          giftSp.chekbygift.isNotEmpty ||
          giftSp.approvedgift.isNotEmpty ||
          giftSp.rejectgift.isNotEmpty) {
        return;
      }
      String? salesCode = await StorageUtil.getSalesCode();
      if (salesCode != null && salesCode.isNotEmpty) {
        _loadSpGiftData(salesCode);
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

  Future<void> _loadSpGiftData(String salesCode) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(giftProvider.notifier).getSpecialGiftData(8890, salesCode);
      await ref
          .read(giftProvider.notifier)
          .getSpecialGiftData(88790, salesCode);
      await ref.read(giftProvider.notifier).getSpecialGiftData(8891, salesCode);
      await ref.read(giftProvider.notifier).getSpecialGiftData(8893, salesCode);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Assets ─────────────────────────────────────────────────────────────────

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
        return Constants.kPrimaryColor;
    }
  }
  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final giftsp = ref.watch(giftProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Gift Request'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: () async {
              String? salesCode = await StorageUtil.getSalesCode();
              if (salesCode != null && salesCode.isNotEmpty) {
                _loadSpGiftData(salesCode);
              }
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          isScrollable: true, // ✅ FIX: prevents overflow
          tabAlignment: TabAlignment.center, // ✅ valid with isScrollable: true
          tabs: [
            _buildTab('Pending & Checked', giftsp.pendinggift.length, Colors.orange),
            _buildTab(
              'For Approval',
              giftsp.chekbygift.length,
              const Color.fromARGB(255, 92, 17, 255),
            ),
            _buildTab('Approved', giftsp.approvedgift.length, Colors.green),
            _buildTab('Rejected', giftsp.rejectgift.length, Colors.red),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildGiftList(
                giftsp.pendinggift,
                isPending: true,
                isApproved: false,
                isChecked: false,
              ),
              _buildGiftList(
                giftsp.chekbygift,
                isPending: false,
                isApproved: false,
                isChecked: true,
              ),
              _buildGiftList(
                giftsp.approvedgift,
                isPending: false,
                isApproved: true,
                isChecked: false,
              ),
              _buildGiftList(
                giftsp.rejectgift,
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
                      Constants.kSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          //  const Watermark(),
        ],
      ),
      floatingActionButton: widget.hideAddButton
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final result = await context.push(
                  '/gifts/special-gift-requests/new-gift-request',
                );
                if (result == true) {
                  String? salesCode = await StorageUtil.getSalesCode();
                  if (salesCode != null && salesCode.isNotEmpty) {
                    _loadSpGiftData(salesCode);
                  }
                }
              },
              backgroundColor: Colors.red,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  // ── Tab (original Row layout — fully preserved) ────────────────────────────

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
    List<SpecialGiftRequest> gifts, {
    required bool isPending,
    required bool isApproved,
    required bool isChecked,
  }) {
    final fontSettings = ref.watch(fontSettingsProvider);

    final String statusLabel = isApproved
        ? 'Approved'
        : isChecked
        ? 'Checked'
        : isPending
        ? 'Pending'
        : 'Rejected';

    return FutureBuilder<List<SpecialGiftRequest>>(
      future: _filterGifts(gifts),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Constants.kSecondaryColor,
              ),
            ),
          );
        }

        final filteredGifts = snapshot.data ?? [];
        if (filteredGifts.isEmpty) {
          return const Center(child: Text("No gifts found"));
        }

        return ListView.builder(
          itemCount: filteredGifts.length,
          itemBuilder: (context, index) {
            final gift = filteredGifts[index];

            String? actionBy;
            String? actionLabel;
            Color? actionColor;

            String? checkedBy;

            if (!isPending && !isChecked) {
              if (gift.firstAppBy != null && gift.firstAppBy!.isNotEmpty) {
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

            if (isChecked || isApproved) {
              if (gift.checkApp != null && gift.checkApp!.isNotEmpty) {
                checkedBy = gift.checkApp;
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
                      '/gifts/special-gift-requests/view-specific-gift-request',
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
                        _loadSpGiftData(salesCode);
                      }
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      title: Text(
                        '${gift.mid} - ${gift.mname}',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gift type
                          Row(
                            children: [
                              const Icon(
                                Icons.card_giftcard,
                                color: Colors.pink,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  gift.cashierPayType.replaceAll("_", " "),
                                  style: TextStyle(
                                    color: Colors.pink,
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Insert date
                          // Row(
                          //   children: [
                          //     const Icon(
                          //       Icons.access_time,
                          //       color: Color.fromARGB(255, 0, 0, 0),
                          //       size: 16,
                          //     ),
                          //     const SizedBox(width: 6),
                          //     Text(
                          //       _formatDate(gift.insertDate),
                          //       style: TextStyle(
                          //         color: const Color.fromARGB(255, 2, 2, 2),
                          //         fontSize: fontSettings.fontSize - 1,
                          //         fontWeight: fontSettings.fontWeight,
                          //       ),
                          //     ),
                          //   ],
                          // ),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Color.fromARGB(255, 0, 0, 0),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Requested : ',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: fontSettings.fontSize + 1,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatDate(gift.insertDate),
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: fontSettings.fontSize + 1,
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
                              const Icon(
                                Icons.person_outline,
                                color: Colors.blue,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Requested By: ',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: fontSettings.fontSize + 2,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  gift.reqBy.isNotEmpty ? gift.reqBy : 'N/A',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: fontSettings.fontSize + 2,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // Checked By / Approved By / Rejected By
                          // Approved By / Rejected By
                          if (actionBy != null && actionLabel != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  actionLabel == 'Approved By'
                                      ? Icons.check_circle_outline
                                      : Icons.cancel_outlined,
                                  color: actionColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$actionLabel: ',
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize + 2,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    actionBy,
                                    style: TextStyle(
                                      color: actionColor,
                                      fontSize: fontSettings.fontSize + 2,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
  if (isApproved ||
                      
                                  gift.firstAppTime != null &&
                                  gift.firstAppTime!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: Color.fromARGB(255, 92, 17, 255),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Approved Time: ',
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _formatDate(gift.firstAppTime),
                                    style: TextStyle(
                                      color: const Color.fromARGB(
                                        255,
                                        92,
                                        17,
                                        255,
                                      ),
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Checked By (shown in both Checked and Approved tabs)
                          if (checkedBy != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.rule_rounded,
                                  color: Color.fromARGB(255, 92, 17, 255),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Checked By: ',
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize + 2,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    checkedBy,
                                    style: TextStyle(
                                      color: const Color.fromARGB(
                                        255,
                                        92,
                                        17,
                                        255,
                                      ),
                                      fontSize: fontSettings.fontSize + 2,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Check Time (Checked tab only)
                          if (isApproved ||
                              isChecked &&
                                  gift.checkAppByTime != null &&
                                  gift.checkAppByTime!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: Color.fromARGB(255, 92, 17, 255),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Check Time: ',
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _formatDate(gift.checkAppByTime),
                                    style: TextStyle(
                                      color: const Color.fromARGB(
                                        255,
                                        92,
                                        17,
                                        255,
                                      ),
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                            if (
                                  gift.deleteTime != null &&
                                  gift.deleteTime!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: Color.fromARGB(255, 255, 17, 116),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Rejected At: ',
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize-2,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _formatDate(gift.deleteTime),
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 17, 17),
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Valid Days (Checked or Approved tab)
                          if ((isChecked || isApproved) &&
                              gift.validDates != null &&
                              gift.validDates!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.deepPurple,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Valid For: ',
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${gift.validDates} days',
                                    style: TextStyle(
                                      color: Colors.deepPurple,
                                      fontSize: fontSettings.fontSize + 2,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                              horizontal: 8,
                              vertical: 4,
                            ),
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
                  child: 
                  // SizedBox(
                  //   width: 90,
                  //   height: 30,
                  //   child: Image.asset(
                  //     ratingImageMap[gift.gRating] ??
                  //         "assets/images/ratings/CLASSIC.png",
                  //     fit: BoxFit.contain,
                  //   ),
                  // ),
                  Hero(
    tag: "rating-image-${gift.mid}",
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _getRatingColor(gift.gRating),
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
        gift.gRating ?? 'N/A',
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
}
