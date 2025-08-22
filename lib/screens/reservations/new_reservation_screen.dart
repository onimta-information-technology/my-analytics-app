import 'package:ballys_reservation_app/components/bottom_sheets/member_search_by_mid_bottom_sheet.dart';
import 'package:ballys_reservation_app/components/flight_card.dart';
import 'package:ballys_reservation_app/components/hotel_selection.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/repositories/hotel_repository.dart';
import 'package:ballys_reservation_app/data/repositories/reservation_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/models/reservation/new_reservation.dart';
import 'package:ballys_reservation_app/providers/hotels_provider.dart';
import 'package:ballys_reservation_app/providers/member_search_provider.dart';
import 'package:ballys_reservation_app/providers/new_reservation_provider.dart';
import 'package:ballys_reservation_app/providers/reservation_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider.dart';
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

  void _populateFields(Reservation selectedReservation) {
    _reservationNoController.text = selectedReservation.reservNo;
    _memberIdController.text = selectedReservation.mid;
    _memberNameController.text = selectedReservation.mName;
    _noOfNightsController.text = selectedReservation.noOfNights.toString();
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
    _arrivalDate = selectedReservation.arrDate;
    _arrivalDateController.text =
        dateFormat.format(selectedReservation.arrDate);
    _departureDate = selectedReservation.depDate;
    _departureDateController.text =
        dateFormat.format(selectedReservation.depDate);
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

  String getGuestAndRoomCounts(List<HotelDescip> hotels) {
    final totalGuests =
        hotels.fold<int>(0, (sum, hotel) => sum + hotel.guestCount!);
    final totalRooms =
        hotels.fold<int>(0, (sum, hotel) => sum + hotel.roomCount!);

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
    final totalGuests =
        flights.fold<int>(0, (sum, hotel) => sum + hotel.guestCount);
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
            HotelRepository(ApiService(const FlutterSecureStorage())));
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

  Future<void> _openMemberSearchBottomSheet(int iid) async {
    GuestRepository guestRepository =
        GuestRepository(ApiService(const FlutterSecureStorage()));

    String searchTerm = "";

    if (iid == 8002) {
      searchTerm = _memberIdController.text;
    } else {
      searchTerm = _memberNameController.text;
    }

    if (searchTerm.length < 3) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<GuestSearchResponse> guests =
          await guestRepository.searchGuest(iid, searchTerm);

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
          return MemberSearchBottomSheet(
            guests: guests,
          );
        },
      );
    } catch (e) {
      print("Error searching guests: $e");
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
        _arrivalDateController.text =
            '${_arrivalDate!.toLocal()}'.split(' ')[0];
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
        _departureDateController.text =
            '${_departureDate!.toLocal()}'.split(' ')[0];
      });
    }
  }

  void _confirmReservation() async {
    final selectedHotels = ref.watch(selectedHotelProvider);
    final selectedFlights = ref.watch(selectedFlightProvider);

    print(_arrivalDate);
    print(_departureDate);

    final resevation = NewReservation(
      bmNumber: _memberIdController.text,
      guestName: _memberNameController.text,
      hotelName: "",
      roomDetails: selectedHotels.map((room) => room.toJson()).toList(),
      noOfNights: 0,
      arrivalDate: _arrivalDate,
      departureDate: _departureDate,
      hasAirTicketReservation: _airTicketRequisition == "Yes" ? "1" : "0",
      remarks: _remarksController.text,
      airTicketDetails:
          selectedFlights.map((ticket) => ticket.toJson()).toList(),
    );

    if (_isEditMode) {
      resevation.reservationNo = _reservationNoController.text;
    }

    ReservationRepository reservationRepository =
        ReservationRepository(ApiService(const FlutterSecureStorage()));

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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: !_isEditMode ? Colors.white : Colors.green,
        foregroundColor: !_isEditMode ? Colors.black : Colors.white,
        title: Text(!_isEditMode ? "New Reservation" : "Update Reservation",
            style: const TextStyle(fontSize: 18)),
      ),
      body: PopScope(
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
                        decoration: const InputDecoration(
                          labelText: "Reservation No",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],
                    if (newReservation.bmNumber != null)
                      const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            keyboardType:
                                const TextInputType.numberWithOptions(),
                            autofocus: false,
                            controller: _memberIdController,
                            decoration: InputDecoration(
                              labelText: "Member ID",
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  _openMemberSearchBottomSheet(8002);
                                },
                              ),
                            ),
                            onChanged: (value) {
                              _memberNameController.text = '';
                              ref
                                  .read(newReservationProvider.notifier)
                                  .resetState();
                            },
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        ElevatedButton.icon(
                          onPressed: newReservation.bmNumber == null
                              ? null
                              : () {
                                  context.push('/home/profile');
                                },
                          icon: const Icon(Icons.person),
                          label: const Text("Guest Details"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: newReservation.bmNumber == null
                                ? Colors.grey.shade400
                                : const Color.fromARGB(255, 70, 70, 70),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      autofocus: false,
                      controller: _memberNameController,
                      decoration: InputDecoration(
                        labelText: "Member Name",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            FocusScope.of(context).requestFocus(FocusNode());
                            _openMemberSearchBottomSheet(8003);
                          },
                        ),
                      ),
                      onChanged: (value) {
                        _memberIdController.text = '';
                        ref.read(newReservationProvider.notifier).resetState();
                      },
                    ),
                    const SizedBox(height: 16.0),
                    ValueListenableBuilder<String>(
                      valueListenable: hotelRoomNotifier,
                      builder: (context, value, child) {
                        return TextFormField(
                          controller: TextEditingController(text: value),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Select Hotels & Rooms",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_drop_down),
                              onPressed: () =>
                                  _openHotelAndRoomSelectorBottomSheet(context),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16.0),
                    selectedHotels.isEmpty
                        ? Center(
                            heightFactor: 3.0,
                            child: Text(
                              'No hotels selected.',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade500),
                            ),
                          )
                        : Column(
                            children: selectedHotels.map((hotel) {
                              return SizedBox(
                                width: double.infinity,
                                child: Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hotel.hotelName!,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: "Category: ",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              TextSpan(
                                                text: hotel.roomCategoryName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: "Room Type: ",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              TextSpan(
                                                text: hotel.roomTypeName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.normal,
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
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(width: 20),
                                            Text(
                                              "Nights: ${hotel.noOfNights}",
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(width: 20),
                                            Text(
                                              "Rooms: ${hotel.roomCount}",
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Estimated Cost: ${hotel.selectedCost}",
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 16.0),
                    // TextFormField(
                    //   autofocus: false,
                    //   readOnly: true,
                    //   controller: _noOfNightsController,
                    //   decoration: const InputDecoration(
                    //     labelText: "No. Of Nights",
                    //     border: OutlineInputBorder(),
                    //   ),
                    // ),
                    // const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _arrivalDateController,
                      readOnly:
                          true, // Make it read-only so the user cannot manually type
                      decoration: InputDecoration(
                        labelText: "Arrival Date",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectArrivalDate(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _departureDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Departure Date",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDepartureDate(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        "Air Ticket Requisition",
                        style: TextStyle(fontSize: 16),
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
                        const Text(
                          "Yes",
                          style: TextStyle(fontSize: 16),
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
                        const Text(
                          "No",
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    // Text(
                    //     'Selected Air Ticket Requisition: $_airTicketRequisition'),
                    if (_airTicketRequisition == "Yes")
                      Column(
                        children: [
                          const SizedBox(height: 16.0),
                          ValueListenableBuilder<String>(
                            valueListenable: airTicketsNotifier,
                            builder: (context, value, child) {
                              return TextFormField(
                                controller: TextEditingController(text: value),
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: "Select Air Tickets",
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.arrow_drop_down),
                                    onPressed: () =>
                                        _openAirTicketsSelectorScreen(context),
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
                          const SizedBox(height: 16.0),
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
                                      final index =
                                          selectedFlights.indexOf(flight);
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
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _remarksController,
                      decoration: InputDecoration(
                        alignLabelWithHint: true,
                        labelText: "Remarks",
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
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
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
                        Constants.kSecondaryColor),
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
