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
import 'package:ballys_reservation_app/models/reservation/airline_response.dart';
import 'package:ballys_reservation_app/models/reservation/flight_bookng_ballys.dart';
import 'package:ballys_reservation_app/models/reservation/flight_sector_entry.dart';
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

  /// Airline master list (API 90156) and the one picked for this ticket.
  List<AirlineResponse> _airlines = [];
  AirlineResponse? _selectedAirline;
  bool _airlinesLoading = false;
  Key _airlineKey = UniqueKey();

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
    _loadAirlines();
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

  /// No direct flight is available, so the ticket routes through transit
  /// airports the user adds between From and To on each leg.
  bool _isMultiSector = false;
  final List<FlightSectorEntry> _departureSectors = [];
  final List<FlightSectorEntry> _returnSectors = [];
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
      });    }
  }

  void _updateAdults(count) {
    if (count >= 1) {
      setState(() {
        numberOfGuests = count;
      });    }
  }

  void _updateChildren(count) {
    if (count >= 0) {
      setState(() {
        numberOfChildren = count;
      });    }
  }

  void _updateInfants(count) {
    if (count >= 0) {
      setState(() {
        numberOfInfants = count;
      });    }
  }

  void _updateRooms(count) {
    if (count >= 1) {
      setState(() {
        numberOfRooms = count;
      });    }
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

  /// The airline list is the same whatever route is picked, so it is fetched
  /// once when the screen opens.
  Future<void> _loadAirlines() async {
    setState(() => _airlinesLoading = true);
    try {
      final airlines = await widget.airportRepository.getAirlines();
      if (!mounted) return;
      setState(() {
        _airlines = airlines;
        _airlinesLoading = false;
        _airlineKey = UniqueKey();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _airlines = [];
        _airlinesLoading = false;
        _airlineKey = UniqueKey();
      });
    }
  }

  /// The list entry matching a name saved on an earlier ticket, so editing one
  /// shows its airline selected instead of blank.
  AirlineResponse? _airlineByName(String? name) {
    final target = name?.trim();
    if (target == null || target.isEmpty) return null;
    for (final airline in _airlines) {
      if (airline.airlineName.trim().toLowerCase() == target.toLowerCase()) {
        return airline;
      }
    }
    return null;
  }

  void _setHotel(flight) {
    selectedHotel = flight;
    selectedHotelId = flight?['Hotel_IID'];
    selectedHotelName = flight?['HotelName'] ?? '';
    if (selectedHotelId != null) {
      roomCategoriesNotifier.value = [];
      roomTypesNotifier.value = [];
      getSelectedHotelRoomCategories(selectedHotelId!);
    }
  }

  void _setRoomCategory(roomCategory) {
    selectedRoomCategory = roomCategory;
    selectedRoomCategoryId = roomCategory?['CatCode'];
    selectedRoomCategoryName = roomCategory?['CatName'] ?? '';    if (selectedHotelId != null && selectedRoomCategoryId != null) {
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
    selectedRoomTypeName = '$sRoomTypeName - $sMealPlanName';  }

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

      // Flights saved before Multi Sector existed carry no stops; ones that do
      // carry stops are multi sector whatever the flag says.
      _isMultiSector = flight.isMultiSector ||
          flight.departureSectors.isNotEmpty ||
          flight.returnSectors.isNotEmpty;
      _departureSectors
        ..clear()
        ..addAll(flight.departureSectors
            .map((sector) => FlightSectorEntry(airport: sector.toAirport())));
      _returnSectors
        ..clear()
        ..addAll(flight.returnSectors
            .map((sector) => FlightSectorEntry(airport: sector.toAirport())));

      _selectedAirline = _airlineByName(flight.airLine);
      _airlineKey = UniqueKey();
    });
  }

  /// The picked stops of a leg, in the order the rows are shown. Rows with no
  /// airport are dropped — [_saveTicketSelection] rejects those first anyway.
  List<AirportInfo> _sectorInfos(List<FlightSectorEntry> sectors) {
    return sectors
        .where((sector) => sector.airport != null)
        .map((sector) => AirportInfo(
              airportCode: sector.airport!.airportCode ?? '',
              cityName: sector.airport!.cityName ?? '',
              airportName: sector.airport!.airportName ?? '',
              country: sector.airport!.country ?? '',
            ))
        .toList();
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

    // A round trip without both return airports would save as a one-way
    // silently, so ask for them instead.
    if (_isRoundTrip &&
        (_returnFromAirport == null || _returnToAirport == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select the return From and To airports.")),
      );
      return;
    }

    // Every added stop has to name an airport, or the route it describes has a
    // hole in it.
    if (_isMultiSector) {
      final bool hasEmptyStop = _departureSectors.any((s) => s.airport == null) ||
          (_isRoundTrip && _returnSectors.any((s) => s.airport == null));
      final bool hasNoStops = _departureSectors.isEmpty && _returnSectors.isEmpty;
      if (hasEmptyStop || hasNoStops) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasNoStops
                ? "Please add at least one stop, or turn Multi Sector off."
                : "Please select an airport for every stop."),
          ),
        );
        return;
      }
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
        returnFlight: _returnFromAirport != null && _returnToAirport != null
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
      // Air ticket costs are no longer captured on this screen.
      selectedCost: 0,
      airLine: _selectedAirline?.airlineName,
      airLineCode: _selectedAirline?.airlineCode,
      iataCode: _selectedAirline?.iataCode,
      contactPerson: _selectedContactPerson,
      visa: _visa,
      meal: _meal,
      extraLegroomSeat: _extraLegroomSeat,
      goldRoute: _goldRoute,
      // Only meaningful for the facilities that are switched on.
      silkRouteType: _silkRouteFacility == "Yes" ? _silkRouteType : null,
      goldRouteType: _goldRoute ? _goldRouteType : null,
      mealRemark: _meal ? _mealRemarkController.text.trim() : null,
      isMultiSector: _isMultiSector,
      departureSectors: _isMultiSector ? _sectorInfos(_departureSectors) : const [],
      // No return leg means the return stops describe nothing.
      returnSectors: _isMultiSector && airport.returnFlight != null
          ? _sectorInfos(_returnSectors)
          : const [],
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

  /// A right-aligned checkbox for the trip type answers ("Multi Sector",
  /// "Round Trip") that sit under the Departure airports.
  Widget _buildTripTypeCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
        ),
      ],
    );
  }

  /// The transit airports for one leg: a row per stop in travel order, an "Add
  /// Stop" button, and a preview of the full route so it is clear the stops sit
  /// between that leg's From and To.
  Widget _buildSectorSection({
    required String label,
    required List<FlightSectorEntry> sectors,
    required Airport? from,
    required Airport? to,
  }) {
    final routeCodes = [
      from?.airportCode,
      ...sectors.map((sector) => sector.airport?.airportCode),
      to?.airportCode,
    ].map((code) => (code == null || code.trim().isEmpty) ? "..." : code);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Constants.kPrimaryColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDADDE3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            routeCodes.join(" → "),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Constants.kPrimaryColor,
            ),
          ),
          for (var i = 0; i < sectors.length; i++) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CustomAirportField(
                    key: sectors[i].key,
                    label: "Stop ${i + 1}",
                    prefixIcon: Icons.connecting_airports,
                    suffixIcon: Icons.arrow_drop_down,
                    cityCountryText: sectors[i].airport != null
                        ? "${sectors[i].airport!.cityName} - ${sectors[i].airport!.country}"
                        : null,
                    airportNameText: sectors[i].airport?.airportCode,
                    onAirportSelected: (selectedAirport) {
                      setState(() => sectors[i].airport = selectedAirport);
                    },
                  ),
                ),
                IconButton(
                  tooltip: "Remove stop",
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  onPressed: () => setState(() => sectors.removeAt(i)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => sectors.add(FlightSectorEntry())),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text(
                "Add Stop",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Constants.kPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
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
      _isMultiSector = false;
      _departureSectors.clear();
      _returnSectors.clear();
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

      _selectedAirline = null;
      _airlineKey = UniqueKey();

      editMode = false;
      editIndex = null;

      _departureFromError = false;
      _departureToError = false;
      _airTicketClassError = false;
      _arrivalDateError = false;
      _departureDateError = false;
    });
  }

  /// Airline picker — the active airlines from API 90156, by name.
  Widget _buildAirlineDropdown() {
    if (_airlinesLoading) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: "Airline",
          labelStyle: const TextStyle(
              fontSize: 20,
              color: Color.fromARGB(255, 0, 0, 0),
              fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          prefixIcon: const Icon(Icons.airplanemode_active),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text("Loading airlines...", style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return DropdownSearch<AirlineResponse>(
      key: _airlineKey,
      selectedItem: _selectedAirline,
      items: (filter, infiniteScrollProps) => _airlines
          .where((airline) => airline.airlineName
              .toLowerCase()
              .contains(filter.toLowerCase()))
          .toList(),
      itemAsString: (airline) => airline.airlineName,
      compareFn: (a, b) => a.airlineName == b.airlineName,
      enabled: _airlines.isNotEmpty,
      onChanged: (airline) => setState(() => _selectedAirline = airline),
      decoratorProps: DropDownDecoratorProps(
        decoration: InputDecoration(
          labelText: _airlines.isEmpty ? "Airline (unavailable)" : "Airline",
          labelStyle: const TextStyle(
              fontSize: 20,
              color: Color.fromARGB(255, 0, 0, 0),
              fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          prefixIcon: const Icon(Icons.airplanemode_active),
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: const TextFieldProps(
          decoration: InputDecoration(
            hintText: "Search airline",
            border: OutlineInputBorder(),
          ),
        ),
        itemBuilder: (context, airline, isSelected, isFocused) => ListTile(
          title: Text(airline.airlineName,
              style: const TextStyle(fontSize: 16)),
          selected: isSelected,
        ),
      ),
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
                      // Asked before Round Trip: guests with no direct flight
                      // route through transit airports, and that changes what
                      // each leg below looks like.
                      _buildTripTypeCheckbox(
                        label: "Multi Sector (No Direct Flight)",
                        value: _isMultiSector,
                        onChanged: (value) {
                          setState(() {
                            _isMultiSector = value;
                            if (_isMultiSector) {
                              // Start each leg off with one empty stop, so
                              // there is something to fill in straight away.
                              if (_departureSectors.isEmpty) {
                                _departureSectors.add(FlightSectorEntry());
                              }
                              if (_isRoundTrip && _returnSectors.isEmpty) {
                                _returnSectors.add(FlightSectorEntry());
                              }
                            } else {
                              _departureSectors.clear();
                              _returnSectors.clear();
                            }
                          });
                        },
                      ),
                      if (_isMultiSector)
                        _buildSectorSection(
                          label: "Departure Stops",
                          sectors: _departureSectors,
                          from: _departureFromAirport,
                          to: _departureToAirport,
                        ),
                      _buildTripTypeCheckbox(
                        label: "Round Trip",
                        value: _isRoundTrip,
                        onChanged: (value) {
                          setState(() {
                            _isRoundTrip = value;
                            if (_isRoundTrip) {
                              _returnFromAirport = _departureToAirport;
                              if (_isMultiSector && _returnSectors.isEmpty) {
                                _returnSectors.add(FlightSectorEntry());
                              }
                            } else {
                              // Departure date is optional for one-way.
                              _departureDateError = false;
                              _returnSectors.clear();
                            }
                          });
                        },
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
                            if (_isMultiSector)
                              _buildSectorSection(
                                label: "Return Stops",
                                sectors: _returnSectors,
                                from: _returnFromAirport ?? _departureToAirport,
                                to: _returnToAirport,
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
                      _buildAirlineDropdown(),
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
                          // Silk and Gold Route are mutually exclusive —
                          // turning one on clears the other.
                          onChanged: (value) => setState(() {
                            _silkRouteFacility = value ? "Yes" : "No";
                            if (value) _goldRoute = false;
                          }),
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
                            onChanged: (value) => setState(() {
                              _goldRoute = value;
                              if (value) _silkRouteFacility = "No";
                            }),
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
