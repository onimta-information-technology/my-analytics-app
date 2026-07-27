import 'package:ballys_reservation_app/components/air_ticket_class_selector.dart';
import 'package:ballys_reservation_app/components/custom_airport_field.dart';
import 'package:ballys_reservation_app/components/flight_card_ballys.dart';
import 'package:ballys_reservation_app/components/passport_upload_widget.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/airport_repository.dart';
import 'package:ballys_reservation_app/data/repositories/contact_person_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ballys_reservation_app/models/airport_search_response.dart';
import 'package:ballys_reservation_app/models/reservation/airport_cost_response.dart';
import 'package:ballys_reservation_app/models/reservation/flight_bookng_ballys.dart';
import 'package:ballys_reservation_app/providers/airports_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider_ballys.dart';
import 'package:ballys_reservation_app/providers/selected_passport_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

class AirTicketsSelectionBallysScreen extends ConsumerStatefulWidget {
  final AirportRepository airportRepository;
  final String arrivalDate;
  final String departureDate;
  const AirTicketsSelectionBallysScreen(
    this.airportRepository, {
    super.key,
    required this.arrivalDate,
    required this.departureDate,
  });

  @override
  ConsumerState<AirTicketsSelectionBallysScreen> createState() =>
      _AirTicketsSelectionBallysScreenState();
}

class _AirTicketsSelectionBallysScreenState
    extends ConsumerState<AirTicketsSelectionBallysScreen> {
  late String _arrivalDate;
  late String _departureDate;
  final TextEditingController _departureFromController =
      TextEditingController();
  final TextEditingController _departureToController = TextEditingController();
  final TextEditingController _returnFromController = TextEditingController();
  final TextEditingController _returnToController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _arrivalDateController = TextEditingController();

  final TextEditingController _hotelRoomController = TextEditingController();
  final TextEditingController _dateRangeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final ValueNotifier<List<Map<String, dynamic>>> roomCategoriesNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  final ValueNotifier<List<Map<String, dynamic>>> roomTypesNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  final ValueNotifier<String> costNotifier = ValueNotifier<String>("0");
  final ValueNotifier<String?> airLineNotifier = ValueNotifier<String?>(null);
  List<String> _contactPersons = [];
  List<PassportFile> _passportFiles = [];

  /// Bellagio (bty.world) hides the Hamoos contact person dropdown.
  bool _isBellagio = false;

  /// Ballys (non–bty.world) shows extra air-ticket options: Meal, Extra
  /// Legroom Seat and Gold Route.
  bool _isBallys = false;

  @override
  void initState() {
    super.initState();
    flightList = List.from(ref.read(selectedFlightBallysProvider));
    _passportFiles = List.from(ref.read(selectedPassportProvider));
    _getAirports();
    _loadBrand();
    _loadContactPersons();
    _arrivalDate = widget.arrivalDate;
    _departureDate = widget.departureDate;
  }

  Future<void> _loadBrand() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    if (mounted) {
      setState(() {
        _isBellagio = apiUrl.contains('bty.world');
        _isBallys = !_isBellagio;
      });
    }
  }

  Future<void> _loadContactPersons() async {
    try {
      final repo = ContactPersonRepository(ApiService(const FlutterSecureStorage()));
      final persons = await repo.getContactPersons();
      if (mounted) setState(() => _contactPersons = persons);
    } catch (_) {}
  }

  static const String _defaultToAirportCode = "CMB";

  Airport? _departureFromAirport;
  Airport? _departureToAirport;
  Airport? _returnFromAirport;
  Airport? _returnToAirport;

  Key _departureFromAirportKey = UniqueKey();
  Key _departureToAirportKey = UniqueKey();

  bool _isSameAsHotelForDeparture = false;
  bool _isSameAsHotelForArrival = false;

  String _silkRouteFacility = "No";

  /// Which leg the Silk / Gold Route facility applies to. Only asked for — and
  /// only sent — while that facility is set to Yes.
  String _silkRouteType = "Arrival";
  String _goldRouteType = "Arrival";

  /// Meal requirement, asked for only while Meal is Yes.
  final TextEditingController _mealRemarkController = TextEditingController();

  String _airportTranspotation = "No";
  int? _airTicketClass;
  String? _airTicketClassName;

  // Validation error flags for required fields
  bool _departureFromError = false;
  bool _departureToError = false;
  bool _airTicketClassError = false;
  bool _arrivalDateError = false;
  bool _departureDateError = false;

  Key _airTicketClassKey = UniqueKey();

  bool _isLoading = false;
  bool _isRoundTrip = false;
  bool _visa = false;
  bool _meal = false;
  bool _extraLegroomSeat = false;
  bool _goldRoute = false;
  bool editMode = false;
  int? editIndex;

  DateTimeRange? selectedDateRange;
  DateTime? arrivalDate;
  DateTime? departureDate;

  double? selectedHotelId;
  String? selectedHotelName;
  Map<String, dynamic>? selectedHotel;

  int? selectedRoomCategoryId;
  String? selectedRoomCategoryName;
  Map<String, dynamic>? selectedRoomCategory;

  int? selectedRoomTypeId;
  String? selectedRoomTypeName;
  String? sRoomTypeName;
  String? sMealPlanName;
  Map<String, dynamic>? selectedRoomType;

  int? selectedHotelAndRoom;
  int? numberOfNights;

  dynamic selectedCost;
  int? costIndex;

  int numberOfGuests = 1;
  int numberOfChildren = 0;
  int numberOfInfants = 0;
  int numberOfRooms = 1;

  List<FlightBookingBallys> flightList = [];
