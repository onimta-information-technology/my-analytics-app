import 'package:ballys_reservation_app/components/flight_card.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/providers/hotels_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider.dart';
import 'package:ballys_reservation_app/providers/selected_reservation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    _getHotels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
      final selectedReservation = ref.watch(selectedReservationProvider);
      ref.read(selectedHotelProvider.notifier).setHotels(
          selectedReservation != null ? selectedReservation.hotelDescip : []);
      ref.read(selectedFlightProvider.notifier).setFlights(
          selectedReservation != null
              ? selectedReservation.airticketDescrip
              : []);
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
      _arrivalDateController.text =
          dateFormat.format(selectedReservation.arrDate);
      _departureDateController.text =
          dateFormat.format(selectedReservation.depDate);
      _airTicketRequisition =
          selectedReservation.airticketReservationStatus == "T" ? "Yes" : "No";
      _remarksController.text = selectedReservation.remarks;
    }

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
                  context.go(
                    "/reservations/new-reservation",
                  );
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
                    decoration: const InputDecoration(
                      labelText: "Reservation No",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(),
                    autofocus: false,
                    readOnly: true,
                    controller: _memberIdController,
                    decoration: const InputDecoration(
                      labelText: "Member ID",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    autofocus: false,
                    readOnly: true,
                    controller: _memberNameController,
                    decoration: const InputDecoration(
                      labelText: "Member Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  ValueListenableBuilder<String>(
                    valueListenable: hotelRoomNotifier,
                    builder: (context, value, child) {
                      return TextFormField(
                        controller: TextEditingController(text: value),
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "Select Hotels & Rooms",
                          border: OutlineInputBorder(),
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
                  TextFormField(
                    controller: _arrivalDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Arrival Date",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _departureDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Departure Date",
                      border: OutlineInputBorder(),
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
                              decoration: const InputDecoration(
                                labelText: "Select Air Tickets",
                                border: OutlineInputBorder(),
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
                    readOnly: true,
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
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 10.0,
                      ),
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
                                      fontWeight: FontWeight.bold),
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
           const Watermark(),
        ],
      ),
    );
  }
}
