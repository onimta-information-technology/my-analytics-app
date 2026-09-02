import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/hotel_repository.dart';
import 'package:ballys_reservation_app/models/guest_reservation_entryBallys.dart';
import 'package:ballys_reservation_app/models/reservation/assigned_guest.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_cost_response.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc_ballys.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_location.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_room_catalog_entry.dart';
import 'package:ballys_reservation_app/providers/hotel_catalog_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider_ballys.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

class HotelAndRoomSelectionBallysBottomSheet extends ConsumerStatefulWidget {
  final HotelRepository hotelRepository;
  final VoidCallback? onClose;

  /// Arrival / departure dates already picked on the reservation form. When
  /// both are set the sheet offers a checkbox that copies them into the
  /// hotel date range.
  final DateTime? reservationArrivalDate;
  final DateTime? reservationDepartureDate;

  /// Everyone already on the reservation, listed at the top of the sheet so a
  /// room can be assigned to the guest — or guests — it is booked for.
  final List<AccompanyingMember> guests;

  const HotelAndRoomSelectionBallysBottomSheet(
    this.hotelRepository, {
    this.onClose,
    this.reservationArrivalDate,
    this.reservationDepartureDate,
    this.guests = const [],
    super.key,
  });

  @override
  ConsumerState<HotelAndRoomSelectionBallysBottomSheet> createState() =>
      _HotelAndRoomSelectionBallysBottomSheetState();
}

class _HotelAndRoomSelectionBallysBottomSheetState
    extends ConsumerState<HotelAndRoomSelectionBallysBottomSheet> {
  final TextEditingController _dateRangeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final ValueNotifier<List<Map<String, dynamic>>> roomCategoriesNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  final ValueNotifier<List<Map<String, dynamic>>> roomTypesNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  final ValueNotifier<String> costNotifier = ValueNotifier<String>("0");

  /// How the cost above was arrived at, e.g. "114.00 x 3 nights x 2 rooms".
  /// Null when no calculation stands behind the figure — an edited row carries
  /// its cost but not the sum that made it.
  final ValueNotifier<String?> costBreakdownNotifier =
      ValueNotifier<String?>(null);

  /// Set when part of an edited row named something the catalog no longer
  /// carries, so the form can say why that dropdown came back empty. A
  /// notifier rather than plain state: it is written from the catalog listener
  /// in build(), which must not call setState.
  final ValueNotifier<String?> staleSelectionNotifier =
      ValueNotifier<String?>(null);

  /// Bellagio (bty.world) swaps the "Payment By" options to the Beyond
  /// Borders wording.
  bool _isBellagio = false;

  @override
  void initState() {
    super.initState();
    hotelList = List.from(ref.read(selectedHotelBallysProvider));
    _preselectSoleGuest();
    _syncRoomCountToGuests();
    _loadBrand();
    // Hotels, categories, room types and meal plans all arrive in one call.
    // Re-read rather than reuse the cached list: this sheet is where a hotel
    // gets picked, so it has to offer what the API holds now, not what it held
    // when the app started. The cached list paints immediately meanwhile and
    // the listener in build() refills the dependent dropdowns when it lands.
    ref.read(hotelCatalogProvider.notifier).refresh();
  }

  Future<void> _loadBrand() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    if (!mounted) return;
    setState(() {
      _isBellagio = apiUrl.contains('bty.world');
      // Bellagio uses "N/A" as the payment default instead of "NA".
      if (_isBellagio &&
          (selectedByPaymnet.isEmpty || selectedByPaymnet == 'NA')) {
        selectedByPaymnet = 'N/A';
      }
    });
  }

  @override
  void dispose() {
    _dateRangeController.dispose();
    _scrollController.dispose();
    roomCategoriesNotifier.dispose();
    roomTypesNotifier.dispose();
    costNotifier.dispose();
    costBreakdownNotifier.dispose();
    staleSelectionNotifier.dispose();
    super.dispose();
  }

  bool editMode = false;
  int? editIndex;

  DateTimeRange? selectedDateRange;
  DateTime? arrivalDate;
  DateTime? departureDate;

  /// Asked before the hotel: the hotel dropdown only offers hotels of this
  /// type, so a city stay is never picked off the out-of-Colombo list.
  HotelLocation? selectedHotelLocation;

  double? selectedHotelId;
  String?  selectedHotelName;
  Map<String, dynamic>? selectedHotel;

  int? selectedRoomCategoryId;
  String? selectedRoomCategoryName;
  Map<String, dynamic>? selectedRoomCategory;

  int? selectedRoomTypeId;
  String? selectedRoomTypeName;
  String? sRoomTypeName;
  String? sMealPlanName;
  Map<String, dynamic>? selectedRoomType;

  int? numberOfNights;

  dynamic selectedCost;
  int? costIndex;

  int numberOfAdults = 1;
  int numberOfChildren = 0;
  int numberOfRooms = 1;

  List<HotelDescipBallys> hotelList = [];
