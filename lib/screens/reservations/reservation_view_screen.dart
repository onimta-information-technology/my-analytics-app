import 'dart:convert';

import 'package:ballys_reservation_app/components/flight_card.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/hotels_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider.dart';
import 'package:ballys_reservation_app/providers/selected_reservation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ReservationViewScreen extends ConsumerStatefulWidget {
  const ReservationViewScreen({super.key});

  @override
  ConsumerState<ReservationViewScreen> createState() =>
      _NewReservationScreenState();
}

class _NewReservationScreenState extends ConsumerState<ReservationViewScreen> {
  final TextEditingController _reservationNoController =
      TextEditingController();
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();

  final ValueNotifier<String> hotelRoomNotifier = ValueNotifier<String>("");
  final ValueNotifier<String> airTicketsNotifier = ValueNotifier<String>("");

  DateTimeRange? selectedDateRange;
  String? selectedHotelAndRoom;
  int? numberOfNights;

  final TextEditingController _arrivalDateController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String _airTicketRequisition = "No";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getHotels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
      final selectedReservation = ref.watch(selectedReservationProvider);
      ref
          .read(selectedHotelProvider.notifier)
          .setHotels(
            selectedReservation != null ? selectedReservation.hotelDescip : [],
          );
      ref
          .read(selectedFlightProvider.notifier)
          .setFlights(
            selectedReservation != null
                ? selectedReservation.airticketDescrip
                : [],
          );
      if (selectedReservation != null) {
        _loadGuestDataForView();
      }
    });
  }

  @override
  void dispose() {
    _memberIdController.dispose();
    _memberNameController.dispose();
    _arrivalDateController.dispose();
    _departureDateController.dispose();
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
  Future<void> _loadGuestDataForView() async {
    if (_memberIdController.text.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
      });

      GuestRepository guestRepository = GuestRepository(
        ApiService(const FlutterSecureStorage()),
      );

      List<GuestSearchResponse> guests = await guestRepository.searchGuest(
        9021, // Using 9021 as the search type for MID lookup
        _memberIdController.text,
      );

      if (guests.isNotEmpty) {
        final guestResponse = guests.first;
        ref
            .read(selectedGuestProvider.notifier)
            .setSelectedGuest(
              Guest(
                mid: guestResponse.mid ?? _memberIdController.text,
                memberName: guestResponse.mName ?? _memberNameController.text,
                country: "",
                lastVisitDate: guestResponse.lvd?.toString() ?? "",
                gift: "",
                age: 0,
                gRating: guestResponse.gRating ?? "",
                mGroup: "",
                gName: guestResponse.gName ?? "",
                memImage2: guestResponse.memImage2,
              ),
            );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading guest data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(Icons.person, size: 40, color: Colors.grey.shade600),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating.toLowerCase()) {
      case 'vip':
      case 'platinum':
        return Colors.purple.shade600;
      case 'gold':
        return Colors.amber.shade600;
      case 'silver':
        return Colors.grey.shade600;
      case 'bronze':
        return Colors.brown.shade600;
      case 'premium':
        return Colors.blue.shade600;
      default:
        return Colors.green.shade600;
    }
  }

  void _showFullScreenImage(BuildContext context) {
    final selectedGuest = ref.read(selectedGuestProvider);

    if (selectedGuest?.memImage2 == null || selectedGuest!.memImage2!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No image available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(selectedGuest.memImage2!),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          width: 200,
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.error,
                            size: 50,
                            color: Colors.red,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getHotels() async {
    final hotels = ref.read(hotelsProvider);

    if (hotels.isEmpty) {
      await ref.read(hotelsProvider.notifier).getAllHotels();
    }
  }

  String getGuestAndRoomCounts(List<HotelDescip> hotels) {
    final totalGuests = hotels.fold<int>(
      0,
      (sum, hotel) => sum + hotel.guestCount!,
    );
    final totalRooms = hotels.fold<int>(
      0,
      (sum, hotel) => sum + hotel.roomCount!,
    );

    String txt = "";

    if (totalGuests == 1) {
      txt += "$totalGuests GUEST";
    } else {
      txt += "$totalGuests GUESTS";
    }

    if (totalRooms == 1) {
      txt += ", $totalRooms ROOM";
    } else {
      txt += ", $totalRooms ROOMS";
    }

    return txt;
  }

  String getGuestAndTicketCounts(List<FlightBooking> flights) {
    final totalGuests = flights.fold<int>(
      0,
      (sum, hotel) => sum + hotel.guestCount,
    );
    final totalTickets = flights.length;

    String txt = "";

    if (totalGuests == 1) {
      txt += "$totalGuests GUEST";
    } else {
      txt += "$totalGuests GUESTS";
    }

    if (totalTickets == 1) {
      txt += ", $totalTickets TICKET";
    } else {
      txt += ", $totalTickets TICKETS";
    }

    return txt;
  }

  @override
  Widget build(BuildContext context) {
    final selectedReservation = ref.watch(selectedReservationProvider);
    final selectedHotels = ref.watch(selectedHotelProvider);
    hotelRoomNotifier.value = getGuestAndRoomCounts(selectedHotels);
    final selectedFlights = ref.watch(selectedFlightProvider);
    airTicketsNotifier.value = getGuestAndTicketCounts(selectedFlights);

    if (selectedReservation != null) {
      _reservationNoController.text = selectedReservation.reservNo;
      _memberIdController.text = selectedReservation.mid;
      _memberNameController.text = selectedReservation.mName;
      final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
      _arrivalDateController.text = dateFormat.format(
        selectedReservation.arrDate,
      );
      _departureDateController.text = dateFormat.format(
        selectedReservation.depDate,
      );
      _airTicketRequisition =
          selectedReservation.airticketReservationStatus == "T" ? "Yes" : "No";
      _remarksController.text = selectedReservation.remarks;
    }
    final fontSettings = ref.watch(fontSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Reservation - ${selectedReservation != null ? selectedReservation.reservNo : ''}",
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          PopScope(
            onPopInvokedWithResult: (bool didPop, dynamic result) {
              ref
                  .read(selectedReservationProvider.notifier)
                  .clearSelectedReservation();
              ref.read(selectedHotelProvider.notifier).setHotels([]);
              ref.read(selectedFlightProvider.notifier).setFlights([]);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: () {
                  context.go("/reservations/new-reservation");
                },
                icon: const Icon(Icons.mode_edit_outline_sharp),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextFormField(
                    autofocus: false,
                    readOnly: true,
                    controller: _reservationNoController,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    decoration: InputDecoration(
                      labelText: "Reservation No",
                      labelStyle: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: -5.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  // TextFormField(
                  //   keyboardType: const TextInputType.numberWithOptions(),
                  //   autofocus: false,
                  //   readOnly: true,
                  //   controller: _memberIdController,
                  //   decoration: InputDecoration(
                  //     labelText: "Member ID",
                  //     labelStyle: TextStyle(
                  //       fontSize: fontSettings.fontSize,
                  //       fontWeight: fontSettings.fontWeight,
                  //     ),
                  //     border: OutlineInputBorder(),
                  //     contentPadding: const EdgeInsets.symmetric(
                  //       horizontal: 12.0,
                  //       vertical: -5.0,
                  //     ),
                  //   ),
                  // ),
                  //
                  Row(
                    children: [
                      // Member ID field
                      Expanded(
                        child: TextFormField(
                          keyboardType: const TextInputType.numberWithOptions(),
                          autofocus: false,
                          controller: _memberIdController,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Member ID",
                            labelStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: -5.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ), // spacing between field and button
                      // Search Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, // Black background
                          foregroundColor: Colors.white, // White text/icon
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onPressed: true
                            ? () async {
                                try {
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  GuestRepository guestRepository =
                                      GuestRepository(
                                        ApiService(
                                          const FlutterSecureStorage(),
                                        ),
                                      );

                                  // Search for guest by MID
                                  List<GuestSearchResponse> guests =
                                      await guestRepository.searchGuest(
                                        9021,
                                        _memberIdController.text,
                                      );

                                  setState(() {
                                    _isLoading = false;
                                  });

                                  if (guests.isNotEmpty) {
                                    final guestResponse = guests.first;
                                    ref
                                        .read(selectedGuestProvider.notifier)
                                        .setSelectedGuest(
                                          Guest(
                                            mid:
                                                guestResponse.mid ??
                                                _memberIdController.text,
                                            memberName:
                                                guestResponse.mName ??
                                                _memberNameController.text,
                                            country: "",
                                            lastVisitDate:
                                                guestResponse.lvd?.toString() ??
                                                "",
                                            gift: "",
                                            age: 0,
                                            gRating:
                                                guestResponse.gRating ?? "",
                                            mGroup: "",
                                            gName: guestResponse.gName ?? "",
                                          ),
                                        );
                                    context.push('/home/profile');
                                  } else {
                                    // fallback guest
                                    ref
                                        .read(selectedGuestProvider.notifier)
                                        .setSelectedGuest(
                                          Guest(
                                            mid: _memberIdController.text,
                                            memberName:
                                                _memberNameController.text,
                                            country: "",
                                            lastVisitDate: "1990-01-01",
                                            gift: "",
                                            age: 0,
                                            gRating: "",
                                            mGroup: "",
                                            gName: "",
                                          ),
                                        );
                                    context.push('/home/profile');
                                  }
                                } catch (e) {
                                  setState(() {
                                    _isLoading = false;
                                  });

                                  print("Error searching guest: $e");

                                  ref
                                      .read(selectedGuestProvider.notifier)
                                      .setSelectedGuest(
                                        Guest(
                                          mid: _memberIdController.text,
                                          memberName:
                                              _memberNameController.text,
                                          country: "",
                                          lastVisitDate: "1990-01-01",
                                          gift: "",
                                          age: 0,
                                          gRating: "",
                                          mGroup: "",
                                          gName: "",
                                        ),
                                      );
                                  context.push('/home/profile');
                                }
                              }
                            : null, // disable if not edit mode
                        // style: ElevatedButton.styleFrom(

                        // ),
                        child: const Icon(Icons.person_search, size: 25),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10.0),
                  TextFormField(
                    autofocus: false,
                    readOnly: true,
                    controller: _memberNameController,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    decoration: InputDecoration(
                      labelText: "Member Name",
                      labelStyle: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                      border: OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: -5.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10.0),

                  // Guest Display Section
                  if (_memberIdController.text.isNotEmpty &&
                      _memberNameController.text.isNotEmpty)
                    Column(
                      children: [
                        const SizedBox(height: 10.0),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(1.0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              // First Row - Profile Picture and Guest Name
                              Row(
                                children: [
                                  // Member Photo - Clickable
                                  GestureDetector(
                                    onTap: () {
                                      _showFullScreenImage(context);
                                    },
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color.fromARGB(
                                            255,
                                            59,
                                            50,
                                            50,
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            final selectedGuest = ref.watch(
                                              selectedGuestProvider,
                                            );

                                            if (selectedGuest?.memImage2 !=
                                                    null &&
                                                selectedGuest!
                                                    .memImage2!
                                                    .isNotEmpty) {
                                              try {
                                                return Image.memory(
                                                  base64Decode(
                                                    selectedGuest.memImage2!,
                                                  ),
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return _buildPlaceholderAvatar();
                                                      },
                                                );
                                              } catch (e) {
                                                return _buildPlaceholderAvatar();
                                              }
                                            }
                                            return _buildPlaceholderAvatar();
                                          },
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  // Guest Name (M P)
                                  Expanded(
                                    child: Consumer(
                                      builder: (context, ref, child) {
                                        final selectedGuest = ref.watch(
                                          selectedGuestProvider,
                                        );

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (selectedGuest?.gName != null &&
                                                selectedGuest!
                                                    .gName!
                                                    .isNotEmpty)
                                              Text(
                                                "M P: ${selectedGuest.gName!}",
                                                style: TextStyle(
                                                  fontSize:
                                                      fontSettings.fontSize *
                                                      0.9,
                                                  fontWeight:
                                                      fontSettings.fontWeight,
                                                  color: Colors.blue.shade700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              )
                                            else if (_memberNameController
                                                .text
                                                .isNotEmpty)
                                              Text(
                                                "M P: ${_memberNameController.text}",
                                                style: TextStyle(
                                                  fontSize:
                                                      fontSettings.fontSize *
                                                      0.9,
                                                  fontWeight:
                                                      fontSettings.fontWeight,
                                                  color: Colors.blue.shade700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              // Second Row - Rating Image (Right aligned)
                              Row(
                                children: [
                                  const Spacer(),
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final selectedGuest = ref.watch(
                                        selectedGuestProvider,
                                      );

                                      if (selectedGuest?.gRating != null &&
                                          selectedGuest!.gRating!.isNotEmpty &&
                                          ratingImageMap.containsKey(
                                            selectedGuest.gRating!
                                                .toUpperCase(),
                                          )) {
                                        return Container(
                                          width: 80,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.asset(
                                              ratingImageMap[selectedGuest
                                                  .gRating!
                                                  .toUpperCase()]!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      color:
                                                          Colors.grey.shade200,
                                                      child: Icon(
                                                        Icons.star,
                                                        color: _getRatingColor(
                                                          selectedGuest
                                                              .gRating!,
                                                        ),
                                                        size: 10,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10.0),
                  ValueListenableBuilder<String>(
                    valueListenable: hotelRoomNotifier,
                    builder: (context, value, child) {
                      return TextFormField(
                        controller: TextEditingController(text: value),
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Select Hotels & Rooms",
                          labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          border: OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: -5.0,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10.0),
                  selectedHotels.isEmpty
                      ? Center(
                          heightFactor: 3.0,
                          child: Text(
                            'No hotels selected.',
                            style: TextStyle(
                              fontSize: 16,
                              color: const Color.fromARGB(255, 236, 203, 203),
                            ),
                          ),
                        )
                      : Column(
                          children: selectedHotels.map((hotel) {
                            return SizedBox(
                              width: double.infinity,
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 8,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hotel.hotelName!,
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: fontSettings.fontWeight,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: "Category: ",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize:
                                                    fontSettings.fontSize + 2,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: hotel.roomCategoryName,
                                              style: TextStyle(
                                                fontSize: fontSettings.fontSize,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: "Room Type: ",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize:
                                                    fontSettings.fontSize + 2,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                              ),
                                            ),
                                            TextSpan(
                                              text: hotel.roomTypeName,
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: fontSettings.fontSize,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Guests: ${hotel.guestCount}",
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Text(
                                            "Nights: ${hotel.noOfNights}",
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Text(
                                            "Rooms: ${hotel.roomCount}",
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Estimated Cost: ${hotel.selectedCost}",
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize + 2,
                                          fontWeight: fontSettings.fontWeight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 10.0),
                  TextFormField(
                    controller: _arrivalDateController,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Arrival Date",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: -5.0,
                      ),
                      labelStyle: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _departureDateController,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Departure Date",
                      labelStyle: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                      border: OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: -5.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      "Air Ticket Requisition",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Radio<String>(
                        value: "Yes",
                        groupValue: _airTicketRequisition,
                        onChanged: (value) {
                          setState(() {
                            _airTicketRequisition = value!;
                          });
                        },
                      ),
                      const Text("Yes", style: TextStyle(fontSize: 16)),
                      Radio<String>(
                        value: "No",
                        groupValue: _airTicketRequisition,
                        onChanged: (value) {
                          setState(() {
                            _airTicketRequisition = value!;
                          });
                        },
                      ),
                      const Text("No", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  if (_airTicketRequisition == "Yes")
                    Column(
                      children: [
                        const SizedBox(height: 10.0),
                        ValueListenableBuilder<String>(
                          valueListenable: airTicketsNotifier,
                          builder: (context, value, child) {
                            return TextFormField(
                              controller: TextEditingController(text: value),
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: "Select Air Tickets",
                                border: OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: -5.0,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  if (_airTicketRequisition == "Yes")
                    Column(
                      children: [
                        const SizedBox(height: 10.0),
                        selectedFlights.isEmpty
                            ? const Center(
                                heightFactor: 6.0,
                                child: Text(
                                  'No air tickets available.',
                                  style: TextStyle(fontSize: 16),
                                ),
                              )
                            : SizedBox(
                                child: Column(
                                  children: selectedFlights.map((flight) {
                                    final index = selectedFlights.indexOf(
                                      flight,
                                    );
                                    return FlightCard(
                                      flight: flight,
                                      index: index,
                                      showDelete: false,
                                    );
                                  }).toList(),
                                ),
                              ),
                      ],
                    ),
                  const SizedBox(height: 10.0),
                  TextFormField(
                    readOnly: true,
                    controller: _remarksController,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    decoration: InputDecoration(
                      alignLabelWithHint: true,
                      labelText: "Remarks",
                      labelStyle: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                      hintText: "Enter additional details...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),

                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    onChanged: (value) {
                      print("Textarea content: $value");
                    },
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: SizedBox(
                          // width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
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
                                Icon(Icons.done, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  "Approve",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: SizedBox(
                          // width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Constants.kSecondaryColor,
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
                                Icon(Icons.cancel, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  "Reject",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
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
          const Watermark(),
        ],
      ),
    );
  }
}
