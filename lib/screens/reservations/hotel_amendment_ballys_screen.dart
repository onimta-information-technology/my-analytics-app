import 'package:ballys_reservation_app/components/amendment_guest_header_ballys.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/hotel_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:ballys_reservation_app/models/guest_reservation_entryBallys.dart';
import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/models/reservation/assigned_guest.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc_ballys.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_room_catalog_entry.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/hotel_catalog_provider.dart';
import 'package:ballys_reservation_app/providers/selectedReservationforBallys_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider_ballys.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// One room booked on the reservation together with the people it may be
/// amended for.
///
/// [guests] is what the room itself came back with — `assigned_guests` names
/// everyone the room is booked for, so the guest list is the room's own rather
/// than the reservation's. Rooms saved before the assignment existed carry an
/// empty list and belong to the guest whose entry they sit in, which is the
/// only case [owner] stands in for.
@immutable
class _AmendableRoom {
  const _AmendableRoom({required this.hotel, required this.guests});

  final HotelDescipBallys hotel;
  final List<AssignedGuest> guests;
}

/// Everything picked against one room: who it is being amended for, and what
/// the amendment is. Held per room rather than per screen — a reservation can
/// carry several rooms and each is amended in its own right.
class _RoomAmendmentDraft {
  /// Positions within the room's own guest list. Positions rather than BM
  /// numbers: a room can name a guest whose `BMNumber` came back blank.
  final Set<int> guests = <int>{};

  String? category;

  // ── Dates ──────────────────────────────────────────────────────────────
  //
  // Date Change only — it is the one category that moves the stay itself. Null
  // is "not picked yet", not "unchanged": the days the room moves *from* are
  // the room's own, and either day may be left alone.

  DateTime? newArrivalDate;
  DateTime? newDepartureDate;

  // ── Hotel / category / room type ───────────────────────────────────────
  //
  // Hotel Change asks for all three (a hotel carries its own categories, so a
  // category picked against the old hotel cannot follow the room across);
  // Room Category asks for the last two against the hotel the room already
  // holds.

  double? newHotelId;
  String? newHotelName;
  int? newRoomCategoryId;
  String? newRoomCategoryName;
  int? newRoomTypeId;
  String? newRoomTypeName;

  /// Which room type is picked, as "ROOMTYPE|MEALPLAN" — the catalog endpoint
  /// sends no room id, so this is what the dropdown selects on and what says a
  /// room type was chosen at all.
  String? newRoomTypeKey;

  /// What the room is asked to carry on top of what was booked — extra bed,
  /// airport transfer, and so on. Extras only.
  final TextEditingController extras = TextEditingController();

  // ── Occupancy ──────────────────────────────────────────────────────────
  //
  // Left blank means "unchanged", so a room moving from 2 adults to 3 without
  // touching its children only fills in the one field. Occupancy asks for all
  // three; a hotel change asks for the first two alongside the new room, since
  // a room moving hotel is re-costed on who is in it.
  /// Null is "not touched", which is what leaves a count as booked. Once a
  /// count is stepped it holds the number asked for, even where that is back to
  /// what the room already had.
  int? adults;
  int? children;
  int? rooms;

  bool get isEarlyCheckIn =>
      category == _HotelAmendmentBallysScreenState._earlyCheckIn;

  bool get isLateCheckOut =>
      category == _HotelAmendmentBallysScreenState._lateCheckOut;

  bool get isDateChange =>
      category == _HotelAmendmentBallysScreenState._dateChange;

  bool get isExtras => category == _HotelAmendmentBallysScreenState._extras;

  bool get isHotelChange =>
      category == _HotelAmendmentBallysScreenState._hotelChange;

  bool get isRoomCategory =>
      category == _HotelAmendmentBallysScreenState._roomCategory;

  bool get isOccupancy =>
      category == _HotelAmendmentBallysScreenState._occupancy;

  /// Whether the category picked has been filled in far enough to stand as an
  /// amendment.
  ///
  /// Early Check-in and Late Check-out stand on the category alone: the room
  /// already holds the days they apply to, so naming the category says the
  /// whole amendment.
  bool get hasDetail {
    if (isEarlyCheckIn || isLateCheckOut) return true;
    if (isDateChange) {
      return newArrivalDate != null || newDepartureDate != null;
    }
    if (isExtras) return extras.text.trim().isNotEmpty;
    if (isHotelChange) return newHotelId != null;
    if (isRoomCategory) {
      return newRoomCategoryId != null || newRoomTypeKey != null;
    }
    if (isOccupancy) {
      return adults != null ||
          children != null ||
          rooms != null ||
          newRoomTypeKey != null;
    }
    return false;
  }

  /// A room counts as amended once someone is picked, the amendment is named
  /// and it says what the room moves to.
  bool get isComplete => guests.isNotEmpty && category != null && hasDetail;

  /// Drops the detail of whatever category was picked before. Every category's
  /// detail goes, not just the one on screen: the fields are shared, so an
  /// occupancy typed against one category must not follow the room into
  /// another.
  void clearCategoryDetail() {
    newArrivalDate = null;
    newDepartureDate = null;
    newHotelId = null;
    newHotelName = null;
    newRoomCategoryId = null;
    newRoomCategoryName = null;
    newRoomTypeId = null;
    newRoomTypeName = null;
    newRoomTypeKey = null;
    extras.clear();
    adults = null;
    children = null;
    rooms = null;
  }

  /// Puts the room back the way it opened: nobody picked, no category, no
  /// detail. Used once an amendment has gone through, so what was submitted is
  /// not left sitting on the screen ready to be sent a second time. The
  /// controllers are kept — the widgets on screen still hold them — and only
  /// their text goes.
  void reset() {
    guests.clear();
    category = null;
    clearCategoryDetail();
  }

  void dispose() {
    extras.dispose();
  }
}

/// Hotel side of the reservation amendment flow.
///
/// Reached from the Amendment button on `ReservationViewScreenBallys` (Pending
/// only) after choosing "Hotel". The screen reads room-first, the same way the
/// air ticket screen reads ticket-first: every room booked on the reservation
/// is listed, ticking one opens the guests that room came back with, and the
/// amendment is then raised against the guests ticked on that room. Rooms come
/// from `selectedHotelBallysProvider`, which the detail view already populated.
class HotelAmendmentBallysScreen extends ConsumerStatefulWidget {
  const HotelAmendmentBallysScreen({super.key});

