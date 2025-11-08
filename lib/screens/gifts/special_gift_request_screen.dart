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

  const SpecialGiftRequestScreen({super.key, required this.giftsRepository});

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
            icon: const Icon(Icons.refresh ,size: 30),
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
              _buildGiftList(giftsp.pendinggift, isPending: true),
              _buildGiftList(giftsp.approvedgift, isPending: false),
              _buildGiftList(giftsp.rejectgift, isPending: false),
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
      floatingActionButton: FloatingActionButton(
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
        child: const Icon(Icons.add, color: Color.fromARGB(255, 255, 255, 255)),
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
  }) {
    final fontSettings = ref.watch(fontSettingsProvider);

    if (gifts.isEmpty) {
      return const Center(child: Text("No gifts found"));
    }

    return ListView.builder(
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        return Stack(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
            
                context.push(
                  '/gifts/special-gift-requests/view-specific-gift-request',
                  extra: {
                    'gift': gift, // the SpecialGiftRequest object
                    'isPending': isPending, // mark it as pending
                  }, // pass the whole object
                );
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
                          Text(
                            gift.cashierPayType.replaceAll("_", " "),
                            style: TextStyle(
                              color: Colors.black,
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
