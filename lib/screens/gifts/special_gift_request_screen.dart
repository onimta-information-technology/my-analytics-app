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
              _buildGiftList(giftsp.pendinggift),
              _buildGiftList(giftsp.approvedgift),
              _buildGiftList(giftsp.rejectgift),
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
          const Watermark(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/gifts/special-gift-requests/new-gift-request');
        },
        backgroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.black),
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
          )
        ],
      ),
    );
  }

  Widget _buildGiftList(List<SpecialGiftRequest> gifts) {
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
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              title: Text(
                '${gift.mid} - ${gift.mname}',   // ✅ use res field
                style: TextStyle(
                  color: Colors.black,
                  fontSize: fontSettings.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${gift.cashierPayType}',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: fontSettings.fontSize,
                    ),
                  ),
                 
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 15,
            child: SizedBox(
              width: 100,
              height: 30,
              child: Image.asset(
                ratingImageMap[gift.gRating] ??
                    "assets/images/ratings/CLASSIC.png", // ✅ safe lookup
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
