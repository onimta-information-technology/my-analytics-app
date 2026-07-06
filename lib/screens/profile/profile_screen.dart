import 'dart:convert';
import 'dart:io';

import 'package:ballys_reservation_app/components/dilog/add_EmailDialog.dart';
import 'package:ballys_reservation_app/components/dilog/add_phone_dialog.dart';
import 'package:ballys_reservation_app/components/dilog/add_whatsapp_dialog.dart';
import 'package:ballys_reservation_app/screens/follow_screen.dart';
import 'package:ballys_reservation_app/components/dilog/set_primary_phone_dialog.dart';
import 'package:ballys_reservation_app/components/dilog/set_primary_email_dialog.dart';
import 'package:ballys_reservation_app/components/dilog/set_primary_whatsapp_dialog.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/airline_history_provider.dart';
import 'package:ballys_reservation_app/providers/birthday_gift_provider.dart';
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
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
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
    with SingleTickerProviderStateMixin ,ConnectivityMixin{
  bool _isLoading = false;
  bool _isTableExpanded = false;
  bool _isFromMarketing = false;
  String? currentLoadingMember;
  bool _nogiftamount = false;
  bool? _memProfSH;
  String? _userMarketingCode;
  bool _useBadgeForRating = false;
bool _showFollowButton = false;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _memProfSH = await StorageUtil.getMemProfSH();
      _userMarketingCode = await StorageUtil.getMarketingCode();

      // Check if we should use badge instead of rating image
      final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
      setState(() {
        _useBadgeForRating = apiUrl.contains('bty.world');
      });

      final extra = GoRouterState.of(context).extra;
      if (extra != null && extra is Map<String, dynamic>) {
        setState(() {
          _nogiftamount = extra['nogiftamount'] == true;
          _showFollowButton = extra['showFollowButton'] == true;
        });
      }

      final guest = ref.read(selectedGuestProvider);

      if (guest != null) {
        if (guest.memImage2 == null) {
          await ref
              .read(selectedGuestProvider.notifier)
              .getGuestImage(9021, guest.mid);
        }

        if (!_nogiftamount &&
            guest.mobile != null &&
            guest.mobile!.isNotEmpty) {
          _whatsappNumberController.text = guest.mobile!;
        }
      }

      _getMemberMainProfileDetails();
    });

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  bool _hasPermissionToViewProfile() {
    final guest = ref.read(selectedGuestProvider);
    debugPrint('Guest mGroup: ${guest?.mGroup}');
    debugPrint('User marketing code: $_userMarketingCode');
    debugPrint('memProfSH: $_memProfSH');

    if (_memProfSH == null || _memProfSH == true || guest?.mGroup == "W") {
      return true;
    }

    if (_memProfSH == false) {
      if (_userMarketingCode != null &&
          guest?.mGroup != null &&
          _userMarketingCode == guest!.mGroup) {
        return true;
      }
      return false;
    }

    return true;
  }

  void _showPermissionDialog() {
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.kPrimaryColor,
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

  Future<void> _getMemberMainProfileDetails() async {
    setState(() {
      _isLoading = true;
    });
    final guest = ref.read(selectedGuestProvider);

    if (guest == null) return;
    await ref
        .read(mainProfileDetailsProvider.notifier)
        .getMemberMainProfileDetails(guest.mid);

    setState(() {
      _isLoading = false;
    });
  }

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
        return Constants.kPrimaryColor;
    }
  }

  void _showAddPhoneDialog(
    BuildContext context,
    String memberId,
    int phoneType,
    String? currentPhone,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddPhoneDialog(
          memberId: memberId,
          phoneType: phoneType,
          currentPhone: currentPhone,
          onPhoneAdded: (phone) {
            // Optional: Handle after phone is added
          },
        );
      },
    );
  }

  void _showAddWhatsAppDialog(
    BuildContext context,
    String memberId,
    int phoneType,
    String? currentPhone,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddwhatsappPhoneDialog(
          memberId: memberId,
          phoneType: phoneType,
          currentPhone: currentPhone,
          onPhoneAdded: (phone) {
            // Optional: Handle after phone is added
          },
        );
      },
    );
  }

  void _showUpdateEmailDialog(
    BuildContext context,
    String memberId,
    String currentEmail,
    int emailType,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddEmailDialog(
          memberId: memberId,
          emailType: emailType,
          currentEmail: currentEmail,
          onEmailAdded: (email) {
            // Optional: Handle after email is updated
          },
        );
      },
    );
  }

  List<String> _getAvailablePhones() {
    final profileDetails = ref.read(mainProfileDetailsProvider);
    List<String> phones = [];

    for (var entry in profileDetails) {
      final name = entry.details['Name']?.toLowerCase() ?? '';
      final detail = entry.details['Detail'] ?? '';

      if ((name == 'phone1' || name == 'phone2' || name == 'phone3') &&
          detail.isNotEmpty) {
        phones.add(detail);
      }
    }

    return phones;
  }

  List<String> _getAvailableEmails() {
    final profileDetails = ref.read(mainProfileDetailsProvider);
    List<String> emails = [];

    for (var entry in profileDetails) {
      final name = entry.details['Name']?.toLowerCase() ?? '';
      final detail = entry.details['Detail'] ?? '';

      if ((name == 'email1' || name == 'email2') && detail.isNotEmpty) {
        emails.add(detail);
      }
    }

    return emails;
  }

  List<String> _getAvailableWhatsApps() {
    final profileDetails = ref.read(mainProfileDetailsProvider);
    List<String> whatsapps = [];

    for (var entry in profileDetails) {
      final name = entry.details['Name']?.toLowerCase() ?? '';
      final detail = entry.details['Detail'] ?? '';

      if ((name == 'whatsapp' || name == 'whatsapp1' || name == 'whatsapp2') &&
          detail.isNotEmpty) {
        whatsapps.add(detail);
      }
    }

    return whatsapps;
  }

  String? _getPrimaryPhone() {
    final profileDetails = ref.read(mainProfileDetailsProvider);
    for (var entry in profileDetails) {
      final name = entry.details['Name']?.toLowerCase() ?? '';
      if (name == 'phone_primary') {
        return entry.details['Detail'];
      }
    }
    return null;
  }

  String? _getPrimaryEmail() {
    final profileDetails = ref.read(mainProfileDetailsProvider);
    for (var entry in profileDetails) {
      final name = entry.details['Name']?.toLowerCase() ?? '';
      if (name == 'email_primary') {
        return entry.details['Detail'];
      }
    }
    return null;
  }

  String? _getPrimaryWhatsApp() {
    final profileDetails = ref.read(mainProfileDetailsProvider);
    for (var entry in profileDetails) {
      final name = entry.details['Name']?.toLowerCase() ?? '';
      if (name == 'whatsapp_primary') {
        return entry.details['Detail'];
      }
    }
    return null;
  }

  void _showSetPrimaryPhoneDialog() {
    final guest = ref.read(selectedGuestProvider);
    if (guest == null) return;

    final availablePhones = _getAvailablePhones();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SetPrimaryPhoneDialog(
          memberId: guest.mid,
          availablePhones: availablePhones,
        );
      },
    );
  }

  void _showSetPrimaryEmailDialog() {
    final guest = ref.read(selectedGuestProvider);
    if (guest == null) return;

    final availableEmails = _getAvailableEmails();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SetPrimaryEmailDialog(
          memberId: guest.mid,
          availableEmails: availableEmails,
        );
      },
    );
  }

  void _showSetPrimaryWhatsAppDialog() {
    final guest = ref.read(selectedGuestProvider);
    if (guest == null) return;

    final availableWhatsApps = _getAvailableWhatsApps();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SetPrimaryWhatsAppDialog(
          memberId: guest.mid,
          availableWhatsApps: availableWhatsApps,
        );
      },
    );
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
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final guest = ref.watch(selectedGuestProvider);
    final currentPath = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.fullPath;

    final birthdayGiftState = ref.watch(birthdayGiftProvider);

    final bool showGiftElements =
        !_nogiftamount &&
        (currentPath == '/birthdays' ||
            currentPath == '/gifts/event-gifts' ||
            guest?.gift != null);

    if (guest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Guest Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final guestProfileDetails = ref.watch(mainProfileDetailsProvider);

    // final String? imagePath = ratingImageMap[guest.gRating];

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text("Guest Profile"),
        ),
        body: Stack(
          children: [
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
                              base64Decode(guest.memImage2!),
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
                ? MemoryImage(base64Decode(guest.memImage2!))
                : const AssetImage('assets/images/placeholder_image.jpg'),
            backgroundColor: Colors.grey[200],
          ),
        ),
      ),
    ),

    // Rating badge — top-left (unchanged)
  
    Positioned(
      top: 0,
      left: -70,
      child: _useBadgeForRating
          ? Hero(
              tag: "rating-image-${guest.mid}",
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRatingColor(guest.gRating),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
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
          : Hero(
              tag: "rating-image-${guest.mid}",
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRatingColorBallys(guest.gRating),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
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
   if (_showFollowButton)
    // ⭐ Follow button — floats on the right side, picture stays centered
   Positioned(
  bottom: 10,
  right: -35,
  child: Column(
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            debugPrint('Follow button tapped'); // temporary check
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FollowScreen(
                  memberId: guest.mid,
                  memberName: guest.memberName,
                  onSubmit: (File? photo, String description, String contactStatus,
                      String? customerResponse, String? remarks) {
                    debugPrint(
                        'Follow photo: ${photo?.path}, description: $description, '
                        'contactStatus: $contactStatus, customerResponse: $customerResponse, '
                        'remarks: $remarks');
                  },
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 0, 0),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 30),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3)],
        ),
        child: const Text('Follow up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    ],
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
                              fontSize: 20,
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
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        if (showGiftElements) const SizedBox(height: 20),
                        if (showGiftElements)
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
                                      padding: const EdgeInsets.all(4),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/images/others/gift.png',
                                            width: 50,
                                            height: 50,
                                          ),
                                          const SizedBox(width: 20),
                                          Text(
                                            "${guest.gift}",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 34,
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

                        // Navigation buttons
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

                        // Profile details expandable section
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
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (_hasPermissionToViewProfile()) {
                                            setState(() {
                                              _isTableExpanded =
                                                  !_isTableExpanded;
                                            });
                                          } else {
                                            _showPermissionDialog();
                                          }
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

                                    // Set Primary buttons
                                    if (_isTableExpanded) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed:
                                                  _showSetPrimaryPhoneDialog,
                                              icon: const Icon(
                                                Icons.phone,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'Set Primary Phone',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF1976D2,
                                                ),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed:
                                                  _showSetPrimaryEmailDialog,
                                              icon: const Icon(
                                                Icons.email,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'Set Primary Email',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFD32F2F,
                                                ),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              _showSetPrimaryWhatsAppDialog,
                                          icon: Image.asset(
                                            'assets/images/others/whatsapp.png',
                                            width: 18,
                                            height: 18,
                                            color: const Color.fromARGB(
                                              255,
                                              0,
                                              0,
                                              0,
                                            ),
                                          ),
                                          label: const Text(
                                            'Set Primary WhatsApp',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF25D366,
                                            ),
                                            foregroundColor:
                                                const Color.fromARGB(
                                                  255,
                                                  0,
                                                  0,
                                                  0,
                                                ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],

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
                                        child: Table(
                                          border: TableBorder.all(),
                                          columnWidths: const {
                                            0: FractionColumnWidth(0.5),
                                            1: FractionColumnWidth(0.5),
                                          },
                                          children: [
                                            ...guestProfileDetails
                                                .map((entry) {
                                                  final name =
                                                      entry.details['Name']
                                                          ?.toLowerCase() ??
                                                      '';
                                                  final detail =
                                                      entry.details['Detail'] ??
                                                      '';

                                                  final isBirthday =
                                                      name == 'birthday';
                                                  final isPhone =
                                                      name == 'phone1';
                                                  final isPhone2 =
                                                      name == 'phone2';
                                                  final isPhone3 =
                                                      name == 'phone3';
                                                  final isEmail =
                                                      name == 'email1';
                                                  final isEmail2 =
                                                      name == 'email2';
                                                  final iswhatsapp =
                                                      name == 'whatsapp';
                                                  final iswhatsapp2 =
                                                      name == 'whatsapp1';
                                                  final iswhatsapp3 =
                                                      name == 'whatsapp2';

                                                  final isPhonePrimary =
                                                      name == 'phone_primary';
                                                  final isEmailPrimary =
                                                      name == 'email_primary';
                                                  final isWhatsAppPrimary =
                                                      name ==
                                                      'whatsapp_primary';

                                                  // Skip rendering primary rows
                                                  if (isPhonePrimary ||
                                                      isEmailPrimary ||
                                                      isWhatsAppPrimary) {
                                                    return null;
                                                  }

                                                  final primaryPhone =
                                                      _getPrimaryPhone();
                                                  final primaryEmail =
                                                      _getPrimaryEmail();
                                                  final primaryWhatsApp =
                                                      _getPrimaryWhatsApp();

                                                  bool isPrimary = false;
                                                  if (detail.isNotEmpty) {
                                                    if ((isPhone ||
                                                            isPhone2 ||
                                                            isPhone3) &&
                                                        primaryPhone != null &&
                                                        detail ==
                                                            primaryPhone) {
                                                      isPrimary = true;
                                                    } else if ((isEmail ||
                                                            isEmail2) &&
                                                        primaryEmail != null &&
                                                        detail ==
                                                            primaryEmail) {
                                                      isPrimary = true;
                                                    } else if ((iswhatsapp ||
                                                            iswhatsapp2 ||
                                                            iswhatsapp3) &&
                                                        primaryWhatsApp !=
                                                            null &&
                                                        detail ==
                                                            primaryWhatsApp) {
                                                      isPrimary = true;
                                                    }
                                                  }

                                                  Color? backgroundColor;
                                                  if (isBirthday) {
                                                    backgroundColor =
                                                        Colors.green.shade200;
                                                  } else if (isPrimary) {
                                                    backgroundColor =
                                                        Colors.amber.shade100;
                                                  } else {
                                                    backgroundColor = Constants
                                                        .kPrimaryColor
                                                        .withAlpha(50);
                                                  }

                                                  return TableRow(
                                                    decoration: BoxDecoration(
                                                      color: backgroundColor,
                                                    ),
                                                    children: [
                                                      // LEFT CELL - Name
                                                      InkWell(
                                                        onTap: isBirthday
                                                            ? () async {
                                                                EasyLoading.show(
                                                                  status:
                                                                      'Loading gift...',
                                                                );
                                                                try {
                                                                  await ref
                                                                      .read(
                                                                        birthdayGiftProvider
                                                                            .notifier,
                                                                      )
                                                                      .fetchGiftData(
                                                                        guest
                                                                            .mid,
                                                                      );
                                                                  EasyLoading.dismiss();
                                                                  final giftState =
                                                                      ref.read(
                                                                        birthdayGiftProvider,
                                                                      );
                                                                  if (giftState
                                                                          .giftData !=
                                                                      null) {
                                                                    ref
                                                                        .read(
                                                                          selectedGuestProvider
                                                                              .notifier,
                                                                        )
                                                                        .updateGuestGift(
                                                                          gift: giftState
                                                                              .giftData!
                                                                              .gift,
                                                                          mobile: giftState
                                                                              .giftData!
                                                                              .mobile,
                                                                        );
                                                                    if (giftState
                                                                        .giftData!
                                                                        .mobile
                                                                        .isNotEmpty) {
                                                                      _whatsappNumberController
                                                                          .text = giftState
                                                                          .giftData!
                                                                          .mobile;
                                                                    }
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(
                                                                      SnackBar(
                                                                        content:
                                                                            Text(
                                                                              'Gift loaded: ${giftState.giftData!.gift}',
                                                                            ),
                                                                        backgroundColor:
                                                                            Colors.green,
                                                                        duration: const Duration(
                                                                          seconds:
                                                                              2,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  } else {
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(
                                                                      const SnackBar(
                                                                        content:
                                                                            Text(
                                                                              'No gift data available',
                                                                            ),
                                                                        backgroundColor:
                                                                            Colors.orange,
                                                                      ),
                                                                    );
                                                                  }
                                                                } catch (e) {
                                                                  EasyLoading.dismiss();
                                                                  ScaffoldMessenger.of(
                                                                    context,
                                                                  ).showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                        'Error loading gift: $e',
                                                                      ),
                                                                      backgroundColor:
                                                                          Colors
                                                                              .red,
                                                                    ),
                                                                  );
                                                                }
                                                              }
                                                            : null,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                8.0,
                                                              ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              if (isPrimary)
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors
                                                                            .green,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              4,
                                                                            ),
                                                                      ),
                                                                      child: const Text(
                                                                        'PRIMARY',
                                                                        style: TextStyle(
                                                                          color:
                                                                              Colors.white,
                                                                          fontSize:
                                                                              11,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              if (isPrimary)
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      entry
                                                                          .details['Name']!,
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .black,
                                                                        fontSize:
                                                                            fontSettings.fontSize,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  if (isBirthday)
                                                                    Row(
                                                                      children: const [
                                                                        Icon(
                                                                          Icons
                                                                              .touch_app,
                                                                          size:
                                                                              23,
                                                                          color: Color.fromARGB(
                                                                            255,
                                                                            230,
                                                                            0,
                                                                            0,
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              4,
                                                                        ),
                                                                        Icon(
                                                                          Icons
                                                                              .card_giftcard,
                                                                          size:
                                                                              23,
                                                                          color: Color.fromARGB(
                                                                            255,
                                                                            230,
                                                                            0,
                                                                            0,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  if (isPhone)
                                                                    InkWell(
                                                                      onTap: () => _showAddPhoneDialog(
                                                                        context,
                                                                        guest
                                                                            .mid,
                                                                        1,
                                                                        entry
                                                                            .details['Detail'],
                                                                      ),
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              4,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color.fromARGB(
                                                                            255,
                                                                            230,
                                                                            0,
                                                                            0,
                                                                          ),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                6,
                                                                              ),
                                                                        ),
                                                                        child: const Icon(
                                                                          Icons
                                                                              .add_call,
                                                                          size:
                                                                              22,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  if (isPhone2)
                                                                    InkWell(
                                                                      onTap: () => _showAddPhoneDialog(
                                                                        context,
                                                                        guest
                                                                            .mid,
                                                                        2,
                                                                        entry
                                                                            .details['Detail'],
                                                                      ),
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              4,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color.fromARGB(
                                                                            255,
                                                                            230,
                                                                            0,
                                                                            0,
                                                                          ),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                6,
                                                                              ),
                                                                        ),
                                                                        child: const Icon(
                                                                          Icons
                                                                              .add_call,
                                                                          size:
                                                                              22,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  if (isPhone3)
                                                                    InkWell(
                                                                      onTap: () => _showAddPhoneDialog(
                                                                        context,
                                                                        guest
                                                                            .mid,
                                                                        3,
                                                                        entry
                                                                            .details['Detail'],
                                                                      ),
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              4,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color.fromARGB(
                                                                            255,
                                                                            230,
                                                                            0,
                                                                            0,
                                                                          ),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                6,
                                                                              ),
                                                                        ),
                                                                        child: const Icon(
                                                                          Icons
                                                                              .add_call,
                                                                          size:
                                                                              22,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  if (iswhatsapp)
                                                                    InkWell(
                                                                      onTap: () => _showAddWhatsAppDialog(
                                                                        context,
                                                                        guest
                                                                            .mid,
                                                                        1,
                                                                        entry
                                                                            .details['Detail'],
                                                                      ),
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              4,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color.fromARGB(
                                                                            255,
                                                                            230,
                                                                            0,
                                                                            0,
                                                                          ),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                6,
                                                                              ),
                                                                        ),
                                                                        child: const Icon(
                                                                          Icons
                                                                              .add_call,
                                                                          size:
                                                                              22,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  if (iswhatsapp2)
                                                                    InkWell(
                                                                      onTap: () => _showAddWhatsAppDialog(
                                                                        context,
                                                                        guest
                                                                            .mid,
                                                                        2,
                                                                        entry
                                                                            .details['Detail'],
                                                                      ),
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              4,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color.fromARGB(
                                                                            255,
                                                                            230,
                                                                            0,
                                                                            0,
                                                                          ),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                6,
                                                                              ),
                                                                        ),
                                                                        child: const Icon(
                                                                          Icons
                                                                              .add_call,
                                                                          size:
                                                                              22,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  if (iswhatsapp3)
                                                                    InkWell(
                                                                      onTap: () => _showAddWhatsAppDialog(
                                                                        context,
                                                                        guest
                                                                            .mid,
                                                                        3,
                                                                        entry
                                                                            .details['Detail'],
                                                                      ),
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              4,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color.fromARGB(
                                                                            255,
                                                                            230,
                                                                            0,
                                                                            0,
                                                                          ),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                6,
                                                                              ),
                                                                        ),
                                                                        child: const Icon(
                                                                          Icons
                                                                              .add_call,
                                                                          size:
                                                                              22,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  if (isEmail)
                                                                    InkWell(
                                                                      onTap: () => _showUpdateEmailDialog(
                                                                        context,
                                                                        guest
                                                                            .mid,
                                                                        entry
                                                                            .details['Detail']!,
                                                                        1,
                                                                      ),
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              4,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color.fromARGB(
                                                                            255,
                                                                            230,
                                                                            0,
                                                                            0,
                                                                          ),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                6,
                                                                              ),
                                                                        ),
                                                                        child: const Icon(
                                                                          Icons
                                                                              .email,
                                                                          size:
                                                                              22,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  if (isEmail2)
                                                                    InkWell(
                                                                      onTap: () => _showUpdateEmailDialog(
                                                                        context,
                                                                        guest
                                                                            .mid,
                                                                        entry
                                                                            .details['Detail']!,
                                                                        2,
                                                                      ),
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              4,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color.fromARGB(
                                                                            255,
                                                                            230,
                                                                            0,
                                                                            0,
                                                                          ),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                6,
                                                                              ),
                                                                        ),
                                                                        child: const Icon(
                                                                          Icons
                                                                              .email,
                                                                          size:
                                                                              22,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      // RIGHT CELL - Detail
                                                      InkWell(
                                                        onTap: isBirthday
                                                            ? () async {
                                                                EasyLoading.show(
                                                                  status:
                                                                      'Loading gift...',
                                                                );
                                                                try {
                                                                  await ref
                                                                      .read(
                                                                        birthdayGiftProvider
                                                                            .notifier,
                                                                      )
                                                                      .fetchGiftData(
                                                                        guest
                                                                            .mid,
                                                                      );
                                                                  EasyLoading.dismiss();
                                                                  final giftState =
                                                                      ref.read(
                                                                        birthdayGiftProvider,
                                                                      );
                                                                  if (giftState
                                                                          .giftData !=
                                                                      null) {
                                                                    ref
                                                                        .read(
                                                                          selectedGuestProvider
                                                                              .notifier,
                                                                        )
                                                                        .updateGuestGift(
                                                                          gift: giftState
                                                                              .giftData!
                                                                              .gift,
                                                                          mobile: giftState
                                                                              .giftData!
                                                                              .mobile,
                                                                        );
                                                                    if (giftState
                                                                        .giftData!
                                                                        .mobile
                                                                        .isNotEmpty) {
                                                                      _whatsappNumberController
                                                                          .text = giftState
                                                                          .giftData!
                                                                          .mobile;
                                                                    }
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(
                                                                      SnackBar(
                                                                        content:
                                                                            Text(
                                                                              'Gift loaded: ${giftState.giftData!.gift}',
                                                                            ),
                                                                        backgroundColor:
                                                                            Colors.green,
                                                                        duration: const Duration(
                                                                          seconds:
                                                                              2,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  } else {
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(
                                                                      const SnackBar(
                                                                        content:
                                                                            Text(
                                                                              'No gift data available',
                                                                            ),
                                                                        backgroundColor:
                                                                            Colors.orange,
                                                                      ),
                                                                    );
                                                                  }
                                                                } catch (e) {
                                                                  EasyLoading.dismiss();
                                                                  ScaffoldMessenger.of(
                                                                    context,
                                                                  ).showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                        'Error loading gift: $e',
                                                                      ),
                                                                      backgroundColor:
                                                                          Colors
                                                                              .red,
                                                                    ),
                                                                  );
                                                                }
                                                              }
                                                            : null,
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
                                                              color:
                                                                  Colors.black,
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
                                                  );
                                                })
                                                .where((row) => row != null)
                                                .cast<TableRow>()
                                                .toList(),
                                          ],
                                        ),
                                      ),
                                    ),
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

                        // WhatsApp section
                        if (showGiftElements)
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
                                  if (guest.gift != null &&
                                      guest.gift!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color.fromARGB(
                                            255,
                                            105,
                                            179,
                                            108,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.card_giftcard,
                                            color: Colors.green,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Gift Amount: ${guest.gift}",
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _whatsappNumberController,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
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
                                      helperText: "e.g., 94712345678",
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "Note: Please enter the WhatsApp number with the country code\n"
                                    "Examples: 94712345678, 971234567890",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color.fromARGB(255, 30, 30, 30),
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

                                        try {
                                          EasyLoading.show(
                                            status: 'Sending gift...',
                                          );

                                          final result = await ref
                                              .read(birthdayProvider.notifier)
                                              .sendWhatsappMessage(
                                                mname: guest.memberName,
                                                whatsappNumber: phoneNumber,
                                                gift: guest.gift!,
                                                mid: guest.mid,
                                                memberMobile:
                                                    guest.mobile ?? '',
                                              );

                                          EasyLoading.dismiss();

                                          if (result == "Success") {
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