String selectedEcLcoFacility = 'NA';
String selectedByPaymnet = 'NA';

  // Validation error flags for required fields
  bool _dateRangeError = false;
  bool _hotelLocationError = false;
  bool _hotelError = false;
  bool _roomCategoryError = false;
  bool _roomTypeError = false;
  bool _guestAssignError = false;

  /// The guests the room being added is booked for, by [_guestKey]. A room can
  /// go to one guest or to several, so this is a set rather than a single pick.
  final Set<String> _assignedGuestKeys = {};

  /// Identifies a guest across rebuilds. BM number alone is not enough — a
  /// member typed in but not yet searched can still be sitting there nameless.
  String _guestKey(AccompanyingMember guest) =>
      "${guest.mid.trim()}|${guest.guestName.trim()}";

  /// Guests a room can actually be booked for: a member with "Shared" ticked is
  /// on somebody else's package and sleeps in that guest's room, so they are
  /// listed on the assignment but never get a room of their own.
  List<AccompanyingMember> get _assignableGuests =>
      widget.guests.where((guest) => !guest.sharedPackage).toList();

  /// The guests the room being added can still be ticked for — assignable and
  /// not already holding another room.
  List<AccompanyingMember> _selectableGuests() {
    final locked = _guestsInOtherRooms();
    return _assignableGuests
        .where((guest) => !locked.contains(_guestKey(guest)))
        .toList();
  }

  /// The ticked guests, in the order they appear on the reservation. The first
  /// one owns the room; the rest each get their own copy of it on save.
  List<AssignedGuest> _selectedAssignedGuests() {
    return _assignableGuests
        .where((guest) => _assignedGuestKeys.contains(_guestKey(guest)))
        .map((guest) =>
            AssignedGuest(mid: guest.mid.trim(), guestName: guest.guestName.trim()))
        .toList();
  }

  /// Ticks the guests a room already names, matching on BM number so a room
  /// pulled back for editing keeps its assignment even if the name was tidied
  /// up since. A shared member is skipped — a room saved against one before the
  /// rule existed is dropped rather than shown as a tick that can't be undone.
  void _applyAssignedGuests(List<AssignedGuest> assigned) {
    _assignedGuestKeys.clear();
    for (final guest in _assignableGuests) {
      if (assigned.any((a) => _namesGuest(a, guest))) {
        _assignedGuestKeys.add(_guestKey(guest));
      }
    }
  }

  /// Whether [assigned] is [guest] — by BM number where there is one, by name
  /// for a member typed in but never searched.
  bool _namesGuest(AssignedGuest assigned, AccompanyingMember guest) {
    final mid = assigned.mid.trim();
    return (mid.isNotEmpty && mid == guest.mid.trim()) ||
        (mid.isEmpty && assigned.guestName.trim() == guest.guestName.trim());
  }

  /// Guests who already have a room on this reservation. They are shown greyed
  /// out rather than offered again — the room being edited is skipped, so its
  /// own guests stay pickable.
  Set<String> _guestsInOtherRooms() {
    final taken = <String>{};
    for (var i = 0; i < hotelList.length; i++) {
      if (editMode && i == editIndex) continue;
      for (final guest in widget.guests) {
        if (hotelList[i].assignedGuests.any((a) => _namesGuest(a, guest))) {
          taken.add(_guestKey(guest));
        }
      }
    }
    return taken;
  }

  /// A single guest on the reservation is the only one a room can be for, so it
  /// starts ticked rather than making every add a two-step job — unless that
  /// guest already has a room.
  void _preselectSoleGuest() {
    if (_assignableGuests.length != 1) return;
    final key = _guestKey(_assignableGuests.first);
    if (_guestsInOtherRooms().contains(key)) return;
    _assignedGuestKeys.add(key);
  }

  /// Rooms are counted per ticked guest: one room each. Shared members never
  /// reach the tick — they are on somebody else's package and sleep in that
  /// guest's room — so they add nothing here either. Never below one: a room is
  /// a room even before anybody is ticked.
  int get _roomsForAssignedGuests {
    final paying = _assignableGuests
        .where((guest) => _assignedGuestKeys.contains(_guestKey(guest)))
        .length;
    return paying < 1 ? 1 : paying;
  }

  /// The room count is the ticked guests' business once there are any, so the
  /// counter is read-only then and can't drift off the assignment.
  bool get _roomCountLocked => _assignedGuestKeys.isNotEmpty;

  /// Pins the room count to the ticked guests while [_roomCountLocked]. Call
  /// after every change to the assignment.
  void _syncRoomCountToGuests() {
    if (!_roomCountLocked) return;
    final rooms = _roomsForAssignedGuests;
    if (rooms == numberOfRooms) return;
    numberOfRooms = rooms;
    _clearSelectedCost();
  }

  /// When true the date range mirrors the reservation arrival / departure
  /// dates and the range picker is locked.
  bool _useReservationDates = false;

  bool get _hasReservationDates =>
      widget.reservationArrivalDate != null &&
      widget.reservationDepartureDate != null;

  String _formatRange(DateTime start, DateTime end) =>
      "${DateFormat('yyyy-MM-dd').format(start)} - ${DateFormat('yyyy-MM-dd').format(end)}";

  void _applyReservationDates() {
    final start = widget.reservationArrivalDate!;
    final end = widget.reservationDepartureDate!;
    final range = DateTimeRange(start: start, end: end);
    setState(() {
      selectedDateRange = range;
      arrivalDate = start;
      departureDate = end;
      numberOfNights = range.duration.inDays;
      _dateRangeError = false;
      _dateRangeController.text = _formatRange(start, end);
    });
    _clearSelectedCost();
  }

  void _toggleUseReservationDates(bool? value) {
    final checked = value ?? false;
    setState(() => _useReservationDates = checked);

    if (checked) {
      _applyReservationDates();
      return;
    }

    setState(() {
      selectedDateRange = null;
      arrivalDate = null;
      departureDate = null;
      numberOfNights = null;
      _dateRangeController.text = "";
    });
    _clearSelectedCost();
  }

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
        _dateRangeError = false;
        _dateRangeController.text =
            "${DateFormat('yyyy-MM-dd').format(pickedDateRange.start)} - ${DateFormat('yyyy-MM-dd').format(pickedDateRange.end)}";
      });
      _clearSelectedCost();
    }
  }

  void _updateAdults(int count) {
    if (count >= 1) {
      setState(() => numberOfAdults = count);
      _clearSelectedCost();
    }
  }

  void _updateChildren(int count) {
    if (count >= 0) {
      setState(() => numberOfChildren = count);
      _clearSelectedCost();
    }
  }

  void _updateRooms(int count) {
    if (_roomCountLocked) return;
    if (count >= 1) {
      setState(() => numberOfRooms = count);
      _clearSelectedCost();
    }
  }

  /// Categories of the picked hotel, filtered out of the catalog that already
  /// carries hotel, category, room type and meal plan (API 90155).
  void getSelectedHotelRoomCategories(
    double hotelId, {
    bool clearSelection = true,
  }) {
    roomCategoriesNotifier.value =
        ref.read(hotelCatalogProvider.notifier).categoriesFor(hotelId);

    if (clearSelection) {
      selectedRoomCategory = null;
      selectedRoomCategoryId = null;
      selectedRoomCategoryName = null;
      selectedRoomType = null;
      selectedRoomTypeId = null;
      selectedRoomTypeName = null;
      roomTypesNotifier.value = [];
    }
  }

  /// Room types (each with its meal plan) of the picked hotel + category, from
  /// the same catalog.
  void getSelectedHotelCategoryRoomTypes(
    double hotelId,
    int categoryId, {
    bool clearSelection = true,
  }) {
    roomTypesNotifier.value =
        ref.read(hotelCatalogProvider.notifier).roomTypesFor(hotelId, categoryId);

    if (clearSelection) {
      selectedRoomType = null;
      selectedRoomTypeId = null;
      selectedRoomTypeName = null;
    }
  }

  /// Drops any part of the current selection that the catalog no longer carries.
  ///
  /// A booked row keeps the hotel, category and room type it was saved with, so
  /// a reservation opened for amendment can name a hotel 90155 has since
  /// retired or renamed. Left alone the field shows that old hotel while the
  /// category and room type dropdowns sit empty — there is nothing in the
  /// catalog to filter — and the row could be re-submitted against a hotel the
  /// back office no longer knows. Whatever is stale is cleared so the dropdowns
  /// offer what the API returns now, and the user is told what went.
  void _dropStaleSelection() {
    final catalog = ref.read(hotelCatalogProvider);
    // Nothing to check against until the catalog lands; the listener in build()
    // runs this again when it does.
    if (catalog.isEmpty || selectedHotelId == null) return;

    final forHotel =
        catalog.where((e) => e.hotelId == selectedHotelId).toList();

    if (forHotel.isEmpty) {
      staleSelectionNotifier.value =
          '"${selectedHotelName ?? 'The saved hotel'}" is no longer available. '
          'Please choose a hotel.';
      selectedHotel = null;
      selectedHotelId = null;
      selectedHotelName = null;
      roomCategoriesNotifier.value = [];
      _clearCategoryAndRoomType();
      return;
    }

    // Still listed, but it may have been renamed since it was booked — show the
    // catalog's wording so the field matches the list behind it. The type comes
    // back off the same row: an edited hotel is picked before the catalog has
    // necessarily landed, leaving the question unanswered until now.
    selectedHotelName = forHotel.first.hotelName;
    selectedHotelLocation = forHotel.first.location ?? selectedHotelLocation;
    selectedHotel = {
      'Hotel_IID': selectedHotelId,
      'HotelName': selectedHotelName,
    };

    if (selectedRoomCategoryId != null &&
        !forHotel.any((e) => e.roomCategoryId == selectedRoomCategoryId)) {
      staleSelectionNotifier.value =
          '"${selectedRoomCategoryName ?? 'The saved room category'}" is no '
          'longer offered at $selectedHotelName. Please choose a room category.';
      _clearCategoryAndRoomType();
      return;
    }

    if (selectedRoomTypeId != null &&
        !forHotel.any((e) =>
            e.roomCategoryId == selectedRoomCategoryId &&
            e.roomTypeId == selectedRoomTypeId)) {
      staleSelectionNotifier.value =
          '"${selectedRoomTypeName ?? 'The saved room type'}" is no longer '
          'offered for $selectedRoomCategoryName. Please choose a room type.';
      _clearRoomType();
      return;
    }

    staleSelectionNotifier.value = null;
  }

  void _clearCategoryAndRoomType() {
    selectedRoomCategory = null;
    selectedRoomCategoryId = null;
    selectedRoomCategoryName = null;
    _clearRoomType();
  }

  void _clearRoomType() {
    selectedRoomType = null;
    selectedRoomTypeId = null;
    selectedRoomTypeName = null;
    sRoomTypeName = null;
    sMealPlanName = null;
    roomTypesNotifier.value = [];
  }

  /// Grading of a category, e.g. "(Standard)" — shown next to the category name.
  String _hotelCategoryLabel(Map<String, dynamic>? category) {
    final grade = (category?['HotelCategory'] ?? '') as String;
    if (grade.isNotEmpty) return grade;
    return ref
        .read(hotelCatalogProvider.notifier)
        .hotelCategoryOf(selectedHotelId, category?['CatCode'] as int?);
  }

  String _categoryWithGrade(Map<String, dynamic>? category) {
    final name = (category?['CatName'] ?? '') as String;
    if (name.isEmpty) return '';
    final grade = _hotelCategoryLabel(category);
    return grade.isEmpty ? name : '$name $grade';
  }

  Future<List<HotelCostResponse>?> getHotelCosts() async {
    try {
      final response = await widget.hotelRepository.getHotelCosts(
        hotelName: selectedHotelName!,
        roomCategory: selectedRoomCategoryName!,
        roomType: sRoomTypeName!,
        mealPlan: sMealPlanName!,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Answers the hotel-type question. Everything picked under the old answer
  /// goes with it — the hotel below belongs to one list or the other, and so do
  /// its categories, room types and cost.
  void _setHotelLocation(HotelLocation location) {
    if (selectedHotelLocation == location) return;
    staleSelectionNotifier.value = null;
    setState(() {
      selectedHotelLocation = location;
      _hotelLocationError = false;
      _hotelError = false;
      selectedHotel = null;
      selectedHotelId = null;
      selectedHotelName = null;
      roomCategoriesNotifier.value = [];
      _clearCategoryAndRoomType();
    });
    _clearSelectedCost();
  }

  void _setHotel(Map<String, dynamic>? hotel) {
    // Picked from the live list, so whatever was stale has been answered.
    staleSelectionNotifier.value = null;
    selectedHotel = hotel;
    selectedHotelId = hotel?['Hotel_IID'];
    selectedHotelName = hotel?['HotelName'] ?? '';
    if (_hotelError) setState(() => _hotelError = false);
    _clearSelectedCost();

    if (selectedHotelId != null) {
      roomCategoriesNotifier.value = [];
      roomTypesNotifier.value = [];
      getSelectedHotelRoomCategories(selectedHotelId!);
    }
  }

  void _setRoomCategory(Map<String, dynamic>? roomCategory) {
    staleSelectionNotifier.value = null;
    selectedRoomCategory = roomCategory;
    selectedRoomCategoryId = roomCategory?['CatCode'];
    selectedRoomCategoryName = roomCategory?['CatName'] ?? '';
    if (_roomCategoryError) setState(() => _roomCategoryError = false);
    _clearSelectedCost();

    if (selectedHotelId != null && selectedRoomCategoryId != null) {
      roomTypesNotifier.value = [];
      getSelectedHotelCategoryRoomTypes(
        selectedHotelId!,
        selectedRoomCategoryId!,
      );
    }
  }

  void _setRoomType(Map<String, dynamic>? roomtype) {
    staleSelectionNotifier.value = null;
    selectedRoomType = roomtype;
    selectedRoomTypeId = roomtype?['ID'];
    sRoomTypeName = roomtype?['RoomType'] ?? '';
    sMealPlanName = roomtype?['MealPlan'] ?? '';
    selectedRoomTypeName = '$sRoomTypeName - $sMealPlanName';
    if (_roomTypeError) setState(() => _roomTypeError = false);
    _clearSelectedCost();
  }

  /// The rate the catalog carries for the picked room type, or null when that
  /// row carries none — there is nothing to calculate from.
  double? get _ourRate {
    final value = selectedRoomType?['OurRate'];
    return value is num ? value.toDouble() : null;
  }

  void _editHotel(HotelDescipBallys hotel, int index) {
    setState(() {
      editMode = true;
      editIndex = index;
      numberOfAdults = hotel.guestCount!;
      numberOfChildren = hotel.childrenCount!;
      numberOfRooms = hotel.roomCount!;

      selectedDateRange = hotel.selectedDateRange;
      numberOfNights = hotel.noOfNights;
      arrivalDate = hotel.arrivalDate;
      departureDate = hotel.departureDate;
      _dateRangeController.text = _formatRange(
        hotel.selectedDateRange.start,
        hotel.selectedDateRange.end,
      );
      _useReservationDates = _hasReservationDates &&
          DateUtils.isSameDay(
            hotel.arrivalDate,
            widget.reservationArrivalDate,
          ) &&
          DateUtils.isSameDay(
            hotel.departureDate,
            widget.reservationDepartureDate,
          );

      selectedHotelId = hotel.hotel;
      selectedHotelName = hotel.hotelName;
      selectedHotel = {"Hotel_IID": hotel.hotel, "HotelName": hotel.hotelName};
      // A saved row names its hotel, not its type — read the type back off the
      // catalog so the question shows as answered rather than sending the user
      // to re-pick a hotel they already booked.
      selectedHotelLocation =
          ref.read(hotelCatalogProvider.notifier).locationOfHotel(hotel.hotel);

      getSelectedHotelRoomCategories(selectedHotelId!, clearSelection: false);

      selectedRoomCategoryId = hotel.roomCategoryId;
      selectedRoomCategoryName = hotel.roomCategoryName;
      selectedRoomCategory = {
        "CatCode": hotel.roomCategoryId,
        "CatName": hotel.roomCategoryName,
      };

      getSelectedHotelCategoryRoomTypes(
        selectedHotelId!,
        selectedRoomCategoryId!,
        clearSelection: false,
      );

      selectedRoomTypeId = hotel.roomTypeId;
      selectedRoomTypeName = hotel.roomTypeName;
      List<String> parts = hotel.roomTypeName!.split("-");
      selectedRoomType = {
        "ID": hotel.roomTypeId,
        "RoomType": parts[0].trim(),
        "MealPlan": parts[1].trim(),
      };
      sRoomTypeName = parts[0].trim();
      sMealPlanName = parts[1].trim();
      selectedCost = hotel.selectedCost;
      costNotifier.value = hotel.selectedCost;
      // The saved row keeps the figure, not the sum behind it.
      costBreakdownNotifier.value = null;
      costIndex = hotel.costIndex;

      _applyAssignedGuests(hotel.assignedGuests);
      _syncRoomCountToGuests();
      _guestAssignError = false;

      // Everything above came off the saved row, not the catalog — anything the
      // API has since dropped goes now rather than being offered as valid.
      _dropStaleSelection();
    });

    // Scroll to top so user sees the form
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _removeHotel(int index) {
    setState(() => hotelList.removeAt(index));
  }

  void _saveHotelSelection() {
    final bool dateMissing = selectedDateRange == null;
    final bool hotelTypeMissing = selectedHotelLocation == null;
    final bool hotelMissing = selectedHotelId == null;
    final bool categoryMissing = selectedRoomCategoryId == null;
    final bool roomTypeMissing = selectedRoomTypeId == null;
    // A room has to name who it is for, but only once there is somebody left to
    // name — the very first guest is still being filled in, everyone else is a
    // shared member or already holds a room of their own.
    final bool guestsMissing =
        _selectableGuests().isNotEmpty && _assignedGuestKeys.isEmpty;

    if (dateMissing ||
        hotelTypeMissing ||
        hotelMissing ||
        categoryMissing ||
        roomTypeMissing ||
        guestsMissing) {
      setState(() {
        _dateRangeError = dateMissing;
        _hotelLocationError = hotelTypeMissing;
        _hotelError = hotelMissing;
        _roomCategoryError = categoryMissing;
        _roomTypeError = roomTypeMissing;
        _guestAssignError = guestsMissing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields.")),
      );
      return;
    }

    // Cost is optional — no blocking if not calculated

    final hotel = HotelDescipBallys(
      hotel: selectedHotelId,
      hotelName: selectedHotelName,
      roomCategoryId: selectedRoomCategoryId,
      roomCategoryName: selectedRoomCategoryName,
      roomTypeId: selectedRoomTypeId,
      roomTypeName: selectedRoomTypeName,
      guestCount: numberOfAdults,
      selectedDateRange: selectedDateRange,
      arrivalDate: arrivalDate,
      departureDate: departureDate,
      childrenCount: numberOfChildren,
      roomCount: numberOfRooms,
      noOfNights: numberOfNights,
      selectedCost: costNotifier.value,
      costIndex: costIndex,
      ecLcoFacility: selectedEcLcoFacility,
      paymentBy: selectedByPaymnet,
      assignedGuests: _selectedAssignedGuests(),
    );

    setState(() {
      if (editMode) {
        hotelList[editIndex!] = hotel;
      } else {
        hotelList.add(hotel);
      }
    });

    _clearSelection();
  }

  void _acceptChanges() {
    ref.read(selectedHotelBallysProvider.notifier).addHotels(hotelList);
    Navigator.pop(context);
  }

  void _closeSheet() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  void _clearSelectedCost() {
    costNotifier.value = "0";
    costBreakdownNotifier.value = null;
    selectedCost = null;
    costIndex = null;
  }

  void _clearSelection() {
    // Keep the "same as reservation dates" choice sticky across adds so a
    // second hotel on the same stay does not need the dates re-picked.
    final bool keepReservationDates =
        _useReservationDates && _hasReservationDates;

    setState(() {
      numberOfAdults = 1;
      numberOfChildren = 0;
      numberOfRooms = 1;

      selectedDateRange = null;
      arrivalDate = null;
      departureDate = null;
      numberOfNights = null;
      _dateRangeController.text = "";

      selectedHotelLocation = null;
      selectedHotelId = null;
      selectedHotelName = null;
      selectedHotel = null;

      selectedRoomCategory = null;
      selectedRoomCategoryId = null;
      selectedRoomCategoryName = null;
      roomCategoriesNotifier.value = [];

      selectedRoomType = null;
      selectedRoomTypeId = null;
      selectedRoomTypeName = null;
      sRoomTypeName = null;
      sMealPlanName = null;
      roomTypesNotifier.value = [];

      selectedCost = null;
      costNotifier.value = "0";
      costBreakdownNotifier.value = null;
      costIndex = null;

      editMode = false;
      editIndex = null;
      staleSelectionNotifier.value = null;
      selectedEcLcoFacility = 'NA';
      selectedByPaymnet = _isBellagio ? 'N/A' : 'NA';

      _useReservationDates = false;
      _dateRangeError = false;
      _hotelLocationError = false;
      _hotelError = false;
      _roomCategoryError = false;
      _roomTypeError = false;

      // The next room is picked for whoever it is picked for, so the ticks
      // start clean — except where there is only one guest to tick.
      _assignedGuestKeys.clear();
      _preselectSoleGuest();
      _syncRoomCountToGuests();
      _guestAssignError = false;
    });

    if (keepReservationDates) {
      _toggleUseReservationDates(true);
    }
  }

  /// Est. cost for the stay: the room's `OurRate` for every night, for every
  /// room. The rate rides on the room type in the hotel catalog, so the sum is
  /// worked out here rather than fetched.
  void _calculateCost() {
    if (selectedHotelName == null ||
        selectedRoomCategoryName == null ||
        selectedRoomTypeId == null ||
        numberOfNights == null ||
        selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select Date range, hotel, category and room type.",
          ),
        ),
      );
      return;
    }

    final rate = _ourRate;
    if (rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This room type has no rate to calculate from."),
        ),
      );
      return;
    }

    final money = NumberFormat('#,##0.00');
    final total = rate * numberOfNights! * numberOfRooms;

    setState(() {
      // Nothing was picked off a list of rates, so the row keeps no index.
      costIndex = null;
      costBreakdownNotifier.value =
          '${money.format(rate)} x $numberOfNights '
          '${numberOfNights == 1 ? "night" : "nights"} x $numberOfRooms '
          '${numberOfRooms == 1 ? "room" : "rooms"}';
      costNotifier.value = money.format(total);
    });
  }

  /// A head count. [enabled] false shows the number but takes the buttons away,
  /// for a count the room's guests have already settled.
  Widget _buildCounter(String label, int count, Function(int) onCountChange,
      {bool enabled = true}) {
    final buttonColor = enabled ? Colors.grey : Colors.grey.shade300;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: enabled ? null : Colors.grey,
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: enabled ? () => onCountChange(count - 1) : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: buttonColor,
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
                    style: TextStyle(
                      fontSize: 18,
                      color: enabled ? null : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: enabled ? () => onCountChange(count + 1) : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: buttonColor,
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

  /// Who the room being added is for: every guest on the reservation, ticked
  /// one by one or several at a time. Each ticked guest gets the room booked
  /// against their BM number.
  Widget _guestAssignment() {
    // Shared members and guests already in another room are along for the ride
    // but can't be picked, so "Select all" and its label only count the rest.
    final locked = _guestsInOtherRooms();
    final selectable = _selectableGuests();
    final allSelected = selectable.isNotEmpty &&
        selectable
            .every((guest) => _assignedGuestKeys.contains(_guestKey(guest)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _guestAssignError ? Colors.red : const Color(0xFFDADDE3),
          width: _guestAssignError ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group, size: 18, color: Constants.kPrimaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Assign this room to (${_assignedGuestKeys.length}/${selectable.length})",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (selectable.length > 1)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _assignedGuestKeys.clear();
                      if (!allSelected) {
                        _assignedGuestKeys.addAll(selectable.map(_guestKey));
                      }
                      _syncRoomCountToGuests();
                      _guestAssignError = false;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    allSelected ? "Clear" : "Select all",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ...widget.guests.map((guest) => _guestAssignmentRow(
                guest,
                locked.contains(_guestKey(guest)),
              )),
          if (selectable.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _assignableGuests.isEmpty
                    ? "Shared members share the room of the guest whose package they are on"
                    : "Every guest already has a room",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          if (_guestAssignError)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "Select at least one guest for this room",
                style: TextStyle(fontSize: 13, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  /// One guest. [locked] means they already have a room, so the row is greyed
  /// out and says so instead of offering the tick again. A shared member is
  /// shown the same way — they sleep in the room of the guest whose package
  /// they are on, so they are named here but never assigned one.
  Widget _guestAssignmentRow(AccompanyingMember guest, bool locked) {
    final key = _guestKey(guest);
    final shared = guest.sharedPackage;
    final disabled = shared || locked;
    final selected = _assignedGuestKeys.contains(key);
    final label = [
      if (guest.mid.trim().isNotEmpty) guest.mid.trim(),
      if (guest.guestName.trim().isNotEmpty) guest.guestName.trim(),
    ].join(" — ");

    return InkWell(
      onTap: disabled
          ? null
          : () {
              setState(() {
                if (selected) {
                  _assignedGuestKeys.remove(key);
                } else {
                  _assignedGuestKeys.add(key);
                }
                _syncRoomCountToGuests();
                _guestAssignError = false;
              });
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Checkbox(
                value: selected && !shared,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: disabled
                    ? null
                    : (checked) {
                        setState(() {
                          if (checked == true) {
                            _assignedGuestKeys.add(key);
                          } else {
                            _assignedGuestKeys.remove(key);
                          }
                          _syncRoomCountToGuests();
                          _guestAssignError = false;
                        });
                      },
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: disabled ? Colors.grey : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (shared) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_alt_outlined,
                        size: 13, color: Colors.orange.shade800),
                    const SizedBox(width: 4),
                    Text(
                      "Shared",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (locked) ...[
              Icon(Icons.check_circle_outline,
                  size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                "Already has a room",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ] else ...[
              Icon(
                guest.hasFamilyMembers
                    ? Icons.family_restroom
                    : Icons.person_outline,
                size: 16,
                color: guest.hasFamilyMembers
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                guest.hasFamilyMembers ? "Family included" : "No family",
                style: TextStyle(
                  fontSize: 13,
                  color: guest.hasFamilyMembers
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The first thing asked in the hotel section: which of the two lists the
  /// hotel comes from. Both arrive in the one catalog, so the answer only
  /// filters the dropdown below — switching type re-fetches nothing.
  Widget _hotelLocationPicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hotelLocationError ? Colors.red : const Color(0xFFDADDE3),
          width: _hotelLocationError ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.travel_explore,
                  size: 18, color: Constants.kPrimaryColor),
              SizedBox(width: 6),
              Text(
                "Hotel Type",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final location in HotelLocation.values) ...[
                Expanded(child: _hotelLocationOption(location)),
                if (location != HotelLocation.values.last)
                  const SizedBox(width: 10),
              ],
            ],
          ),
          if (_hotelLocationError)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Please choose a hotel type first",
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hotelLocationOption(HotelLocation location) {
    final bool selected = selectedHotelLocation == location;
    final IconData icon = location == HotelLocation.cityHotel
        ? Icons.location_city
        : Icons.landscape_outlined;

    return InkWell(
      onTap: () => _setHotelLocation(location),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? Constants.kPrimaryColor.withOpacity(0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected ? Constants.kPrimaryColor : const Color(0xFFDADDE3),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Constants.kPrimaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                location.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? Constants.kPrimaryColor : Colors.black87,
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
    // Rebuilds when the combined catalog lands so the hotel list fills in.
    // Both locations arrive in the one catalog; the type picked above decides
    // which half of it this dropdown offers.
    final hotelOptions = HotelRoomCatalogEntry.hotelsAsMapFrom(
      ref.watch(hotelCatalogProvider),
      location: selectedHotelLocation,
    );

    // A hotel row pulled in for editing selects its hotel and category before
    // the catalog is necessarily loaded — refill those dropdowns once it is.
    ref.listen<List<HotelRoomCatalogEntry>>(hotelCatalogProvider, (_, __) {
      if (selectedHotelId == null) return;
      // The refreshed catalog may have dropped what was picked, so settle the
      // selection against it before refilling anything that hangs off it.
      _dropStaleSelection();
      if (selectedHotelId == null) return;
      getSelectedHotelRoomCategories(selectedHotelId!, clearSelection: false);
      if (selectedRoomCategoryId != null) {
        getSelectedHotelCategoryRoomTypes(
          selectedHotelId!,
          selectedRoomCategoryId!,
          clearSelection: false,
        );
      }
    });
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Select Hotels & Rooms",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: "Close",
                  icon: const Icon(Icons.close),
                  onPressed: _closeSheet,
                ),
              ],
            ),
            const SizedBox(height: 5),
            // ── Scrollable Body ─────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // ── Assign this room to guests ─────────
                        if (widget.guests.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          _guestAssignment(),
                        ],

                        // ── Date Range ─────────────────────────
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _dateRangeController,
                          readOnly: true,
                          enabled: !_useReservationDates,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            labelText: "Select Date Range",
                            labelStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            border: const OutlineInputBorder(),
                            errorText: _dateRangeError ? "Required" : null,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _useReservationDates
                                  ? null
                                  : () => _selectDateRange(context),
                            ),
                          ),
                        ),

                        // ── Same as reservation dates ──────────
                        CheckboxListTile(
                          value: _useReservationDates,
                          onChanged: _hasReservationDates
                              ? _toggleUseReservationDates
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text(
                            "Same as Arrival & Departure Date",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            _hasReservationDates
                                ? _formatRange(
                                    widget.reservationArrivalDate!,
                                    widget.reservationDepartureDate!,
                                  )
                                : "Pick the reservation Arrival & Departure dates first",
                            style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        if (selectedDateRange != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                "$numberOfNights night(s)",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // ── Counters ───────────────────────────
                        _buildCounter("Adults", numberOfAdults, _updateAdults),
                        const SizedBox(height: 16),
                        _buildCounter(
                          "Children",
                          numberOfChildren,
                          _updateChildren,
                        ),
                        const SizedBox(height: 16),
                        _buildCounter(
                          "Rooms",
                          numberOfRooms,
                          _updateRooms,
                          enabled: !_roomCountLocked,
                        ),
                        const SizedBox(height: 16),

                        // ── Stale selection notice ─────────────
                        // Explains an emptied dropdown when the row being
                        // amended was booked against something the catalog no
                        // longer returns.
                        ValueListenableBuilder<String?>(
                          valueListenable: staleSelectionNotifier,
                          builder: (context, notice, _) {
                            if (notice == null) return const SizedBox.shrink();
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4E5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE0A800),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Color(0xFF8A6100),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      notice,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF8A6100),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // ── Hotel Type ─────────────────────────
                        _hotelLocationPicker(),
                        const SizedBox(height: 16),

                        // ── Hotel Dropdown ─────────────────────
                        DropdownSearch<Map<String, dynamic>>(
                          enabled: selectedHotelLocation != null,
                          selectedItem: selectedHotel,
                          items: (filter, infiniteScrollProps) => hotelOptions,
                          itemAsString: (item) => item['HotelName'] ?? '',
                          compareFn: (a, b) => a['Hotel_IID'] == b['Hotel_IID'],
                          decoratorProps: DropDownDecoratorProps(
                            decoration: InputDecoration(
                              labelText: selectedHotelLocation == null
                                  ? 'Select Hotel  (choose hotel type first)'
                                  : 'Select Hotel',
                              labelStyle: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              border: const OutlineInputBorder(),
                              errorText: _hotelError ? "Required" : null,
                            ),
                          ),
                          suffixProps: DropdownSuffixProps(
                            dropdownButtonProps: DropdownButtonProps(
                              iconClosed: Icon(Icons.arrow_drop_down, size: 30),
                              iconOpened: Icon(Icons.arrow_drop_up, size: 30),
                            ),
                          ),
                          dropdownBuilder: (context, selectedItem) {
                            return Text(
                              selectedItem?['HotelName'] ?? '',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                          onChanged: _setHotel,
                          popupProps: PopupProps.dialog(
                            showSearchBox: true,
                            searchFieldProps: const TextFieldProps(
                              autofocus: true,
                            ),
                            itemBuilder:
                                (context, item, isSelected, isFocused) {
                                  return ListTile(
                                    title: Text(
                                      item['HotelName'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    selected: isSelected,
                                    tileColor: isFocused
                                        ? Colors.grey.shade200
                                        : null,
                                  );
                                },
                            dialogProps: DialogProps(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Room Category Dropdown ─────────────
                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: roomCategoriesNotifier,
                          builder: (context, roomCategories, _) {
                            return DropdownSearch<Map<String, dynamic>>(
                              selectedItem: selectedRoomCategory,
                              items: (filter, infiniteScrollProps) =>
                                  roomCategories,
                              itemAsString: _categoryWithGrade,
                              compareFn: (a, b) => a['CatCode'] == b['CatCode'],
                              decoratorProps: DropDownDecoratorProps(
                                decoration: InputDecoration(
                                  labelText: 'Select Category',
                                  labelStyle: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  border: const OutlineInputBorder(),
                                  errorText:
                                      _roomCategoryError ? "Required" : null,
                                ),
                              ),
                              suffixProps: DropdownSuffixProps(
                                dropdownButtonProps: DropdownButtonProps(
                                  iconClosed: Icon(
                                    Icons.arrow_drop_down,
                                    size: 30,
                                  ),
                                  iconOpened: Icon(
                                    Icons.arrow_drop_up,
                                    size: 30,
                                  ),
                                ),
                              ),
                              dropdownBuilder: (context, selectedItem) {
                                return Text(
                                  _categoryWithGrade(selectedItem),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                              onChanged: _setRoomCategory,
                              popupProps: PopupProps.dialog(
                                showSearchBox: true,
                                searchFieldProps: const TextFieldProps(
                                  autofocus: true,
                                ),
                                itemBuilder:
                                    (context, item, isSelected, isFocused) {
                                      final grade = _hotelCategoryLabel(item);
                                      return ListTile(
                                        title: Text(
                                          item['CatName'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: grade.isEmpty
                                            ? null
                                            : Text(
                                                grade,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                        selected: isSelected,
                                        tileColor: isFocused
                                            ? Colors.grey.shade200
                                            : null,
                                      );
                                    },
                                dialogProps: DialogProps(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Room Type Dropdown ─────────────────
                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: roomTypesNotifier,
                          builder: (context, roomTypes, _) {
                            return DropdownSearch<Map<String, dynamic>>(
                              selectedItem: selectedRoomType,
                              items: (filter, infiniteScrollProps) => roomTypes,
                              itemAsString: (item) {
                                final rt = item['RoomType'] ?? '';
                                final mp = item['MealPlan'] ?? '';
                                return '$rt - $mp';
                              },
                              compareFn: (a, b) => a['ID'] == b['ID'],
                              decoratorProps: DropDownDecoratorProps(
                                decoration: InputDecoration(
                                  labelText: 'Select Room Type',
                                  labelStyle: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  border: const OutlineInputBorder(),
                                  errorText: _roomTypeError ? "Required" : null,
                                ),
                              ),
                              dropdownBuilder: (context, selectedItem) {
                                if (selectedItem == null) return const Text('');
                                final rt = selectedItem['RoomType'] ?? '';
                                final mp = selectedItem['MealPlan'] ?? '';
                                final rate =
                                    HotelRoomCatalogEntry.ourRateLabelOf(
                                        selectedItem);
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$rt - $mp',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (rate.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        rate,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Constants.kPrimaryColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                              onChanged: _setRoomType,
                              popupProps: PopupProps.dialog(
                                showSearchBox: true,
                                searchFieldProps: const TextFieldProps(
                                  autofocus: true,
                                ),
                                itemBuilder:
                                    (context, item, isSelected, isFocused) {
                                      final rt = item['RoomType'] ?? '';
                                      final mp = item['MealPlan'] ?? '';
                                      final rate = HotelRoomCatalogEntry
                                          .ourRateLabelOf(item);
                                      return ListTile(
                                        title: Text(
                                          '$rt - $mp',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        trailing: rate.isEmpty
                                            ? null
                                            : Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  const Text(
                                                    'Our Rate',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  Text(
                                                    rate,
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Constants
                                                          .kPrimaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        selected: isSelected,
                                        tileColor: isFocused
                                            ? Colors.grey.shade200
                                            : null,
                                      );
                                    },
                                dialogProps: DialogProps(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
// ── EC/LCO Facility Dropdown ────────────────────────────
DropdownButtonFormField<String>(
  value: selectedEcLcoFacility,
  decoration: const InputDecoration(
    labelText: 'EC/LCO Facility',
    labelStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    border: OutlineInputBorder(),
  ),
  style: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  ),
  icon: const Icon(Icons.arrow_drop_down, size: 30),
  items: const [
    DropdownMenuItem(value: 'NA',        child: Text('NA')),
    DropdownMenuItem(value: 'ECI',       child: Text('ECI')),
    DropdownMenuItem(value: 'LCO',       child: Text('LCO')),
    DropdownMenuItem(value: 'ECI & LCO', child: Text('ECI & LCO')),
  ],
  onChanged: (value) {
    setState(() => selectedEcLcoFacility = value ?? 'NA');
  },
),
const SizedBox(height: 16),
DropdownButtonFormField<String>(
  value: selectedByPaymnet,
  decoration: const InputDecoration(
    labelText: 'Payment By',
    labelStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    border: OutlineInputBorder(),
  ),
  style: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  ),
  icon: const Icon(Icons.arrow_drop_down, size: 30),
  items: _isBellagio
      ? const [
          DropdownMenuItem(value: 'N/A',               child: Text('N/A')),
          DropdownMenuItem(value: 'By Guest',          child: Text('By Guest')),
          DropdownMenuItem(value: 'By Beyond Borders', child: Text('By Beyond Borders')),
          DropdownMenuItem(value: 'By Guest & Beyond', child: Text('By Guest & Beyond Borders')),
        ]
      : const [
          DropdownMenuItem(value: 'NA',                child: Text('NA')),
          DropdownMenuItem(value: 'By Guest',          child: Text('By Guest')),
          DropdownMenuItem(value: 'By Hamoos ',        child: Text('By Hamoos')),
          DropdownMenuItem(value: 'By Guest & Hamoos', child: Text('By Guest & Hamoos')),
        ],
  onChanged: (value) {
    setState(() => selectedByPaymnet = value ?? (_isBellagio ? 'N/A' : 'NA'));
  },
),
const SizedBox(height: 16),
                        // ── Cost Calculator Button ─────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _calculateCost,
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Estimated Cost ─────────────────────
                        ValueListenableBuilder<String>(
                          valueListenable: costNotifier,
                          builder: (context, cost, _) {
                            final hasNoCost = cost == "0";
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasNoCost
                                        ? "Est. Cost: No cost calculation done"
                                        : "Est. Cost $cost",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: hasNoCost
                                          ? const Color.fromARGB(
                                              255, 255, 30, 0)
                                          : Colors.black,
                                    ),
                                  ),
                                  // The sum behind the figure, so the rate the
                                  // room type carries is checkable without
                                  // re-opening the dropdown.
                                  ValueListenableBuilder<String?>(
                                    valueListenable: costBreakdownNotifier,
                                    builder: (context, breakdown, _) {
                                      if (breakdown == null || hasNoCost) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Text(
                                          breakdown,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Add / Update Hotel Button ──────────
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _saveHotelSelection,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: editMode
                                  ? Colors.green
                                  : Constants.kSecondaryColor,
                              side: BorderSide(
                                color: editMode
                                    ? Colors.green
                                    : Constants.kSecondaryColor,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              editMode ? "Update Hotel" : "Add Hotel",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // ── Cancel Edit Button ─────────────────
                        if (editMode) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _clearSelection,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey,
                                side: const BorderSide(
                                  color: Colors.grey,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // ── Hotel List ─────────────────────────
                        hotelList.isEmpty
                            ? const Center(
                                heightFactor: 4.0,
                                child: Text(
                                  'No hotels added yet.',
                                  style: TextStyle(fontSize: 16),
                                ),
                              )
                            : Column(
                                children: hotelList.map((hotel) {
                                  final index = hotelList.indexOf(hotel);
                                  return SizedBox(
                                    width: double.infinity,
                                    child: GestureDetector(
                                      onDoubleTap: () =>
                                          _editHotel(hotel, index),
                                      child: Card(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                          vertical: 8,
                                        ),
                                        child: Stack(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                12.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    hotel.hotelName!,
                                                    style: const TextStyle(
                                                      fontSize: 19,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                  // Who the room is booked for
                                                  // — the whole point of the
                                                  // ticks above the form.
                                                  if (hotel.assignedGuests
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Icon(
                                                          Icons.group,
                                                          size: 16,
                                                          color: Constants
                                                              .kPrimaryColor,
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            hotel
                                                                .assignedGuests
                                                                .map((g) =>
                                                                    g.label)
                                                                .join(", "),
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Constants
                                                                  .kPrimaryColor,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                  const SizedBox(height: 8),
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        const TextSpan(
                                                          text: "Category: ",
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: hotel
                                                              .roomCategoryName,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 18,
                                                                color: Colors
                                                                    .black,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
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
                                                            fontSize: 18,
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: hotel
                                                              .roomTypeName,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 18,
                                                                color: Colors
                                                                    .black,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
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
                                                          text:
                                                              "Arrival Date: ",
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              hotel.arrivalDate !=
                                                                  null
                                                              ? DateFormat(
                                                                  'yyyy-MM-dd',
                                                                ).format(
                                                                  hotel
                                                                      .arrivalDate!,
                                                                )
                                                              : '',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 18,
                                                                color: Colors
                                                                    .black,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
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
                                                          text:
                                                              "Departure Date: ",
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              hotel.arrivalDate !=
                                                                  null
                                                              ? DateFormat(
                                                                  'yyyy-MM-dd',
                                                                ).format(
                                                                  hotel
                                                                      .departureDate!,
                                                                )
                                                              : '',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 18,
                                                                color: Colors
                                                                    .black,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 20,
                                                    runSpacing: 4,
                                                    children: [
                                                      Text(
                                                        "Guest Count: ${hotel.guestCount}",
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        "Children: ${hotel.childrenCount ?? 0}",
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        "Rooms: ${hotel.roomCount}",
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        "Nights: ${hotel.noOfNights}",
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),

                                                  // ── Cost display with soft warning ──
                                                  Builder(
                                                    builder: (context) {
                                                      final hasNoCost =
                                                          hotel.selectedCost ==
                                                              null ||
                                                          hotel.selectedCost ==
                                                              "0";
                                                      return Text(
                                                        hasNoCost
                                                            ? "Estimated Cost: No cost calculation done"
                                                            : "Estimated Cost: LKR ${hotel.selectedCost}",
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: hasNoCost
                                                              ? const Color.fromARGB(255, 255, 30, 0)
                                                              : Colors.black,
                                                        ),
                                                      );
                                                    },
                                                  ),

                                                  const SizedBox(height: 24),
                                                  const Text(
                                                    "Double-tap to edit",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    _removeHotel(index),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                        const SizedBox(height: 16),

                        // ── Accept Changes Button ──────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: hotelList.isNotEmpty
                                ? _acceptChanges
                                : null,
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
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
  final List<HotelCostResponse>? hotelCosts;
  final Function(HotelCostResponse, int) onItemSelected;

  const CostCalculatorBottomSheet({
    super.key,
    required this.onBackPressed,
    required this.hotelCosts,
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
          // ── Header ──────────────────────────────────────────
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

          // ── Tabs ─────────────────────────────────────────────
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

          // ── Tab Views ────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // General tab
                widget.hotelCosts == null || widget.hotelCosts!.isEmpty
                    ? const Center(
                        child: Text(
                          "No data available.",
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.hotelCosts!.length,
                        itemBuilder: (context, index) {
                          final cost = widget.hotelCosts![index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
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
                                      Text(
                                        "Check-In: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(cost.checkIn!))}",
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "Check-Out: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(cost.checkOut!))}",
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const Text("Net Rate: "),
                                      Text(
                                        cost.netRate!.toStringAsFixed(2),
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                // Guest's Prev Data tab
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