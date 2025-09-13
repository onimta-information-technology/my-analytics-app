import 'dart:convert';

import 'package:ballys_reservation_app/components/bottom_sheets/member_search-new_sheet.dart';
import 'package:ballys_reservation_app/components/bottom_sheets/member_search_by_mid_bottom_sheet.dart';
import 'package:ballys_reservation_app/components/flight_card.dart';
import 'package:ballys_reservation_app/components/hotel_selection.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/repositories/hotel_repository.dart';
import 'package:ballys_reservation_app/data/repositories/reservation_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/models/reservation/new_reservation.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/hotels_provider.dart';
import 'package:ballys_reservation_app/providers/member_search_provider.dart';
import 'package:ballys_reservation_app/providers/new_reservation_provider.dart';
import 'package:ballys_reservation_app/providers/reservation_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider.dart';
import 'package:ballys_reservation_app/providers/selected_reservation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NewReservationScreen extends ConsumerStatefulWidget {
  const NewReservationScreen({super.key});

  @override
  ConsumerState<NewReservationScreen> createState() =>
      _NewReservationScreenState();
}

class _NewReservationScreenState extends ConsumerState<NewReservationScreen> {
  final TextEditingController _reservationNoController =
      TextEditingController();
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _hotelRoomController = TextEditingController();

  final ValueNotifier<String> hotelRoomNotifier = ValueNotifier<String>("");
  final ValueNotifier<String> airTicketsNotifier = ValueNotifier<String>("");

  bool _isLoading = false;
  String _selectedPrefix = "BM";
  final TextEditingController _memberIdNumberController =
      TextEditingController();
  DateTimeRange? selectedDateRange;
  String? selectedHotelAndRoom;
  int? numberOfNights;

  final TextEditingController _noOfNightsController = TextEditingController();
  final TextEditingController _arrivalDateController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  DateTime? _arrivalDate;
  DateTime? _departureDate;
  String _airTicketRequisition = "No";
  bool _isEditMode = false;
  final _formKey = GlobalKey<FormState>();
  bool hasError = false;
  String? _hotelError;
  String? _airTicketError;