String? _selectedContactPerson;
  void _selectDateRange(BuildContext context) async {
    DateTimeRange? pickedDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: selectedDateRange,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDateRange != null) {
      setState(() {
        selectedDateRange = pickedDateRange;
        numberOfNights = pickedDateRange.duration.inDays;
        arrivalDate = pickedDateRange.start;
        departureDate = pickedDateRange.end;
        _dateRangeController.text =
            "${DateFormat('yyyy-MM-dd').format(pickedDateRange.start)} - ${DateFormat('yyyy-MM-dd').format(pickedDateRange.end)}";
      });
      _clearSelectedCost();
    }
  }

  void _updateAdults(count) {
    if (count >= 1) {
      setState(() {
        numberOfGuests = count;
      });
      _clearSelectedCost();
    }
  }

  void _updateChildren(count) {
    if (count >= 0) {
      setState(() {
        numberOfChildren = count;
      });
      _clearSelectedCost();
    }
  }

  void _updateInfants(count) {
    if (count >= 0) {
      setState(() {
        numberOfInfants = count;
      });
      _clearSelectedCost();
    }
  }

  void _updateRooms(count) {
    if (count >= 1) {
      setState(() {
        numberOfRooms = count;
      });
      _clearSelectedCost();
    }
  }

  Future<void> getSelectedHotelRoomCategories(double hotelId,
      {bool clearSelection = true}) async {
    try {
      final response =
          await widget.airportRepository.getSelectedHotelRoomCategories(hotelId);
      roomCategoriesNotifier.value =
          response.map((category) => category.toJson()).toList();

      if (clearSelection) {
        selectedRoomCategory = null;
        selectedRoomCategoryId = null;
        selectedRoomCategoryName = null;
        selectedRoomType = null;
        selectedRoomTypeId = null;
        selectedRoomTypeName = null;
        roomTypesNotifier.value = [];
      }
    } catch (e) {
      roomCategoriesNotifier.value = [];
    }
  }

  Future<void> getSelectedHotelCategoryRoomTypes(
      double hotelId, int categoryId,
      {bool clearSelection = true}) async {
    try {
      final response = await widget.airportRepository
          .getSelectedHotelCategoryRoomTypes(hotelId, categoryId);
      roomTypesNotifier.value =
          response.map((category) => category.toJson()).toList();

      if (clearSelection) {
        selectedRoomType = null;
        selectedRoomTypeId = null;
        selectedRoomTypeName = null;
      }
    } catch (e) {
      roomTypesNotifier.value = [];
    }
  }

  Future<List<AirportCostResponse>?> getAirportCosts() async {
    try {
      final response = await widget.airportRepository.getAirportCosts(
          departureFrom: _departureFromAirport!.airportCode!,
          departureTo: _departureToAirport!.airportCode!,
          returnTo: _returnToAirport!.airportCode!);
      return response;
    } catch (e) {
      return null;
    }
  }

  void _setHotel(flight) {
    selectedHotel = flight;
    selectedHotelId = flight?['Hotel_IID'];
    selectedHotelName = flight?['HotelName'] ?? '';
    _clearSelectedCost();

    if (selectedHotelId != null) {
      roomCategoriesNotifier.value = [];
      roomTypesNotifier.value = [];
      getSelectedHotelRoomCategories(selectedHotelId!);
    }
  }

  void _setRoomCategory(roomCategory) {
    selectedRoomCategory = roomCategory;
    selectedRoomCategoryId = roomCategory?['CatCode'];
    selectedRoomCategoryName = roomCategory?['CatName'] ?? '';
    _clearSelectedCost();
    if (selectedHotelId != null && selectedRoomCategoryId != null) {
      roomTypesNotifier.value = [];
      getSelectedHotelCategoryRoomTypes(
          selectedHotelId!, selectedRoomCategoryId!);
    }
  }

  void _setRoomType(roomtype) {
    selectedRoomType = roomtype;
    selectedRoomTypeId = roomtype?['ID'];
    sRoomTypeName = roomtype?['RoomType'] ?? '';
    sMealPlanName = roomtype?['MealPlan'] ?? '';
    selectedRoomTypeName = '$sRoomTypeName - $sMealPlanName';
    _clearSelectedCost();
  }

  void _handleItemSelected(AirportCostResponse cost, int index) {
    setState(() {
      costIndex = index;
      double calculation = cost.cost! * numberOfGuests;
      costNotifier.value = NumberFormat().format(calculation.round());
      airLineNotifier.value = cost.airLine;
    });
  }

  void __editFlightDetails(FlightBookingBallys flight, int index) {
    setState(() {
      editMode = true;
      editIndex = index;
      numberOfGuests = flight.guestCount;
      numberOfChildren = flight.childrenCount;
      numberOfInfants = flight.infantCount;

      _airTicketClass = flight.airTicketClass;
      _airTicketClassName = flight.airTicketClassName;

      _airTicketClassKey = UniqueKey();

      final dateFormat = DateFormat('yyyy-MM-dd');
      _arrivalDateController.text = flight.arrivalDate != null
          ? dateFormat.format(flight.arrivalDate!)
          : '';
      _departureDateController.text = flight.departureDate != null
          ? dateFormat.format(flight.departureDate!)
          : '';

      _silkRouteFacility = flight.silkRoute == 1 ? "Yes" : "No";
      _airportTranspotation = flight.airportTransportation == 1 ? "Yes" : "No";
      _isRoundTrip = flight.isRoundTrip;
      _visa = flight.visa;
      _meal = flight.meal;
      _extraLegroomSeat = flight.extraLegroomSeat;
      _goldRoute = flight.goldRoute;
      // Blank on flights saved before these were captured — fall back to the
      // default leg rather than leaving the radios unselected.
      _silkRouteType = flight.silkRouteType?.trim().isNotEmpty == true
          ? flight.silkRouteType!
          : "Arrival";
      _goldRouteType = flight.goldRouteType?.trim().isNotEmpty == true
          ? flight.goldRouteType!
          : "Arrival";
      _mealRemarkController.text = flight.mealRemark ?? "";
      _selectedContactPerson = flight.contactPerson;

      _departureFromAirport = flight.airports!.departure?.dFrom.toAirport();
      _departureToAirport = flight.airports!.departure?.dTo.toAirport();
      _returnFromAirport = flight.airports!.returnFlight?.rFrom.toAirport();
      _returnToAirport = flight.airports!.returnFlight?.rTo.toAirport();

      _departureFromAirportKey = UniqueKey();
      _departureToAirportKey = UniqueKey();

      costNotifier.value = flight.selectedCost;
      airLineNotifier.value = flight.airLine;
    });
  }

  void _removeFlight(int index) {
    setState(() {
      flightList.removeAt(index);
    });
  }

  void _saveTicketSelection() {
    final bool departureFromMissing = _departureFromAirport == null;
    final bool departureToMissing = _departureToAirport == null;
    final bool classMissing = _airTicketClass == null;
    final bool arrivalMissing = _arrivalDateController.text == "";
    // Departure date is only required for round trips; optional for one-way.
    final bool departureMissing =
        _isRoundTrip && _departureDateController.text == "";

    if (departureFromMissing ||
        departureToMissing ||
        classMissing ||
        arrivalMissing ||
        departureMissing) {
      setState(() {
        _departureFromError = departureFromMissing;
        _departureToError = departureToMissing;
        _airTicketClassError = classMissing;
        _arrivalDateError = arrivalMissing;
        _departureDateError = departureMissing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields.")),
      );
      return;
    }

    // Cost is optional — no blocking if not calculated

    final FlightAirport airport = FlightAirport(
        departure: Departure(
            dFrom: AirportInfo(
              airportCode: _departureFromAirport!.airportCode!,
              cityName: _departureFromAirport!.cityName!,
              airportName: _departureFromAirport!.airportName!,
              country: _departureFromAirport!.country!,
            ),
            dTo: AirportInfo(
              airportCode: _departureToAirport!.airportCode!,
              cityName: _departureToAirport!.cityName!,
              airportName: _departureToAirport!.airportName!,
              country: _departureToAirport!.country!,
            )),
        returnFlight: _returnFromAirport != null
            ? ReturnFlight(
                rFrom: AirportInfo(
                  airportCode: _returnFromAirport!.airportCode!,
                  cityName: _returnFromAirport!.cityName!,
                  airportName: _returnFromAirport!.airportName!,
                  country: _returnFromAirport!.country!,
                ),
                rTo: AirportInfo(
                  airportCode: _returnToAirport!.airportCode!,
                  cityName: _returnToAirport!.cityName!,
                  airportName: _returnToAirport!.airportName!,
                  country: _returnToAirport!.country!,
                ))
            : null);

    final flightBooking = FlightBookingBallys(
      guestCount: numberOfGuests,
      childrenCount: numberOfChildren,
      infantCount: numberOfInfants,
      airTicketClass: _airTicketClass!,
      arrivalDate: DateFormat("yyyy-MM-dd").parse(_arrivalDateController.text),
      departureDate: _departureDateController.text.isEmpty
          ? null
          : DateFormat("yyyy-MM-dd").parse(_departureDateController.text),
      silkRoute: _silkRouteFacility == "Yes" ? 1 : 0,
      airportTransportation: _airportTranspotation == "Yes" ? 1 : 0,
      airTicketClassName: _airTicketClassName!,
      isRoundTrip: _isRoundTrip,
      selectedCost: costNotifier.value,
      airLine: airLineNotifier.value,
      contactPerson: _selectedContactPerson,
      visa: _visa,
      meal: _meal,
      extraLegroomSeat: _extraLegroomSeat,
      goldRoute: _goldRoute,
      // Only meaningful for the facilities that are switched on.
      silkRouteType: _silkRouteFacility == "Yes" ? _silkRouteType : null,
      goldRouteType: _goldRoute ? _goldRouteType : null,
      mealRemark: _meal ? _mealRemarkController.text.trim() : null,
      airports: airport,
    );

    setState(() {
      if (editMode) {
        flightList[editIndex!] = flightBooking;
      } else {
        flightList.add(flightBooking);
      }
    });

    _clearSelection();
  }

  void _acceptChanges() {
    ref.read(selectedFlightBallysProvider.notifier).addFlights(flightList);
    ref.read(selectedPassportProvider.notifier).setFiles(_passportFiles);
    Navigator.pop(context);
  }

  /// Lays [options] out two per row, with 16px vertical gaps between rows. A
  /// trailing odd option keeps the left column, leaving the right column empty.
  List<Widget> _buildOptionGrid(List<Widget> options) {
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: options[i]),
          Expanded(
            child:
                i + 1 < options.length ? options[i + 1] : const SizedBox(),
          ),
        ],
      ));
      if (i + 2 < options.length) {
        rows.add(const SizedBox(height: 16));
      }
    }
    return rows;
  }

  /// A labelled Yes/No radio group, sized to fill its column so several can be
  /// laid out side by side in a [Row].
  Widget _buildYesNoOption({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: value,
              onChanged: (v) => onChanged(v!),
            ),
            const Text("Yes", style: TextStyle(fontSize: 16)),
            Radio<bool>(
              value: false,
              groupValue: value,
              onChanged: (v) => onChanged(v!),
            ),
            const Text("No", style: TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  /// Full-width Arrival / Departure picker for the Silk and Gold Route
  /// facilities: two tap targets side by side, the chosen one filled and
  /// ticked, so the answer is readable at a glance instead of hunting for
  /// which small radio is filled.
  Widget _buildLegSelector({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    Widget leg(String leg, IconData icon) {
      final selected = value == leg;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(leg),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: selected
                  ? Constants.kPrimaryColor.withValues(alpha: 0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? Constants.kPrimaryColor
                    : const Color(0xFFDADDE3),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      selected ? Constants.kPrimaryColor : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    leg,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      color: selected
                          ? Constants.kPrimaryColor
                          : Colors.black87,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Constants.kPrimaryColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            leg("Arrival", Icons.flight_land),
            const SizedBox(width: 12),
            leg("Departure", Icons.flight_takeoff),
          ],
        ),
      ],
    );
  }

  void _clearSelectedCost() {
    costNotifier.value = "0";
    airLineNotifier.value = null;
    selectedCost = null;
    costIndex = null;
  }

  void _clearSelection() {
    setState(() {
      numberOfGuests = 1;
      numberOfChildren = 0;
      numberOfInfants = 0;
      arrivalDate = null;
      _arrivalDateController.text = "";
      _departureDateController.text = "";
      _airTicketClass = null;
      _airTicketClassName = null;
      _airTicketClassKey = UniqueKey();

      _silkRouteFacility = "No";
      _airportTranspotation = "No";
      _isRoundTrip = false;
      _visa = false;
      _meal = false;
      _extraLegroomSeat = false;
      _goldRoute = false;
      _silkRouteType = "Arrival";
      _goldRouteType = "Arrival";
      _mealRemarkController.clear();
      _selectedContactPerson = null;

      _departureFromAirport = null;
      _departureToAirport = ref
          .read(airportsProvider.notifier)
          .findByCode(_defaultToAirportCode);
      _returnFromAirport = null;
      _returnToAirport = null;

      _departureFromAirportKey = UniqueKey();
      _departureToAirportKey = UniqueKey();

      selectedCost = null;
      costNotifier.value = "0";
      airLineNotifier.value = null;
      costIndex = null;

      editMode = false;
      editIndex = null;

      _departureFromError = false;
      _departureToError = false;
      _airTicketClassError = false;
      _arrivalDateError = false;
      _departureDateError = false;
    });
  }

  void _showCostCalculator(BuildContext context) async {
    if (_departureFromAirport == null || _departureToAirport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select departure and arrival airports")),
      );
      return;
    }
    final airportCosts = await getAirportCosts();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return CostCalculatorBottomSheet(
            onBackPressed: () {
              Navigator.pop(context);
            },
            onItemSelected: _handleItemSelected,
            airportCosts: airportCosts ?? []);
      },
    );
  }

  Future<void> _getAirports() async {
    try {
      final airports = ref.read(airportsProvider);

      if (airports.isEmpty) {
        setState(() {
          _isLoading = true;
        });
        await ref.read(airportsProvider.notifier).getAllAirports();
        setState(() {
          _isLoading = false;
        });
      }

      ref.read(airportsProvider.notifier).filterAirports("");
      _applyDefaultDepartureToAirport();
    } catch (e) {}
  }

  /// Departure "To" defaults to CMB (from the loaded airport list); the user
  /// can still pick another airport.
  void _applyDefaultDepartureToAirport() {
    if (_departureToAirport != null) return;
    final cmb = ref.read(airportsProvider.notifier).findByCode(_defaultToAirportCode);
    if (cmb == null || !mounted) return;
    setState(() {
      _departureToAirport = cmb;
      _departureToError = false;
      _departureToAirportKey = UniqueKey();
    });
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    DateTime selectedDate = now;

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
                controller == _arrivalDateController
                    ? "Select Arrival Date"
                    : "Select Departure Date",
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
                initialDateTime: now,
                minimumDate: now,
                maximumDate: DateTime(
                  now.year + 1,
                  now.month,
                  now.day,
                ),
                onDateTimeChanged: (DateTime newDate) {
                  selectedDate = newDate;
                },
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () {
                if (controller == _departureDateController &&
                    _arrivalDateController.text.isNotEmpty) {
                  final arrivalParsed = DateFormat('yyyy-MM-dd')
                      .parse(_arrivalDateController.text);
                  if (!selectedDate.isAfter(arrivalParsed)) {
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
                }
                setState(() {
                  controller.text = DateFormat('yyyy-MM-dd').format(selectedDate);
                });
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

  Widget _buildCounter(
      String label, int count, int type, Function(int) onCountChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                GestureDetector(
                  onTap: () => onCountChange(count - 1),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(Icons.remove, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 40,
                  child: Text(
                    count.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => onCountChange(count + 1),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotelsDropDownKey = GlobalKey<DropdownSearchState>();
    final roomCategoriesDropDownKey = GlobalKey<DropdownSearchState>();
    final roomTypeDropDownKey = GlobalKey<DropdownSearchState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Air Tickets Reservation",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: 400,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildCounter("Guests", numberOfGuests, 1,
                          (count) => _updateAdults(count)),
                      const SizedBox(height: 12),
                      _buildCounter("Children", numberOfChildren, 2,
                          (count) => _updateChildren(count)),
                      const SizedBox(height: 12),
                      _buildCounter("Infants", numberOfInfants, 3,
                          (count) => _updateInfants(count)),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          "Departure",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                      ),
                      const SizedBox(height: 5),
                      CustomAirportField(
                        label: "From",
                        key: _departureFromAirportKey,
                        hasError: _departureFromError,
                        prefixIcon: Icons.airplane_ticket_outlined,
                        suffixIcon: Icons.arrow_drop_down,
                        cityCountryText: _departureFromAirport != null
                            ? "${_departureFromAirport!.cityName} - ${_departureFromAirport!.country}"
                            : null,
                        airportNameText: _departureFromAirport?.airportCode,
                        onAirportSelected: (selectedAirport) {
                          setState(() {
                            _departureFromAirport = selectedAirport;
                            _departureFromError = false;
                          });
                        },
                      ),
                      const SizedBox(height: 5),
                      CustomAirportField(
                        label: "To",
                        key: _departureToAirportKey,
                        hasError: _departureToError,
                        prefixIcon: Icons.airplane_ticket_outlined,
                        suffixIcon: Icons.arrow_drop_down,
                        cityCountryText: _departureToAirport != null
                            ? "${_departureToAirport!.cityName} - ${_departureToAirport!.country}"
                            : null,
                        airportNameText: _departureToAirport?.airportCode,
                        onAirportSelected: (selectedAirport) {
                          setState(() {
                            _departureToAirport = selectedAirport;
                            _departureToError = false;
                          });
                        },
                      ),
                      Row(
                        children: [
                          const Spacer(),
                          Row(
                            children: [
                              const Text(
                                "Round Trip",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Checkbox(
                                value: _isRoundTrip,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _isRoundTrip = value ?? false;
                                    if (_isRoundTrip) {
                                      _returnFromAirport = _departureToAirport;
                                    } else {
                                      // Departure date is optional for one-way.
                                      _departureDateError = false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 0),
                      if (_isRoundTrip)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                "Return",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                            ),
                            const SizedBox(height: 5),
                            CustomAirportField(
                              label: "From",
                              prefixIcon: Icons.airplane_ticket_outlined,
                              suffixIcon: Icons.arrow_drop_down,
                              cityCountryText: _departureToAirport != null
                                  ? "${_departureToAirport!.cityName} - ${_departureToAirport!.country}"
                                  : null,
                              airportNameText: _departureToAirport?.airportCode,
                              onAirportSelected: (selectedAirport) {
                                setState(() {
                                  _returnFromAirport = selectedAirport;
                                });
                              },
                            ),
                            const SizedBox(height: 5),
                            CustomAirportField(
                              label: "To",
                              prefixIcon: Icons.airplane_ticket_outlined,
                              suffixIcon: Icons.arrow_drop_down,
                              cityCountryText: _returnToAirport != null
                                  ? "${_returnToAirport!.cityName} - ${_returnToAirport!.country}"
                                  : null,
                              airportNameText: _returnToAirport?.airportCode,
                              onAirportSelected: (selectedAirport) {
                                setState(() {
                                  _returnToAirport = selectedAirport;
                                });
                              },
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      AirTicketClassSelector(
                        key: _airTicketClassKey,
                        hasError: _airTicketClassError,
                        selectedClass: _airTicketClass == null
                            ? null
                            : {
                                "id": _airTicketClass!,
                                "type": _airTicketClassName!
                              },
                        onClassSelected: (selectedClass) {
                          if (selectedClass != null) {
                            _airTicketClass = selectedClass['id'];
                            _airTicketClassName = selectedClass['type'];
                            if (_airTicketClassError) {
                              setState(() => _airTicketClassError = false);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _arrivalDateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Arrival Date",
                          labelStyle: const TextStyle(
                              fontSize: 20,
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          prefixIcon: const Icon(Icons.calendar_today),
                          errorText: _arrivalDateError ? "Required" : null,
                        ),
                        onTap: () async {
                          await _selectDate(context, _arrivalDateController);
                          if (_arrivalDateController.text.isNotEmpty &&
                              _arrivalDateError) {
                            setState(() => _arrivalDateError = false);
                          }
                        },
                      ),
                      if (_arrivalDate.isNotEmpty)
                        Row(
                          children: [
                            Checkbox(
                              value: _isSameAsHotelForArrival,
                              onChanged: (value) {
                                setState(() {
                                  _isSameAsHotelForArrival = value!;
                                  if (_isSameAsHotelForArrival &&
                                      _arrivalDate.isNotEmpty) {
                                    _arrivalDateController.text = _arrivalDate;
                                  }
                                });
                              },
                            ),
                            const Text("Same as flight reservation",
                                style: TextStyle(fontSize: 18)),
                          ],
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _departureDateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: _isRoundTrip
                              ? "Departure Date"
                              : "Departure Date (Optional)",
                          labelStyle: const TextStyle(
                              fontSize: 20,
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          prefixIcon: const Icon(Icons.calendar_today),
                          errorText: _departureDateError ? "Required" : null,
                        ),
                        onTap: () async {
                          await _selectDate(context, _departureDateController);
                          if (_departureDateController.text.isNotEmpty &&
                              _departureDateError) {
                            setState(() => _departureDateError = false);
                          }
                        },
                      ),
                      if (_departureDate.isNotEmpty)
                        Row(
                          children: [
                            Checkbox(
                              value: _isSameAsHotelForDeparture,
                              onChanged: (value) {
                                setState(() {
                                  _isSameAsHotelForDeparture = value!;
                                  if (_isSameAsHotelForDeparture &&
                                      _departureDate.isNotEmpty) {
                                    _departureDateController.text =
                                        _departureDate;
                                  }
                                });
                              },
                            ),
                            const Text("Same as flight reservation",
                                style: TextStyle(fontSize: 18)),
                          ],
                        ),
                           const SizedBox(height: 16),
  PassportUploadWidget(
    initialFiles: _passportFiles,
    onFilesChanged: (files) {
      setState(() {
        _passportFiles = List.from(files);
      });
    },
  ),
  const SizedBox(height: 20),
// const Align(
//   alignment: Alignment.topLeft,
//   child: Text(
//     "Contact Person",
//     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
//   ),
// ),
// const SizedBox(height: 5),
if (!_isBellagio)
DropdownSearch<String>(
  items: (filter, infiniteScrollProps) => _contactPersons
      .where((item) => item.toLowerCase().contains(filter.toLowerCase()))
      .toList(),
  selectedItem: _selectedContactPerson,
  onChanged: (value) {
    setState(() {
      _selectedContactPerson = value;
    });
  },
  decoratorProps: DropDownDecoratorProps(
    decoration: InputDecoration(
      labelText: "Hamoos Contact Person",
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      prefixIcon: const Icon(Icons.person_outline),
    ),
  ),
  popupProps: PopupProps.menu(
    showSearchBox: true,
    searchFieldProps: const TextFieldProps(
      decoration: InputDecoration(
        hintText: "Search contact person",
        border: OutlineInputBorder(),
      ),
    ),
  ),
),
                      const SizedBox(height: 16),
                      ..._buildOptionGrid([
                        _buildYesNoOption(
                          label: "Visa",
                          value: _visa,
                          onChanged: (value) => setState(() => _visa = value),
                        ),
                        _buildYesNoOption(
                          label: "Airport Transpotation",
                          value: _airportTranspotation == "Yes",
                          onChanged: (value) => setState(() =>
                              _airportTranspotation = value ? "Yes" : "No"),
                        ),
                          _buildYesNoOption(
                          label: "Silk Route Facility",
                          value: _silkRouteFacility == "Yes",
                          onChanged: (value) => setState(() =>
                              _silkRouteFacility = value ? "Yes" : "No"),
                        ),

                        if (_isBallys) ...[
                          _buildYesNoOption(
                            label: "Meal",
                            value: _meal,
                            onChanged: (value) =>
                                setState(() => _meal = value),
                          ),
                          _buildYesNoOption(
                            label: "Extra Legroom Seat",
                            value: _extraLegroomSeat,
                            onChanged: (value) =>
                                setState(() => _extraLegroomSeat = value),
                          ),
                          _buildYesNoOption(
                            label: "Gold Route",
                            value: _goldRoute,
                            onChanged: (value) =>
                                setState(() => _goldRoute = value),
                          ),
                        ],
                      ]),

                      // ── Follow-ups for the Yes answers above ──────────
                      // Full width, one per row: the leg pickers and the meal
                      // note need more space than a half-width grid cell.
                      if (_silkRouteFacility == "Yes") ...[
                        const SizedBox(height: 20),
                        _buildLegSelector(
                          label: "Silk Route Facility For",
                          value: _silkRouteType,
                          onChanged: (leg) =>
                              setState(() => _silkRouteType = leg),
                        ),
                      ],
                      if (_isBallys && _goldRoute) ...[
                        const SizedBox(height: 20),
                        _buildLegSelector(
                          label: "Gold Route For",
                          value: _goldRouteType,
                          onChanged: (leg) =>
                              setState(() => _goldRouteType = leg),
                        ),
                      ],
                      if (_isBallys && _meal) ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _mealRemarkController,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: "Meal Details",
                            hintText: "e.g. vegetarian, no nuts",
                            prefixIcon: const Icon(Icons.restaurant_menu),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 35),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _showCostCalculator(context);
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
                              Icon(Icons.calculate, size: 20),
                              SizedBox(width: 10),
                              Text(
                                "Cost Calculator",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Estimated Cost with soft warning ──────
                      Row(
                        children: [
                          ValueListenableBuilder<String>(
                            valueListenable: costNotifier,
                            builder: (context, cost, child) {
                              final hasNoCost = cost == "0";
                              return Text(
                                hasNoCost
                                    ? "Est. Cost: No cost calculation done"
                                    : "Est. Cost LKR $cost",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: hasNoCost
                                      ? Colors.red
                                      : Colors.black,
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: double.infinity,
                          child: editMode
                              ? OutlinedButton(
                                  onPressed: _saveTicketSelection,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green,
                                    side: const BorderSide(
                                        color: Colors.green, width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: const Text(
                                    "Update Air Ticket",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              : OutlinedButton(
                                  onPressed: _saveTicketSelection,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Constants.kSecondaryColor,
                                    side: const BorderSide(
                                        color: Constants.kSecondaryColor,
                                        width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: const Text(
                                    "Add Air Ticket",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: double.infinity,
                          child: editMode
                              ? OutlinedButton(
                                  onPressed: _clearSelection,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey,
                                    side: const BorderSide(
                                        color: Colors.grey, width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      flightList.isEmpty
                          ? const Center(
                              heightFactor: 6.0,
                              child: Text(
                                'No air tickets available.',
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : SizedBox(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: flightList.map((flight) {
                                    int index = flightList.indexOf(flight);
                                    return FlightCardBallys(
                                      flight: flight,
                                      index: index,
                                      showDelete: true,
                                      onDoubleTap: () {
                                        if (_scrollController.hasClients) {
                                          _scrollController.animateTo(
                                            0,
                                            duration: const Duration(
                                                milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                        __editFlightDetails(flight, index);
                                      },
                                      onDelete: () {
                                        _removeFlight(index);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                      const SizedBox(height: 16),
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                flightList.isNotEmpty ? _acceptChanges : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Constants.kSecondaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
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
                                Icon(Icons.save, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  "Accept Changes",
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
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cost Calculator Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class CostCalculatorBottomSheet extends StatefulWidget {
  final Function onBackPressed;
  final List<AirportCostResponse>? airportCosts;
  final Function(AirportCostResponse, int) onItemSelected;

  const CostCalculatorBottomSheet({
    super.key,
    required this.onBackPressed,
    required this.airportCosts,
    required this.onItemSelected,
  });

  @override
  _CostCalculatorBottomSheetState createState() =>
      _CostCalculatorBottomSheetState();
}

class _CostCalculatorBottomSheetState extends State<CostCalculatorBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Cost Calculator",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => widget.onBackPressed(),
              ),
            ],
          ),
          const SizedBox(height: 0),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "General"),
              Tab(text: "Guest's Prev Data"),
            ],
            labelColor: Colors.black,
            indicatorColor: Colors.blue,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                widget.airportCosts == null || widget.airportCosts!.isEmpty
                    ? const Center(
                        child: Text(
                          "No data available.",
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.airportCosts?.length ?? 0,
                        itemBuilder: (context, index) {
                          final cost = widget.airportCosts![index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: ListTile(
                                onTap: () {
                                  widget.onItemSelected(cost, index);
                                  Navigator.pop(context);
                                },
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: "Airline: ",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              TextSpan(
                                                text: cost.airLine!,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: "Class: ",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              TextSpan(
                                                text: cost.travelClass!,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: "Month: ",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              TextSpan(
                                                text: DateFormat('MMMM yyyy')
                                                    .format(cost.arrivalDate!),
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        const Text("Net Rate: "),
                                        Text(
                                          NumberFormat("#,##0")
                                              .format(cost.cost),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                // Guest's Prev Data Tab
                const Center(
                  child: Text(
                    "No previous data available.",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}