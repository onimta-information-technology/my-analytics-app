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
  bool isPending = false;
  bool isApproved = false;
   bool _hasGiftAppPermission = false;
  

  Future<bool> _canAccessGiftDetails(BirthdayIncressGiftRequest gift) async {
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
      final birthdayGiftSp = ref.read(birthdayGiftIncreesProvider);

      if (birthdayGiftSp.pendingBirthdayGift.isNotEmpty ||
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
      // Remove any existing commas or currency symbols
      String cleanAmount = amount.replaceAll(RegExp(r'[^0-9.]'), '');
      
      // Parse as double
      double value = double.parse(cleanAmount);
      
      // Format with thousand separator
      final formatter = NumberFormat('#,##0.00', 'en_US');
      return formatter.format(value);
    } catch (e) {
      // If parsing fails, return original amount
      return amount;
    }
  }

  Future<void> _loadBirthdayGiftData(String salesCode) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(birthdayGiftIncreesProvider.notifier).getBirthdayGiftData(98890, salesCode);
      await ref.read(birthdayGiftIncreesProvider.notifier).getBirthdayGiftData(98891, salesCode);
      await ref.read(birthdayGiftIncreesProvider.notifier).getBirthdayGiftData(98893, salesCode);
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
          tabs: [
            _buildTab('Pending', birthdayGiftsp.pendingBirthdayGift.length, Colors.orange),
            _buildTab('Approved', birthdayGiftsp.approvedBirthdayGift.length, Colors.green),
            _buildTab('Rejected', birthdayGiftsp.rejectBirthdayGift.length, Colors.red),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildGiftList(birthdayGiftsp.pendingBirthdayGift, isPending: true, isApproved: false),
              _buildGiftList(birthdayGiftsp.approvedBirthdayGift, isPending: false, isApproved: true),
              _buildGiftList(birthdayGiftsp.rejectBirthdayGift, isPending: false, isApproved: false),
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
    List<BirthdayIncressGiftRequest> gifts, {
    required bool isPending,
    required bool isApproved,
  }) {
    final fontSettings = ref.watch(fontSettingsProvider);

    if (gifts.isEmpty) {
      return const Center(child: Text("No birthday gifts found"));
    }

    return ListView.builder(
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        
        String? actionBy;
        String? actionLabel;
        Color? actionColor;
        
        if (!isPending) {
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
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.block, color: Colors.red),
                            SizedBox(width: 10),
                            Text('Access Denied'),
                          ],
                        ),
                        content: const Text(
                          'You do not have permission to view this gift request. '
                          
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }
                final result = await context.push(
                  '/menu/approve-reject/birthday-gifts/view-birthday-gift-request',
                  extra: {
                    'gift': gift,
                    'isPending': isPending,
                    'isApproved': isApproved,
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
                            Icons.cake,
                            color: Colors.pink,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Birthday Gift',
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
                            color: Color.fromARGB(255, 0, 0, 0),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(gift.insertDate),
                            style: TextStyle(
                              color: const Color.fromARGB(255, 2, 2, 2),
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
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
                              fontSize: fontSettings.fontSize,
                           fontWeight: fontSettings.fontWeight,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              gift.reqBy.isNotEmpty ? gift.reqBy : 'N/A',
                              style: TextStyle(
                                color: const Color.fromARGB(225, 0, 0, 0),
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
                                fontSize: fontSettings.fontSize,
                               fontWeight: fontSettings.fontWeight,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                actionBy,
                                style: TextStyle(
                                  color: actionColor,
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
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
                                fontSize: fontSettings.fontSize ,
                               fontWeight: fontSettings.fontWeight,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${gift.validDates} days',
                                style: TextStyle(
                                  color: Colors.deepPurple,
                                  fontSize: fontSettings.fontSize,
                                 fontWeight: fontSettings.fontWeight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (gift.prvGiftAmount != null && gift.prvGiftAmount!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.attach_money,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Previous Gift: ',
                              style: TextStyle(
                                fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatAmount(gift.prvGiftAmount),
                                style: TextStyle(
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                  fontSize: fontSettings.fontSize+1,
                                fontWeight: fontSettings.fontWeight,
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
}