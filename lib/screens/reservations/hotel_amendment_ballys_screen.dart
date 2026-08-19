import 'package:ballys_reservation_app/components/amendment_guest_header_ballys.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/guest_reservation_entryBallys.dart';
import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/models/reservation/assigned_guest.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/hotel_catalog_provider.dart';
import 'package:ballys_reservation_app/providers/selectedReservationforBallys_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider_ballys.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Shared by the three categories that move a day: Date Change asks for both,
  // Early Check-in for the arrival alone and Late Check-out for the departure
  // alone. Null is "not picked yet", not "unchanged" — the days the room moves
  // *from* are the room's own.

  DateTime? newArrivalDate;
  DateTime? newDepartureDate;

  /// The hour asked for, alongside the day. Early Check-in / Late Check-out
  /// only: the room already holds its days, so what changes is the hour it is
  /// taken up or given back.
  TimeOfDay? checkInTime;
  TimeOfDay? checkOutTime;

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

  /// What the room is asked to carry on top of what was booked — extra bed,
  /// airport transfer, and so on. Extras only.
  final TextEditingController extras = TextEditingController();

  // ── Occupancy ──────────────────────────────────────────────────────────
  //
  // Left blank means "unchanged", so a room moving from 2 adults to 3 without
  // touching its children only fills in the one field.
  final TextEditingController adults = TextEditingController();
  final TextEditingController children = TextEditingController();
  final TextEditingController rooms = TextEditingController();

  /// Why the amendment is being raised, and anything else worth saying. Asked
  /// for by every category, so one pair of controllers serves them all — the
  /// detail is cleared whenever the category changes.
  final TextEditingController reason = TextEditingController();
  final TextEditingController additionalRemark = TextEditingController();

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
  /// amendment. Every category asks for at least one thing beyond itself —
  /// naming the category alone never says what the room moves to.
  bool get hasDetail {
    if (isEarlyCheckIn) return newArrivalDate != null || checkInTime != null;
    if (isLateCheckOut) return newDepartureDate != null || checkOutTime != null;
    if (isDateChange) {
      return newArrivalDate != null || newDepartureDate != null;
    }
    if (isExtras) return extras.text.trim().isNotEmpty;
    if (isHotelChange) return newHotelId != null;
    if (isRoomCategory) return newRoomCategoryId != null;
    if (isOccupancy) {
      return adults.text.trim().isNotEmpty ||
          children.text.trim().isNotEmpty ||
          rooms.text.trim().isNotEmpty;
    }
    return false;
  }

  /// A room counts as amended once someone is picked, the amendment is named
  /// and it says what the room moves to.
  bool get isComplete => guests.isNotEmpty && category != null && hasDetail;

  /// Drops the detail of whatever category was picked before. Every category's
  /// detail goes, not just the one on screen: the fields are shared, so a
  /// reason typed against an early check-in must not follow the room into a
  /// date change.
  void clearCategoryDetail() {
    newArrivalDate = null;
    newDepartureDate = null;
    checkInTime = null;
    checkOutTime = null;
    newHotelId = null;
    newHotelName = null;
    newRoomCategoryId = null;
    newRoomCategoryName = null;
    newRoomTypeId = null;
    newRoomTypeName = null;
    extras.clear();
    adults.clear();
    children.clear();
    rooms.clear();
    reason.clear();
    additionalRemark.clear();
  }

  void dispose() {
    extras.dispose();
    adults.dispose();
    children.dispose();
    rooms.dispose();
    reason.dispose();
    additionalRemark.dispose();
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
    _hotelChange,
    _roomCategory,
    _occupancy,
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
  void _onNewHotelChanged(int roomIndex, double? hotelId, String? hotelName) {
    final draft = _draftFor(roomIndex);
    if (hotelId == draft.newHotelId) return;
    setState(() {
      draft.newHotelId = hotelId;
      draft.newHotelName = hotelName;
      draft.newRoomCategoryId = null;
      draft.newRoomCategoryName = null;
      draft.newRoomTypeId = null;
      draft.newRoomTypeName = null;
    });
  }

  /// Room types belong to a category, so changing the category drops the type
  /// underneath it for the same reason a hotel change drops the category.
  void _onNewCategoryChanged(int roomIndex, Map<String, dynamic>? category) {
    final draft = _draftFor(roomIndex);
    final id = category?['CatCode'] as int?;
    if (id == draft.newRoomCategoryId) return;
    setState(() {
      draft.newRoomCategoryId = id;
      draft.newRoomCategoryName = category?['CatName'] as String?;
      draft.newRoomTypeId = null;
      draft.newRoomTypeName = null;
    });
  }

  void _onNewRoomTypeChanged(int roomIndex, Map<String, dynamic>? roomType) {
    final draft = _draftFor(roomIndex);
    setState(() {
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

  /// The hour asked for on an early check-in / late check-out. Opens on what is
  /// already picked, or on the hotel's own standard hour, so the sheet starts
  /// where the change is being measured from.
  Future<void> _pickTime({
    required TimeOfDay? current,
    required TimeOfDay fallback,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? fallback,
    );
    if (picked != null) setState(() => onPicked(picked));
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

  /// The hour asked for, read the same way as the day beside it.
  Widget _timeField({
    required String label,
    required TimeOfDay? value,
    required FontSettings fontSettings,
    required VoidCallback onTap,
    String? helperText,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _dropdownDeco(label, fontSettings).copyWith(
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: const Icon(Icons.schedule, size: 18),
          helperText: helperText,
          helperMaxLines: 2,
          helperStyle: TextStyle(
            fontSize: fontSettings.fontSize - 3,
            color: Colors.grey.shade700,
          ),
        ),
        child: Text(
          value == null ? "Select time" : value.format(context),
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
            color: value == null ? Colors.grey.shade600 : Colors.black,
          ),
        ),
      ),
    );
  }

  /// A value the amendment reports rather than asks for, styled as the fields
  /// around it so the block reads as one form.
  Widget _readOnlyField({
    required String label,
    required String value,
    required FontSettings fontSettings,
  }) {
    return InputDecorator(
      decoration: _dropdownDeco(label, fontSettings).copyWith(
        // Nothing to pick here, so it floats like a filled field rather than
        // sitting empty waiting to be tapped.
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      child: Text(
        value.trim().isEmpty ? "—" : value,
        style: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
          color: Colors.black,
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

  /// One of the occupancy counts. Left blank means unchanged, so what the room
  /// holds now sits underneath rather than being pre-filled — a pre-filled
  /// count would be re-sent as a change that was never asked for.
  Widget _countField({
    required String label,
    required TextEditingController controller,
    required int? current,
    required FontSettings fontSettings,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      // The count feeds the card's "filled in" state, so the card follows it
      // as it is typed rather than only once the field is left.
      onChanged: (_) => setState(() {}),
      style: TextStyle(
        fontSize: fontSettings.fontSize,
        fontWeight: fontSettings.fontWeight,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
        ),
        helperText: "Currently: ${current ?? 0}",
        helperStyle: TextStyle(
          fontSize: fontSettings.fontSize - 3,
          color: Colors.grey.shade700,
        ),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Guests: ${hotel.guestCount ?? 0}",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      "Nights: ${hotel.noOfNights ?? 0}",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      "Rooms: ${hotel.roomCount ?? 0}",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Estimated Cost: ${hotel.selectedCost}",
                  style: TextStyle(
                    fontSize: fontSettings.fontSize + 2,
                    fontWeight: fontSettings.fontWeight,
                  ),
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
  double? _catalogHotelFor(_RoomAmendmentDraft draft, HotelDescipBallys hotel) {
    return draft.isHotelChange ? draft.newHotelId : _hotelIdOf(hotel);
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
    final hotels = notifier.hotelsAsMap;
    final catalogHotelId = _catalogHotelFor(draft, hotel);

    final categories = catalogHotelId == null
        ? const <Map<String, dynamic>>[]
        : notifier.categoriesFor(catalogHotelId);
    final roomTypes =
        (catalogHotelId == null || draft.newRoomCategoryId == null)
        ? const <Map<String, dynamic>>[]
        : notifier.roomTypesFor(catalogHotelId, draft.newRoomCategoryId!);

    // What the category dropdown has to say for itself: on a hotel change it
    // waits for the hotel and is then optional (a room can move hotels and keep
    // the category it had); on a room category change it is the amendment
    // itself, so it says nothing unless the room's hotel is missing from the
    // catalog and there is nothing to list.
    final String? categoryHelper;
    if (draft.isHotelChange && draft.newHotelId == null) {
      categoryHelper =
          "Pick the new hotel first — categories are the hotel's own";
    } else if (draft.isHotelChange) {
      categoryHelper = "Leave blank to keep the current category";
    } else if (catalogHotelId == null) {
      categoryHelper =
          "This room's hotel is not in the catalog, so its categories cannot "
          "be listed.";
    } else {
      categoryHelper = null;
    }

    // The catalog has to land before any of these can be opened, so the block
    // says so rather than showing three dropdowns with nothing in them.
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
                    : "Hotels could not be loaded. Go back and open the "
                          "amendment again.",
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                  color: _isLoadingCatalog
                      ? Colors.grey.shade700
                      : const Color.fromARGB(255, 168, 49, 49),
                ),
              ),
            ),
          ],
        ),
      ];
    }

    return [
      if (draft.isHotelChange) ...[
        _readOnlyField(
          label: "Current Hotel",
          value: hotel.hotelName ?? '',
          fontSettings: fontSettings,
        ),
        const SizedBox(height: 10.0),
        DropdownButtonFormField<double>(
          initialValue: draft.newHotelId,
          isExpanded: true,
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
            color: Colors.black,
          ),
          decoration: _dropdownDeco("New Hotel", fontSettings),
          hint: Text(
            "Select hotel",
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
            ),
          ),
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
          onChanged: (value) => _onNewHotelChanged(
            index,
            value,
            hotels.firstWhere(
                  (h) => h['Hotel_IID'] == value,
                  orElse: () => const {'HotelName': ''},
                )['HotelName']
                as String?,
          ),
        ),
        const SizedBox(height: 10.0),
      ],

      _readOnlyField(
        label: "Current Room Category",
        value: hotel.roomCategoryName ?? '',
        fontSettings: fontSettings,
      ),
      const SizedBox(height: 10.0),
      DropdownButtonFormField<int>(
        initialValue: draft.newRoomCategoryId,
        isExpanded: true,
        style: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
          color: Colors.black,
        ),
        decoration: _dropdownDeco("New Room Category", fontSettings).copyWith(
          helperText: categoryHelper,
          helperMaxLines: 2,
          helperStyle: TextStyle(
            fontSize: fontSettings.fontSize - 3,
            color: Colors.grey.shade700,
          ),
        ),
        hint: Text(
          "Select category",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
          ),
        ),
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
        onChanged: categories.isEmpty
            ? null
            : (value) => _onNewCategoryChanged(
                index,
                categories.firstWhere((c) => c['CatCode'] == value),
              ),
      ),

      // The room type belongs to the category above it, so it only opens once
      // that is picked — there is nothing to list against no category.
      if (draft.newRoomCategoryId != null) ...[
        const SizedBox(height: 10.0),
        _readOnlyField(
          label: "Current Room Type",
          value: hotel.roomTypeName ?? '',
          fontSettings: fontSettings,
        ),
        const SizedBox(height: 10.0),
        DropdownButtonFormField<int>(
          initialValue: draft.newRoomTypeId,
          isExpanded: true,
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
            color: Colors.black,
          ),
          decoration: _dropdownDeco("New Room Type", fontSettings),
          hint: Text(
            "Select room type",
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
            ),
          ),
          items: roomTypes
              .map(
                (t) => DropdownMenuItem<int>(
                  value: t['ID'] as int,
                  child: Text(
                    "${t['RoomType']} - ${t['MealPlan']}",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: roomTypes.isEmpty
              ? null
              : (value) => _onNewRoomTypeChanged(
                  index,
                  roomTypes.firstWhere((t) => t['ID'] == value),
                ),
        ),
      ],
    ];
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
        DropdownButtonFormField<String>(
          initialValue: draft.category,
          isExpanded: true,
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
            color: Colors.black,
          ),
          decoration: _dropdownDeco("Amendment Category", fontSettings),
          hint: Text(
            "Select category",
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
            ),
          ),
          items: _categories
              .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
              .toList(),
          onChanged: (value) => _onCategoryChanged(index, value),
        ),

        // ── Early check-in detail ────────────────────────────────────────
        //
        // The day the room is taken up and the hour it is wanted from. The day
        // is asked for as well as the hour: an early check-in can be the hour
        // before the standard one, or the night before altogether.
        if (draft.isEarlyCheckIn) ...[
          const SizedBox(height: 10.0),
          _dateField(
            label: "Check-in Date",
            value: draft.newArrivalDate,
            fontSettings: fontSettings,
            helperText: _currentlyLabel(hotel.arrivalDate),
            onTap: () => _pickDate(
              title: "check-in date",
              current: draft.newArrivalDate,
              roomDate: hotel.arrivalDate,
              onPicked: (picked) => draft.newArrivalDate = picked,
            ),
          ),
          const SizedBox(height: 10.0),
          _timeField(
            label: "Check-in Time",
            value: draft.checkInTime,
            fontSettings: fontSettings,
            helperText: "The hour the room is wanted from",
            onTap: () => _pickTime(
              current: draft.checkInTime,
              fallback: const TimeOfDay(hour: 14, minute: 0),
              onPicked: (picked) => draft.checkInTime = picked,
            ),
          ),
        ],

        // ── Late check-out detail ────────────────────────────────────────
        if (draft.isLateCheckOut) ...[
          const SizedBox(height: 10.0),
          _dateField(
            label: "Check-out Date",
            value: draft.newDepartureDate,
            fontSettings: fontSettings,
            helperText: _currentlyLabel(hotel.departureDate),
            onTap: () => _pickDate(
              title: "check-out date",
              current: draft.newDepartureDate,
              roomDate: hotel.departureDate,
              onPicked: (picked) => draft.newDepartureDate = picked,
            ),
          ),
          const SizedBox(height: 10.0),
          _timeField(
            label: "Check-out Time",
            value: draft.checkOutTime,
            fontSettings: fontSettings,
            helperText: "The hour the room is given back",
            onTap: () => _pickTime(
              current: draft.checkOutTime,
              fallback: const TimeOfDay(hour: 12, minute: 0),
              onPicked: (picked) => draft.checkOutTime = picked,
            ),
          ),
        ],

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
            hint: "e.g. extra bed, airport transfer, late dinner",
          ),
        ],

        // ── Hotel change / room category detail ──────────────────────────
        if (draft.isHotelChange || draft.isRoomCategory) ...[
          const SizedBox(height: 10.0),
          ..._catalogFields(index, draft, hotel, fontSettings),
        ],

        // ── Occupancy detail ─────────────────────────────────────────────
        //
        // Each count stands on its own and blank means unchanged, so a room
        // adding one adult fills in that field alone.
        if (draft.isOccupancy) ...[
          const SizedBox(height: 10.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _countField(
                  label: "Adults",
                  controller: draft.adults,
                  current: hotel.guestCount,
                  fontSettings: fontSettings,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _countField(
                  label: "Children",
                  controller: draft.children,
                  current: hotel.childrenCount,
                  fontSettings: fontSettings,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _countField(
                  label: "Rooms",
                  controller: draft.rooms,
                  current: hotel.roomCount,
                  fontSettings: fontSettings,
                ),
              ),
            ],
          ),
        ],

        // ── Why, and anything else ───────────────────────────────────────
        //
        // Asked for by every category, once one is picked: an amendment is
        // approved on why it was raised as much as on what it changes.
        if (draft.category != null) ...[
          const SizedBox(height: 10.0),
          _textField(
            label: "Reason",
            controller: draft.reason,
            fontSettings: fontSettings,
            maxLines: 3,
            hint: "Why this amendment is being raised",
          ),
          const SizedBox(height: 10.0),
          _textField(
            label: "Additional Remark",
            controller: draft.additionalRemark,
            fontSettings: fontSettings,
            maxLines: 2,
          ),
        ],
      ],
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
