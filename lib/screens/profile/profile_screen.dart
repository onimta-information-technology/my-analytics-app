import 'dart:convert';

import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/airline_history_provider.dart';
import 'package:ballys_reservation_app/providers/birthdays_provider.dart';
import 'package:ballys_reservation_app/providers/f_and_b_history_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/games_summary_provider.dart';
import 'package:ballys_reservation_app/providers/hotel_history_provider.dart';
import 'package:ballys_reservation_app/providers/loyalty_summary_provider.dart';
import 'package:ballys_reservation_app/providers/main_profile_details_provider.dart';
import 'package:ballys_reservation_app/providers/member_summary_provider.dart';
import 'package:ballys_reservation_app/providers/profile_date_filter_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/trip_information_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isTableExpanded = false;
  bool _isFromMarketing = false;
  String? currentLoadingMember;
  @override
  void initState() {
    super.initState();
    _getGuestImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // final state = GoRouterState.of(context);
      // final extra = state.extra as Map<String, dynamic>?;

      // if (extra != null && extra['fromMarketing'] == true) {
      //   setState(() {
      //     _isFromMarketing = true;
      //   });
      // Load profile details when coming from marketing
      _getMemberMainProfileDetails();
      // }
    });

    final guest = ref.read(selectedGuestProvider);
    if (guest?.mobile != null && guest!.mobile!.isNotEmpty) {
      _whatsappNumberController.text = guest.mobile!;
    }
    if (GoRouter.of(context).routerDelegate.currentConfiguration.fullPath ==
        '/members') {
      _getMemberMainProfileDetails();
    }

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }
  //   Future<void> _handleMemberIdTap(String memberId) async {
  //   if (currentLoadingMember == memberId || currentLoadingMember != null) {
  //     return;
  //   }

  //   setState(() {
  //     currentLoadingMember = memberId;
  //   });

  //   try {
  //     await ref
  //         .read(selectedGuestProvider.notifier)
  //         .setSelectedGuestWithId(memberId);

  //     if (mounted) {
  //       // Pass the fromMarketing flag
  //       context.push('/home/profile', extra: {'fromMarketing': true});
  //     }
  //   } catch (error) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error loading member details: $error'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         currentLoadingMember = null;
  //       });
  //     }
  //   }
  // }

  final TextEditingController _whatsappNumberController =
      TextEditingController();
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void dispose() {
    _controller.dispose();
    _whatsappNumberController.dispose();
    super.dispose();
  }

  Future<void> _getGuestImage() async {
    final guest = ref.read(selectedGuestProvider);
    if (guest!.memImage2 != null) return;

    if (guest.memImage2 == null) {
      print("Fetching image for guest: ${guest.mid}");
      await ref
          .read(selectedGuestProvider.notifier)
          .getGuestImage(9021, guest.mid);
    } else {
      print("Image already loaded for guest: ${guest.memImage2}");
    }
  }

  Future<void> _getMemberMainProfileDetails() async {
    setState(() {
      _isLoading = true;
    });
    final guest = ref.read(selectedGuestProvider);
    print(guest);
    if (guest == null) return;
    await ref
        .read(mainProfileDetailsProvider.notifier)
        .getMemberMainProfileDetails(guest.mid);

    setState(() {
      _isLoading = false;
    });
  }

  // String formatDate(String dateString) {
  //   final date = DateTime.parse(dateString);
  //   return DateFormat('dd MMM yyyy').format(date);
  // }

  String formatDate(String dateString) {
    if (dateString == "1990-01-01" || dateString.isEmpty) {
      return "N/A";
    }

    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return "N/A";
    }
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
    final guest = ref.watch(selectedGuestProvider);
    if (guest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Guest Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final guestProfileDetails = ref.watch(mainProfileDetailsProvider);

    final String? imagePath = ratingImageMap[guest.gRating];

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },

      child: Scaffold(
        appBar: AppBar(title: const Text("Guest Profile")),
        body: Stack(
          children: [
            // 🔹 Watermark Layer
            PopScope(
              onPopInvokedWithResult: (bool didPop, dynamic result) {
                ref.read(dateFilterProvider.notifier).resetDates();
                ref.read(tripHistoryProvider.notifier).reset();
                ref.read(airlineHistoryProvider.notifier).reset();
                ref.read(loyaltySummaryProvider.notifier).reset();
                ref.read(hotelHistoryProvider.notifier).reset();
                ref.read(fAndBHistoryProvider.notifier).reset();
                ref.read(gamesSummaryProvider.notifier).reset();
                ref.read(memberSummaryProvider.notifier).reset();
                ref.read(mainProfileDetailsProvider.notifier).reset();
              },
              child: SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 15.0,
                    ),
                    child: Column(
                      // mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 3,
                                    blurRadius: 5,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return Dialog(
                                        backgroundColor: Colors.transparent,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Hero(
                                              tag: "guest-image",
                                              child: guest.memImage2 != null
                                                  ? Image.memory(
                                                      base64Decode(
                                                        guest.memImage2!,
                                                      ),
                                                      fit: BoxFit.contain,
                                                    )
                                                  : Image.asset(
                                                      'assets/images/placeholder_image.jpg',
                                                      fit: BoxFit.contain,
                                                    ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: Hero(
                                  tag: "guest-image",
                                  child: CircleAvatar(
                                    radius: 70,
                                    backgroundImage: guest.memImage2 != null
                                        ? MemoryImage(
                                            base64Decode(guest.memImage2!),
                                          )
                                        : const AssetImage(
                                            'assets/images/placeholder_image.jpg',
                                          ),
                                    backgroundColor: Colors.grey[200],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: -70,
                              child: Card(
                                elevation: 5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(0),
                                  child: SizedBox(
                                    width: 120,
                                    height: 50,
                                    child: imagePath != null
                                        ? Hero(
                                            tag: "rating-image-${guest.mid}",
                                            child: Image.asset(
                                              imagePath,
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
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            "${guest.mid} -  ${guest.memberName}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Center(
                          child: Text(
                            "M P - ${guest.gName}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color.fromARGB(255, 158, 0, 148),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Last Visit on -  ${formatDate(guest.lastVisitDate)}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),

                        if (GoRouter.of(context)
                                    .routerDelegate
                                    .currentConfiguration
                                    .fullPath ==
                                '/birthdays' ||
                            GoRouter.of(context)
                                    .routerDelegate
                                    .currentConfiguration
                                    .fullPath ==
                                '/gifts/event-gifts')
                          const SizedBox(height: 20),
                        if (GoRouter.of(context)
                                    .routerDelegate
                                    .currentConfiguration
                                    .fullPath ==
                                '/birthdays' ||
                            GoRouter.of(context)
                                    .routerDelegate
                                    .currentConfiguration
                                    .fullPath ==
                                '/gifts/event-gifts')
                          AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    gradient: SweepGradient(
                                      colors: const [
                                        Colors.purple,
                                        Colors.blue,
                                        Colors.green,
                                        Colors.yellow,
                                        Colors.orange,
                                        Colors.red,
                                        Colors.purple,
                                      ],
                                      stops: const [
                                        0.0,
                                        0.16,
                                        0.33,
                                        0.5,
                                        0.66,
                                        0.83,
                                        1.0,
                                      ],
                                      transform: GradientRotation(
                                        _animation.value * 6.28,
                                      ),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      color: Colors.white,
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/images/others/gift.png',
                                            width: 50,
                                            height: 50,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "${guest.gift}",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              context.push("/home/profile/guest-performance");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Constants.kPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.emoji_events, size: 30),
                                SizedBox(width: 10),
                                Text(
                                  "Guest Performance",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              context.push("/home/profile/member-summary");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Constants.kPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bar_chart, size: 30),
                                SizedBox(width: 10),
                                Text(
                                  "Guest Summary",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              context.push("/home/profile/trip-history");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Constants.kPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.luggage, size: 30),
                                SizedBox(width: 10),
                                Text(
                                  "Trip History",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // if (_isFromMarketing)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: _isLoading
                              ? const Center(
                                  child: RefreshProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Constants.kSecondaryColor,
                                    ),
                                  ),
                                )
                              : Column(
                                  //mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _isTableExpanded =
                                                !_isTableExpanded;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Constants.kPrimaryColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                            horizontal: 20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // 👇 Centered icon + text
                                            Expanded(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(
                                                    Icons.person,
                                                    size: 30,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    "Guest Profile Details",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // 👇 Arrow stays at right
                                            AnimatedRotation(
                                              turns: _isTableExpanded ? 0.5 : 0,
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              child: const Icon(
                                                Icons.keyboard_arrow_down,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Expandable table content with animation
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      curve: Curves.easeInOut,
                                      height: _isTableExpanded ? null : 0,
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        opacity: _isTableExpanded ? 1.0 : 0.0,
                                        // child: ClipRect(
                                        child: Table(
                                          border: TableBorder.all(),
                                          columnWidths: const {
                                            0: FractionColumnWidth(0.5),
                                            1: FractionColumnWidth(0.5),
                                          },
                                          children: [
                                            ...guestProfileDetails
                                                .map((entry) {
                                                  return [
                                                    TableRow(
                                                      decoration: BoxDecoration(
                                                        color: Constants
                                                            .kPrimaryColor
                                                            .withAlpha(50),
                                                      ),
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                8.0,
                                                              ),
                                                          child: Text(
                                                            entry
                                                                .details['Name']!,
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.black,
                                                              fontSize:
                                                                  fontSettings
                                                                      .fontSize,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          color: Colors.white,
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8.0,
                                                                ),
                                                            child: Text(
                                                              entry
                                                                  .details['Detail']!,
                                                              textAlign:
                                                                  TextAlign.end,
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize:
                                                                    fontSettings
                                                                        .fontSize,
                                                                fontWeight:
                                                                    fontSettings
                                                                        .fontWeight,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ];
                                                })
                                                .expand((x) => x),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Preview hint when collapsed
                                    if (!_isTableExpanded &&
                                        guestProfileDetails.isNotEmpty)
                                      Card(
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                size: 16,
                                                color: Constants.kPrimaryColor
                                                    .withOpacity(0.7),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "Tap above to view ${guestProfileDetails.length} profile details",
                                                style: TextStyle(
                                                  fontSize:
                                                      fontSettings.fontSize - 1,
                                                  color:
                                                      Constants.kPrimaryColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 8),
                        if (GoRouter.of(context)
                                    .routerDelegate
                                    .currentConfiguration
                                    .fullPath ==
                                '/birthdays' ||
                            GoRouter.of(context)
                                    .routerDelegate
                                    .currentConfiguration
                                    .fullPath ==
                                '/gifts/event-gifts')
                          // Card(
                          //   elevation: 5,
                          //   shape: RoundedRectangleBorder(
                          //     borderRadius: BorderRadius.circular(12),
                          //   ),
                          //   child: Container(
                          //     color: Colors.green[10],
                          //     padding: const EdgeInsets.all(16.0),
                          //     child: Column(
                          //       crossAxisAlignment: CrossAxisAlignment.start,
                          //       children: [
                          //         const Text(
                          //           "Send the Gift via Whatsapp",
                          //           style: TextStyle(
                          //             fontSize: 18,
                          //             fontWeight: FontWeight.bold,
                          //           ),
                          //         ),
                          //         const SizedBox(height: 10),
                          //         TextField(
                          //           controller: _whatsappNumberController,
                          //           keyboardType: TextInputType.number,
                          //           decoration: InputDecoration(
                          //             border: OutlineInputBorder(
                          //               borderRadius: BorderRadius.circular(12),
                          //               borderSide: const BorderSide(
                          //                 color: Colors.green,
                          //                 width: 2.0,
                          //               ),
                          //             ),
                          //             enabledBorder: OutlineInputBorder(
                          //               borderRadius: BorderRadius.circular(12),
                          //               borderSide: const BorderSide(
                          //                 color: Colors.green,
                          //                 width: 2.0,
                          //               ),
                          //             ),
                          //             focusedBorder: OutlineInputBorder(
                          //               borderRadius: BorderRadius.circular(12),
                          //               borderSide: const BorderSide(
                          //                 color: Colors.green,
                          //                 width: 2.0,
                          //               ),
                          //             ),
                          //             hintText: "Enter the whatsapp number",
                          //           ),
                          //         ),
                          //         const SizedBox(height: 10),
                          //         const Text(
                          //           "Note: Please enter the whatsapp number with the country code Eg:- 94712345678, 97712333456780",
                          //           style: TextStyle(
                          //             fontSize: 14,
                          //             color: Colors.grey,
                          //           ),
                          //         ),
                          //         const SizedBox(height: 20),
                          //         SizedBox(
                          //           width: double.infinity,
                          //           child: ElevatedButton.icon(
                          //             onPressed: () {
                          //               ref
                          //                   .read(birthdayProvider.notifier)
                          //                   .sendWhatsappMessage(
                          //                     mname: guest.memberName,
                          //                     whatsappNumber:
                          //                         _whatsappNumberController.text,
                          //                     gift: guest.gift!,
                          //                   );
                          //             },
                          //             icon: Image.asset(
                          //               'assets/images/others/whatsapp.png',
                          //               width: 24,
                          //               height: 24,
                          //               color: Colors.white,
                          //             ),
                          //             label: const Text(
                          //               "Send the gift",
                          //               style: TextStyle(
                          //                 fontSize: 16,
                          //                 fontWeight: FontWeight.bold,
                          //                 color: Colors.white,
                          //               ),
                          //             ),
                          //             style: ElevatedButton.styleFrom(
                          //               backgroundColor: Colors.green,
                          //               padding: const EdgeInsets.symmetric(
                          //                 vertical: 16,
                          //                 horizontal: 20,
                          //               ),
                          //               shape: RoundedRectangleBorder(
                          //                 borderRadius: BorderRadius.circular(12),
                          //               ),
                          //             ),
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),
                          // ),
                          // Updated WhatsApp section in ProfileScreen
                          // Replace the existing WhatsApp Card section with this:
                          Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              color: Colors.green[10],
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Send the Gift via WhatsApp",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _whatsappNumberController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.green,
                                          width: 2.0,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.green,
                                          width: 2.0,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.green,
                                          width: 2.0,
                                        ),
                                      ),
                                      hintText:
                                          "Enter WhatsApp number with country code",
                                      //prefixText: "+",
                                      helperText: "e.g., 94712345678",
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "Note: Please enter the WhatsApp number with the country code\n"
                                    "Examples: 94712345678, 971234567890",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final phoneNumber =
                                            _whatsappNumberController.text
                                                .trim();

                                        // Basic validation
                                        if (phoneNumber.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please enter a WhatsApp number',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        // Check if phone number is valid (at least 10 digits)
                                        // String cleanNumber = phoneNumber
                                        //     .replaceAll(RegExp(r'[^\d]'), '');
                                        // if (cleanNumber.length < 10) {
                                        //   ScaffoldMessenger.of(
                                        //     context,
                                        //   ).showSnackBar(
                                        //     const SnackBar(
                                        //       content: Text(
                                        //         'Please enter a valid phone number',
                                        //       ),
                                        //       backgroundColor: Colors.red,
                                        //     ),
                                        //   );
                                        //   return;
                                        // }

                                        try {
                                          // Show loading
                                          EasyLoading.show(
                                            status: 'Sending gift...',
                                          );

                                          // Send WhatsApp message
                                          final result = await ref
                                              .read(birthdayProvider.notifier)
                                              .sendWhatsappMessage(
                                                mname: guest.memberName,
                                                whatsappNumber: phoneNumber,
                                                gift: guest.gift!,
                                              );

                                          // Hide loading
                                          EasyLoading.dismiss();

                                          if (result == "Success") {
                                            // Clear the text field on success
                                            // _whatsappNumberController.clear();

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Gift sent successfully via WhatsApp!',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to send gift: $result',
                                                ),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          // Hide loading
                                          EasyLoading.dismiss();

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      icon: Image.asset(
                                        'assets/images/others/whatsapp.png',
                                        width: 24,
                                        height: 24,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        "Send the Gift",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 20,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Watermark(),
          ],
        ),
      ),
    );
  }
}