  @override
  void initState() {
    super.initState();
    _getHotels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
      final selectedReservation = ref.watch(selectedReservationProvider);
      if (selectedReservation != null) {
        _isEditMode = true;
        _populateFields(selectedReservation);
        _loadGuestDataInEditMode();
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

  Future<void> _loadGuestDataInEditMode() async {
    if (!_isEditMode || _memberIdController.text.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
      });

      GuestRepository guestRepository = GuestRepository(
        ApiService(const FlutterSecureStorage()),
      );

      // Search for guest by MID to get full guest information
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
                memImage2:
                    guestResponse.memImage2, // Add this line to get the image
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

  void _populateFields(Reservation selectedReservation) {
    _reservationNoController.text = selectedReservation.reservNo;
    _memberIdController.text = selectedReservation.mid;
    _memberNameController.text = selectedReservation.mName;
    _noOfNightsController.text = selectedReservation.noOfNights.toString();
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
    _arrivalDate = selectedReservation.arrDate;
    _arrivalDateController.text = dateFormat.format(
      selectedReservation.arrDate,
    );
    _departureDate = selectedReservation.depDate;
    _departureDateController.text = dateFormat.format(
      selectedReservation.depDate,
    );
    _airTicketRequisition =
        selectedReservation.airticketReservationStatus == "T" ? "Yes" : "No";
    _remarksController.text = selectedReservation.remarks;
  }

  Future<void> _getHotels() async {
    final hotels = ref.read(hotelsProvider);

    if (hotels.isEmpty) {
      await ref.read(hotelsProvider.notifier).getAllHotels();
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

  void _openHotelAndRoomSelectorBottomSheet(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return HotelAndRoomSelectionBottomSheet(
          HotelRepository(ApiService(const FlutterSecureStorage())),
        );
      },
    );
    // context.go("/reservations/new-reservation/hotel-selection");
  }

  void _openAirTicketsSelectorScreen(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());
    context.go(
      "/reservations/new-reservation/air-tickets-selection",
      extra: {
        'arrivalDate': _arrivalDateController.text,
        'departureDate': _departureDateController.text,
      },
    );
  }

  // Future<void> _openMemberSearchBottomSheet(int iid) async {
  //   GuestRepository guestRepository = GuestRepository(
  //     ApiService(const FlutterSecureStorage()),
  //   );

  //   String searchTerm = "";

  //   if (iid == 8002) {
  //     searchTerm = _memberIdController.text;
  //   } else {
  //     searchTerm = _memberNameController.text;
  //   }

  //   if (searchTerm.length < 3) return;
  //   print(_memberNameController.text);
  //    print(_memberIdController.text);
  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     List<GuestSearchResponse> guests = await guestRepository.searchGuest(
  //       iid,
  //       searchTerm,
  //     );

  //     setState(() {
  //       _isLoading = false;
  //     });

  //     showModalBottomSheet(
  //       context: context,
  //       isScrollControlled: true,
  //       shape: const RoundedRectangleBorder(
  //         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //       ),
  //       builder: (BuildContext context) {
  //         return MemberSearchBottomSheet(guests: guests);
  //       },
  //     );
  //   } catch (e) {
  //     print("Error searching guests: $e");
  //   }
  // }
  Future<void> _openMemberSearchBottomSheet(int iid) async {
    GuestRepository guestRepository = GuestRepository(
      ApiService(const FlutterSecureStorage()),
    );

    String searchTerm = "";

    if (iid == 8002) {
      searchTerm = _memberIdController.text;
    } else {
      searchTerm = _memberNameController.text;
    }

    if (searchTerm.length < 3) {
      // Show modal with empty results and let user search from within modal
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext context) {
          return MemberNewSearchBottomSheet(
            guests: [], // Empty list initially
            initialSearchTerm: searchTerm,
            searchIid: iid,
            onSearch: (String term, int searchIid) async {
              await _performGuestSearch(term, searchIid);
            },
          );
        },
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<GuestSearchResponse> guests = await guestRepository.searchGuest(
        iid,
        searchTerm,
      );

      setState(() {
        _isLoading = false;
      });

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext context) {
          return MemberNewSearchBottomSheet(
            guests: guests,
            initialSearchTerm: searchTerm,
            searchIid: iid,
            onSearch: (String term, int searchIid) async {
              await _performGuestSearch(term, searchIid);
            },
          );
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error searching guests: $e");
    }
  }

  // Add this new method to handle search from within the modal
  Future<void> _performGuestSearch(String searchTerm, int iid) async {
    if (searchTerm.length < 3) return;

    GuestRepository guestRepository = GuestRepository(
      ApiService(const FlutterSecureStorage()),
    );

    try {
      List<GuestSearchResponse> guests = await guestRepository.searchGuest(
        iid,
        searchTerm,
      );

      // Close current modal
      Navigator.of(context).pop();

      // Open new modal with updated results
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext context) {
          return MemberNewSearchBottomSheet(
            guests: guests,
            initialSearchTerm: searchTerm,
            searchIid: iid,
            onSearch: (String term, int searchIid) async {
              await _performGuestSearch(term, searchIid);
            },
          );
        },
      );
    } catch (e) {
      print("Error searching guests: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching guests: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectArrivalDate(BuildContext context) async {
    final DateTime? selectedArrivalDate = await showDatePicker(
      context: context,
      initialDate: _arrivalDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (selectedArrivalDate != null && selectedArrivalDate != _arrivalDate) {
      setState(() {
        _arrivalDate = selectedArrivalDate;
        _arrivalDateController.text = '${_arrivalDate!.toLocal()}'.split(
          ' ',
        )[0];
        // Reset the departure date if the arrival date is changed
        _departureDate = null;
        _departureDateController.clear();
      });
    }
  }

  Future<void> _selectDepartureDate(BuildContext context) async {
    final DateTime? selectedDepartureDate = await showDatePicker(
      context: context,
      initialDate: _departureDate ?? _arrivalDate ?? DateTime.now(),
      firstDate: _arrivalDate ?? DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (selectedDepartureDate != null &&
        selectedDepartureDate != _departureDate) {
      setState(() {
        _departureDate = selectedDepartureDate;
        _departureDateController.text = '${_departureDate!.toLocal()}'.split(
          ' ',
        )[0];
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
              // Full screen image
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

              // Close button
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

  void _confirmReservation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final selectedHotels = ref.watch(selectedHotelProvider);
    final selectedFlights = ref.watch(selectedFlightProvider);

    print(_arrivalDate);
    print(_departureDate);

    setState(() {
      _hotelError = null;
      _airTicketError = null;
      hasError = false;
    });

    //At least one hotel or flight must be selected
    if (selectedHotels.isEmpty && selectedFlights.isEmpty) {
      setState(() {
        _hotelError = "Please select at least one hotel or flight";
      });
      hasError = true;
    }
    //If Air Ticket Yes ,flights required
    if (_airTicketRequisition == "Yes" && selectedFlights.isEmpty) {
      setState(() {
        _airTicketError = "Please select at least one flight";
      });
      hasError = true;
    }

    if (hasError) return;

    final resevation = NewReservation(
      bmNumber: _memberIdController.text,
      //bmNumber: "$_selectedPrefix${_memberIdNumberController.text}",
      guestName: _memberNameController.text,
      hotelName: "",
      roomDetails: selectedHotels.map((room) => room.toJson()).toList(),
      noOfNights: 0,
      arrivalDate: _arrivalDate,
      departureDate: _departureDate,
      hasAirTicketReservation: _airTicketRequisition == "Yes" ? "1" : "0",
      remarks: _remarksController.text,
      airTicketDetails: selectedFlights
          .map((ticket) => ticket.toJson())
          .toList(),
    );

    if (_isEditMode) {
      resevation.reservationNo = _reservationNoController.text;
    }

    ReservationRepository reservationRepository = ReservationRepository(
      ApiService(const FlutterSecureStorage()),
    );

    setState(() {
      _isLoading = true;
    });

    try {
      Reservation? response = !_isEditMode
          ? await reservationRepository.saveReservation(resevation)
          : await reservationRepository.updateReservation(resevation);
      if (response != null) {
        ref
            .read(reservationProvider.notifier)
            .addReservationToPending(response);
      }
      setState(() {
        _isLoading = false;
      });

      print(response);
      Navigator.of(context).pop();
    } catch (e) {
      print("Error saving reservation: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedHotels = ref.watch(selectedHotelProvider);
    hotelRoomNotifier.value = getGuestAndRoomCounts(selectedHotels);
    final selectedFlights = ref.watch(selectedFlightProvider);
    airTicketsNotifier.value = getGuestAndTicketCounts(selectedFlights);

    final newReservation = ref.watch(newReservationProvider);
    if (newReservation.bmNumber != null &&
        _memberIdController.text != newReservation.bmNumber) {
      _memberIdController.text = newReservation.bmNumber!;
      _memberNameController.text = newReservation.guestName!;
    }
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: !_isEditMode ? Colors.white : Colors.green,
        foregroundColor: !_isEditMode ? Colors.black : Colors.white,
        title: Text(
          !_isEditMode ? "New Reservation" : "Update Reservation",
          style: TextStyle(
            fontSize: 18 * (fontSettings.fontSize / 16),
            fontWeight: fontSettings.fontWeight,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: PopScope(
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            // if (didPop) return;
            ref.read(newReservationProvider.notifier).resetState();
            ref.read(memberSearchProvider.notifier).resetState();
            ref
                .read(selectedReservationProvider.notifier)
                .clearSelectedReservation();
            ref.read(selectedHotelProvider.notifier).setHotels([]);
            ref.read(selectedFlightProvider.notifier).setFlights([]);
          },
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (_isEditMode) ...[
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
                      ],
                      if (newReservation.bmNumber != null)
                        const SizedBox(height: 16.0),

                      Row(
                        children: [
                          Expanded(
                            child: _isEditMode
                                ? TextFormField(
                                    controller: _memberIdController,
                                    readOnly: true,
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "MID *",
                                      labelStyle: TextStyle(
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                            vertical: -5.0,
                                          ),
                                    ),
                                  )
                                : TextFormField(
                                    controller: _memberIdNumberController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "MID *",
                                      labelStyle: TextStyle(
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                      border: const OutlineInputBorder(),
                                      // isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                            vertical: -5.0,
                                          ),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                          right: 4,
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedPrefix,
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                              color: Colors.black,
                                            ),
                                            items: ["BM", "BL", "BN"].map((
                                              prefix,
                                            ) {
                                              return DropdownMenuItem(
                                                value: prefix,
                                                child: Text(
                                                  prefix,
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    fontWeight:
                                                        fontSettings.fontWeight,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedPrefix = value!;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.search),
                                        onPressed: () {
                                          FocusScope.of(context).unfocus();
                                          _memberIdController.text =
                                              '$_selectedPrefix${_memberIdNumberController.text}';
                                          _openMemberSearchBottomSheet(8002);
                                        },
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return "Member ID is required";
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      _memberNameController.text = '';
                                      ref
                                          .read(newReservationProvider.notifier)
                                          .resetState();
                                    },
                                  ),
                          ),
                          const SizedBox(width: 10.0),

                          ElevatedButton(
                            onPressed: _isEditMode
                                ? () async {
                                    try {
                                      // Set loading state
                                      setState(() {
                                        _isLoading = true;
                                      });

                                      GuestRepository guestRepository =
                                          GuestRepository(
                                            ApiService(
                                              const FlutterSecureStorage(),
                                            ),
                                          );

                                      // Search for guest by MID to get full guest information
                                      List<GuestSearchResponse>
                                      guests = await guestRepository.searchGuest(
                                        9021, // Using 9021 as the search type for MID lookup
                                        _memberIdController.text,
                                      );

                                      setState(() {
                                        _isLoading = false;
                                      });

                                      if (guests.isNotEmpty) {
                                        // Set the selected guest with the retrieved information
                                        final guestResponse = guests.first;
                                        ref
                                            .read(
                                              selectedGuestProvider.notifier,
                                            )
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
                                                    guestResponse.lvd
                                                        .toString() ??
                                                    "",
                                                gift: "",
                                                age: 0,
                                                gRating:
                                                    guestResponse.gRating ?? "",
                                                mGroup: "",
                                                gName:
                                                    guestResponse.gName ?? "",
                                              ),
                                            );

                                        // Navigate to profile
                                        context.push('/home/profile');
                                      } else {
                                        // If no guest found, create a basic guest object with available info
                                        ref
                                            .read(
                                              selectedGuestProvider.notifier,
                                            )
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

                                      // Still allow navigation with basic info if search fails
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
                                : (newReservation.bmNumber == null
                                      ? null
                                      : () {
                                          context.push('/home/profile');
                                        }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEditMode
                                  ? const Color.fromARGB(255, 70, 70, 70)
                                  : (newReservation.bmNumber == null
                                        ? Colors.grey.shade400
                                        : const Color.fromARGB(
                                            255,
                                            70,
                                            70,
                                            70,
                                          )),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 14,
                              ),
                            ),
                            child: const Icon(Icons.person_search, size: 25),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10.0),
                      // Member Name field - simplified for edit mode
                      TextFormField(
                        autofocus: false,
                        controller: _memberNameController,
                        readOnly: _isEditMode, // Make read-only in edit mode
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        decoration: InputDecoration(
                          labelText: "Member Name *",
                          labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          border: const OutlineInputBorder(),
                          //isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: -5.0,
                          ),

                          // Only show search icon when NOT in edit mode
                          suffixIcon: !_isEditMode
                              ? IconButton(
                                  icon: const Icon(Icons.search),
                                  onPressed: () {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(FocusNode());
                                    _openMemberSearchBottomSheet(8003);
                                  },
                                )
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Member Name is required";
                          }
                          return null;
                        },
                        onChanged: !_isEditMode
                            ? (value) {
                                _memberIdController.text = '';
                                ref
                                    .read(newReservationProvider.notifier)
                                    .resetState();
                              }
                            : null,
                      ),

                      if ((_isEditMode &&
                              _memberIdController.text.isNotEmpty &&
                              _memberNameController.text.isNotEmpty) ||
                          (newReservation.bmNumber != null &&
                              newReservation.guestName != null))
                        Column(
                          children: [
                            const SizedBox(height: 16.0),
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
                                              color: Colors.grey.shade400,
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
                                                        selectedGuest
                                                            .memImage2!,
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

                                      const SizedBox(width: 12),

                                      // Guest Name (M P) - Show gName or fallback to member name
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
                                                // Show gName if available, otherwise show member name
                                                if (selectedGuest?.gName !=
                                                        null &&
                                                    selectedGuest!
                                                        .gName!
                                                        .isNotEmpty)
                                                  Text(
                                                    "M P: ${selectedGuest.gName!}",
                                                    style: TextStyle(
                                                      fontSize:
                                                          fontSettings
                                                              .fontSize *
                                                          0.9,
                                                      fontWeight: fontSettings
                                                          .fontWeight,
                                                      color:
                                                          Colors.blue.shade700,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                  )
                                                else if (_memberNameController
                                                    .text
                                                    .isNotEmpty)
                                                  Text(
                                                    "M P: ${_memberNameController.text}",
                                                    style: TextStyle(
                                                      fontSize:
                                                          fontSettings
                                                              .fontSize *
                                                          0.9,
                                                      fontWeight: fontSettings
                                                          .fontWeight,
                                                      color:
                                                          Colors.blue.shade700,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                              selectedGuest!
                                                  .gRating!
                                                  .isNotEmpty &&
                                              ratingImageMap.containsKey(
                                                selectedGuest.gRating!
                                                    .toUpperCase(),
                                              )) {
                                            return Container(
                                              width: 80,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.grey.shade300,
                                                  width: 1,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.asset(
                                                  ratingImageMap[selectedGuest
                                                      .gRating!
                                                      .toUpperCase()]!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Container(
                                                          color: Colors
                                                              .grey
                                                              .shade200,
                                                          child: Icon(
                                                            Icons.star,
                                                            color:
                                                                _getRatingColor(
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
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: TextEditingController(text: value),
                                readOnly: true,
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Select Hotels & Rooms",
                                  labelStyle: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _hotelError != null
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: -5.0,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _hotelError != null
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _hotelError != null
                                          ? Colors.red
                                          : const Color.fromARGB(
                                              255,
                                              103,
                                              4,
                                              125,
                                            ),
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.arrow_drop_down),
                                    onPressed: () =>
                                        _openHotelAndRoomSelectorBottomSheet(
                                          context,
                                        ),
                                  ),
                                ),
                              ),
                              // Error message for hotel selection
                              if (_hotelError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12.0,
                                    top: 4.0,
                                  ),
                                  child: Text(
                                    _hotelError!,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: fontSettings.fontSize * 0.75,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                  ),
                                ),
                            ],
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
                                  fontSize: fontSettings.fontSize,
                                  color: Colors.grey.shade500,
                                  fontWeight: fontSettings.fontWeight,
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
                                              fontSize:
                                                  fontSettings.fontSize * 1.125,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: "Category: ",
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: hotel.roomCategoryName,
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    color: Colors.black,
                                                    fontWeight:
                                                        fontSettings.fontWeight,
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
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: hotel.roomTypeName,
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    color: Colors.black,
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
                                                  fontSize:
                                                      fontSettings.fontSize *
                                                      0.875,
                                                  fontWeight:
                                                      fontSettings.fontWeight,
                                                ),
                                              ),
                                              const SizedBox(width: 20),
                                              Text(
                                                "Nights: ${hotel.noOfNights}",
                                                style: TextStyle(
                                                  fontSize:
                                                      fontSettings.fontSize *
                                                      0.875,
                                                  fontWeight:
                                                      fontSettings.fontWeight,
                                                ),
                                              ),
                                              const SizedBox(width: 20),
                                              Text(
                                                "Rooms: ${hotel.roomCount}",
                                                style: TextStyle(
                                                  fontSize:
                                                      fontSettings.fontSize *
                                                      0.875,
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
                                              fontSize: fontSettings.fontSize,
                                              fontWeight: FontWeight.bold,
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
                        readOnly: true,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        decoration: InputDecoration(
                          labelText: "Arrival Date *",
                          labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: -5.0,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _selectArrivalDate(context),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Arrival Date is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _departureDateController,
                        readOnly: true,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        decoration: InputDecoration(
                          labelText: "Departure Date *",
                          labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: -5.0,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _selectDepartureDate(context),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Departure Date is required";
                          }
                          if (_arrivalDate != null &&
                              _departureDate != null &&
                              _departureDate!.isBefore(_arrivalDate!)) {
                            return "Departure must be after Arrival";
                          }
                          return null;
                        },
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
                          Text(
                            "Yes",
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                          ),
                          Radio<String>(
                            value: "No",
                            groupValue: _airTicketRequisition,
                            onChanged: (value) {
                              setState(() {
                                _airTicketRequisition = value!;
                              });
                            },
                          ),
                          Text(
                            "No",
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                          ),
                        ],
                      ),
                      if (_airTicketRequisition == "Yes")
                        Column(
                          children: [
                            const SizedBox(height: 10.0),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ValueListenableBuilder<String>(
                                  valueListenable: airTicketsNotifier,
                                  builder: (context, value, child) {
                                    return TextFormField(
                                      controller: TextEditingController(
                                        text: value,
                                      ),
                                      readOnly: true,
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: "Select Air Tickets",
                                        labelStyle: TextStyle(
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: fontSettings.fontWeight,
                                        ),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: _airTicketError != null
                                                ? Colors.red
                                                : Colors.grey,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12.0,
                                              vertical: -5.0,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: _airTicketError != null
                                                ? Colors.red
                                                : Colors.grey,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: _airTicketError != null
                                                ? Colors.red
                                                : Colors.blue,
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: const Icon(
                                            Icons.arrow_drop_down,
                                          ),
                                          onPressed: () =>
                                              _openAirTicketsSelectorScreen(
                                                context,
                                              ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Error message for air ticket selection
                                if (_airTicketError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12.0,
                                      top: 4.0,
                                    ),
                                    child: Text(
                                      _airTicketError!,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: fontSettings.fontSize * 0.75,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      if (_airTicketRequisition == "Yes")
                        Column(
                          children: [
                            const SizedBox(height: 16.0),
                            selectedFlights.isEmpty
                                ? Center(
                                    heightFactor: 6.0,
                                    child: Text(
                                      'No air tickets available.',
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
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
                          hintStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                            color: Colors.grey,
                          ),
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
                      const SizedBox(height: 10.0),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirmReservation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_isEditMode
                                ? Constants.kSecondaryColor
                                : Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.done, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                !_isEditMode
                                    ? "Confirm Reservation"
                                    : "Update Reservation",
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
}
