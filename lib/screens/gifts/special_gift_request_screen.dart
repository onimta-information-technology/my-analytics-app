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
  bool isPending = false;
  bool isApproved = false;
  bool _hasGiftAppPermission = false;

  Future<bool> _canAccessGiftDetails(SpecialGiftRequest gift) async {
    // Check if user has Gift_App permission
    final giftApp = await StorageUtil.getGiftApp();
    if (giftApp == true) {
      return true;
    }

    // Check if current user is the requester
    final currentUserName = await StorageUtil.getUserName();
    if (currentUserName != null && 
        gift.reqBy.isNotEmpty && 
        currentUserName.trim().toLowerCase() == gift.reqBy.trim().toLowerCase()) {
      return true;
    }

    return false;
  }
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final giftSp = ref.read(giftProvider);

      if (giftSp.pendinggift.isNotEmpty ||
          giftSp.approvedgift.isNotEmpty ||
          giftSp.rejectgift.isNotEmpty) {
        return;
      }

      /// 🔹 Fix: fetch salesCode from StorageUtil
      String? salesCode = await StorageUtil.getSalesCode();
      if (salesCode != null && salesCode.isNotEmpty) {
        _loadSpGiftData(salesCode);
      }
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";

    try {
      // Adjust parse format depending on how your backend sends date
      final dateTime = DateTime.parse(dateStr);
      return DateFormat("yyyy-MM-dd hh:mm a").format(dateTime);
    } catch (e) {
      return dateStr; // fallback: just show raw string if parsing fails
    }
  }

  Future<void> _loadSpGiftData(String salesCode) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(giftProvider.notifier).getSpecialGiftData(8890, salesCode);
      await ref.read(giftProvider.notifier).getSpecialGiftData(8891, salesCode);
      await ref.read(giftProvider.notifier).getSpecialGiftData(8893, salesCode);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final Map<String, String> ratingImageMap = {
    "CLASSIC": "assets/images/ratings/CLASSIC.png",
    "DIAMOND": "assets/images/ratings/DIAMOND.png",
    "GOLD": "assets/images/ratings/GOLD.png",
    "INFINITY": "assets/images/ratings/INFINITY.png",
    "PLATINUM": "assets/images/ratings/PLATINUM.png",
    "SILVER": "assets/images/ratings/SILVER.png",
  };

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final giftsp = ref.watch(giftProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Special Gift Request'),
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
          tabs: [
            _buildTab('Pending', giftsp.pendinggift.length, Colors.orange),
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
              _buildGiftList(giftsp.pendinggift, isPending: true, isApproved: false),
              _buildGiftList(giftsp.approvedgift, isPending: false,isApproved: true),
              _buildGiftList(giftsp.rejectgift, isPending: false,isApproved: false),
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
          const Watermark(),
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
              child: const Icon(
                Icons.add,
                color: Color.fromARGB(255, 255, 255, 255),
              ),
            ),
    );
  }

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

Widget _buildGiftList(
  List<SpecialGiftRequest> gifts, {
  required bool isPending,
  required bool isApproved,
}) {
  final fontSettings = ref.watch(fontSettingsProvider);

  if (gifts.isEmpty) {
    return const Center(child: Text("No gifts found"));
  }

  return ListView.builder(
    itemCount: gifts.length,
    itemBuilder: (context, index) {
      final gift = gifts[index];
      
      // Determine approval/rejection info based on status
      String? actionBy;
      String? actionLabel;
      Color? actionColor;
      
      if (!isPending) {
        // Check if it's approved or rejected
        if (gift.firstAppBy != null && gift.firstAppBy!.isNotEmpty) {
          actionBy = gift.firstAppBy;
          actionLabel = 'Approved By';
          actionColor = Colors.green;
        } else if (gift.deleteUser != null && gift.deleteUser!.isNotEmpty) {
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
              final canAccess = await _canAccessGiftDetails(gift);
                   if (!canAccess) {
                  // Show access denied dialog
                  if (mounted) {
                //     showDialog(
                //       context: context,
                //       builder: (context) => AlertDialog(
                //         title: const Row(
                //           children: [
                //             Icon(Icons.block, color: Colors.red),
                //             SizedBox(width: 10),
                //             Text('Access Denied'),
                //           ],
                //         ),
                //         content: const Text(
                //           'You do not have permission to view this gift request. '
                          
                //         ),
                //         actions: [
                //           TextButton(
                //             onPressed: () => Navigator.of(context).pop(),
                //             child: const Text('OK'),
                //           ),
                //         ],
                //       ),
                //     );
                //   }
                //   return;
                // }


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
      }
    );
    return;
              }
                   }

              final result = await context.push(
                '/gifts/special-gift-requests/view-specific-gift-request',
                extra: {
                  'gift': gift,
                  'isPending': isPending,
                  'isApproved': isApproved,
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
                              color: Colors.black,
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(gift.insertDate),
                          style: TextStyle(
                            color: const Color.fromARGB(255, 2, 2, 2),
                            fontSize: fontSettings.fontSize - 1,
                            fontWeight: fontSettings.fontWeight,
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
                           
                            fontSize: fontSettings.fontSize - 1,
                            fontWeight: fontSettings.fontWeight,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            gift.reqBy.isNotEmpty ? gift.reqBy : 'N/A',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: fontSettings.fontSize - 1,
                              fontWeight: fontSettings.fontWeight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Approved By or Rejected By (only for non-pending items)
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
                             
                              fontSize: fontSettings.fontSize - 1,
                              fontWeight: fontSettings.fontWeight,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              actionBy,
                              style: TextStyle(
                                color: actionColor,
                                fontSize: fontSettings.fontSize - 1,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Valid Date (only for approved items)
                    if (isApproved && gift.validDates != null && gift.validDates!.isNotEmpty) ...[
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
                              fontSize: fontSettings.fontSize - 1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${gift.validDates} days',
                              style: TextStyle(
                                color: Colors.deepPurple,
                                fontSize: fontSettings.fontSize - 1,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
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
}
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
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
      default:
        return Icons.hourglass_bottom;
    }
  }
}