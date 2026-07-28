import 'dart:convert';

import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/models/gift/redeem_location.dart';
import 'package:ballys_reservation_app/models/guest_gift_modal.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
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

class _GuestGiftsScreenState extends ConsumerState<GuestGiftsScreen> with ConnectivityMixin{
  String selectedDateOption = "1";
  String selectedBuyInOption = "1";
  bool _isLoading = false;

  List<GuestGift> originalMembers = [];
  List<GuestGift> inactiveMembers = [];

  // Redeem is a Bellagio-only feature; Ballys logins never see the button.
  bool _isBellagio = false;

  @override
  void initState() {
    _applyFilter();
    _loadLocation();
    super.initState();
  }

  Future<void> _loadLocation() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    if (mounted) {
      setState(() {
        _isBellagio = apiUrl.contains('bty.world');
      });
    }
  }

  void _applyFilter() async {
    setState(() {
      _isLoading = true;
    });

    List<GuestGift> giftMembers_ = [];
    try {
      giftMembers_ = await widget.giftsRepository.getGuestGifts(widget.mid);
    } catch (e) {
      print('Error loading guest gifts: $e');
    }

    if (!mounted) return;
    setState(() {
      originalMembers = giftMembers_;
      inactiveMembers = List<GuestGift>.from(originalMembers);
      _isLoading = false;
    });
  }

  // final Map<String, String> ratingImageMap = {
  //   "CLASSIC": "assets/images/ratings/CLASSIC.png",
  //   "DIAMOND": "assets/images/ratings/DIAMOND.png",
  //   "GOLD": "assets/images/ratings/GOLD.png",
  //   "INFINITY": "assets/images/ratings/INFINITY.png",
  //   "PLATINUM": "assets/images/ratings/PLATINUM.png",
  //   "SILVER": "assets/images/ratings/SILVER.png",
  // };
 String _formatLastVisitDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '-';
    return DateFormat('dd MMM yyyy').format(parsed);
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
        return const Color(0xFF5D4037);
    }
  }
  /// Redeem flow: pick a location (iid 90332), then redeem there (iid 90333).
  Future<void> _onRedeemPressed(GuestGift gift) async {
    final serialNo = gift.srNo;
    if (serialNo == null || serialNo.trim().isEmpty) {
      _showMessage('Serial number missing for this gift');
      return;
    }

    setState(() => _isLoading = true);
    List<RedeemLocation> locations = [];
    try {
      locations = await widget.giftsRepository.getRedeemLocations();
    } catch (e) {
      print('Error loading redeem locations: $e');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (locations.isEmpty) {
      _showMessage('No redeem locations available');
      return;
    }

    final selected = await _showLocationPicker(locations);
    if (selected == null || !mounted) return;

    final confirmed = await _showRedeemConfirmation(gift, selected);
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    final resp = await widget.giftsRepository.redeemGift(
      mid: gift.mid,
      serialNo: serialNo,
      commLoca: selected.commLoca,
      rcNum :gift.rcNo,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (resp != null && resp['strRturnRes'] == true) {
      _showMessage('Gift redeemed at ${selected.location}');
      _applyFilter();
    } else {
      _showMessage('Failed to redeem gift. Please try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<bool?> _showRedeemConfirmation(
    GuestGift gift,
    RedeemLocation location,
  ) {
    final amount = NumberFormat.currency(
      symbol: '',
      decimalDigits: 0,
    ).format(gift.amount);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          title: const Text('Confirm Redeem'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Do you want to redeem ${gift.categoryCode} ($amount) at ${location.location}?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'Serial No: ${gift.srNo}',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.kSecondaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Redeem'),
            ),
          ],
        );
      },
    );
  }

  Future<RedeemLocation?> _showLocationPicker(
    List<RedeemLocation> locations,
  ) {
    return showDialog<RedeemLocation>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          title: const Text('Select Location'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: locations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final location = locations[index];
                return ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: Constants.kSecondaryColor,
                  ),
                  title: Text(location.location),
                  onTap: () => Navigator.of(dialogContext).pop(location),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showImagePopup(BuildContext context, Guest selectedGuest) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: selectedGuest.memImage2 != null
                        ? Image.memory(
                            base64Decode(selectedGuest.memImage2!),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/others/profile.png',
                                fit: BoxFit.contain,
                              );
                            },
                          )
                        : Image.asset(
                            'assets/images/others/profile.png',
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(
    Guest? selectedGuest,
    String? ratingFromGifts,
    String? gNameFromGifts,
    String? lvdFromGifts,
  ) {
    final fontSettings = ref.watch(fontSettingsProvider);

    if (selectedGuest == null) return const SizedBox.shrink();

    String? displayRating = ratingFromGifts ?? selectedGuest.gRating;
    final displayGName = gNameFromGifts ?? selectedGuest.gName;
    final displayLvd = lvdFromGifts ?? selectedGuest.lastVisitDate;

    // If rating is null, empty, or equals "NULL", set it to CLASSIC
    if (displayRating == null ||
        displayRating.trim().isEmpty ||
        displayRating.toUpperCase() == "NULL") {
      displayRating = "CLASSIC";
    }
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showImagePopup(context, selectedGuest),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: selectedGuest.memImage2 != null
                          ? Image.memory(
                              base64Decode(selectedGuest.memImage2!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => Image.asset(
                                'assets/images/others/profile.png',
                              ),
                            )
                          : Image.asset('assets/images/others/profile.png'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final currentGuest = ref.read(selectedGuestProvider);
                          // The list is empty once every gift has been redeemed.
                          final firstGift = inactiveMembers.isNotEmpty
                              ? inactiveMembers.first
                              : null;

                          // Create the new guest object with all data including the loaded image
                          final guestToSet = Guest(
                            mid: selectedGuest.mid,
                            memberName: selectedGuest.memberName,
                            country: "",
                            lastVisitDate: firstGift?.lvd ?? "1990-01-01",

                            age: 0,
                            gRating: displayRating,
                            mGroup: firstGift?.mGroup,
                            gName: firstGift?.gName,

                            // IMPORTANT: Preserve the image from current guest if it exists
                            memImage2: currentGuest?.memImage2,
                          );

                          // Update the provider with the new guest data (keeping the image)
                          ref
                              .read(selectedGuestProvider.notifier)
                              .setSelectedGuest(guestToSet);

                          // Only load image if it's not already loaded
                          if (currentGuest?.memImage2 == null) {
                            await ref
                                .read(selectedGuestProvider.notifier)
                                .getGuestImage(9021, selectedGuest.mid);
                          }

                          // Navigate to profile screen
                          if (mounted) {
                            context.push('/home/profile',extra: {'nogiftamount': true});
                          }
                        },
                        child: Text(
                          selectedGuest.memberName,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize + 2,
                            fontWeight: FontWeight.bold,
                            //decoration: TextDecoration.underline,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                      if (displayGName != null && displayGName.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                'M P: $displayGName',
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                        //Icon(Icons.badge, size: 15, color: Colors.grey[600]),
                          const SizedBox(width: 2),
                          Text(
                            'MID: ${selectedGuest.mid}',
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 2),
                          Text(
                            'LVD:${_formatLastVisitDate(displayLvd)}',
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),
                const SizedBox(width: 40), // space for rating image
              ],
            ),

            /// ⭐ Rating image in bottom-right corner
            // if ((displayRating?.isNotEmpty ?? false) &&
            //     ratingImageMap.containsKey(displayRating))
            //   Positioned(
            //     bottom: 0,
            //     right: 0,
            //     child: Image.asset(
            //       ratingImageMap[displayRating]!,
            //       height: 45,
            //       width: 90,
            //       fit: BoxFit.contain,
            //     ),
            //   ),
            if (displayRating != null && displayRating.isNotEmpty)
  Positioned(
    bottom: 0,
    right: 0,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getRatingColor(displayRating),
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
        displayRating,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final selectedGuest = ref.watch(selectedGuestProvider);
    final ratingFromGifts = inactiveMembers.isNotEmpty
        ? inactiveMembers.first.gRating
        : null;
    final gNameFromGifts = inactiveMembers.isNotEmpty
        ? inactiveMembers.first.gName
        : null;
    final lvdFromGifts = inactiveMembers.isNotEmpty
        ? inactiveMembers.first.lvd
        : null;

    return Scaffold(
      appBar: AppBar(title: Text('Guest Gifts')),
      body: Stack(
        children: [
          Column(
            children: [
              // Profile Card at the top
              _buildProfileCard(
                selectedGuest,
                ratingFromGifts,
                gNameFromGifts,
                lvdFromGifts,
              ),

              // Gifts List
              Expanded(
                child: inactiveMembers.isEmpty
                    ? const Center(child: Text("No gifts available"))
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ListView.builder(
                          itemCount: inactiveMembers.length,
                          itemBuilder: (context, index) {
                            final guest = inactiveMembers[index];
                            final hasSerialNo =
                                guest.srNo != null &&
                                guest.srNo!.trim().isNotEmpty;
                            return InkWell(
                              key: ValueKey(guest.mid),
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                // Get the current selected guest from provider (which should have the image)
                                final currentGuest = ref.read(
                                  selectedGuestProvider,
                                );

                                // Create the new guest object with all data including the loaded image
                                final guestToSet = Guest(
                                  mid: guest.mid,
                                  memberName: guest.memberName,
                                  country: "",
                                  lastVisitDate: guest.lvd ?? "1990-01-01",
                                  gift: NumberFormat.currency(
                                    symbol: '',
                                    decimalDigits: 0,
                                  ).format(guest.amount),
                                  age: 0,
                                  gRating: guest.gRating,
                                  mGroup: guest.mGroup,
                                  gName: guest.gName,
                                  mobile: guest.mobile,
                                  categoryCode: guest.categoryCode,
                                  // IMPORTANT: Preserve the image from current guest if it exists
                                  memImage2: currentGuest?.memImage2,
                                );

                                // Update the provider with the new guest data (keeping the image)
                                ref
                                    .read(selectedGuestProvider.notifier)
                                    .setSelectedGuest(guestToSet);

                                // Only load image if it's not already loaded
                                if (currentGuest?.memImage2 == null) {
                                  await ref
                                      .read(selectedGuestProvider.notifier)
                                      .getGuestImage(9021, guest.mid);
                                }

                                // Navigate to profile screen
                                if (mounted) {
                                  context.push(
                                    '/home/profile',
                                    extra: {'isNormalGift': true},
                                  );
                                }
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
                                      if (_formatLastVisitDate(
                                            guest.issueDate,
                                          ) !=
                                          '-') ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.event_available,
                                              color: Colors.grey,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Valid from ${_formatLastVisitDate(guest.issueDate)}',
                                              style: TextStyle(
                                                fontSize:
                                                    fontSettings.fontSize,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
                                      if (hasSerialNo || _isBellagio) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            if (hasSerialNo)
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .confirmation_number,
                                                      color: Colors.grey,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Serial No: ${guest.srNo}',
                                                        style: TextStyle(
                                                          fontSize: fontSettings
                                                              .fontSize,
                                                          fontWeight:
                                                              fontSettings
                                                                  .fontWeight,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              const Spacer(),
                                            if (_isBellagio)
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _onRedeemPressed(guest),
                                                icon: const Icon(
                                                  Icons.redeem,
                                                  size: 18,
                                                ),
                                                label: const Text('Redeem'),
                                                style:
                                                    ElevatedButton.styleFrom(
                                                  backgroundColor: Constants
                                                      .kSecondaryColor,
                                                  foregroundColor:
                                                      Colors.white,
                                                  shape:
                                                      RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
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
