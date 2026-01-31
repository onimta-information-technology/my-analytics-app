import 'dart:convert';

import 'package:ballys_reservation_app/components/flight_card.dart';
import 'package:ballys_reservation_app/components/guest_details_card.dart';
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
import 'package:ballys_reservation_app/providers/reservation_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider.dart';
import 'package:ballys_reservation_app/providers/selected_reservation_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
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
  bool _isGuestLoading = false;
  bool _guestDataLoaded = false;
  bool _hasGiftAppPermission = false;
  
  @override
  void initState() {
    super.initState();
    _checkGiftAppPermission();
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

      // Only load guest data if it hasn't been loaded yet
      if (selectedReservation != null && !_guestDataLoaded) {
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

  Future<void> _checkGiftAppPermission() async {
    final giftApp = await StorageUtil.getGiftApp();
    setState(() {
      _hasGiftAppPermission = giftApp ?? false;
    });
  }

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 10),
            Text('Access Denied'),
          ],
        ),
        content: const Text(
          'You do not have permission to Approve or Reject gift requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadGuestDataForView() async {
    if (_memberIdController.text.isEmpty || _guestDataLoaded) return;

    try {
      setState(() {
        _isGuestLoading = true;
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
               
                age: 0,
                gRating: guestResponse.gRating ?? "",
                mGroup: guestResponse.mGroup,
                gName: guestResponse.gName ?? "",
                memImage2: guestResponse.memImage2,
              
              ),
            );
      }

      // Mark guest data as loaded
      _guestDataLoaded = true;

      setState(() {
        _isGuestLoading = false;
      });
    } catch (e) {
      setState(() {
        _isGuestLoading = false;
      });
    }
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

  Future<String?> _showRemarksDialog(String title) async {
    final TextEditingController remarksController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },

          child: AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Please enter remarks for this action:'),
                const SizedBox(height: 16),
                TextField(
                  controller: remarksController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter your remarks here...',
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Cancel
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(remarksController.text);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _approveReservation() async {
    // Check permission first
    if (!_hasGiftAppPermission) {
      _showAccessDeniedDialog();
      return;
    }

    final selectedReservation = ref.watch(selectedReservationProvider);
    if (selectedReservation == null) return;

    // Show remarks dialog first
    final remarks = await _showRemarksDialog('Approve Reservation');
    if (remarks == null) return; // User cancelled

    try {
      setState(() {
        _isLoading = true;
      });
      final currentUserName = await StorageUtil.getUserName();
      // Use the repository method through the provider
      final success = await ref
          .read(reservationProvider.notifier)
          .approveOrRejectReservation(
            memberID: selectedReservation.mid,
            reservationNo: selectedReservation.reservNo,
            currentUName: currentUserName ?? '',
            status: "Approved",
            remarks: remarks,
          );

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation approved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back and refresh the reservation list
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to approve reservation');
      }
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rejectReservation() async {
    // Check permission first
    if (!_hasGiftAppPermission) {
      _showAccessDeniedDialog();
      return;
    }

    final selectedReservation = ref.watch(selectedReservationProvider);
    if (selectedReservation == null) return;

    // Show remarks dialog first
    final remarks = await _showRemarksDialog('Reject Reservation');
    if (remarks == null) return; // User cancelled

    try {
      setState(() {
        _isLoading = true;
      });
      final currentUserName = await StorageUtil.getUserName();
      // Use the repository method through the provider
      final success = await ref
          .read(reservationProvider.notifier)
          .approveOrRejectReservation(
            memberID: selectedReservation.mid,
            reservationNo: selectedReservation.reservNo,
            currentUName: currentUserName ?? '',
            status: "Rejected",
            remarks: remarks,
          );

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation rejected successfully'),
            backgroundColor: Colors.orange,
          ),
        );

        // Navigate back and refresh the reservation list
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to reject reservation');
      }
    } catch (e) {
   
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      bool hasAirTickets = false;

      String status = selectedReservation.airticketReservationStatus
          .toString()
          .toUpperCase()
          .trim();

      // Check for various possible "Yes" values
      hasAirTickets =
          status == "T" ||
          status == "TRUE" ||
          status == "YES" ||
          status == "Y" ||
          status == "1";

      _airTicketRequisition = hasAirTickets ? "Yes" : "No";
     
      _remarksController.text = selectedReservation.remarks;
    }
    final fontSettings = ref.watch(fontSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/MenuScreen');
            }
          },
        ),
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

              child: (selectedReservation?.requestStatus == 'Pending')
                  ? IconButton(
                      onPressed: () async {
                        Future<void> navigateToEditReservation() async {
                          final result = await context.push(
                            "/reservations/new-reservation",
                          );
                          if (result == true) {
                            if (mounted) {
                              Navigator.of(context).pop(true);
                            }
                          }
                        }

                        // Ensure guest data is loaded before navigation
                        if (_memberIdController.text.isNotEmpty &&
                            !_guestDataLoaded) {
                          await _loadGuestDataForView();
                          await navigateToEditReservation();
                        } else {
                          await navigateToEditReservation();
                        }
                      },
                      icon: const Icon(Icons.mode_edit_outline_sharp),
                    )
                  : const SizedBox.shrink(),
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
                        onPressed: () async {
                          try {
                            // Only load if not already loaded
                            if (!_guestDataLoaded &&
                                _memberIdController.text.isNotEmpty) {
                              setState(() {
                                _isLoading = true;
                              });

                              await _loadGuestDataForView();

                              setState(() {
                                _isLoading = false;
                              });
                            }

                            context.push('/home/profile');
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                            });

                          }
                        },
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
                  GuestDisplayCard(
                    memberIdText: _memberIdController.text,
                    memberNameText: _memberNameController.text,
                    showCard:
                        _memberIdController.text.isNotEmpty &&
                        _memberNameController.text.isNotEmpty,
                    isLoading: _isGuestLoading,
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
                              color: const Color.fromARGB(255, 168, 49, 49),
                            ),
                          ),
                        )
                      : Column(
                          children: selectedHotels.map((hotel) {
                            return SizedBox(
                              width: double.infinity,
                              child: Card(
                                color: const Color.fromARGB(255, 228, 224, 224),
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
                                contentPadding: EdgeInsets.symmetric(
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
                    
                    },
                  ),
                  const SizedBox(height: 16.0),
                  if (selectedReservation?.requestStatus == 'Pending')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: SizedBox(
                            child: ElevatedButton(
                              onPressed: _approveReservation,
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
                            child: ElevatedButton(
                              onPressed: _rejectReservation,
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
          if (_isLoading && !_isGuestLoading)
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