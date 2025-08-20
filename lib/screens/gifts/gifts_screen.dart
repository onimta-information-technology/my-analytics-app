import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GiftsScreen extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;

  const GiftsScreen({super.key, required this.giftsRepository});

  @override
  ConsumerState<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends ConsumerState<GiftsScreen> {
  String selectedDateOption = "1";
  String selectedBuyInOption = "1";
  bool _isLoading = false;

  List<Guest> originalMembers = [];
  List<Guest> inactiveMembers = [];

  @override
  void initState() {
    _applyFilter();
    super.initState();
  }

  void _applyFilter() async {
    setState(() {
      _isLoading = true;
    });
    final giftMembers_ = await widget.giftsRepository.getGiftMembers();

    setState(() {
      originalMembers = giftMembers_;
      inactiveMembers = List<Guest>.from(originalMembers);
      _isLoading = false;
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gifts'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        inactiveMembers = List<Guest>.from(originalMembers);
                      } else {
                        inactiveMembers = originalMembers.where((guest) {
                          return guest.memberName
                                  .toLowerCase()
                                  .contains(value.toLowerCase()) ||
                              guest.mid
                                  .toLowerCase()
                                  .contains(value.toLowerCase());
                        }).toList();
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: inactiveMembers.isEmpty
                    ? const Center(
                        child: Text("No gifts available"),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListView.builder(
                          itemCount: inactiveMembers.length,
                          itemBuilder: (context, index) {
                            final guest = inactiveMembers[index];
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
                                    context.push(
                                        '/gifts/guest-gifts/${guest.mid}');
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 5.0),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  "${guest.mid} - ${guest.memberName}",
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
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
                                                  fontSize:
                                                      fontSettings.fontSize,
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
                                      child: ratingImageMap[guest.gRating] !=
                                              null
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
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color.fromARGB(135, 117, 115, 115),
                ),
                child: const Center(
                  child: RefreshProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Constants.kSecondaryColor),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
