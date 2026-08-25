import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MemberVisits extends ConsumerStatefulWidget {
  const MemberVisits({super.key, required this.title, required this.guestList});

  final String title;
  final List<Guest> guestList;

  @override
  ConsumerState<MemberVisits> createState() => _MemberVisitsState();
}

class _MemberVisitsState extends ConsumerState<MemberVisits> with ConnectivityMixin {
  bool _useBadgeForRating = false;

  // ── Profile access gating (mirrors MarketingDetailPage) ──
  bool? _memProfSH;
  String? _userMarketingCode;
  String? _userSalesCode;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Guest> get _filteredGuestList {
    if (_searchQuery.isEmpty) return widget.guestList;
    final query = _searchQuery.toLowerCase();
    return widget.guestList.where((guest) {
      return guest.mid.toLowerCase().contains(query) ||
          guest.memberName.toLowerCase().contains(query);
    }).toList();
  }

  // final Map<String, String> ratingImageMap = {
  //   "CLASSIC": "assets/images/ratings/CLASSIC.png",
  //   "DIAMOND": "assets/images/ratings/DIAMOND.png",
  //   "GOLD": "assets/images/ratings/GOLD.png",
  //   "INFINITY": "assets/images/ratings/INFINITY.png",
  //   "PLATINUM": "assets/images/ratings/PLATINUM.png",
  //   "SILVER": "assets/images/ratings/SILVER.png",
  // };
  Color _getRatingColorBallys(String? rating) {
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
      case 'CLASSIC':
        return const Color(0xFF5D4037);
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRatingMode();
    _loadAccessSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRatingMode() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    if (mounted) {
      setState(() {
        _useBadgeForRating = apiUrl.contains('bty.world');
      });
    }
  }

  Future<void> _loadAccessSettings() async {
    final memProfSH = await StorageUtil.getMemProfSH();
    final userMarketingCode = await StorageUtil.getMarketingCode();
    final userSalesCode = await StorageUtil.getSalesCode();
    if (mounted) {
      setState(() {
        _memProfSH = memProfSH;
        _userMarketingCode = userMarketingCode;
        _userSalesCode = userSalesCode;
      });
    }
  }

  // Sales code AD001 can view every member profile.
  // Otherwise, when memProfSH is null or true, every member is accessible.
  // When memProfSH is false, only members in the logged-in user's
  // marketing group can be opened.
  bool _hasPermissionToViewMember(Guest guest) {
    if (_userSalesCode == 'AD001') {
      return true;
    }

    // if (_memProfSH == null || _memProfSH == true) {
    //   return true;
    // }

    if (_userSalesCode != 'AD001') {
      return _userMarketingCode != null &&
          (guest.mGroup ?? '').isNotEmpty &&
          _userMarketingCode == guest.mGroup;
    }

    return true;
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
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
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 20.0)),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by member ID or name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: _filteredGuestList.isEmpty
                    ? Center(
                        child: Text(
                          widget.guestList.isEmpty
                              ? "No guests available for ${widget.title}"
                              : "No guests match your search",
                        ),
                      )
                    : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: _filteredGuestList.length,
                    itemBuilder: (context, index) {
                      final guest = _filteredGuestList[index];
                      return Stack(
                        children: [
                          InkWell(
                            key: ValueKey(guest.mid),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () {
                              if (!_hasPermissionToViewMember(guest)) {
                                _showAccessDeniedDialog();
                                return;
                              }
                              ref
                                  .read(selectedGuestProvider.notifier)
                                  .setSelectedGuest(guest);
                              context.push('/home/profile');
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 5.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 16.0,
                                  right: 16.0,
                                  top: 28.0,
                                  bottom: 16.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "${guest.mid} - ${guest.memberName}",
                                            style: TextStyle(
                                              fontSize:
                                                  fontSettings.fontSize + 2,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Last visit on ${DateFormat('dd MMM yyyy').format(DateTime.parse(guest.lastVisitDate))}',
                                          style: TextStyle(
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                            color: const Color.fromARGB(
                                              255,
                                              0,
                                              0,
                                              0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── Rating badge / image (mirrors ProfileScreen logic) ──
                          Positioned(
                            top: 6,
                            right: 2,
                            child: _useBadgeForRating
                                ? Hero(
                                    tag: "rating-image-${guest.mid}",
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRatingColor(guest.gRating),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.25,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        guest.gRating ?? 'N/A',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                // : Padding(
                                //     padding: const EdgeInsets.all(0),
                                //     child: SizedBox(
                                //       width: 80,
                                //       height: 26,
                                //       child: ratingImageMap[guest.gRating] !=
                                //               null
                                //           ? Hero(
                                //               tag:
                                //                   "rating-image-${guest.mid}",
                                //               child: Image.asset(
                                //                 ratingImageMap[guest.gRating]!,
                                //                 fit: BoxFit.contain,
                                //               ),
                                //             )
                                //           : Hero(
                                //               tag:
                                //                   "rating-image-${guest.mid}",
                                //               child: Image.asset(
                                //                 "assets/images/ratings/CLASSIC.png",
                                //                 fit: BoxFit.contain,
                                //               ),
                                //             ),
                                //     ),
                                //   ),
                                : Hero(
                                    tag: "rating-image-${guest.mid}",
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRatingColorBallys(
                                          guest.gRating,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.25,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        guest.gRating ?? 'N/A',
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
                  ),
                ),
              ),
            ],
          ),
          const Watermark(),
        ],
      ),
    );
  }
}
