import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MemberVisits extends ConsumerStatefulWidget {
  final String title;
  final List<Guest> guestList;

  const MemberVisits({super.key, required this.title, required this.guestList});

  @override
  ConsumerState<MemberVisits> createState() => _MemberVisitsState();
}

class _MemberVisitsState extends ConsumerState<MemberVisits> {
  DateTime? lastseen;
  String? userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await StorageUtil.getUserName();
    setState(() {
      userName = name;
      lastseen = DateTime.now();
    });
  }

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
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final formattedLastSeen = lastseen != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(lastseen!)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 20.0)),
      ),
      body: widget.guestList.isEmpty
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
                                      'Last visit on ${formatDate(guest.lastVisitDate)}',
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
                      // Watermark
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.2,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Wrap(
                                  alignment: WrapAlignment.start,
                                  runAlignment: WrapAlignment.center,
                                  spacing: 1,
                                  runSpacing: 25,
                                  children: List.generate(
                                    100,
                                    (index) => Transform.rotate(
                                      angle: -0.7,
                                      child: Text(
                                        "${userName ?? "Loading..."}\n${formattedLastSeen.isNotEmpty ? formattedLastSeen : "Loading..."}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
