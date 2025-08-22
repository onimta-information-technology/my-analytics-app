import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MemberVisits extends ConsumerWidget {
  MemberVisits({super.key, required this.title, required this.guestList});

  final String title;
  final List<Guest> guestList;

  String formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('dd MMM yyyy').format(date);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 20.0),
        ),
      ),
      body: guestList.isEmpty
          ? Center(child: Text("No guests available for $title"))
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                itemCount: guestList.length,
                itemBuilder: (context, index) {
                  final guest = guestList[index];
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
                                bottom: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "${guest.mid} - ${guest.memberName}",
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: FontWeight.bold,
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
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Last visit on ${DateFormat('dd MMM yyyy').format(DateTime.parse(guest.lastVisitDate))}',
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize,
                                        color: Colors.grey[600],
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
                        top: 6,
                        right: -2,
                        child: Padding(
                          padding: const EdgeInsets.all(0),
                          child: SizedBox(
                            width: 80,
                            height: 26,
                            child: ratingImageMap[guest.gRating] != null
                                ? Hero(
                                    tag: "rating-image-${guest.mid}",
                                    child: Image.asset(
                                      ratingImageMap[guest.gRating]!,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : Hero(
                                    tag: "rating-image-${guest.mid}",
                                    child: Image.asset(
                                      "assets/images/ratings/CLASSIC.png",
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                        const Watermark(),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
