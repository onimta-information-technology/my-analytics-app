import 'dart:convert';

import 'package:ballys_reservation_app/components/bottom_sheets/member_search-new_sheet.dart';
import 'package:ballys_reservation_app/components/bottom_sheets/member_search_by_mid_bottom_sheet.dart';
import 'package:ballys_reservation_app/components/flight_card.dart';
import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/components/guest_details_card.dart';
import 'package:ballys_reservation_app/components/hotel_selection.dart';
import 'package:ballys_reservation_app/components/package_amount_field.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/repositories/hotel_repository.dart';
import 'package:ballys_reservation_app/data/repositories/reservation_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_reservation_entry.dart';
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
import 'package:ballys_reservation_app/components/passport_upload_widget.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/selected_passport_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider.dart';
import 'package:ballys_reservation_app/providers/selected_reservation_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/cupertino.dart';
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

class _NewReservationScreenState extends ConsumerState<NewReservationScreen>
    with ConnectivityMixin {
  final TextEditingController _reservationNoController =
      TextEditingController();
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();

  final ValueNotifier<String> hotelRoomNotifier = ValueNotifier<String>("");
  final ValueNotifier<String> airTicketsNotifier = ValueNotifier<String>("");

  bool _isLoading = false;
  String _selectedPrefix = "BM";
  final TextEditingController _memberIdNumberController =
      TextEditingController();

  final TextEditingController _noOfNightsController = TextEditingController();
  final TextEditingController _arrivalDateController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _reservationnewnumberController =
      TextEditingController();
        final TextEditingController _packageAmountController =
      TextEditingController();

  DateTime? _arrivalDate;
  DateTime? _departureDate;
  String _airTicketRequisition = "No";
  bool _isEditMode = false;
  final _formKey = GlobalKey<FormState>();
  bool hasError = false;
  String? _hotelError;
  String? _airTicketError;
  bool _isNumericOnlyLocation = false;
  List<String> _prefixes = ["BM", "BL", "BN"];

  // ── Multi-guest support ───────────────────────────────────────────────
  // Guests already "added" to this single reservation. They all share one
  // reservationNo but each carries its own hotel(s) / flight(s) / dates.
  final List<GuestReservationEntry> _guestEntries = [];
  // Set when the user double-taps an added guest card to edit it; tells us
  // which index in _guestEntries to replace (instead of appending) on the
  // next Add Guest / Add New Guest tap.
  int? _editingGuestIndex;

  @override
  void initState() {
    super.initState();
    _getHotels();
    _loadLocationPrefix();
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

  Future<void> _loadLocationPrefix() async {
    final location = await StorageUtil.getCurrentLocation();
    if (location != null) {
      final code = location.code.split('_').first; // "BELLAGIO"
      final isNumeric = code == "BELLAGIO";
      setState(() {
        _isNumericOnlyLocation = isNumeric;
        _prefixes = isNumeric ? [] : ["BM", "BL", "BN"];
        _selectedPrefix = isNumeric ? "" : "BM";
      });
    }
  }

  @override
  void dispose() {
    _reservationNoController.dispose();
    _memberIdController.dispose();
    _memberNameController.dispose();
    _memberIdNumberController.dispose();
    _noOfNightsController.dispose();
    _arrivalDateController.dispose();
    _departureDateController.dispose();
    _remarksController.dispose();
    hotelRoomNotifier.dispose();
    airTicketsNotifier.dispose();
    _reservationnewnumberController.dispose();
    super.dispose();
  }

  void _updateMemberIdFields(String fullMemberId) {
    if (fullMemberId.isNotEmpty) {
      if (_isNumericOnlyLocation) {
        setState(() {
          _memberIdNumberController.text = fullMemberId;
          _memberIdController.text = fullMemberId;
        });
        return;
      }
      String prefix = 'BM';
      String numberPart = fullMemberId;

      if (fullMemberId.startsWith('BM')) {
        prefix = 'BM';
        numberPart = fullMemberId.substring(2);
      } else if (fullMemberId.startsWith('BL')) {
        prefix = 'BL';
        numberPart = fullMemberId.substring(2);
      } else if (fullMemberId.startsWith('BN')) {
        prefix = 'BN';
        numberPart = fullMemberId.substring(2);
      }

      setState(() {
        _selectedPrefix = prefix;
        _memberIdNumberController.text = numberPart;
        _memberIdController.text = fullMemberId;
      });
    }
  }

  Future<void> _loadGuestDataInEditMode() async {
    if (!_isEditMode || _memberIdController.text.isEmpty) return;

    final currentSelectedGuest = ref.read(selectedGuestProvider);
    if (currentSelectedGuest != null &&
        currentSelectedGuest.mid == _memberIdController.text) {
      return;
    }

    try {
      setState(() => _isLoading = true);

      GuestRepository guestRepository = GuestRepository(
        ApiService(const FlutterSecureStorage()),
      );

      List<GuestSearchResponse> guests = await guestRepository.searchGuest(
        9021,
        _memberIdController.text,
      );

      if (guests.isNotEmpty) {
        final guestResponse = guests.first;
        ref.read(selectedGuestProvider.notifier).setSelectedGuest(
              Guest(
                mid: guestResponse.mid ?? _memberIdController.text,
                memberName:
                    guestResponse.mName ?? _memberNameController.text,
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
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
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

    final String status = selectedReservation.airticketReservationStatus
        .toString()
        .toUpperCase()
        .trim();
    final bool hasAirTickets = status == "T" ||
        status == "TRUE" ||
        status == "YES" ||
        status == "Y" ||
        status == "1";

    _airTicketRequisition = hasAirTickets ? "Yes" : "No";
    _remarksController.text = selectedReservation.remarks;
    _reservationnewnumberController.text =
        selectedReservation.reservationnewnumber ?? '';
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

    final guestTxt =
        totalGuests == 1 ? "$totalGuests GUEST" : "$totalGuests GUESTS";
    final roomTxt =
        totalRooms == 1 ? "$totalRooms ROOM" : "$totalRooms ROOMS";
    return "$guestTxt, $roomTxt";
  }

  String getGuestAndTicketCounts(List<FlightBooking> flights) {
    final totalGuests = flights.fold<int>(0, (sum, f) => sum + f.guestCount);
    final totalTickets = flights.length;

    final guestTxt =
        totalGuests == 1 ? "$totalGuests GUEST" : "$totalGuests GUESTS";
    final ticketTxt =
        totalTickets == 1 ? "$totalTickets TICKET" : "$totalTickets TICKETS";
    return "$guestTxt, $ticketTxt";
  }

  // ── Key fix: isDismissible: false + enableDrag: false so that
  //    dropdown dialog dismissal does NOT close the bottom sheet.
  void _openHotelAndRoomSelectorBottomSheet(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // ← prevents tap-outside close
      enableDrag: false, // ← prevents swipe-down close
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return HotelAndRoomSelectionBottomSheet(
          HotelRepository(ApiService(const FlutterSecureStorage())),
          onClose: () => Navigator.pop(context), // ← X button callback
        );
      },
    );
  }

  void _openAirTicketsSelectorScreen(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());
    context.push(
      "/reservationMain/reservations/new-reservation/air-tickets-selection",
      extra: {
        'arrivalDate': _arrivalDateController.text,
        'departureDate': _departureDateController.text,
      },
    );
  }

  bool _canChangeAirTicketToNo() {
    if (_isEditMode) {
      final selectedFlights = ref.watch(selectedFlightProvider);
      return selectedFlights.isEmpty;
    }
    return true;
  }

  Future<void> _openMemberSearchBottomSheet(int iid) async {
    GuestRepository guestRepository = GuestRepository(
      ApiService(const FlutterSecureStorage()),
    );

    String searchTerm =
        iid == 8002 ? _memberIdController.text : _memberNameController.text;

    if (searchTerm.length < 3) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext context) {
          return MemberNewSearchBottomSheet(
            guests: [],
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

    setState(() => _isLoading = true);

    try {
      List<GuestSearchResponse> guests =
          await guestRepository.searchGuest(iid, searchTerm);

      setState(() => _isLoading = false);

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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performGuestSearch(String searchTerm, int iid) async {
    if (searchTerm.length < 3) return;

    GuestRepository guestRepository = GuestRepository(
      ApiService(const FlutterSecureStorage()),
    );

    try {
      List<GuestSearchResponse> guests =
          await guestRepository.searchGuest(iid, searchTerm);

      Navigator.of(context).pop();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching guests: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _validateUpdateFields() {
    setState(() {
      _hotelError = null;
      _airTicketError = null;
      hasError = false;
    });

    if (_arrivalDate != null && _departureDate != null) {
      if (_departureDate!.isBefore(_arrivalDate!) ||
          _departureDate!.isAtSameMomentAs(_arrivalDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Departure date must be after arrival date'),
            backgroundColor: Colors.red,
          ),
        );
        hasError = true;
      }
    }

    final selectedHotels = ref.watch(selectedHotelProvider);
    final selectedFlights = ref.watch(selectedFlightProvider);

    if (selectedHotels.isEmpty && selectedFlights.isEmpty) {
      setState(
          () => _hotelError = "Please select at least one hotel or flight");
      hasError = true;
    }

    if (_airTicketRequisition == "Yes" && selectedFlights.isEmpty) {
      setState(() => _airTicketError =
          "Please select at least one flight when air ticket requisition is 'Yes'");
      hasError = true;
    }

    if (selectedFlights.isNotEmpty &&
        _arrivalDate != null &&
        _departureDate != null) {
      for (var flight in selectedFlights) {
        if (flight.departureDate != null) {
          DateTime flightDate =
              DateTime.parse(flight.departureDate.toString());
          if (flightDate.isBefore(_arrivalDate!) ||
              flightDate.isAfter(_departureDate!)) {
            setState(() => _airTicketError =
                "Flight dates must be within the reservation period");
            hasError = true;
            break;
          }
        }
      }
    }

    if (_isEditMode && _airTicketRequisition == "No") {
      if (selectedFlights.isNotEmpty) {
        setState(() => _airTicketError =
            "Cannot set to 'No' when flights are already booked. Please remove flights first.");
        hasError = true;
      }
    }

    return !hasError;
  }

  Future<void> _selectArrivalDate(BuildContext context) async {
    DateTime selectedDate = _arrivalDate ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Select Arrival Date",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                minimumDate: DateTime(2000),
                maximumDate: DateTime(2101),
                onDateTimeChanged: (DateTime newDate) {
                  selectedDate = newDate;
                },
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _arrivalDate = selectedDate;
                    _arrivalDateController.text =
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                    // Reset departure when arrival changes
                    _departureDate = null;
                    _departureDateController.clear();
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                "Confirm",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Future<void> _selectDepartureDate(BuildContext context) async {
    DateTime selectedDate = _departureDate ?? _arrivalDate ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Select Departure Date",
                style: TextStyle(
                  fontSize: 20,
                  color: const Color.fromARGB(255, 0, 0, 0),
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                minimumDate: _arrivalDate ?? DateTime(2000),
                maximumDate: DateTime(2101),
                onDateTimeChanged: (DateTime newDate) {
                  selectedDate = newDate;
                },
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () {
                // Validate departure is after arrival
                if (_arrivalDate != null &&
                    !selectedDate.isAfter(_arrivalDate!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Departure date must be after arrival date',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (mounted) {
                  setState(() {
                    _departureDate = selectedDate;
                    _departureDateController.text =
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                "Confirm",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // ── Multi-guest helpers ─────────────────────────────────────────────

  /// Validates that the CURRENT on-screen guest has at minimum a Member ID,
  /// Member Name, and at least one hotel or flight selected — the minimum
  /// needed to be worth saving as a guest-entry row.
  bool _validateCurrentGuestForAdd() {
    if (_memberIdController.text.trim().isEmpty ||
        _memberNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Member ID and Name first'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final selectedHotels = ref.read(selectedHotelProvider);
    final selectedFlights = ref.read(selectedFlightProvider);
    if (selectedHotels.isEmpty && selectedFlights.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one hotel or flight'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_arrivalDate == null || _departureDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Arrival and Departure dates'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  /// Snapshots the guest currently on screen into a GuestReservationEntry.
  GuestReservationEntry _snapshotCurrentGuest() {
    final selectedHotels = ref.read(selectedHotelProvider);
    final selectedFlights = ref.read(selectedFlightProvider);
    final selectedPassports = ref.read(selectedPassportProvider);

    return GuestReservationEntry(
      mid: _memberIdController.text.trim(),
      guestName: _memberNameController.text.trim(),
      hotels: List<HotelDescip>.from(selectedHotels),
      flights: List<FlightBooking>.from(selectedFlights),
      arrivalDate: _arrivalDate,
      departureDate: _departureDate,
      remarks: _remarksController.text,
      airTicketRequisition: _airTicketRequisition,
      passportImages: selectedPassports
          .map((f) => PassportImage(
                path: f.path,
                fileName: f.fileName,
                isPdf: f.isPdf,
              ))
          .toList(),
    );
  }

  /// "Add Guest" — same hotel/flight/dates carried forward.
  /// Saves current guest into the list, clears ONLY Member ID + Name
  /// (and the linked selected-guest provider) so the next guest can be
  /// searched for, while hotel/flight/dates/remarks stay as-is.
  void _onAddGuest() {
    if (!_validateCurrentGuestForAdd()) return;

    final entry = _snapshotCurrentGuest();

    setState(() {
      if (_editingGuestIndex != null) {
        _guestEntries[_editingGuestIndex!] = entry;
        _editingGuestIndex = null;
      } else {
        _guestEntries.add(entry);
      }

      // Clear only guest identity fields.
      _memberIdController.clear();
      _memberIdNumberController.clear();
      _memberNameController.clear();
    });

    ref.read(selectedGuestProvider.notifier).clearGuest();
    ref.read(selectedPassportProvider.notifier).setFiles([]);
    ref.read(newReservationProvider.notifier).resetState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.guestName} added. Search next guest.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// "Add New Guest" — different hotel/flight/dates for the next guest.
  /// Saves current guest into the list, clears Member ID + Name AND
  /// hotel/flight selections AND dates, so the next guest starts fresh.
  void _onAddNewGuest() {
    if (!_validateCurrentGuestForAdd()) return;

    final entry = _snapshotCurrentGuest();

    setState(() {
      if (_editingGuestIndex != null) {
        _guestEntries[_editingGuestIndex!] = entry;
        _editingGuestIndex = null;
      } else {
        _guestEntries.add(entry);
      }

      // Clear guest identity fields.
      _memberIdController.clear();
      _memberIdNumberController.clear();
      _memberNameController.clear();

      // Clear hotel/flight/date selections for a completely fresh guest.
      _arrivalDate = null;
      _departureDate = null;
      _arrivalDateController.clear();
      _departureDateController.clear();
      _remarksController.clear();
      _airTicketRequisition = "No";
    });

    ref.read(selectedHotelProvider.notifier).setHotels([]);
    ref.read(selectedFlightProvider.notifier).setFlights([]);
    ref.read(selectedPassportProvider.notifier).setFiles([]);
    ref.read(selectedGuestProvider.notifier).clearGuest();
    ref.read(newReservationProvider.notifier).resetState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.guestName} added. Start next guest.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Loads an already-added guest's data back into the form for editing,
  /// removing it from the list (it will be re-added on the next
  /// Add Guest / Add New Guest tap, or discarded if the user navigates away).
  void _editGuestEntry(int index) {
    final entry = _guestEntries[index];

    setState(() {
      _editingGuestIndex = index;
      _memberIdController.text = entry.mid;
      _memberNameController.text = entry.guestName;
      _updateMemberIdFields(entry.mid);

      _arrivalDate = entry.arrivalDate;
      _departureDate = entry.departureDate;
      if (entry.arrivalDate != null) {
        _arrivalDateController.text =
            DateFormat('yyyy-MM-dd').format(entry.arrivalDate!);
      }
      if (entry.departureDate != null) {
        _departureDateController.text =
            DateFormat('yyyy-MM-dd').format(entry.departureDate!);
      }
      _remarksController.text = entry.remarks;
      _airTicketRequisition = entry.airTicketRequisition;
    });

    ref.read(selectedHotelProvider.notifier).setHotels(entry.hotels);
    ref.read(selectedFlightProvider.notifier).setFlights(entry.flights);
    ref.read(selectedPassportProvider.notifier).setFiles(
          entry.passportImages
              .map((p) => PassportFile(
                    path: p.path,
                    fileName: p.fileName,
                    isPdf: p.isPdf,
                  ))
              .toList(),
        );
  }

  void _removeGuestEntry(int index) {
    setState(() {
      _guestEntries.removeAt(index);
      if (_editingGuestIndex == index) {
        _editingGuestIndex = null;
      }
    });
  }

  String _summarizeGuestEntry(GuestReservationEntry entry) {
    final hotelCount = entry.hotels.length;
    final flightCount = entry.flights.length;
    final parts = <String>[];
    if (hotelCount > 0) {
      parts.add(hotelCount == 1 ? "1 Hotel" : "$hotelCount Hotels");
    }
    if (flightCount > 0) {
      parts.add(flightCount == 1 ? "1 Flight" : "$flightCount Flights");
    }
    if (parts.isEmpty) parts.add("No hotel/flight");
    return parts.join(", ");
  }

  void _confirmReservation() async {
    if (_isEditMode) {
      if (!_validateUpdateFields()) return;
    } else {
      // In multi-guest mode, the form-level validator on Member ID/Name
      // only applies to whatever guest is currently on screen. If there
      // are already-added guests and the current fields are empty, that's
      // fine — it just means the user finished adding guests and is ready
      // to submit without a "dangling" extra guest.
      final hasDanglingGuestFields =
          _memberIdController.text.trim().isNotEmpty ||
              _memberNameController.text.trim().isNotEmpty;

      if (_guestEntries.isEmpty || hasDanglingGuestFields) {
        if (!_formKey.currentState!.validate()) return;
        if (!_validateUpdateFields()) return;
      }
    }

    final selectedHotels = ref.read(selectedHotelProvider);
    final selectedFlights = ref.read(selectedFlightProvider);

    setState(() {
      _hotelError = null;
      _airTicketError = null;
      hasError = false;
    });

    // Build the final list of guests for this single reservation.
    final List<GuestReservationEntry> allGuests =
        List<GuestReservationEntry>.from(_guestEntries);

    final bool currentGuestHasData =
        _memberIdController.text.trim().isNotEmpty &&
            _memberNameController.text.trim().isNotEmpty;

    if (currentGuestHasData) {
      // Auto-append whatever is currently on screen as the final guest.
      if (selectedHotels.isEmpty && selectedFlights.isEmpty) {
        setState(() =>
            _hotelError = "Please select at least one hotel or flight");
        hasError = true;
      }
      if (_airTicketRequisition == "Yes" && selectedFlights.isEmpty) {
        setState(
            () => _airTicketError = "Please select at least one flight");
        hasError = true;
      }
      if (hasError) return;

      allGuests.add(_snapshotCurrentGuest());
    }

    if (allGuests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one guest'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // The top-level bmNumber/guestName/dates mirror the FIRST guest for
    // backward compatibility. roomDetails/airTicketDetails/passportImages span
    // ALL guests, each item tagged with its owner's BMNumber. The lightweight
    // per-guest payload travels in `guests`.
    final firstGuest = allGuests.first;

    final reservation = NewReservation(
      bmNumber: firstGuest.mid,
      guestName: firstGuest.guestName,
      hotelName: "",
      roomDetails:
          allGuests.expand((g) => g.toRoomDetailsJson()).toList(),
      noOfNights: 0,
      arrivalDate: firstGuest.arrivalDate,
      departureDate: firstGuest.departureDate,
      hasAirTicketReservation: firstGuest.airTicketRequisition == "Yes"
          ? "1"
          : "0",
      remarks: firstGuest.remarks,
      airTicketDetails:
          allGuests.expand((g) => g.toAirTicketDetailsJson()).toList(),
      reservationnewnumber: _reservationnewnumberController.text,
      packageAmount: _packageAmountController.text,
      guests: allGuests.map((g) => g.toJson()).toList(),
      passportImages: allGuests
          .expand((g) => g.toPassportImagesJson())
          .toList(),
    );

    if (_isEditMode) {
      reservation.reservationNo = _reservationNoController.text;
    }

    ReservationRepository reservationRepository = ReservationRepository(
      ApiService(const FlutterSecureStorage()),
    );

    setState(() => _isLoading = true);

    try {
      Reservation? response = !_isEditMode
          ? await reservationRepository.saveReservation(reservation)
          : await reservationRepository.updateReservation(reservation);

      if (response != null) {
        ref.read(reservationProvider.notifier).addReservationToPending(response);
      }

      // Clear all form fields
      setState(() {
        _isLoading = false;
        _memberIdController.clear();
        _memberIdNumberController.clear();
        _memberNameController.clear();
        _noOfNightsController.clear();
        _arrivalDateController.clear();
        _departureDateController.clear();
        _remarksController.clear();
        _reservationnewnumberController.clear();
        _packageAmountController.clear();
        _reservationNoController.clear();
        _arrivalDate = null;
        _departureDate = null;
        _airTicketRequisition = 'No';
        _guestEntries.clear();
        _editingGuestIndex = null;
        _hotelError = null;
        _airTicketError = null;
        hasError = false;
      });

      // Clear all provider state
      ref.read(selectedHotelProvider.notifier).setHotels([]);
      ref.read(selectedFlightProvider.notifier).setFlights([]);
      ref.read(selectedPassportProvider.notifier).setFiles([]);
      ref.read(selectedGuestProvider.notifier).clearGuest();
      ref.read(newReservationProvider.notifier).resetState();
      ref.read(memberSearchProvider.notifier).resetState();
      ref.read(selectedReservationProvider.notifier).clearSelectedReservation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToProfile() async {
    try {
      final currentSelectedGuest = ref.read(selectedGuestProvider);
      if (currentSelectedGuest != null &&
          currentSelectedGuest.mid == _memberIdController.text) {
        context.push('/home/profile');
        return;
      }

      setState(() => _isLoading = true);

      GuestRepository guestRepository = GuestRepository(
        ApiService(const FlutterSecureStorage()),
      );

      List<GuestSearchResponse> guests =
          await guestRepository.searchGuest(9021, _memberIdController.text);

      setState(() => _isLoading = false);

      Guest guest;
      if (guests.isNotEmpty) {
        final g = guests.first;
        guest = Guest(
          mid: g.mid ?? _memberIdController.text,
          memberName: g.mName ?? _memberNameController.text,
          country: "",
          lastVisitDate: g.lvd?.toString() ?? "",
          gift: "",
          age: 0,
          gRating: g.gRating ?? "",
          mGroup: "",
          gName: g.gName ?? "",
          memImage2: g.memImage2,
        );
      } else {
        guest = Guest(
          mid: _memberIdController.text,
          memberName: _memberNameController.text,
          country: "",
          lastVisitDate: "1990-01-01",
          gift: "",
          age: 0,
          gRating: "",
          mGroup: "",
          gName: "",
        );
      }

      ref.read(selectedGuestProvider.notifier).setSelectedGuest(guest);
      context.push('/home/profile');
    } catch (e) {
      setState(() => _isLoading = false);
      ref.read(selectedGuestProvider.notifier).setSelectedGuest(
            Guest(
              mid: _memberIdController.text,
              memberName: _memberNameController.text,
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

  @override
  Widget build(BuildContext context) {
    final selectedHotels = ref.watch(selectedHotelProvider);
    hotelRoomNotifier.value = getGuestAndRoomCounts(selectedHotels);

    final selectedFlights = ref.watch(selectedFlightProvider);
    airTicketsNotifier.value = getGuestAndTicketCounts(selectedFlights);

    final newReservation = ref.watch(newReservationProvider);
    if (newReservation.bmNumber != null &&
        (_memberIdController.text != newReservation.bmNumber ||
            _memberNameController.text != (newReservation.guestName ?? ''))) {
      _memberIdController.text = newReservation.bmNumber!;
      _memberNameController.text = newReservation.guestName ?? '';
      _updateMemberIdFields(newReservation.bmNumber!);
    }

    final fontSettings = ref.watch(fontSettingsProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
              ref.read(newReservationProvider.notifier).resetState();
              ref.read(memberSearchProvider.notifier).resetState();
              ref
                  .read(selectedReservationProvider.notifier)
                  .clearSelectedReservation();
              ref.read(selectedHotelProvider.notifier).setHotels([]);
              ref.read(selectedFlightProvider.notifier).setFlights([]);
              ref.read(selectedPassportProvider.notifier).setFiles([]);
            },
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // ── Reservation No (edit mode only) ────
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

                        // ── Already-added guests banner ────────
                        // if (_guestEntries.isNotEmpty) ...[
                        //   Align(
                        //     alignment: Alignment.topLeft,
                        //     child: Text(
                        //       "Guests added: ${_guestEntries.length}"
                        //       "${_editingGuestIndex != null ? ' (editing #${_editingGuestIndex! + 1})' : ''}",
                        //       style: TextStyle(
                        //         fontSize: fontSettings.fontSize,
                        //         fontWeight: FontWeight.bold,
                        //         color: Constants.kSecondaryColor,
                        //       ),
                        //     ),
                        //   ),
                        //   const SizedBox(height: 8.0),
                        //   Column(
                        //     children:
                        //         _guestEntries.asMap().entries.map((mapEntry) {
                        //       final i = mapEntry.key;
                        //       final g = mapEntry.value;
                        //       return Card(
                        //         color: const Color.fromARGB(
                        //             255, 235, 245, 233),
                        //         margin: const EdgeInsets.symmetric(
                        //           horizontal: 3,
                        //           vertical: 6,
                        //         ),
                        //         child: ListTile(
                        //           leading: CircleAvatar(
                        //             backgroundColor:
                        //                 Constants.kSecondaryColor,
                        //             foregroundColor: Colors.white,
                        //             child: Text("${i + 1}"),
                        //           ),
                        //           title: Text(
                        //             g.guestName,
                        //             style: TextStyle(
                        //               fontWeight: FontWeight.bold,
                        //               fontSize: fontSettings.fontSize,
                        //             ),
                        //           ),
                        //           subtitle: Text(
                        //             "${g.mid}\n${_summarizeGuestEntry(g)}"
                        //             "${g.arrivalDate != null && g.departureDate != null ? '\n${DateFormat('yyyy-MM-dd').format(g.arrivalDate!)} → ${DateFormat('yyyy-MM-dd').format(g.departureDate!)}' : ''}",
                        //             style: TextStyle(
                        //               fontSize:
                        //                   fontSettings.fontSize * 0.85,
                        //             ),
                        //           ),
                        //           isThreeLine: true,
                        //           trailing: Row(
                        //             mainAxisSize: MainAxisSize.min,
                        //             children: [
                        //               IconButton(
                        //                 icon: const Icon(Icons.edit,
                        //                     color: Colors.blue),
                        //                 onPressed: () => _editGuestEntry(i),
                        //               ),
                        //               IconButton(
                        //                 icon: const Icon(Icons.delete,
                        //                     color: Colors.red),
                        //                 onPressed: () => _removeGuestEntry(i),
                        //               ),
                        //             ],
                        //           ),
                        //         ),
                        //       );
                        //     }).toList(),
                        //   ),
                        //   const SizedBox(height: 16.0),
                        // ],
 if (_guestEntries.isNotEmpty) ...[
                          // Align(
                          //   alignment: Alignment.topLeft,
                          //   child: Text(
                          //     "Guests added: ${_guestEntries.length}"
                          //     "${_editingGuestIndex != null ? ' (editing #${_editingGuestIndex! + 1})' : ''}",
                          //     style: TextStyle(
                          //       fontSize: fontSettings.fontSize,
                          //       fontWeight: FontWeight.bold,
                          //       color: Constants.kSecondaryColor,
                          //     ),
                          //   ),
                          // ),
                        //  const SizedBox(height: 8.0),
                          Column(
                            children:
                                _guestEntries.asMap().entries.map((mapEntry) {
                              final i = mapEntry.key;
                              final g = mapEntry.value;
                              return Card(
                                color: const Color.fromARGB(
                                    255, 235, 245, 233),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 6,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5.0,
                                    horizontal: 8.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ── Left column: number, edit, delete (stacked) ──
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                Constants.kSecondaryColor,
                                            foregroundColor: Colors.white,
                                            child: Text("${i + 1}"),
                                          ),
                                          const SizedBox(height: 2),
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () =>
                                                _editGuestEntry(i),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                          const SizedBox(height: 2),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _removeGuestEntry(i),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                      // ── Right side: guest details ──
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              g.guestName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize:
                                                    fontSettings.fontSize,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${g.mid}\n${_summarizeGuestEntry(g)}"
                                              "${g.arrivalDate != null && g.departureDate != null ? '\n${DateFormat('yyyy-MM-dd').format(g.arrivalDate!)} → ${DateFormat('yyyy-MM-dd').format(g.departureDate!)}' : ''}",
                                              style: TextStyle(
                                                fontSize: fontSettings
                                                        .fontSize*0.90,
                                                fontWeight: fontSettings.fontWeight
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8.0),
                        ],
                        // ── MID + Profile Button ───────────────
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
                                          fontWeight:
                                              fontSettings.fontWeight,
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
                                          fontWeight:
                                              fontSettings.fontWeight,
                                        ),
                                        border: const OutlineInputBorder(),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: -5.0,
                                        ),
                                        prefixIcon: _isNumericOnlyLocation
                                            ? null
                                            : Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                  left: 12,
                                                  right: 4,
                                                ),
                                                child:
                                                    DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    value: _selectedPrefix,
                                                    style: TextStyle(
                                                      fontSize: fontSettings
                                                          .fontSize,
                                                      fontWeight: fontSettings
                                                          .fontWeight,
                                                      color: Colors.black,
                                                    ),
                                                    items: _prefixes
                                                        .map((prefix) {
                                                      return DropdownMenuItem(
                                                        value: prefix,
                                                        child: Text(
                                                          prefix,
                                                          style: TextStyle(
                                                            fontSize:
                                                                fontSettings
                                                                    .fontSize,
                                                            fontWeight:
                                                                fontSettings
                                                                    .fontWeight,
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: (value) {
                                                      setState(() =>
                                                          _selectedPrefix =
                                                              value!);
                                                    },
                                                  ),
                                                ),
                                              ),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.search),
                                          onPressed: () {
                                            FocusScope.of(context).unfocus();
                                            _memberIdController.text =
                                                _isNumericOnlyLocation
                                                    ? _memberIdNumberController
                                                        .text
                                                    : '$_selectedPrefix${_memberIdNumberController.text}';
                                            _openMemberSearchBottomSheet(
                                                8002);
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        // Skip the "required" check when the
                                        // user has already added other
                                        // guests and intentionally left the
                                        // current fields blank to submit.
                                        if (_guestEntries.isNotEmpty &&
                                            (value == null ||
                                                value.trim().isEmpty) &&
                                            _memberNameController.text
                                                .trim()
                                                .isEmpty) {
                                          return null;
                                        }
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return "Member ID is required";
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        _memberNameController.text = '';
                                        ref
                                            .read(newReservationProvider
                                                .notifier)
                                            .resetState();
                                      },
                                    ),
                            ),
                            const SizedBox(width: 10.0),
                            ElevatedButton(
                              onPressed: _isEditMode
                                  ? _navigateToProfile
                                  : (newReservation.bmNumber == null
                                      ? null
                                      : () => context.push('/home/profile')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isEditMode
                                    ? const Color.fromARGB(255, 70, 70, 70)
                                    : (newReservation.bmNumber == null
                                        ? Colors.grey.shade400
                                        : const Color.fromARGB(
                                            255, 70, 70, 70)),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 14,
                                ),
                              ),
                              child:
                                  const Icon(Icons.person_search, size: 25),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10.0),

                        // ── Member Name ────────────────────────
                        TextFormField(
                          autofocus: false,
                          controller: _memberNameController,
                          readOnly: _isEditMode,
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: -5.0,
                            ),
                            suffixIcon: !_isEditMode
                                ? IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: () {
                                      FocusScope.of(context)
                                          .requestFocus(FocusNode());
                                      _openMemberSearchBottomSheet(8003);
                                    },
                                  )
                                : null,
                          ),
                          validator: (value) {
                            // Same exemption as Member ID above.
                            if (_guestEntries.isNotEmpty &&
                                (value == null || value.trim().isEmpty) &&
                                _memberIdController.text.trim().isEmpty) {
                              return null;
                            }
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

                        // ── Guest Card ─────────────────────────
                        GuestDisplayCardSpecialGiftview(
                          memberIdText: _memberIdController.text,
                          memberNameText: _memberNameController.text,
                          showCard: _memberIdController.text.isNotEmpty &&
                              _memberNameController.text.isNotEmpty,
                          showLastVisitDate: true,
                        ),
 const SizedBox(height: 10.0),
                          PackageAmountField(
                          controller: _packageAmountController,
                          enabled: !_isEditMode,
                          textStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            labelText: "Package Amount *",
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
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Package Amount Number is required";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10.0),

                          // ── Arrival Date ───────────────────────
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
                            if (_guestEntries.isNotEmpty &&
                                (value == null || value.trim().isEmpty) &&
                                _memberIdController.text.trim().isEmpty) {
                              return null;
                            }
                            if (value == null || value.trim().isEmpty) {
                              return "Arrival Date is required";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // ── Departure Date ─────────────────────
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
                            if (_guestEntries.isNotEmpty &&
                                (value == null || value.trim().isEmpty) &&
                                _memberIdController.text.trim().isEmpty) {
                              return null;
                            }
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
 // ── Air Ticket Requisition ─────────────
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
                              onChanged: (value) => setState(
                                  () => _airTicketRequisition = value!),
                            ),
                            Text("Yes",
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                )),
                            Radio<String>(
                              value: "No",
                              groupValue: _airTicketRequisition,
                              onChanged: _canChangeAirTicketToNo()
                                  ? (value) => setState(
                                      () => _airTicketRequisition = value!)
                                  : null,
                            ),
                            Text(
                              "No",
                              style: TextStyle(
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                                color: _canChangeAirTicketToNo()
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),

                        // ── Air Tickets Selector ───────────────
                        if (_airTicketRequisition == "Yes") ...[
                          const SizedBox(height: 10.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ValueListenableBuilder<String>(
                                valueListenable: airTicketsNotifier,
                                builder: (context, value, _) {
                                  return TextFormField(
                                    controller:
                                        TextEditingController(text: value),
                                    readOnly: true,
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "Select Air Tickets",
                                      labelStyle: TextStyle(
                                        fontSize: fontSettings.fontSize,
                                        fontWeight:
                                            fontSettings.fontWeight,
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
                                            Icons.arrow_drop_down),
                                        onPressed: () =>
                                            _openAirTicketsSelectorScreen(
                                                context),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (_airTicketError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 12.0, top: 4.0),
                                  child: Text(
                                    _airTicketError!,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize:
                                          fontSettings.fontSize * 0.75,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
                              : Column(
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
                        ],
                   
                        const SizedBox(height: 10.0),

                      
     // ── Hotels & Rooms Selector ────────────
                        ValueListenableBuilder<String>(
                          valueListenable: hotelRoomNotifier,
                          builder: (context, value, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller:
                                      TextEditingController(text: value),
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
                                    contentPadding:
                                        const EdgeInsets.symmetric(
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
                                                255, 103, 4, 125),
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      icon:
                                          const Icon(Icons.arrow_drop_down),
                                      onPressed: () =>
                                          _openHotelAndRoomSelectorBottomSheet(
                                              context),
                                    ),
                                  ),
                                ),
                                if (_hotelError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 12.0, top: 4.0),
                                    child: Text(
                                      _hotelError!,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize:
                                            fontSettings.fontSize * 0.75,
                                        fontWeight: fontSettings.fontWeight,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10.0),

                        // ── Selected Hotels List ───────────────
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
                                      color: const Color.fromARGB(
                                          255, 228, 224, 224),
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
                                                    fontSettings.fontSize *
                                                        1.125,
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
                                                      fontSize: fontSettings
                                                          .fontSize,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: hotel
                                                        .roomCategoryName,
                                                    style: TextStyle(
                                                      fontSize: fontSettings
                                                          .fontSize,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          fontSettings
                                                              .fontWeight,
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
                                                      fontSize: fontSettings
                                                          .fontSize,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: hotel.roomTypeName,
                                                    style: TextStyle(
                                                      fontSize: fontSettings
                                                          .fontSize,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          fontSettings
                                                              .fontWeight,
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
                                                    text: "Arrival Date: ",
                                                    style: TextStyle(
                                                      fontSize: fontSettings
                                                          .fontSize,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: hotel.arrivalDate !=
                                                            null
                                                        ? DateFormat(
                                                                'yyyy-MM-dd')
                                                            .format(hotel
                                                                .arrivalDate!)
                                                        : '',
                                                    style: TextStyle(
                                                      fontSize: fontSettings
                                                          .fontSize,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          fontSettings
                                                              .fontWeight,
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
                                                    text: "Departure Date: ",
                                                    style: TextStyle(
                                                      fontSize: fontSettings
                                                          .fontSize,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: hotel
                                                                .departureDate !=
                                                            null
                                                        ? DateFormat(
                                                                'yyyy-MM-dd')
                                                            .format(hotel
                                                                .departureDate!)
                                                        : '',
                                                    style: TextStyle(
                                                      fontSize: fontSettings
                                                          .fontSize,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          fontSettings
                                                              .fontWeight,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Text(
                                                  "Guests: ${hotel.guestCount}",
                                                  style: TextStyle(
                                                    fontSize: fontSettings
                                                        .fontSize,
                                                    fontWeight: fontSettings
                                                        .fontWeight,
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Text(
                                                  "Nights: ${hotel.noOfNights}",
                                                  style: TextStyle(
                                                    fontSize: fontSettings
                                                        .fontSize,
                                                    fontWeight: fontSettings
                                                        .fontWeight,
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Text(
                                                  "Rooms: ${hotel.roomCount}",
                                                  style: TextStyle(
                                                    fontSize: fontSettings
                                                        .fontSize,
                                                    fontWeight: fontSettings
                                                        .fontWeight,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Estimated Cost: ${hotel.selectedCost}",
                                              style: TextStyle(
                                                fontSize:
                                                    fontSettings.fontSize,
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

                        // ── Remarks ────────────────────────────
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
                        ),
                        //const SizedBox(height: 10.0),
                        // TextFormField(
                        //   controller: _reservationnewnumberController,
                        //   readOnly: _isEditMode,
                        //   style: TextStyle(
                        //     fontSize: fontSettings.fontSize,
                        //     fontWeight: fontSettings.fontWeight,
                        //   ),
                        //   decoration: InputDecoration(
                        //     labelText: "Manual Reservation No",
                        //     labelStyle: TextStyle(
                        //       fontSize: fontSettings.fontSize,
                        //       fontWeight: fontSettings.fontWeight,
                        //     ),
                        //     border: const OutlineInputBorder(),
                        //     contentPadding: const EdgeInsets.symmetric(
                        //       horizontal: 12.0,
                        //       vertical: -5.0,
                        //     ),
                        //   ),
                        //   // validator: (value) {
                        //   //   if (value == null || value.trim().isEmpty) {
                        //   //     return "Manual Reservation Number is required";
                        //   //   }
                        //   //   return null;
                        //   // },
                        // ),
                        const SizedBox(height: 16.0),

                        // ── Add Guest / Add New Guest Buttons ──
                        if (!_isEditMode) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton(
                                onPressed: _onAddGuest,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      Constants.kSecondaryColor,
                                  side: BorderSide(
                                    color: Constants.kSecondaryColor,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person_add, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Add Member With Same Details",
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize *
                                            0.9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: _onAddNewGuest,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.deepOrange,
                                  side: const BorderSide(
                                    color: Colors.deepOrange,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                        Icons.person_add_alt_1,
                                        size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Apply & Add Member",
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize *
                                            0.9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10.0),
                        ],

                        // ── Confirm / Update Button ────────────
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

                // ── Loading Overlay ──────────────────────────
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}