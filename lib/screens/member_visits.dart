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
  }

  Future<void> _loadRatingMode() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    if (mounted) {
      setState(() {
        _useBadgeForRating = apiUrl.contains('bty.world');
      });
    }
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
          widget.guestList.isEmpty
              ? Center(child: Text("No guests available for ${widget.title}"))
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: widget.guestList.length,
                    itemBuilder: (context, index) {
                      final guest = widget.guestList[index];
                      return Stack(
                        children: [
                          InkWell(
                            key: ValueKey(guest.mid),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () {
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
          const Watermark(),
        ],
      ),
    );
  }
}