  @override
  ConsumerState<HotelAmendmentBallysScreen> createState() =>
      _HotelAmendmentBallysScreenState();
}

class _HotelAmendmentBallysScreenState
    extends ConsumerState<HotelAmendmentBallysScreen> {
  bool _submitting = false;

  // ── Amendment category ─────────────────────────────────────────────────
  //
  // One level, unlike the air ticket's category → type: a hotel amendment is
  // named by what it moves, and each of these carries its own detail below.
  static const String _earlyCheckIn = 'Early Check-in';
  static const String _lateCheckOut = 'Late Check-out';
  static const String _dateChange = 'Date Change';
  static const String _extras = 'Extras';
  static const String _hotelChange = 'Hotel Change';
  static const String _roomCategory = 'Room Category';
  static const String _occupancy = 'Occupancy';

  static const List<String> _categories = [
    _earlyCheckIn,
    _lateCheckOut,
    _dateChange,
    _extras,
 _occupancy,
    _roomCategory,
        _hotelChange,
   
  ];

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Per-room state, keyed by the room's position in the list built below. The
  /// screen is read-only, so that list — and these keys — hold still for as
  /// long as the screen is open.
  final Map<int, _RoomAmendmentDraft> _drafts = <int, _RoomAmendmentDraft>{};

  /// The rooms ticked, by position. Every room is picked in its own right —
  /// one amendment can cover several of a reservation's rooms, and each ticked
  /// room carries its own guests and its own amendment below.
  ///
  /// A room opens exactly when it is ticked: an unticked room is not part of
  /// the amendment, so there is nothing to show under it. Unticking keeps what
  /// was already filled in, so a room ticked again comes back as it was.
  final Set<int> _selectedRooms = <int>{};

  /// True while the hotel catalog is being fetched, so the hotel / category
  /// dropdowns can say they are not ready yet rather than opening onto nothing.
  bool _isLoadingCatalog = false;

  @override
  void initState() {
    super.initState();
    // The hotel and room category dropdowns read a catalog nothing on this
    // screen's way in fills: it is loaded by whichever screen offers those
    // dropdowns, and an amendment opened straight off the reservation view has
    // passed none of them. Left alone, the dropdowns open empty.
    //
    // Deferred past the first frame: this writes to a provider, which must not
    // happen while the widget is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalog());
  }

  Future<void> _loadCatalog() async {
    try {
      if (ref.read(hotelCatalogProvider).isEmpty) {
        setState(() => _isLoadingCatalog = true);
        await ref.read(hotelCatalogProvider.notifier).load();
        if (!mounted) return;
        setState(() => _isLoadingCatalog = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCatalog = false);
    }
  }

  /// Fetches the catalog again after a dropped request, from the Retry the
  /// hotel dropdowns offer when they have nothing to list.
  Future<void> _reloadCatalog() async {
    if (_isLoadingCatalog) return;
    setState(() => _isLoadingCatalog = true);
    try {
      await ref.read(hotelCatalogProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _isLoadingCatalog = false);
    }
  }

  @override
  void dispose() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  _RoomAmendmentDraft _draftFor(int index) =>
      _drafts.putIfAbsent(index, () => _RoomAmendmentDraft());

  // ── Rooms and the guests on them ───────────────────────────────────────

  /// Every room on the reservation, each with the guests it is booked for.
  ///
  /// The reservation's own room list is what the screen counts, NOT the rooms
  /// hanging off the guest entries: a room lands on a guest entry only when the
  /// guest it is booked for is one, and the first guest on a room can just as
  /// easily be a member sharing someone's package — members are folded into the
  /// guest that owns them and hold no `hotels`. Reading the guests would drop
  /// those rooms, so a reservation with two rooms could show one.
  ///
  /// The guest entries are still walked, but only to name the guest behind a
  /// room that came back with no assignment at all.
  List<_AmendableRoom> _rooms(
    ReservationBallys reservation,
    List<HotelDescipBallys> reservationHotels,
  ) {
    final guestRooms = <HotelDescipBallys>[];
    // Which guest entry a room sits in, for the rooms that name nobody. Keyed
    // by what the room is rather than by identity: the reservation's list and
    // the guests' lists are parsed separately off the same rows, so the same
    // room arrives as two objects.
    final owners = <String, GuestReservationEntryBallys>{};
    for (final guest in reservation.guests) {
      for (final hotel in guest.hotels) {
        guestRooms.add(hotel);
        owners.putIfAbsent(_roomSignature(hotel), () => guest);
      }
    }

    // Payloads that carry the rooms only on the guests leave the reservation's
    // own list empty, so those guests' rooms stand in.
    final source = reservationHotels.isNotEmpty
        ? reservationHotels
        : (reservation.hotelDescip.isNotEmpty
              ? reservation.hotelDescip
              : guestRooms);

    return source
        .map(
          (hotel) => _AmendableRoom(
            hotel: hotel,
            guests: _guestsOn(hotel, owners[_roomSignature(hotel)]),
          ),
        )
        .toList();
  }

  /// What a room is, as a string — enough of it to recognise the same room
  /// parsed twice off the same row. Two genuinely identical rooms share a
  /// signature, which is harmless: it is only used to look up a name to fall
  /// back to.
  static String _roomSignature(HotelDescipBallys hotel) {
    return [
      hotel.hotelName ?? '',
      hotel.roomCategoryName ?? '',
      hotel.roomTypeName ?? '',
      hotel.arrivalDate?.toIso8601String() ?? '',
      hotel.departureDate?.toIso8601String() ?? '',
      hotel.roomCount?.toString() ?? '',
      hotel.guestCount?.toString() ?? '',
      hotel.noOfNights?.toString() ?? '',
    ].join('|');
  }

  /// The hotel a room is booked at, as the catalog keys its hotels. The field
  /// is `dynamic`: it is saved as the id the picker held and comes back off the
  /// API as whatever that column carries.
  static double? _hotelIdOf(HotelDescipBallys hotel) {
    final value = hotel.hotel;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  /// The people a room may be amended for: whoever the API named on the room,
  /// falling back to [owner] for rooms that carry no assignment.
  List<AssignedGuest> _guestsOn(
    HotelDescipBallys hotel,
    GuestReservationEntryBallys? owner,
  ) {
    final assigned = hotel.assignedGuests
        .where((g) => g.mid.trim().isNotEmpty || g.guestName.trim().isNotEmpty)
        .toList();
    if (assigned.isNotEmpty) return assigned;

    if (owner == null) return const [];
    if (owner.mid.trim().isEmpty && owner.guestName.trim().isEmpty) {
      return const [];
    }
    return [AssignedGuest(mid: owner.mid, guestName: owner.guestName)];
  }

  void _toggleRoom(int index) {
    setState(() {
      if (!_selectedRooms.remove(index)) _selectedRooms.add(index);
    });
  }

  void _toggleGuest(int roomIndex, int guestIndex) {
    setState(() {
      final draft = _draftFor(roomIndex);
      if (!draft.guests.remove(guestIndex)) draft.guests.add(guestIndex);
    });
  }

  void _onCategoryChanged(int roomIndex, String? value) {
    final draft = _draftFor(roomIndex);
    if (value == draft.category) return;
    setState(() {
      draft.category = value;
      draft.clearCategoryDetail();
    });
  }

  /// Moving to another hotel drops the category and room type picked against
  /// the one before it — categories are the hotel's own, so a category kept
  /// across the change would name a room the new hotel does not offer.
  void _onNewHotelChanged(int roomIndex, double? hotelId) {
    final draft = _draftFor(roomIndex);
    if (hotelId == draft.newHotelId) return;
    final name = ref
        .read(hotelCatalogProvider)
        .where((e) => e.hotelId == hotelId)
        .map((e) => e.hotelName)
        .firstOrNull;
    setState(() {
      draft.newHotelId = hotelId;
      draft.newHotelName = name;
      draft.newRoomCategoryId = null;
      draft.newRoomCategoryName = null;
      draft.newRoomTypeId = null;
      draft.newRoomTypeName = null;
      draft.newRoomTypeKey = null;
    });
  }

  /// Room types belong to a category, so changing the category drops the type
  /// underneath it for the same reason a hotel change drops the category.
  void _onNewCategoryChanged(
    int roomIndex,
    int? categoryId,
    List<Map<String, dynamic>> categories,
  ) {
    final draft = _draftFor(roomIndex);
    if (categoryId == draft.newRoomCategoryId) return;
    final category = categories
        .where((c) => c['CatCode'] == categoryId)
        .firstOrNull;
    setState(() {
      draft.newRoomCategoryId = categoryId;
      draft.newRoomCategoryName = category?['CatName'] as String?;
      draft.newRoomTypeId = null;
      draft.newRoomTypeName = null;
      draft.newRoomTypeKey = null;
    });
  }

  void _onNewRoomTypeChanged(
    int roomIndex,
    String? roomTypeKey,
    List<Map<String, dynamic>> roomTypes,
  ) {
    final draft = _draftFor(roomIndex);
    final roomType = roomTypes
        .where((t) => HotelRoomCatalogEntry.roomTypeKeyOf(t) == roomTypeKey)
        .firstOrNull;
    setState(() {
      draft.newRoomTypeKey = roomType == null ? null : roomTypeKey;
      // 0 on everything the catalog endpoint returns — the room's own id is no
      // longer sent, so the name is what names the room to the back office.
      draft.newRoomTypeId = roomType?['ID'] as int?;
      draft.newRoomTypeName = roomType == null
          ? null
          : "${roomType['RoomType']} - ${roomType['MealPlan']}";
    });
  }

  // ── Building blocks ────────────────────────────────────────────────────

  InputDecoration _dropdownDeco(String label, FontSettings fontSettings) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: fontSettings.fontSize,
        fontWeight: fontSettings.fontWeight,
      ),
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 4.0,
      ),
    );
  }

  /// A dropdown that shows exactly what the draft holds.
  ///
  /// Deliberately a plain [DropdownButton] rather than a
  /// [DropdownButtonFormField]: the form field keeps the pick in its own state
  /// and only reports it through a callback, so the field could show a hotel
  /// the draft never received — which is what left the category and room type
  /// dropdowns saying "pick the hotel first" under a hotel that was plainly
  /// picked. Here the value shown *is* the draft's, so the two cannot part.
  ///
  /// [enabled] is separate from `items`: a dropdown with nothing to offer stays
  /// on screen and says what it is waiting for, rather than coming and going.
  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required FontSettings fontSettings,
    String? helperText,
  }) {
    final enabled = items.isNotEmpty;
    // A value the list no longer carries would assert inside [DropdownButton].
    // The lists are refilled from the catalog, which can be reloaded under a
    // pick, so the field falls back to its hint rather than bringing the screen
    // down.
    final shown = items.any((item) => item.value == value) ? value : null;
    return InputDecorator(
      decoration: _dropdownDeco(label, fontSettings).copyWith(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        helperText: helperText,
        helperMaxLines: 3,
        helperStyle: TextStyle(
          fontSize: fontSettings.fontSize - 3,
          color: Colors.grey.shade700,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: shown,
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
            color: Colors.black,
          ),
          hint: Text(
            hint,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
              color: Colors.grey.shade600,
            ),
          ),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  /// Picks one of the days a room moves to, in the same wheel the room was
  /// booked with.
  ///
  /// [current] is what is already picked, [roomDate] the day the room holds
  /// now — the wheel opens on the first of those it has. A room booked for a
  /// day that has since passed still opens on its own day rather than being
  /// dragged forward, so the bounds stretch to whatever it opens on.
  ///
  /// [mustBeAfter] refuses a day that would land on or before it, which is how
  /// a departure is kept after its arrival.
  Future<void> _pickDate({
    required String title,
    required DateTime? current,
    required DateTime? roomDate,
    required ValueChanged<DateTime> onPicked,
    DateTime? mustBeAfter,
  }) async {
    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final DateTime initial = current ?? roomDate ?? now;
    final DateTime minimum = initial.isBefore(now) ? initial : now;
    final DateTime yearOut = DateTime(now.year + 1, now.month, now.day);
    final DateTime maximum = initial.isAfter(yearOut) ? initial : yearOut;

    DateTime selectedDate = initial;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Select $title",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                minimumDate: minimum,
                maximumDate: maximum,
                onDateTimeChanged: (DateTime newDate) {
                  selectedDate = newDate;
                },
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () {
                final picked = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                );
                if (mustBeAfter != null && !picked.isAfter(mustBeAfter)) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Departure date must be after arrival date',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                setState(() => onPicked(picked));
                Navigator.of(sheetContext).pop();
              },
              child: const Text(
                "Confirm",
                style: TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
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

  /// "Currently: 2026-08-20" — the day the room holds now, for a field asking
  /// what it moves to.
  static String _currentlyLabel(DateTime? roomDate) {
    return roomDate == null
        ? "Not set on this room"
        : "Currently: ${_dateFormat.format(roomDate)}";
  }

  /// One of the room's new days. Reads empty until it is picked, with the day
  /// the room holds now underneath — the amendment says what changes, so the
  /// old day is shown rather than pre-filled and mistaken for a new one.
  Widget _dateField({
    required String label,
    required DateTime? value,
    required FontSettings fontSettings,
    required VoidCallback onTap,
    String? helperText,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _dropdownDeco(label, fontSettings).copyWith(
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
          helperText: helperText,
          helperMaxLines: 2,
          helperStyle: TextStyle(
            fontSize: fontSettings.fontSize - 3,
            color: Colors.grey.shade700,
          ),
        ),
        child: Text(
          value == null ? "Select date" : _dateFormat.format(value),
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
            color: value == null ? Colors.grey.shade600 : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required FontSettings fontSettings,
    int maxLines = 1,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      style: TextStyle(
        fontSize: fontSettings.fontSize,
        fontWeight: fontSettings.fontWeight,
      ),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
        labelStyle: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
        ),
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 12.0,
        ),
      ),
    );
  }

  /// One of the occupancy counts, stepped up and down.
  ///
  /// [current] is what the room holds now and is what the counter opens on:
  /// the amendment sends a count only once it has been stepped, so an untouched
  /// counter reads as the booking rather than as a change. [minimum] is the
  /// floor the room cannot go below — a room holds at least one of itself and
  /// at least one adult, while children can go to none.
  Widget _counterField({
    required String label,
    required int? value,
    required int? current,
    required int minimum,
    required ValueChanged<int> onChanged,
    required FontSettings fontSettings,
  }) {
    final booked = current ?? minimum;
    final shown = value ?? booked;
    final changed = value != null && value != booked;

    Widget button(IconData icon, int next, bool enabled) {
      return GestureDetector(
        onTap: enabled ? () => onChanged(next) : null,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: enabled ? Constants.kPrimaryColor : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
    }

    return InputDecorator(
      decoration: _dropdownDeco(label, fontSettings).copyWith(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        // Says what the room was booked with, so a stepped count reads as a
        // change rather than as the booking itself.
        helperText: "Currently: $booked",
        helperStyle: TextStyle(
          fontSize: fontSettings.fontSize - 3,
          color: Colors.grey.shade700,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 8.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          button(Icons.remove, shown - 1, shown > minimum),
          // Two counters share a row, so the number gives way to the buttons
          // rather than overflowing when the font setting is turned up.
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "$shown",
                  style: TextStyle(
                    fontSize: fontSettings.fontSize + 2,
                    fontWeight: FontWeight.bold,
                    // A count that has moved off the booking stands out, so
                    // the amendment reads at a glance.
                    color: changed ? Constants.kPrimaryColor : Colors.black,
                  ),
                ),
              ),
            ),
          ),
          button(Icons.add, shown + 1, true),
        ],
      ),
    );
  }

  /// "2 GUESTS, 1 ROOM" — the same summary line the detail view shows above the
  /// hotel cards.
  static String _guestAndRoomCounts(List<HotelDescipBallys> hotels) {
    final totalGuests = hotels.fold<int>(
      0,
      (sum, hotel) => sum + (hotel.guestCount ?? 0),
    );
    final totalRooms = hotels.fold<int>(
      0,
      (sum, hotel) => sum + (hotel.roomCount ?? 0),
    );

    String txt = totalGuests == 1
        ? "$totalGuests GUEST"
        : "$totalGuests GUESTS";
    txt += totalRooms == 1 ? ", $totalRooms ROOM" : ", $totalRooms ROOMS";
    return txt;
  }

  Widget _labelled(
    String label,
    String value,
    FontSettings fontSettings, {
    bool boldLabel = true,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSettings.fontSize + 2,
              fontWeight: boldLabel ? FontWeight.bold : fontSettings.fontWeight,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
            ),
          ),
        ],
      ),
    );
  }

  /// The room's own row: its checkbox, enough of the room to tell it from the
  /// others, and how far its amendment has got.
  Widget _roomSummary(
    int index,
    _AmendableRoom room,
    _RoomAmendmentDraft draft,
    bool isSelected,
    FontSettings fontSettings,
  ) {
    final hotel = room.hotel;
    final selectedCount = draft.guests.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The room is picked in its own right, so the checkbox stands where
          // the plain number used to; the number rides along beside it so a
          // room can still be referred to by position.
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: isSelected,
              activeColor: Constants.kPrimaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) => _toggleRoom(index),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 14,
            backgroundColor: isSelected
                ? Constants.kPrimaryColor
                : Colors.black,
            child: Text(
              "${index + 1}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.hotel, size: 18, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (hotel.hotelName ?? '').trim().isEmpty
                            ? "Unnamed hotel"
                            : hotel.hotelName!,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _labelled(
                  "Category: ",
                  hotel.roomCategoryName ?? '',
                  fontSettings,
                ),
                const SizedBox(height: 5),
                _labelled(
                  "Room Type: ",
                  hotel.roomTypeName ?? '',
                  fontSettings,
                  boldLabel: false,
                ),
                const SizedBox(height: 6),
                Text(
                  "Arrival: ${hotel.arrivalDate != null ? _dateFormat.format(hotel.arrivalDate!) : 'N/A'}"
                  " · Departure: ${hotel.departureDate != null ? _dateFormat.format(hotel.departureDate!) : 'N/A'}",
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: fontSettings.fontWeight,
                  ),
                ),
                const SizedBox(height: 6),
                // Wrapped rather than a row: a fourth count runs past the
                // card on a narrow screen, and the font size is the user's to
                // set.
                Wrap(
                  spacing: 20,
                  runSpacing: 4,
                  children: [
                    Text(
                      "Guests: ${hotel.guestCount ?? 0}",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                    Text(
                      "Children: ${hotel.childrenCount ?? 0}",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                    Text(
                      "Nights: ${hotel.noOfNights ?? 0}",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                    Text(
                      "Rooms: ${hotel.roomCount ?? 0}",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                  ],
                ),
                if (hotel.ecLcoFacility != null &&
                    hotel.ecLcoFacility!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    "EC/LCO Facility: ${hotel.ecLcoFacility}",
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                ],
                if (hotel.paymentBy != null &&
                    hotel.paymentBy!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    "Payment By: ${hotel.paymentBy}",
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                ],
                // What has been picked so far, so an unticked room still says
                // what was filled in before it was put aside.
                if (selectedCount > 0 || draft.category != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (selectedCount > 0)
                        selectedCount == 1
                            ? "1 guest selected"
                            : "$selectedCount guests selected",
                      if (draft.category != null) draft.category!,
                    ].join(" · "),
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: FontWeight.bold,
                      color: Constants.kPrimaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            isSelected ? Icons.expand_less : Icons.expand_more,
            color: Colors.black54,
          ),
        ],
      ),
    );
  }

  /// The guests this room is booked for, each ticked in their own right — an
  /// amendment can be raised for one guest on a shared room without touching
  /// the others.
  Widget _guestPicker(
    int index,
    _AmendableRoom room,
    _RoomAmendmentDraft draft,
    FontSettings fontSettings,
  ) {
    if (room.guests.isEmpty) {
      return Text(
        "This room came back without any guests, so there is nobody to "
        "amend it for.",
        style: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
          color: const Color.fromARGB(255, 168, 49, 49),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          room.guests.length == 1
              ? "Guest on this room"
              : "Guests on this room (${room.guests.length})",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        ...room.guests.asMap().entries.map((entry) {
          final guest = entry.value;
          final isSelected = draft.guests.contains(entry.key);
          final name = guest.guestName.trim().isNotEmpty
              ? guest.guestName.trim()
              : "Unnamed guest";

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => _toggleGuest(index, entry.key),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                decoration: BoxDecoration(
                  // A ticked guest lifts out of the grey so the chosen ones
                  // read at a glance without scanning the checkboxes.
                  color: isSelected
                      ? const Color.fromARGB(255, 245, 233, 208)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? Constants.kPrimaryColor
                        : Colors.grey.shade400,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                        value: isSelected,
                        activeColor: Constants.kPrimaryColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (_) => _toggleGuest(index, entry.key),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          if (guest.mid.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              guest.mid.trim(),
                              style: TextStyle(
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// The hotel the amendment's category and room type are read against: the one
  /// it is moving to on a Hotel Change, the one the room already holds
  /// otherwise.
  ///
  /// A booked room carries whatever id it was saved with, which need not be one
  /// the catalog still keys its hotels by — the row can also come back without
  /// the id at all. Either way the categories would be read against a hotel the
  /// catalog does not hold and come back empty, leaving the category dropdown
  /// with nothing to open. So the name it was booked under stands in.
  double? _catalogHotelFor(_RoomAmendmentDraft draft, HotelDescipBallys hotel) {
    if (draft.isHotelChange) return draft.newHotelId;

    final catalog = ref.read(hotelCatalogProvider);
    final id = _hotelIdOf(hotel);
    if (id != null && catalog.any((e) => e.hotelId == id)) return id;

    final name = (hotel.hotelName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final entry in catalog) {
      if (entry.hotelName.trim().toLowerCase() == name) return entry.hotelId;
    }
    return null;
  }

  /// The new hotel / category / room type block, shared by Hotel Change (which
  /// asks for all three) and Room Category (which asks for the last two against
  /// the hotel the room already holds).
  List<Widget> _catalogFields(
    int index,
    _RoomAmendmentDraft draft,
    HotelDescipBallys hotel,
    FontSettings fontSettings,
  ) {
    final catalog = ref.watch(hotelCatalogProvider);
    final notifier = ref.read(hotelCatalogProvider.notifier);
    final hotels = notifier.hotelsAsMap();
    final catalogHotelId = _catalogHotelFor(draft, hotel);

    final categories = catalogHotelId == null
        ? const <Map<String, dynamic>>[]
        : notifier.categoriesFor(catalogHotelId);

    // What each dropdown has to say for itself. Both stand whether or not they
    // have anything to offer yet: a dropdown that comes and goes reads as a
    // missing field, so an empty one says what it is waiting for instead.
    final String? categoryHelper;
    if (draft.isHotelChange && draft.newHotelId == null) {
      categoryHelper =
          "Pick the new hotel first — categories are the hotel's own";
    } else if (catalogHotelId == null) {
      categoryHelper =
          "This room's hotel is not in the catalog, so its categories cannot "
          "be listed.";
    } else if (categories.isEmpty) {
      categoryHelper = "This hotel carries no room categories in the catalog";
    } else if (draft.isHotelChange) {
      categoryHelper = "Leave blank to keep the current category";
    } else {
      categoryHelper = null;
    }

    // The catalog has to land before any of these can be opened. A fetch that
    // dropped leaves nothing to pick from, so the block offers it again rather
    // than sending the user back out of the amendment to try once more.
    if (catalog.isEmpty) {
      return [
        Row(
          children: [
            if (_isLoadingCatalog) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                _isLoadingCatalog
                    ? "Loading hotels…"
                    : "Hotels could not be loaded.",
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                  color: _isLoadingCatalog
                      ? Colors.grey.shade700
                      : const Color.fromARGB(255, 168, 49, 49),
                ),
              ),
            ),
            if (!_isLoadingCatalog)
              TextButton.icon(
                onPressed: _reloadCatalog,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Retry"),
              ),
          ],
        ),
      ];
    }

    return [
      if (draft.isHotelChange) ...[
        _dropdownField<double>(
          label: "New Hotel",
          value: draft.newHotelId,
          hint: "Select hotel",
          fontSettings: fontSettings,
          items: hotels
              .map(
                (h) => DropdownMenuItem<double>(
                  value: h['Hotel_IID'] as double,
                  child: Text(
                    (h['HotelName'] ?? '').toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => _onNewHotelChanged(index, value),
        ),
        const SizedBox(height: 10.0),
      ],

      _dropdownField<int>(
        label: "New Room Category",
        value: draft.newRoomCategoryId,
        hint: "Select category",
        helperText: categoryHelper,
        fontSettings: fontSettings,
        items: categories
            .map(
              (c) => DropdownMenuItem<int>(
                value: c['CatCode'] as int,
                child: Text(
                  [
                    (c['CatName'] ?? '').toString(),
                    (c['HotelCategory'] ?? '').toString(),
                  ].where((t) => t.trim().isNotEmpty).join(" "),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) => _onNewCategoryChanged(index, value, categories),
      ),

      const SizedBox(height: 10.0),
      _roomTypeField(index, draft, hotel, fontSettings),
    ];
  }

  /// The room type the room moves to.
  ///
  /// Read against the new category once one is picked and against the one the
  /// room already holds until then, so a room type can be changed on its own —
  /// which is what an occupancy change usually needs, a room taking one more
  /// guest without moving category.
  Widget _roomTypeField(
    int index,
    _RoomAmendmentDraft draft,
    HotelDescipBallys hotel,
    FontSettings fontSettings,
  ) {
    final notifier = ref.read(hotelCatalogProvider.notifier);
    final catalogHotelId = _catalogHotelFor(draft, hotel);
    final effectiveCategoryId = draft.newRoomCategoryId ?? hotel.roomCategoryId;
    final roomTypes = (catalogHotelId == null || effectiveCategoryId == null)
        ? const <Map<String, dynamic>>[]
        : notifier.roomTypesFor(catalogHotelId, effectiveCategoryId);

    final String? helper;
    if (catalogHotelId == null) {
      helper = draft.isHotelChange
          ? "Pick the new hotel first"
          : "This room's hotel is not in the catalog, so its room types "
                "cannot be listed.";
    } else if (roomTypes.isEmpty) {
      // A hotel change leaves the room holding a category the new hotel need
      // not carry, so there is nothing to list until a category is picked.
      helper = draft.isHotelChange
          ? "Pick a room category first"
          : "No room types for this room's category";
    } else if (draft.newRoomCategoryId == null) {
      helper = "Room types of the category this room already holds";
    } else {
      helper = null;
    }

    return _dropdownField<String>(
      label: "New Room Type",
      value: draft.newRoomTypeKey,
      hint: "Select room type",
      helperText: helper,
      fontSettings: fontSettings,
      items: roomTypes
          .map(
            (t) => DropdownMenuItem<String>(
              value: HotelRoomCatalogEntry.roomTypeKeyOf(t),
              child: Text(
                "${t['RoomType']} - ${t['MealPlan']}",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) => _onNewRoomTypeChanged(index, value, roomTypes),
    );
  }

  /// The amendment itself, asked for once the room has someone to amend it for
  /// — the amendment is raised against guests, so they come first.
  Widget _amendmentFields(
    int index,
    _AmendableRoom room,
    _RoomAmendmentDraft draft,
    FontSettings fontSettings,
  ) {
    if (draft.guests.isEmpty) {
      return Text(
        "Select at least one guest to amend this room.",
        style: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
          color: Colors.grey.shade700,
        ),
      );
    }

    final hotel = room.hotel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Amendment for this room",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // ── Amendment category ───────────────────────────────────────────
        _dropdownField<String>(
          label: "Amendment Category",
          value: draft.category,
          hint: "Select category",
          fontSettings: fontSettings,
          items: _categories
              .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
              .toList(),
          onChanged: (value) => _onCategoryChanged(index, value),
        ),

        // Early Check-in / Late Check-out ask for nothing of their own: the
        // room keeps the days it holds, so the category is the whole
        // amendment.

        // ── Date change detail ───────────────────────────────────────────
        //
        // Both days of the stay. Either can be left alone — a stay that only
        // runs longer moves its departure and keeps its arrival.
        if (draft.isDateChange) ...[
          const SizedBox(height: 10.0),
          _dateField(
            label: "New Arrival Date",
            value: draft.newArrivalDate,
            fontSettings: fontSettings,
            helperText: _currentlyLabel(hotel.arrivalDate),
            onTap: () => _pickDate(
              title: "new arrival date",
              current: draft.newArrivalDate,
              roomDate: hotel.arrivalDate,
              onPicked: (picked) {
                draft.newArrivalDate = picked;
                // A departure already picked before this arrival no longer
                // stands, so it is dropped rather than left behind the stay.
                final departure = draft.newDepartureDate;
                if (departure != null && !departure.isAfter(picked)) {
                  draft.newDepartureDate = null;
                }
              },
            ),
          ),
          const SizedBox(height: 10.0),
          _dateField(
            label: "New Departure Date",
            value: draft.newDepartureDate,
            fontSettings: fontSettings,
            helperText: _currentlyLabel(hotel.departureDate),
            onTap: () => _pickDate(
              title: "new departure date",
              current: draft.newDepartureDate,
              roomDate: hotel.departureDate,
              // Kept after whichever arrival the stay now starts on.
              mustBeAfter: draft.newArrivalDate ?? hotel.arrivalDate,
              onPicked: (picked) => draft.newDepartureDate = picked,
            ),
          ),
        ],

        // ── Extras detail ────────────────────────────────────────────────
        if (draft.isExtras) ...[
          const SizedBox(height: 10.0),
          _textField(
            label: "Extras Required",
            controller: draft.extras,
            fontSettings: fontSettings,
            maxLines: 3,
            hint: "e.g. Define how the total cost will be shared between Hamoos and the Guest.",
          ),
        ],

        // ── Hotel change / room category detail ──────────────────────────
        if (draft.isHotelChange || draft.isRoomCategory) ...[
          const SizedBox(height: 10.0),
          ..._catalogFields(index, draft, hotel, fontSettings),
          // A room moving hotel or category is re-costed on who is in it, so
          // who the new room holds is asked for alongside it. An untouched
          // counter leaves that count as booked — neither change need also
          // move the occupancy.
          const SizedBox(height: 10.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _counterField(
                  label: "Guests",
                  value: draft.adults,
                  current: hotel.guestCount,
                  minimum: 1,
                  fontSettings: fontSettings,
                  onChanged: (value) => setState(() => draft.adults = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _counterField(
                  label: "Children",
                  value: draft.children,
                  current: hotel.childrenCount,
                  minimum: 0,
                  fontSettings: fontSettings,
                  onChanged: (value) => setState(() => draft.children = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          _counterField(
            label: "Rooms",
            value: draft.rooms,
            current: hotel.roomCount,
            minimum: 1,
            fontSettings: fontSettings,
            onChanged: (value) => setState(() => draft.rooms = value),
          ),
        ],

        // ── Occupancy detail ─────────────────────────────────────────────
        //
        // Each count stands on its own and an untouched one stays as booked, so
        // a room adding one adult steps that counter alone.
        if (draft.isOccupancy) ...[
          // The room being counted is settled first — more guests can mean a
          // different room type, read against the category the room already
          // holds — and the counts follow underneath it.
          const SizedBox(height: 10.0),
          _roomTypeField(index, draft, hotel, fontSettings),
          const SizedBox(height: 10.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _counterField(
                  label: "Adults",
                  value: draft.adults,
                  current: hotel.guestCount,
                  minimum: 1,
                  fontSettings: fontSettings,
                  onChanged: (value) => setState(() => draft.adults = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _counterField(
                  label: "Children",
                  value: draft.children,
                  current: hotel.childrenCount,
                  minimum: 0,
                  fontSettings: fontSettings,
                  onChanged: (value) => setState(() => draft.children = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          _counterField(
            label: "Rooms",
            value: draft.rooms,
            current: hotel.roomCount,
            minimum: 1,
            fontSettings: fontSettings,
            onChanged: (value) => setState(() => draft.rooms = value),
          ),
        ],
      ],
    );
  }

  // ── Submitting ─────────────────────────────────────────────────────────

  /// The rooms in the amendment, in the order they are shown, paired with what
  /// has been filled in against each.
  List<MapEntry<int, _AmendableRoom>> _amendedRooms(
    List<_AmendableRoom> rooms,
  ) {
    final picked = _selectedRooms.where((i) => i < rooms.length).toList()
      ..sort();
    return picked.map((i) => MapEntry(i, rooms[i])).toList();
  }

  /// The first thing stopping the amendment from being sent, or null when there
  /// is nothing. One message at a time, naming the room it belongs to, so a
  /// long form does not answer with a wall of errors.
  String? _firstProblem(List<_AmendableRoom> rooms) {
    final amended = _amendedRooms(rooms);
    if (amended.isEmpty) return "Tick at least one room to amend.";

    for (final entry in amended) {
      final label = "Room ${entry.key + 1}";
      final draft = _draftFor(entry.key);

      if (draft.guests.isEmpty) {
        return "$label: select the guests this amendment is for.";
      }
      if (draft.category == null) return "$label: select the category.";

      if (draft.isDateChange &&
          draft.newArrivalDate == null &&
          draft.newDepartureDate == null) {
        return "$label: pick the new arrival or departure date.";
      }

      if (draft.isExtras && draft.extras.text.trim().isEmpty) {
        return "$label: say what extras the room needs.";
      }

      if (draft.isHotelChange && draft.newHotelId == null) {
        return "$label: select the hotel it moves to.";
      }

      if (draft.isRoomCategory &&
          draft.newRoomCategoryId == null &&
          draft.newRoomTypeKey == null) {
        return "$label: select the new room category or room type.";
      }

      if (draft.isOccupancy && !draft.hasDetail) {
        return "$label: change a count, or pick the new room type.";
      }
    }
    return null;
  }

  /// The whole amendment as one payload: the reservation it belongs to, and a
  /// row per room carrying who it is for and what changes.
  ///
  /// Each row holds only the detail its own category asked for, and states what
  /// the room holds now beside what it moves to — the back office needs both
  /// halves to record the change.
  Map<String, dynamic> _buildPayload(
    ReservationBallys reservation,
    List<_AmendableRoom> rooms,
  ) {
    final entries = <Map<String, dynamic>>[];

    for (final entry in _amendedRooms(rooms)) {
      final room = entry.value;
      final hotel = room.hotel;
      final draft = _draftFor(entry.key);

      final row = <String, dynamic>{
        'room_no': entry.key + 1,
        'hotel': hotel.hotel,
        'hotel_name': hotel.hotelName,
        'room_category': hotel.roomCategoryId,
        'room_category_name': hotel.roomCategoryName,
        'room_type': hotel.roomTypeId,
        'room_type_name': hotel.roomTypeName,
        'arrival_date': hotel.arrivalDate?.toIso8601String(),
        'departure_date': hotel.departureDate?.toIso8601String(),
        'guest_count': hotel.guestCount,
        'children_count': hotel.childrenCount,
        'room_count': hotel.roomCount,
        'assigned_guests': draft.guests
            .where((i) => i < room.guests.length)
            .map((i) => room.guests[i].toJson())
            .toList(),
        'amendment_category': draft.category,
      };

      if (draft.isDateChange) {
        row['new_arrival_date'] = draft.newArrivalDate?.toIso8601String();
        row['new_departure_date'] = draft.newDepartureDate?.toIso8601String();
      }

      if (draft.isExtras) {
        row['extras'] = draft.extras.text.trim();
      }

      if (draft.isHotelChange) {
        row['new_hotel'] = draft.newHotelId;
        row['new_hotel_name'] = draft.newHotelName;
      }

      // The room the amendment moves to, for every category that can name one.
      // A blank half means that part is unchanged — an untouched counter sends
      // nothing rather than re-sending what the room was booked with.
      if (draft.isHotelChange || draft.isRoomCategory || draft.isOccupancy) {
        row['new_room_category'] = draft.newRoomCategoryId;
        row['new_room_category_name'] = draft.newRoomCategoryName;
        row['new_room_type'] = draft.newRoomTypeId;
        row['new_room_type_name'] = draft.newRoomTypeName;
        row['new_guest_count'] = draft.adults;
        row['new_children_count'] = draft.children;
        row['new_room_count'] = draft.rooms;
      }

      entries.add(row);
    }

    return {
      'master_id': reservation.idNo,
      'reservation_no': reservation.reservNo,
      'bm_number': reservation.mid,
      'guest_name': reservation.mName,
      'amendment_on': 'Hotel',
      'rooms': entries,
    };
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Constants.kPrimaryColor,
      ),
    );
  }

  Future<void> _onSubmit(
    ReservationBallys reservation,
    List<_AmendableRoom> rooms,
  ) async {
    final problem = _firstProblem(rooms);
    if (problem != null) {
      _showMessage(problem);
      return;
    }

    final count = _amendedRooms(rooms).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Submit Amendment"),
        content: Text(
          count == 1
              ? "Raise this amendment for 1 room?"
              : "Raise this amendment for $count rooms?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text("Submit"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final payload = _buildPayload(reservation, rooms);

    setState(() => _submitting = true);

    try {
      final repo = HotelRepository(ApiService(SecureStorage.instance));
      final result = await repo.submitAmendment(payload);
      if (!mounted) return;

      if (result.success) {
        final message = result.message?.trim();
        // Everything filled in goes before the screen closes: the amendment is
        // raised, so leaving the rooms ticked and the fields typed would only
        // invite the same amendment being sent twice.
        _resetForm();
        _showMessage(
          message == null || message.isEmpty
              ? (count == 1
                    ? "Amendment submitted successfully for 1 room."
                    : "Amendment submitted successfully for $count rooms.")
              : message,
          isError: false,
        );
        context.pop();
        return;
      }

      setState(() => _submitting = false);
      _showMessage(result.message ?? "Failed to submit amendment.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage("Failed to submit amendment: $e");
    }
  }

  /// Clears the whole form — every room's draft and the ticks that opened them.
  void _resetForm() {
    if (!mounted) return;
    setState(() {
      for (final draft in _drafts.values) {
        draft.reset();
      }
      _selectedRooms.clear();
      _submitting = false;
    });
  }

  /// The button that raises the amendment. Greyed until a room is ticked, since
  /// that is the least an amendment can be.
  Widget _submitButton(
    ReservationBallys reservation,
    List<_AmendableRoom> rooms,
    FontSettings fontSettings,
  ) {
    final count = _amendedRooms(rooms).length;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: count == 0 || _submitting
            ? null
            : () => _onSubmit(reservation, rooms),
        style: ElevatedButton.styleFrom(
          backgroundColor: Constants.kPrimaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                count == 0
                    ? "Submit Amendment"
                    : count == 1
                    ? "Submit Amendment (1 Hotel)"
                    : "Submit Amendment ($count Hotels)",
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _roomCard(int index, _AmendableRoom room, FontSettings fontSettings) {
    final draft = _draftFor(index);
    final isSelected = _selectedRooms.contains(index);

    return Card(
      // A ticked room lifts out of the grey, the same way a ticked guest does,
      // so the rooms in the amendment read at a glance.
      color: isSelected
          ? const Color.fromARGB(255, 245, 233, 208)
          : const Color.fromARGB(255, 228, 224, 224),
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        // Outlined once the room is ticked, and more heavily once its
        // amendment is filled in, so a long list shows at a glance which rooms
        // have been dealt with.
        side: isSelected
            ? BorderSide(
                color: Constants.kPrimaryColor,
                width: draft.isComplete ? 2 : 1.5,
              )
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleRoom(index),
            borderRadius: BorderRadius.circular(4),
            child: _roomSummary(index, room, draft, isSelected, fontSettings),
          ),
          // A room that is not in the amendment has nothing to pick under it,
          // so the guests and the amendment come with the tick.
          if (isSelected) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _guestPicker(index, room, draft, fontSettings),
                  if (room.guests.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _amendmentFields(index, room, draft, fontSettings),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservation = ref.watch(selectedReservationBallysProvider);
    final selectedHotels = ref.watch(selectedHotelBallysProvider);
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // Explicit brand colour: with no appBarTheme set and Material 3 on, the
        // default bar picks up a surface tint that shifts as content scrolls
        // under it.
        backgroundColor: Constants.kPrimaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text("Hotel Amendment", style: TextStyle(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Back goes to the reservation detail view, which still owns the
            // selection providers this screen read from.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(
                '/reservationMain/reservations/reservation-view-ballys',
              );
            }
          },
        ),
      ),
      body: reservation == null
          ? const Center(child: Text('No reservation selected.'))
          : Builder(
              builder: (context) {
                final rooms = _rooms(reservation, selectedHotels);

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Whose reservation this is. The guests themselves are
                        // picked per room below, not here.
                        AmendmentGuestHeaderBallys(
                          reservation: reservation,
                          showGuests: false,
                        ),
                        const SizedBox(height: 10.0),

                        // ── Hotels & rooms ───────────────────────────────
                        Text(
                          rooms.length == 1
                              ? "Hotel Room"
                              : "Hotel Rooms (${rooms.length})",
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (rooms.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _guestAndRoomCounts(
                              rooms.map((r) => r.hotel).toList(),
                            ),
                            style: TextStyle(
                              fontSize: fontSettings.fontSize - 3,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8.0),

                        if (rooms.isEmpty)
                          const Center(
                            heightFactor: 3.0,
                            child: Text(
                              'No hotels selected.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color.fromARGB(255, 168, 49, 49),
                              ),
                            ),
                          )
                        else
                          ...rooms.asMap().entries.map(
                            (entry) =>
                                _roomCard(entry.key, entry.value, fontSettings),
                          ),
                        const SizedBox(height: 20.0),

                        // ── Submit ───────────────────────────────────────
                        if (rooms.isNotEmpty)
                          _submitButton(reservation, rooms, fontSettings),
                        const SizedBox(height: 24.0),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
