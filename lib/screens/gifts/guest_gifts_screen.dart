import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/models/guest_gift_modal.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GuestGiftsScreen extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;
  final String mid;

  const GuestGiftsScreen({
    super.key,
    required this.giftsRepository,
    required this.mid,
  });

  @override
  ConsumerState<GuestGiftsScreen> createState() => _GuestGiftsScreenState();
}

class _GuestGiftsScreenState extends ConsumerState<GuestGiftsScreen> {
  String selectedDateOption = "1";
  String selectedBuyInOption = "1";
  bool _isLoading = false;

  List<GuestGift> originalMembers = [];
  List<GuestGift> inactiveMembers = [];

  @override
  void initState() {
    _applyFilter();
    super.initState();
  }

  void _applyFilter() async {
    setState(() {
      _isLoading = true;
    });
    final giftMembers_ = await widget.giftsRepository.getGuestGifts(widget.mid);

    setState(() {
      originalMembers = giftMembers_;
      inactiveMembers = List<GuestGift>.from(originalMembers);
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
      appBar: AppBar(title: const Text('Guest Gifts')),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: inactiveMembers.isEmpty
                    ? const Center(child: Text("No gifts available"))
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListView.builder(
                          itemCount: inactiveMembers.length,
                          itemBuilder: (context, index) {
                            final guest = inactiveMembers[index];
                            return InkWell(
                              key: ValueKey(guest.mid),
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () {
                                ref
                                    .read(selectedGuestProvider.notifier)
                                    .setSelectedGuest(
                                      Guest(
                                        mid: guest.mid,
                                        memberName: guest.memberName,
                                        country: "",
                                        lastVisitDate:
                                            guest.lvd ?? "1990-01-01",
                                        gift: NumberFormat.currency(
                                          symbol: '',
                                          decimalDigits: 0,
                                        ).format(guest.amount),
                                        age: 0,
                                        gRating: guest.gRating ?? "",
                                        mGroup: "",
                                        gName: guest.gName,
                                      ),
                                    );
                                context.push('/home/profile');
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 5.0,
                                ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Image.asset(
                                            'assets/images/others/gift.png',
                                            height: 50,
                                            width: 50,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              guest.categoryCode,
                                              style: const TextStyle(
                                                fontSize: 18.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Text(
                                            'Price: ',
                                            style: TextStyle(
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            NumberFormat.currency(
                                              symbol: '',
                                              decimalDigits: 0,
                                            ).format(guest.amount),
                                            style: const TextStyle(
                                              fontSize: 25.0,
                                              fontWeight: FontWeight.bold,
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
                                            'Use before ${DateFormat('dd MMM yyyy').format(DateTime.parse(guest.expireDate))}',
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
                      Constants.kSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
