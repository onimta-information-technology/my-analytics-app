import 'dart:convert';
import 'dart:io';

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
import 'package:ballys_reservation_app/models/reservation/reservation_passport_image.dart';
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
import 'package:path_provider/path_provider.dart';

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
        _loadGuestEntriesForEdit(selectedReservation);
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

  /// Loads the reservation's guests as guest cards — each carrying its own
  /// hotels, air tickets, dates and passports — so an update shows exactly who
  /// booked what, and leaves the form blank for adding a further guest.
  Future<void> _loadGuestEntriesForEdit(Reservation reservation) async {
    setState(() => _isLoading = true);

    final entries = <GuestReservationEntry>[];

    if (reservation.guests.isNotEmpty) {
      for (final guest in reservation.guests) {
        entries.add(
          GuestReservationEntry(
            mid: guest.mid,
            guestName: guest.guestName,
            hotels: List<HotelDescip>.from(guest.hotels),
            flights: List<FlightBooking>.from(guest.flights),
            arrivalDate: guest.arrivalDate ?? reservation.arrDate,
            departureDate: guest.departureDate ?? reservation.depDate,
            remarks: guest.remarks,
            airTicketRequisition: guest.airTicketRequisition,
            passportImages: await _materializePassports(
              reservation.passportImages
                  .where((p) => p.guestBmNumber == guest.mid),
            ),
          ),
        );
      }
    } else {
      // Reservations made before the multi-guest payload carry no per-guest
      // breakdown: every hotel and flight belongs to the single member on the
      // reservation.
      entries.add(
        GuestReservationEntry(
          mid: reservation.mid,
          guestName: reservation.mName,
          hotels: List<HotelDescip>.from(reservation.hotelDescip),
          flights: List<FlightBooking>.from(reservation.airticketDescrip),
          arrivalDate: reservation.arrDate,
          departureDate: reservation.depDate,
          remarks: reservation.remarks,
          airTicketRequisition:
              reservation.airticketDescrip.isNotEmpty ? "Yes" : "No",
          passportImages:
              await _materializePassports(reservation.passportImages),
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _guestEntries
        ..clear()
        ..addAll(entries);
      _isLoading = false;
    });

    // The view screen fills these with every hotel/flight on the reservation to
    // render its summary. They now live on the guest cards, so start the form
    // empty for the next guest.
    ref.read(selectedHotelProvider.notifier).setHotels([]);
    ref.read(selectedFlightProvider.notifier).setFlights([]);
    ref.read(selectedPassportProvider.notifier).setFiles([]);
    ref.read(selectedGuestProvider.notifier).clearGuest();
  }

  /// Writes API passport images (base64) to disk so they behave like freshly
  /// picked files: the upload widget can show them and they get re-encoded on
  /// save, which keeps existing passports attached when the record is replaced.
  Future<List<PassportImage>> _materializePassports(
    Iterable<ReservationPassportImage> images,
  ) async {
    final result = <PassportImage>[];

    try {
      final dir = await getApplicationDocumentsDirectory();
      final passportDir = Directory('${dir.path}/passport_uploads');
      if (!await passportDir.exists()) {
        await passportDir.create(recursive: true);
      }

      for (final image in images) {
        final bytes = image.bytes;
        if (bytes == null) continue;
        final fileName = image.fileName.isNotEmpty
            ? image.fileName
            : 'passport${image.isPdf ? '.pdf' : '.jpg'}';
        final file = File(
          '${passportDir.path}/${DateTime.now().microsecondsSinceEpoch}_$fileName',
        );
        await file.writeAsBytes(bytes);
        result.add(
          PassportImage(
            path: file.path,
            fileName: fileName,
            isPdf: image.isPdf,
          ),
        );
      }
    } catch (_) {
      // Nothing to attach; the guest keeps whatever passports get picked next.
    }

    return result;
  }

  void _populateFields(Reservation selectedReservation) {
    _reservationNoController.text = selectedReservation.reservNo;
    _noOfNightsController.text = selectedReservation.noOfNights.toString();
    _packageAmountController.text = selectedReservation.packageAmountDisplay;
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
          reservationArrivalDate: _arrivalDate,
          reservationDepartureDate: _departureDate,
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

    // Rooms and air tickets are matched back to their owner by BM number, so
    // the same member twice would merge into one guest on the API side.
    final mid = _memberIdController.text.trim();
    final duplicateIndex =
        _guestEntries.indexWhere((g) => g.mid.trim() == mid);
    if (duplicateIndex != -1 && duplicateIndex != _editingGuestIndex) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$mid is already added to this reservation'),
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

  /// One line per hotel this guest booked, e.g.
  /// "Hilton Colombo — Deluxe, 2 Rooms, 3 Nights".
  List<String> _hotelLines(GuestReservationEntry entry) {
    return entry.hotels.map((hotel) {
      final name = hotel.hotelName?.trim();
      final rooms = hotel.roomCount ?? 0;
      final nights = hotel.noOfNights ?? 0;
      final details = [
        if (hotel.roomCategoryName?.trim().isNotEmpty ?? false)
          hotel.roomCategoryName!.trim(),
        if (rooms > 0) rooms == 1 ? "1 Room" : "$rooms Rooms",
        if (nights > 0) nights == 1 ? "1 Night" : "$nights Nights",
      ];
      final title = (name != null && name.isNotEmpty) ? name : "Hotel";
      return details.isEmpty ? title : "$title — ${details.join(', ')}";
    }).toList();
  }

  /// One line per air ticket this guest booked, e.g.
  /// "CMB → SIN — Round Trip, Business".
  List<String> _flightLines(GuestReservationEntry entry) {
    return entry.flights.map((flight) {
      final from = flight.airports?.departure?.dFrom.airportCode.trim() ?? '';
      final to = flight.airports?.departure?.dTo.airportCode.trim() ?? '';
      final route =
          (from.isEmpty && to.isEmpty) ? "Air Ticket" : "$from → $to";
      final details = [
        if (flight.isRoundTrip) "Round Trip",
        if (flight.airTicketClassName.trim().isNotEmpty)
          flight.airTicketClassName.trim(),
      ];
      return details.isEmpty ? route : "$route — ${details.join(', ')}";
    }).toList();
  }

  /// A single hotel / air-ticket row on a guest card: the icon is what tells
  /// the two apart at a glance.
  Widget _bookingLine({
    required IconData icon,
    required Color color,
    required String label,
    required double fontSize,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: fontSize + 2, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: fontSize, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReservation() async {
    // The form-level validator on Member ID/Name only applies to whatever guest
    // is currently on screen. If guests have already been added and the current
    // fields are empty, that's fine — it just means the user is ready to submit
    // without a "dangling" extra guest. Update works the same way: the existing
    // guests are already loaded as cards.
    final hasDanglingGuestFields = _memberIdController.text.trim().isNotEmpty ||
        _memberNameController.text.trim().isNotEmpty;

    if (_guestEntries.isEmpty || hasDanglingGuestFields) {
      if (!_formKey.currentState!.validate()) return;
      if (!_validateUpdateFields()) return;
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

      // The on-screen guest is either one pulled back from a card for editing
      // (replace it in place — appending would submit that guest twice) or a
      // brand-new one the user never pressed "Add Guest" for.
      if (_editingGuestIndex != null &&
          _editingGuestIndex! < allGuests.length) {
        allGuests[_editingGuestIndex!] = _snapshotCurrentGuest();
      } else {
        allGuests.add(_snapshotCurrentGuest());
      }
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

      // On update the caller reloads the list from the API; adding here would
      // show the reservation twice until that reload lands.
      if (response != null && !_isEditMode) {
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
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Reservation updated successfully'
                  : 'Reservation saved successfully',
            ),
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
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0.5,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: !_isEditMode
                    ? const [
                        Constants.kPrimaryColor,
                        Constants.kSecondaryColor,
                      ]
                    : const [
                        Color(0xFF2E7D5B),
                        Color(0xFF1B5E3F),
                      ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          title: Text(
            !_isEditMode ? "New Reservation" : "Update Reservation",
            style: TextStyle(
              fontSize: 18 * (fontSettings.fontSize / 16),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
        body: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDADDE3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDADDE3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Constants.kPrimaryColor,
                  width: 1.6,
                ),
              ),
            ),
          ),
          child: Form(
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
                              border: const OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              ),
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
                              // This guest is currently loaded into the form
                              // below; the form overwrites this card on save
                              // rather than adding a second guest.
                              final isEditing = _editingGuestIndex == i;
                              return Card(
                                elevation: 0,
                                color: isEditing
                                    ? const Color(0xFFFFF4E5)
                                    : const Color(0xFFEFF7F1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isEditing
                                        ? Colors.deepOrange
                                        : const Color(0xFFCADFD1),
                                    width: isEditing ? 1.6 : 1,
                                  ),
                                ),
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
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    g.guestName,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: fontSettings
                                                          .fontSize,
                                                    ),
                                                  ),
                                                ),
                                                if (isEditing)
                                                  Text(
                                                    "EDITING BELOW",
                                                    style: TextStyle(
                                                      fontSize: fontSettings
                                                              .fontSize *
                                                          0.75,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.deepOrange,
                                                    ),
                                                  ),
                                              ],
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
                                            // Spell out what this guest booked
                                            // so a hotel is never mistaken for
                                            // an air ticket.
                                            ..._hotelLines(g).map(
                                              (line) => _bookingLine(
                                                icon: Icons.hotel,
                                                color: Constants.kSecondaryColor,
                                                label: line,
                                                fontSize:
                                                    fontSettings.fontSize * 0.85,
                                              ),
                                            ),
                                            ..._flightLines(g).map(
                                              (line) => _bookingLine(
                                                icon: Icons.flight_takeoff,
                                                color: Colors.deepOrange,
                                                label: line,
                                                fontSize:
                                                    fontSettings.fontSize * 0.85,
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
                              child: TextFormField(
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
                                        border: const OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              ),
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
                              onPressed: _memberIdController.text.trim().isEmpty
                                  ? null
                                  : _navigateToProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _memberIdController.text.trim().isEmpty
                                        ? Colors.grey.shade400
                                        : const Color.fromARGB(
                                            255, 70, 70, 70),
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
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: -5.0,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                FocusScope.of(context)
                                    .requestFocus(FocusNode());
                                _openMemberSearchBottomSheet(8003);
                              },
                            ),
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
                          onChanged: (value) {
                            _memberIdController.text = '';
                            ref
                                .read(newReservationProvider.notifier)
                                .resetState();
                          },
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
                          enabled: true,
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
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
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
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
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
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
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
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _airTicketError != null
                                              ? Colors.red
                                              : const Color(0xFFDADDE3),
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                        vertical: -5.0,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _airTicketError != null
                                              ? Colors.red
                                              : const Color(0xFFDADDE3),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _airTicketError != null
                                              ? Colors.red
                                              : Constants.kPrimaryColor,
                                          width: 1.6,
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
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: _hotelError != null
                                            ? Colors.red
                                            : const Color(0xFFDADDE3),
                                      ),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                      vertical: -5.0,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: _hotelError != null
                                            ? Colors.red
                                            : const Color(0xFFDADDE3),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: _hotelError != null
                                            ? Colors.red
                                            : Constants.kPrimaryColor,
                                        width: 1.6,
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
                                      elevation: 0,
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        side: const BorderSide(
                                          color: Color(0xFFE4D9C2),
                                        ),
                                      ),
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
                                                color:
                                                    const Color(0xFF1F2430),
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
                                                color: const Color(
                                                    0xFFB07A1E),
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
      ),
    );
  }
}