import 'package:ballys_reservation_app/components/air_ticket_class_count_selector.dart';
import 'package:ballys_reservation_app/components/amendment_guest_header_ballys.dart';
import 'package:ballys_reservation_app/components/custom_airport_field.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/reservation/air_ticket_class_count.dart';
import 'package:ballys_reservation_app/models/guest_reservation_entryBallys.dart';
import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/models/airport_search_response.dart';
import 'package:ballys_reservation_app/models/reservation/assigned_guest.dart';
import 'package:ballys_reservation_app/models/reservation/flight_bookng_ballys.dart';
import 'package:ballys_reservation_app/models/reservation/flight_sector_entry.dart';
import 'package:ballys_reservation_app/providers/airports_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selectedReservationforBallys_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider_ballys.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// One air ticket on the reservation together with the people it may be
/// amended for.s
///
/// [guests] is what the ticket itself came back with — `assigned_guests` names
/// everyone the ticket is booked for, so the guest list is the ticket's own
/// rather than the reservation's. Tickets saved before the assignment existed
/// carry an empty list and belong to the guest whose entry they sit in, which
/// is the only case [owner] stands in for.
@immutable
class _AmendableTicket {
  const _AmendableTicket({required this.flight, required this.guests});

  final FlightBookingBallys flight;
  final List<AssignedGuest> guests;
}

/// Everything picked against one ticket: who it is being amended for, and what
/// the amendment is. Held per ticket rather than per screen — a reservation can
/// carry several tickets and each is amended in its own right.
class _TicketAmendmentDraft {
  /// Positions within the ticket's own guest list. Positions rather than BM
  /// numbers: a ticket can name a guest whose `BMNumber` came back blank.
  final Set<int> guests = <int>{};

  String? category;
  String? type;

  /// The classes the ticket moves up to, each with its own seat count — an
  /// upgrade can split a ticket across classes (Business x1 plus Economy x1)
  /// the same way the ticket itself was booked. The class it moves *from* is
  /// not asked for: that is the ticket's own class, which it already carries.
  /// Cabin Upgrade only.
  List<AirTicketClassCount> newClasses = const [];

  /// The days the ticket moves to. Date Change only. Null is "not picked yet",
  /// not "unchanged" — the dates it moves *from* are the ticket's own.
  DateTime? newArrivalDate;
  DateTime? newDepartureDate;

  // ── Route Change ───────────────────────────────────────────────────────
  //
  // A ticket has two legs and a route change need not touch both, so the leg
  // is asked for first and only the legs it names are filled in below.

  /// Which legs move: the outbound, the return, or both. Null until picked.
  String? routeLeg;

  /// The outbound leg's new endpoints, filled in when [changesDeparture].
  Airport? departureFrom;
  Airport? departureTo;

  /// The return leg's new endpoints, filled in when [changesReturn].
  Airport? returnFrom;
  Airport? returnTo;

  /// The new route does not fly direct — it goes through the stops below,
  /// which sit between each leg's own endpoints.
  bool isMultiSector = false;
  final List<FlightSectorEntry> departureSectors = <FlightSectorEntry>[];
  final List<FlightSectorEntry> returnSectors = <FlightSectorEntry>[];

  /// Why the amendment is being raised, and anything else worth saying. Asked
  /// for by every type that carries detail, so one pair of controllers serves
  /// them all — the detail is cleared whenever the type changes.
  final TextEditingController reason = TextEditingController();
  final TextEditingController additionalRemark = TextEditingController();

  /// How long the cancelled ticket stays good for and on what terms it can be
  /// reissued. Cancel and open ticket only: the ticket is not refunded, it is
  /// left open, so what it is still worth has to travel with the amendment.
  final TextEditingController validityNote = TextEditingController();

  /// How the money goes back. Cancel & refund ticket only — the ticket is
  /// settled rather than left open, so the amendment has to say by what means.
  String? refundMethod;

  bool get isCabinUpgrade =>
      category == _AirTicketAmendmentBallysScreenState._exchange &&
      type == _AirTicketAmendmentBallysScreenState._cabinUpgrade;

  bool get isDateChange =>
      category == _AirTicketAmendmentBallysScreenState._exchange &&
      type == _AirTicketAmendmentBallysScreenState._dateChange;

  bool get isRouteChange =>
      category == _AirTicketAmendmentBallysScreenState._exchange &&
      type == _AirTicketAmendmentBallysScreenState._routeChange;

  /// Voiding a ticket needs no detail beyond why it is being voided, which is
  /// the one thing every type carrying detail asks for anyway.
  bool get isVoid =>
      category == _AirTicketAmendmentBallysScreenState._voidCategory;

  bool get isCancelAndOpen =>
      category == _AirTicketAmendmentBallysScreenState._routeCancellation &&
      type == _AirTicketAmendmentBallysScreenState._cancelAndOpen;

  bool get isCancelAndRefund =>
      category == _AirTicketAmendmentBallysScreenState._routeCancellation &&
      type == _AirTicketAmendmentBallysScreenState._cancelAndRefund;

  /// Whether the outbound / return leg is one of the legs being moved.
  bool get changesDeparture =>
      routeLeg == _AirTicketAmendmentBallysScreenState._legDeparture ||
      routeLeg == _AirTicketAmendmentBallysScreenState._legBoth;

  bool get changesReturn =>
      routeLeg == _AirTicketAmendmentBallysScreenState._legReturn ||
      routeLeg == _AirTicketAmendmentBallysScreenState._legBoth;

  /// Whether the type picked asks for anything beyond itself.
  bool get hasDetail =>
      isCabinUpgrade ||
      isDateChange ||
      isRouteChange ||
      isVoid ||
      isCancelAndOpen ||
      isCancelAndRefund;

  /// A ticket counts as amended once someone is picked and the amendment is
  /// named — the detail below the type is asked for per type, not always.
  bool get isComplete => guests.isNotEmpty && category != null && type != null;

  /// Drops the detail of whatever type was picked before. Every type's detail
  /// goes, not just the one on screen: the fields are shared, so a reason typed
  /// against an upgrade must not follow the ticket into a date change.
  void clearTypeDetail() {
    newClasses = const [];
    newArrivalDate = null;
    newDepartureDate = null;
    routeLeg = null;
    departureFrom = null;
    departureTo = null;
    returnFrom = null;
    returnTo = null;
    isMultiSector = false;
    departureSectors.clear();
    returnSectors.clear();
    reason.clear();
    additionalRemark.clear();
    validityNote.clear();
    refundMethod = null;
  }

  void dispose() {
    reason.dispose();
    additionalRemark.dispose();
    validityNote.dispose();
  }
}

/// Air ticket side of the reservation amendment flow.
///
/// Reached from the Amendment button on `ReservationViewScreenBallys` (Pending
/// only) after choosing "Air Ticket". The screen reads ticket-first: every
/// ticket booked on the reservation is listed, opening one shows the guests
/// that ticket came back with, and the amendment is then raised against the
/// guests ticked on that ticket. Tickets come from
/// `selectedFlightBallysProvider`, which the detail view already populated.
class AirTicketAmendmentBallysScreen extends ConsumerStatefulWidget {
  const AirTicketAmendmentBallysScreen({super.key});

  @override
  ConsumerState<AirTicketAmendmentBallysScreen> createState() =>
      _AirTicketAmendmentBallysScreenState();
}

class _AirTicketAmendmentBallysScreenState
    extends ConsumerState<AirTicketAmendmentBallysScreen> {
  // ── Amendment category / type ──────────────────────────────────────────
  //
  // The type on offer depends entirely on the category picked, so the two
  // dropdowns are driven off one map rather than three parallel lists. A
  // category carrying a single type (Void) settles it on its own, so no type
  // dropdown is shown for it — there would be nothing in it to pick.
  static const String _exchange = 'Exchange';
  static const String _voidCategory = 'Void';
  static const String _routeCancellation = 'Cancellation';

  static const String _cabinUpgrade = 'Cabin Upgrade';
  static const String _dateChange = 'Date Change';
  static const String _routeChange = 'Route Change';
  static const String _cancelAndOpen = 'Cancel and open ticket';
  static const String _cancelAndRefund = 'Cancel & refund ticket';

  /// How a refunded ticket is settled. Cancel & refund ticket only.
  static const List<String> _refundMethods = [
    'Original Form of Payment',
    'Credit Note',
    'Bank Transfer',
  ];

  /// Which legs a route change moves. A one-way ticket only ever offers the
  /// first — it has no return leg to move.
  static const String _legDeparture = 'Departure only';
  static const String _legReturn = 'Return only';
  static const String _legBoth = 'Both legs';

  static const Map<String, List<String>> _typesByCategory = {
    _exchange: [_cabinUpgrade, _dateChange, _routeChange],
    _voidCategory: ['Void'],
    _routeCancellation: [_cancelAndOpen, _cancelAndRefund],
  };

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Per-ticket state, keyed by the ticket's position in the list built below.
  /// The screen is read-only, so that list — and these keys — hold still for as
  /// long as the screen is open.
  final Map<int, _TicketAmendmentDraft> _drafts = <int, _TicketAmendmentDraft>{};

  /// The tickets ticked, by position. Every ticket is picked in its own right
  /// — one amendment can cover several of a reservation's tickets, and each
  /// ticked ticket carries its own guests and its own amendment below.
  ///
  /// A ticket opens exactly when it is ticked: an unticked ticket is not part
  /// of the amendment, so there is nothing to show under it. Unticking keeps
  /// what was already filled in, so a ticket ticked again comes back as it was.
  final Set<int> _selectedTickets = <int>{};

  /// True while the airport list is being fetched, so the route change block
  /// can say the picker is not ready yet rather than opening onto nothing.
  bool _isLoadingAirports = false;

  @override
  void initState() {
    super.initState();
    // The airport picker reads a list nothing on this screen's way in fills:
    // it is loaded by whichever screen uses the picker, and an amendment
    // opened straight off the reservation view has passed none of them. Left
    // alone, the search sheet opens empty.
    //
    // Deferred past the first frame: this writes to a provider, which must not
    // happen while the widget is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAirports());
  }

  Future<void> _loadAirports() async {
    try {
      if (ref.read(airportsProvider).isEmpty) {
        setState(() => _isLoadingAirports = true);
        await ref.read(airportsProvider.notifier).getAllAirports();
        if (!mounted) return;
        setState(() => _isLoadingAirports = false);
      }
      // Another screen may have left the list narrowed to its last search, so
      // the sheet opens on the full list rather than on someone else's query.
      ref.read(airportsProvider.notifier).filterAirports("");
    } catch (_) {
      if (mounted) setState(() => _isLoadingAirports = false);
    }
  }

  @override
  void dispose() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  _TicketAmendmentDraft _draftFor(int index) =>
      _drafts.putIfAbsent(index, () => _TicketAmendmentDraft());

  // ── Tickets and the guests on them ─────────────────────────────────────

  /// Every ticket on the reservation, each with the guests it is booked for.
  ///
  /// The reservation's own ticket list is what the screen counts, NOT the
  /// tickets hanging off the guest entries: a ticket lands on a guest entry
  /// only when the guest it is booked for is one, and the first guest on a
  /// ticket can just as easily be a member sharing someone's package — members
  /// are folded into the guest that owns them and hold no `flights`. Reading
  /// the guests would drop those tickets, so a reservation with two tickets
  /// could show one.
  ///
  /// The guest entries are still walked, but only to name the guest behind a
  /// ticket that came back with no assignment at all.
  List<_AmendableTicket> _tickets(
    ReservationBallys reservation,
    List<FlightBookingBallys> reservationFlights,
  ) {
    final guestFlights = <FlightBookingBallys>[];
    // Which guest entry a ticket sits in, for the tickets that name nobody.
    // Keyed by what the ticket is rather than by identity: the reservation's
    // list and the guests' lists are parsed separately off the same rows, so
    // the same ticket arrives as two objects.
    final owners = <String, GuestReservationEntryBallys>{};
    for (final guest in reservation.guests) {
      for (final flight in guest.flights) {
        guestFlights.add(flight);
        owners.putIfAbsent(_ticketSignature(flight), () => guest);
      }
    }

    // Payloads that carry the tickets only on the guests leave the
    // reservation's own list empty, so those guests' tickets stand in.
    final source = reservationFlights.isNotEmpty
        ? reservationFlights
        : (reservation.airticketDescrip.isNotEmpty
            ? reservation.airticketDescrip
            : guestFlights);

    return source
        .map((flight) => _AmendableTicket(
              flight: flight,
              guests: _guestsOn(flight, owners[_ticketSignature(flight)]),
            ))
        .toList();
  }

  /// What a ticket is, as a string — enough of it to recognise the same ticket
  /// parsed twice off the same row. Two genuinely identical tickets share a
  /// signature, which is harmless: it is only used to look up a name to fall
  /// back to.
  static String _ticketSignature(FlightBookingBallys flight) {
    return [
      flight.departureRouteText,
      flight.returnRouteText,
      flight.departureDate?.toIso8601String() ?? '',
      flight.arrivalDate?.toIso8601String() ?? '',
      flight.ticketClassSummary,
      flight.airLineCode ?? flight.airLine ?? '',
      flight.guestCount,
      flight.childrenCount,
      flight.infantCount,
    ].join('|');
  }

  /// The people a ticket may be amended for: whoever the API named on the
  /// ticket, falling back to [owner] for tickets that carry no assignment.
  List<AssignedGuest> _guestsOn(
    FlightBookingBallys flight,
    GuestReservationEntryBallys? owner,
  ) {
    final assigned = flight.assignedGuests
        .where((g) => g.mid.trim().isNotEmpty || g.guestName.trim().isNotEmpty)
        .toList();
    if (assigned.isNotEmpty) return assigned;

    if (owner == null) return const [];
    if (owner.mid.trim().isEmpty && owner.guestName.trim().isEmpty) {
      return const [];
    }
    return [AssignedGuest(mid: owner.mid, guestName: owner.guestName)];
  }

  void _toggleTicket(int index) {
    setState(() {
      if (!_selectedTickets.remove(index)) _selectedTickets.add(index);
    });
  }

  void _toggleGuest(int ticketIndex, int guestIndex) {
    setState(() {
      final draft = _draftFor(ticketIndex);
      if (!draft.guests.remove(guestIndex)) draft.guests.add(guestIndex);
    });
  }
           
  void _onCategoryChanged(int ticketIndex, String? value) {
    final draft = _draftFor(ticketIndex);
    if (value == draft.category) return;
    setState(() {
      draft.category = value;
      final types = _typesByCategory[value] ?? const <String>[];
      // A single-type category (Void) has nothing to choose, so it is filled in
      // rather than left blank for the user to open and pick the only entry.
      draft.type = types.length == 1 ? types.first : null;
      draft.clearTypeDetail();
    });
  }

  void _onTypeChanged(int ticketIndex, String? value) {
    final draft = _draftFor(ticketIndex);
    if (value == draft.type) return;
    setState(() {
      draft.type = value;
      // The detail belongs to the type that asked for it, so moving to any
      // other type — not just away from Cabin Upgrade — starts it clean.
      draft.clearTypeDetail();
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

  /// Picks one of the days a ticket moves to, in the same wheel the ticket was
  /// booked with.
  ///
  /// [current] is what is already picked, [ticketDate] the day the ticket
  /// holds now — the wheel opens on the first of those it has. A ticket booked
  /// for a day that has since passed still opens on its own day rather than
  /// being dragged forward, so the bounds stretch to whatever it opens on.
  ///
  /// [mustBeAfter] refuses a day that would land on or before it, which is how
  /// a departure is kept after its arrival.
  Future<void> _pickDate({
    required String title,
    required DateTime? current,
    required DateTime? ticketDate,
    required ValueChanged<DateTime> onPicked,
    DateTime? mustBeAfter,
  }) async {
    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    DateTime initial = current ?? ticketDate ?? now;
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

  /// "Currently: 2026-08-20" — the day the ticket holds now, for a field
  /// asking what it moves to.
  static String _currentlyLabel(DateTime? ticketDate) {
    return ticketDate == null
        ? "Not set on this ticket"
        : "Currently: ${_dateFormat.format(ticketDate)}";
  }

  /// One of the ticket's new days. Reads empty until it is picked, with the day
  /// the ticket holds now underneath — the amendment says what changes, so the
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

  /// "2 GUESTS, 3 TICKETS" — the same summary line the detail view shows above
  /// the flight cards.
  static String _guestAndTicketCounts(List<FlightBookingBallys> flights) {
    final totalGuests = flights.fold<int>(0, (sum, f) => sum + f.guestCount);
    final totalTickets = flights.length;

    String txt =
        totalGuests == 1 ? "$totalGuests GUEST" : "$totalGuests GUESTS";
    txt += totalTickets == 1
        ? ", $totalTickets TICKET"
        : ", $totalTickets TICKETS";
    return txt;
  }

  /// The ticket's own row: its checkbox, enough of the ticket to tell it from
  /// the others, and how far its amendment has got.
  Widget _ticketSummary(
    int index,
    _AmendableTicket ticket,
    _TicketAmendmentDraft draft,
    bool isSelected,
    FontSettings fontSettings,
  ) {
    final flight = ticket.flight;
    final selectedCount = draft.guests.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The ticket is picked in its own right, so the checkbox stands
          // where the plain number used to; the number rides along beside it
          // so a ticket can still be referred to by position.
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: isSelected,
              activeColor: Constants.kPrimaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) => _toggleTicket(index),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 14,
            backgroundColor:
                isSelected ? Constants.kPrimaryColor : Colors.black,
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
                    const Icon(Icons.flight_takeoff,
                        size: 18, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        // Includes every transit stop, so the whole outbound
                        // leg reads in travel order.
                        flight.departureRouteText,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (flight.returnRouteText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.flight_land,
                          size: 18, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          flight.returnRouteText,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  // Every class on the ticket with its seat count, e.g.
                  // "Economy x2, Business x1".
                  "Class: ${flight.ticketClassSummary}",
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: fontSettings.fontWeight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Departure: ${flight.departureDate != null ? _dateFormat.format(flight.departureDate!) : 'N/A'}"
                  " · Arrival: ${flight.arrivalDate != null ? _dateFormat.format(flight.arrivalDate!) : 'N/A'}",
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: fontSettings.fontWeight,
                  ),
                ),
                if ((flight.airLine ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    "Airline: ${flight.airLine}",
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                // Text(
                //   ticket.guests.isEmpty
                //       ? "No guests on this ticket"
                //       : "Guests on ticket: ${ticket.guests.length}",
                //   style: TextStyle(
                //     fontSize: fontSettings.fontSize,
                //     fontWeight: fontSettings.fontWeight,
                //   ),
                // ),
                // What has been picked so far, so an unticked ticket still
                // says what was filled in before it was put aside.
                if (selectedCount > 0 || draft.category != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (selectedCount > 0)
                        selectedCount == 1
                            ? "1 guest selected"
                            : "$selectedCount guests selected",
                      if (draft.category != null)
                        draft.type ?? draft.category!,
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

  // ── Void window ────────────────────────────────────────────────────────

  /// How long after a reservation is made a ticket on it may still be voided.
  static const Duration _voidWindow = Duration(hours: 24);

  /// Whether Void is still on offer: a ticket may only be voided within a day
  /// of the reservation being made, so the category is closed off once that
  /// day is up rather than being taken and refused later.
  ///
  /// Measured from the reservation's own created date. A reservation that came
  /// back without one falls back to its arrival date and then to now, which is
  /// the model's doing — where that happens the window is read off whatever
  /// stood in.
  bool _canVoid(ReservationBallys reservation) {
    return !DateTime.now().isAfter(reservation.insertDate.add(_voidWindow));
  }

  /// "made 3 days ago" — how long the reservation has been standing, for the
  /// line saying why Void is closed.
  static String _madeAgoLabel(DateTime insertDate) {
    final elapsed = DateTime.now().difference(insertDate);
    if (elapsed.inDays >= 1) {
      final days = elapsed.inDays;
      return days == 1 ? "1 day ago" : "$days days ago";
    }
    final hours = elapsed.inHours;
    if (hours >= 1) return hours == 1 ? "1 hour ago" : "$hours hours ago";
    return "just now";
  }

  // ── Submitting ─────────────────────────────────────────────────────────

  /// The tickets in the amendment, in the order they are shown, paired with
  /// what has been filled in against each.
  List<MapEntry<int, _AmendableTicket>> _amendedTickets(
    List<_AmendableTicket> tickets,
  ) {
    final picked = _selectedTickets.where((i) => i < tickets.length).toList()
      ..sort();
    return picked.map((i) => MapEntry(i, tickets[i])).toList();
  }

  /// The first thing stopping the amendment from being sent, or null when
  /// there is nothing. One message at a time, naming the ticket it belongs to,
  /// so a long form does not answer with a wall of errors.
  String? _firstProblem(
    ReservationBallys reservation,
    List<_AmendableTicket> tickets,
  ) {
    final amended = _amendedTickets(tickets);
    if (amended.isEmpty) return "Tick at least one air ticket to amend.";

    for (final entry in amended) {
      final label = "Ticket ${entry.key + 1}";
      final draft = _draftFor(entry.key);

      if (draft.guests.isEmpty) {
        return "$label: select the guests this amendment is for.";
      }
      if (draft.category == null) return "$label: select the category.";
      if (draft.type == null) return "$label: select the type.";

      // The window can run out while the form is open, so it is checked again
      // here rather than trusted from when the category was picked.
      if (draft.isVoid && !_canVoid(reservation)) {
        return "$label: a ticket can only be voided within 24 hours of the "
            "reservation being made.";
      }

      if (draft.isCancelAndRefund && draft.refundMethod == null) {
        return "$label: select how the ticket is refunded.";
      }

      if (draft.isCabinUpgrade && draft.newClasses.isEmpty) {
        return "$label: select the class it is upgraded to.";
      }

      if (draft.isDateChange &&
          draft.newArrivalDate == null &&
          draft.newDepartureDate == null) {
        return "$label: pick the new arrival or departure date.";
      }

      if (draft.isRouteChange) {
        if (draft.routeLeg == null) return "$label: select which leg changes.";
        if (draft.changesDeparture &&
            (draft.departureFrom == null || draft.departureTo == null)) {
          return "$label: select the departure leg's From and To airports.";
        }
        if (draft.changesReturn &&
            (draft.returnFrom == null || draft.returnTo == null)) {
          return "$label: select the return leg's From and To airports.";
        }
        if (draft.isMultiSector) {
          final stops = [
            if (draft.changesDeparture) ...draft.departureSectors,
            if (draft.changesReturn) ...draft.returnSectors,
          ];
          if (stops.isEmpty) {
            return "$label: add a stop, or turn Multi Sector off.";
          }
          if (stops.any((stop) => stop.airport == null)) {
            return "$label: every stop needs an airport.";
          }
        }
      }
    }
    return null;
  }

  /// One transit stop as the API takes it, keyed the same way the ticket's own
  /// stops are.
  Map<String, dynamic> _sectorJson(FlightSectorEntry sector) {
    return {
      'AirportCode': sector.airport?.airportCode ?? '',
      'CityName': sector.airport?.cityName ?? '',
      'AirportName': sector.airport?.airportName ?? '',
      'Country': sector.airport?.country ?? '',
      'SectorDate':
          sector.date == null ? '' : _dateFormat.format(sector.date!),
    };
  }

  Map<String, dynamic> _airportJson(Airport? airport) {
    return {
      'AirportCode': airport?.airportCode ?? '',
      'CityName': airport?.cityName ?? '',
      'AirportName': airport?.airportName ?? '',
      'Country': airport?.country ?? '',
    };
  }

  /// The whole amendment as one payload: the reservation it belongs to, and a
  /// row per ticket carrying who it is for and what changes.
  ///
  /// Each row holds only the detail its own type asked for, and states what
  /// the ticket holds now beside what it moves to — the back office needs both
  /// halves to record the change.
  Map<String, dynamic> _buildPayload(
    ReservationBallys reservation,
    List<_AmendableTicket> tickets,
  ) {
    final rows = <Map<String, dynamic>>[];

    for (final entry in _amendedTickets(tickets)) {
      final ticket = entry.value;
      final flight = ticket.flight;
      final draft = _draftFor(entry.key);

      final row = <String, dynamic>{
        'ticket_no': entry.key + 1,
        'departure_route': flight.departureRouteText,
        'return_route': flight.returnRouteText,
        'assigned_guests': draft.guests
            .where((i) => i < ticket.guests.length)
            .map((i) => ticket.guests[i].toJson())
            .toList(),
        'amendment_category': draft.category,
        'amendment_type': draft.type,
        'reason': draft.reason.text.trim(),
        'additional_remark': draft.additionalRemark.text.trim(),
      };

      if (draft.isCancelAndOpen) {
        row['ticket_validity_note'] = draft.validityNote.text.trim();
      }

      if (draft.isCancelAndRefund) {
        row['refund_method'] = draft.refundMethod;
      }

      if (draft.isCabinUpgrade) {
        row['previous_classes'] =
            flight.ticketClasses.map((c) => c.toJson()).toList();
        row['new_classes'] = draft.newClasses.map((c) => c.toJson()).toList();
      }

      if (draft.isDateChange) {
        row['previous_arrival_date'] = flight.arrivalDate?.toIso8601String();
        row['previous_departure_date'] =
            flight.departureDate?.toIso8601String();
        row['new_arrival_date'] = draft.newArrivalDate?.toIso8601String();
        row['new_departure_date'] = draft.newDepartureDate?.toIso8601String();
      }

      if (draft.isRouteChange) {
        row['route_leg'] = draft.routeLeg;
        row['is_multi_sector'] = draft.isMultiSector;
        if (draft.changesDeparture) {
          row['new_departure_leg'] = {
            'from': _airportJson(draft.departureFrom),
            'to': _airportJson(draft.departureTo),
            'sectors': draft.isMultiSector
                ? draft.departureSectors.map(_sectorJson).toList()
                : const [],
          };
        }
        if (draft.changesReturn) {
          row['new_return_leg'] = {
            'from': _airportJson(draft.returnFrom),
            'to': _airportJson(draft.returnTo),
            'sectors': draft.isMultiSector
                ? draft.returnSectors.map(_sectorJson).toList()
                : const [],
          };
        }
      }

      rows.add(row);
    }

    return {
      'master_id': reservation.idNo,
      'reservation_no': reservation.reservNo,
      'bm_number': reservation.mid,
      'guest_name': reservation.mName,
      'amendment_on': 'AirTicket',
      'tickets': rows,
    };
  }

  /// What the reason field is called. The field is the same whichever type
  /// asked for it; only the wording follows the type.
  static String _reasonLabel(_TicketAmendmentDraft draft) {
    if (draft.isCabinUpgrade) return "Reason for Upgrade";
    if (draft.isDateChange) return "Reason for Date Change";
    if (draft.isRouteChange) return "Reason for Route Change";
    if (draft.isVoid) return "Reason for Void";
    if (draft.isCancelAndOpen || draft.isCancelAndRefund) {
      return "Reason for Cancellation";
    }
    return "Reason";
  }

  static String _reasonHint(_TicketAmendmentDraft draft) {
    if (draft.isCabinUpgrade) return "Why is this ticket being upgraded?";
    if (draft.isDateChange) {
      return "Why are this ticket's dates being changed?";
    }
    if (draft.isRouteChange) return "Why is this ticket's route being changed?";
    if (draft.isVoid) return "Why is this ticket being voided?";
    if (draft.isCancelAndOpen || draft.isCancelAndRefund) {
      return "Why is this ticket being cancelled?";
    }
    return "Why is this amendment being raised?";
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
    List<_AmendableTicket> tickets,
  ) async {
    final problem = _firstProblem(reservation, tickets);
    if (problem != null) {
      _showMessage(problem);
      return;
    }

    final count = _amendedTickets(tickets).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Submit Amendment"),
        content: Text(
          count == 1
              ? "Raise this amendment for 1 air ticket?"
              : "Raise this amendment for $count air tickets?",
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

    final payload = _buildPayload(reservation, tickets);

    // The endpoint that takes this does not exist yet, so the amendment is
    // built and shown rather than sent. Everything it needs is in [payload] —
    // posting it is all that is left to add here.
    debugPrint("Air ticket amendment payload: $payload");

    _showMessage(
      count == 1
          ? "Amendment prepared for 1 ticket. It is not sent yet — the "
              "amendment endpoint is still to be connected."
          : "Amendment prepared for $count tickets. It is not sent yet — the "
              "amendment endpoint is still to be connected.",
      isError: false,
    );
  }

  /// The button that raises the amendment. Greyed until a ticket is ticked,
  /// since that is the least an amendment can be.
  Widget _submitButton(
    ReservationBallys reservation,
    List<_AmendableTicket> tickets,
    FontSettings fontSettings,
  ) {
    final count = _amendedTickets(tickets).length;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed:
            count == 0 ? null : () => _onSubmit(reservation, tickets),
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
        child: Text(
          count == 0
              ? "Submit Amendment"
              : count == 1
                  ? "Submit Amendment (1 ticket)"
                  : "Submit Amendment ($count tickets)",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Route change ───────────────────────────────────────────────────────

  /// The legs a route change may move. A one-way ticket has no return leg, so
  /// only its outbound is on offer.
  List<String> _legsFor(FlightBookingBallys flight) {
    final hasReturn = flight.airports?.returnFlight != null || flight.isRoundTrip;
    return hasReturn
        ? const [_legDeparture, _legReturn, _legBoth]
        : const [_legDeparture];
  }

  /// Says whether the airport picker has anything to offer. Silent once the
  /// airports are loaded, which is the ordinary case by the time a route
  /// change is being filled in.
  Widget _airportListStatus(FontSettings fontSettings) {
    if (_isLoadingAirports) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              "Loading airports...",
              style: TextStyle(
                fontSize: fontSettings.fontSize - 3,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (ref.watch(airportsProvider).isNotEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Airports could not be loaded, so the picker has nothing to "
              "search.",
              style: TextStyle(
                fontSize: fontSettings.fontSize - 3,
                color: const Color.fromARGB(255, 168, 49, 49),
              ),
            ),
          ),
          TextButton(
            onPressed: _loadAirports,
            style: TextButton.styleFrom(
              foregroundColor: Constants.kPrimaryColor,
            ),
            child: Text(
              "Retry",
              style: TextStyle(
                fontSize: fontSettings.fontSize - 3,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One leg of the new route: where it flies from, where it flies to, and the
  /// stops in between while the route is multi-sector.
  ///
  /// [current] is the leg as the ticket holds it now, shown above the fields —
  /// the amendment says what the route becomes, so the fields start empty
  /// rather than pre-filled with the route being moved away from.
  Widget _routeLegSection({
    required String title,
    required String current,
    required Airport? from,
    required Airport? to,
    required ValueChanged<Airport> onFrom,
    required ValueChanged<Airport> onTo,
    required bool showSectors,
    required List<FlightSectorEntry> sectors,
    required FontSettings fontSettings,
  }) {
    return Container(
      // Keyed by leg: the airport fields keep what they show in their own
      // state, so without this the return leg could take over the departure
      // leg's element — and its airports with it — when the leg is switched.
      key: ValueKey("route-leg-$title"),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            current.isEmpty ? "No route on this ticket" : "Currently: $current",
            style: TextStyle(
              fontSize: fontSettings.fontSize - 3,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          CustomAirportField(
            key: ValueKey("$title-from"),
            label: "From",
            prefixIcon: Icons.airplane_ticket_outlined,
            suffixIcon: Icons.arrow_drop_down,
            cityCountryText:
                from != null ? "${from.cityName} - ${from.country}" : null,
            airportNameText: from?.airportCode,
            onAirportSelected: (airport) => setState(() => onFrom(airport)),
          ),
          const SizedBox(height: 8),
          CustomAirportField(
            key: ValueKey("$title-to"),
            label: "To",
            prefixIcon: Icons.airplane_ticket_outlined,
            suffixIcon: Icons.arrow_drop_down,
            cityCountryText:
                to != null ? "${to.cityName} - ${to.country}" : null,
            airportNameText: to?.airportCode,
            onAirportSelected: (airport) => setState(() => onTo(airport)),
          ),
          if (showSectors)
            _sectorSection(
              label: "$title Stops",
              sectors: sectors,
              from: from,
              to: to,
              fontSettings: fontSettings,
            ),
        ],
      ),
    );
  }

  /// The transit stops on one leg, in travel order between its endpoints —
  /// the same block the ticket was booked with.
  Widget _sectorSection({
    required String label,
    required List<FlightSectorEntry> sectors,
    required Airport? from,
    required Airport? to,
    required FontSettings fontSettings,
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
        borderRadius: BorderRadius.circular(8),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFFDADDE3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            routeCodes.join(" → "),
            style: TextStyle(
              fontSize: fontSettings.fontSize,
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
                    onAirportSelected: (airport) =>
                        setState(() => sectors[i].airport = airport),
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
            // The stop's own travel day, so a route spread over several days
            // reads in order rather than as a bare list of airports.
            Padding(
              // Lines the field up with the airport field above, clear of the
              // remove button's column.
              padding: const EdgeInsets.only(top: 8, right: 48),
              child: _dateField(
                label: "Stop ${i + 1} Date",
                value: sectors[i].date,
                fontSettings: fontSettings,
                onTap: () => _pickDate(
                  title: "Stop ${i + 1} Date",
                  current: sectors[i].date,
                  ticketDate: null,
                  onPicked: (picked) => sectors[i].date = picked,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => sectors.add(FlightSectorEntry())),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: Text(
                "Add Stop",
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: FontWeight.bold,
                ),
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

  /// Turns the stops on and off for whichever legs the change covers. Each leg
  /// starts with one empty stop so there is something to fill in straight away.
  void _onMultiSectorChanged(_TicketAmendmentDraft draft, bool value) {
    setState(() {
      draft.isMultiSector = value;
      if (!value) {
        draft.departureSectors.clear();
        draft.returnSectors.clear();
        return;
      }
      if (draft.changesDeparture && draft.departureSectors.isEmpty) {
        draft.departureSectors.add(FlightSectorEntry());
      }
      if (draft.changesReturn && draft.returnSectors.isEmpty) {
        draft.returnSectors.add(FlightSectorEntry());
      }
    });
  }

  /// Moving to a leg the stops were not built for leaves the other leg's stops
  /// behind, so they are dropped as the leg changes.
  void _onRouteLegChanged(_TicketAmendmentDraft draft, String? value) {
    if (value == draft.routeLeg) return;
    setState(() {
      draft.routeLeg = value;
      if (!draft.changesDeparture) {
        draft.departureFrom = null;
        draft.departureTo = null;
        draft.departureSectors.clear();
      }
      if (!draft.changesReturn) {
        draft.returnFrom = null;
        draft.returnTo = null;
        draft.returnSectors.clear();
      }
      if (draft.isMultiSector) _seedSectors(draft);
    });
  }

  /// A leg that has just come into the change needs a stop to fill in.
  void _seedSectors(_TicketAmendmentDraft draft) {
    if (draft.changesDeparture && draft.departureSectors.isEmpty) {
      draft.departureSectors.add(FlightSectorEntry());
    }
    if (draft.changesReturn && draft.returnSectors.isEmpty) {
      draft.returnSectors.add(FlightSectorEntry());
    }
  }

  /// The guests this ticket came back with, each pickable in their own right —
  /// an amendment can be raised for one traveller on a shared ticket without
  /// touching the others.
  Widget _guestPicker(
    int index,
    _AmendableTicket ticket,
    _TicketAmendmentDraft draft,
    FontSettings fontSettings,
  ) {
    if (ticket.guests.isEmpty) {
      return Text(
        "This ticket came back without any guests, so there is nobody to "
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
          ticket.guests.length == 1
              ? "Guest on this ticket"
              : "Guests on this ticket (${ticket.guests.length})",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        ...ticket.guests.asMap().entries.map((entry) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                        value: isSelected,
                        activeColor: Constants.kPrimaryColor,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
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

  /// The amendment itself, asked for once the ticket has someone to amend it
  /// for — the amendment is raised against guests, so they come first.
  Widget _amendmentFields(
    int index,
    ReservationBallys reservation,
    _AmendableTicket ticket,
    _TicketAmendmentDraft draft,
    FontSettings fontSettings,
  ) {
    if (draft.guests.isEmpty) {
      return Text(
        "Select at least one guest to amend this ticket.",
        style: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
          color: Colors.grey.shade700,
        ),
      );
    }

    final types = _typesByCategory[draft.category] ?? const <String>[];
    final canVoid = _canVoid(reservation);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Amendment for this ticket",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // ── Amendment category ───────────────────────────────────────────
        //
        // Void is only on offer for a day after the reservation is made, so
        // outside that it is greyed out where it stands — hiding it would
        // leave the rule unexplained.
        DropdownButtonFormField<String>(
          initialValue: draft.category,
          isExpanded: true,
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
            color: Colors.black,
          ),
          decoration:
              _dropdownDeco("Amendment Category", fontSettings).copyWith(
            helperText: canVoid
                ? null
                : "Void is closed — a ticket can only be voided within 24 "
                    "hours of the reservation being made "
                    "(made ${_madeAgoLabel(reservation.insertDate)})",
            helperMaxLines: 3,
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
          items: _typesByCategory.keys.map((c) {
            final enabled = c != _voidCategory || canVoid;
            return DropdownMenuItem<String>(
              value: c,
              enabled: enabled,
              child: Text(
                c,
                style: TextStyle(
                  color: enabled ? Colors.black : Colors.grey,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) => _onCategoryChanged(index, value),
        ),

        // ── Amendment type ───────────────────────────────────────────────
        //
        // Only appears once a category is picked, since its contents are the
        // category's — and only while that category leaves something to
        // choose. Void carries one type and has it filled in already, so a
        // dropdown holding that single entry is left out rather than shown
        // with nothing to do.
        if (types.length > 1) ...[
          const SizedBox(height: 10.0),
          DropdownButtonFormField<String>(
            initialValue: draft.type,
            isExpanded: true,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
              color: Colors.black,
            ),
            decoration: _dropdownDeco("Amendment Type", fontSettings),
            hint: Text(
              "Select type",
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
            items: types
                .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                .toList(),
            onChanged: (value) => _onTypeChanged(index, value),
          ),
        ],

        // ── Cabin upgrade detail ─────────────────────────────────────────
        //
        // The class the ticket holds now, the classes it moves to, and why —
        // only asked for on Exchange → Cabin Upgrade.
        if (draft.isCabinUpgrade) ...[
          const SizedBox(height: 10.0),
          // Not asked for: the class it moves *from* is the ticket's own, so
          // it is shown as the ticket carries it rather than picked again and
          // risked disagreeing with the ticket.
          // _readOnlyField(
          //   label: "Previous Class",
          //   value: ticket.flight.ticketClassSummary,
          //   fontSettings: fontSettings,
          // ),
          // const SizedBox(height: 10.0),
          // Several classes with their own seat counts, the same picker the
          // ticket was booked with — an upgrade can move some of a ticket's
          // seats up and leave the rest where they are. Capped at the seats
          // the ticket holds: an upgrade moves seats, it does not add any.
          AirTicketClassCountSelector(
            label: "New Class",
            selectedClasses: draft.newClasses,
            maxSeats: ticket.flight.totalTicketCount > 0
                ? ticket.flight.totalTicketCount
                : null,
            onChanged: (classes) => setState(() => draft.newClasses = classes),
          ),
        ],

        // ── Date change detail ───────────────────────────────────────────
        //
        // The days the ticket moves to — only asked for on Exchange → Date
        // Change. The days it moves *from* are the ticket's own, so they sit
        // under each field rather than being picked again.
        if (draft.isDateChange) ...[
          const SizedBox(height: 10.0),
          _dateField(
            label: "Arrival Date",
            value: draft.newArrivalDate,
            helperText: _currentlyLabel(ticket.flight.arrivalDate),
            fontSettings: fontSettings,
            onTap: () => _pickDate(
              title: "Arrival Date",
              current: draft.newArrivalDate,
              ticketDate: ticket.flight.arrivalDate,
              onPicked: (picked) {
                draft.newArrivalDate = picked;
                // A departure already picked can be left stranded on or
                // before the new arrival, so it goes rather than standing as
                // a date the ticket could not be flown on.
                final departure = draft.newDepartureDate;
                if (departure != null && !departure.isAfter(picked)) {
                  draft.newDepartureDate = null;
                }
              },
            ),
          ),
          const SizedBox(height: 10.0),
          _dateField(
            label: "Departure Date",
            value: draft.newDepartureDate,
            helperText: _currentlyLabel(ticket.flight.departureDate),
            fontSettings: fontSettings,
            onTap: () => _pickDate(
              title: "Departure Date",
              current: draft.newDepartureDate,
              ticketDate: ticket.flight.departureDate,
              // Against the new arrival where one is picked, otherwise
              // against the arrival the ticket already holds.
              mustBeAfter:
                  draft.newArrivalDate ?? ticket.flight.arrivalDate,
              onPicked: (picked) => draft.newDepartureDate = picked,
            ),
          ),
        ],

        // ── Route change detail ──────────────────────────────────────────
        //
        // Which legs move, where they move to, and the stops they route
        // through — only asked for on Exchange → Route Change. A change need
        // not touch both legs, so the leg comes first and only what it names
        // is filled in.
        if (draft.isRouteChange) ...[
          const SizedBox(height: 10.0),
          Builder(
            builder: (context) {
              final legs = _legsFor(ticket.flight);

              return DropdownButtonFormField<String>(
                initialValue: draft.routeLeg,
                isExpanded: true,
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                  color: Colors.black,
                ),
                decoration: _dropdownDeco("Which Leg Changes", fontSettings)
                    .copyWith(
                  helperText: legs.length == 1
                      ? "One-way ticket — it has only an outbound leg"
                      : null,
                  helperStyle: TextStyle(
                    fontSize: fontSettings.fontSize - 3,
                    color: Colors.grey.shade700,
                  ),
                ),
                hint: Text(
                  "Select leg",
                  style: TextStyle(
                    fontSize: fontSettings.fontSize,
                    fontWeight: fontSettings.fontWeight,
                  ),
                ),
                items: legs
                    .map((leg) =>
                        DropdownMenuItem<String>(value: leg, child: Text(leg)))
                    .toList(),
                onChanged: (value) => _onRouteLegChanged(draft, value),
              );
            },
          ),

          // The stops belong to the route as a whole, so the tick sits above
          // the legs and each leg carries its own stops underneath.
          if (draft.routeLeg != null) ...[
            const SizedBox(height: 4),
            CheckboxListTile(
              value: draft.isMultiSector,
              onChanged: (value) =>
                  _onMultiSectorChanged(draft, value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: Constants.kPrimaryColor,
              title: Text(
                "Multi Sector (No Direct Flight)",
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                ),
              ),
            ),
          ],

          // The airports the picker searches are fetched when this screen
          // opens; say so while that is in flight, and offer it again when it
          // came back with nothing.
          if (draft.routeLeg != null) _airportListStatus(fontSettings),

          if (draft.changesDeparture)
            _routeLegSection(
              title: "Departure",
              current: ticket.flight.departureRouteText,
              from: draft.departureFrom,
              to: draft.departureTo,
              onFrom: (airport) => draft.departureFrom = airport,
              onTo: (airport) => draft.departureTo = airport,
              showSectors: draft.isMultiSector,
              sectors: draft.departureSectors,
              fontSettings: fontSettings,
            ),

          if (draft.changesReturn)
            _routeLegSection(
              title: "Return",
              current: ticket.flight.returnRouteText,
              from: draft.returnFrom,
              to: draft.returnTo,
              onFrom: (airport) => draft.returnFrom = airport,
              onTo: (airport) => draft.returnTo = airport,
              showSectors: draft.isMultiSector,
              sectors: draft.returnSectors,
              fontSettings: fontSettings,
            ),
        ],

        // ── Refund detail ────────────────────────────────────────────────
        //
        // How the money goes back — only asked for on Cancellation → Cancel &
        // refund ticket, which is the one type that settles the ticket rather
        // than leaving it open.
        if (draft.isCancelAndRefund) ...[
          const SizedBox(height: 10.0),
          DropdownButtonFormField<String>(
            initialValue: draft.refundMethod,
            isExpanded: true,
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
              color: Colors.black,
            ),
            decoration: _dropdownDeco("Refund Method", fontSettings),
            hint: Text(
              "Select refund method",
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
            items: _refundMethods
                .map((m) =>
                    DropdownMenuItem<String>(value: m, child: Text(m)))
                .toList(),
            onChanged: (value) =>
                setState(() => draft.refundMethod = value),
          ),
        ],

        // ── Why, and anything else ───────────────────────────────────────
        //
        // Asked for by every type that carries detail, so the two fields are
        // written once and only their wording follows the type.
        if (draft.hasDetail) ...[
          const SizedBox(height: 10.0),
          _textField(
            label: _reasonLabel(draft),
            controller: draft.reason,
            fontSettings: fontSettings,
            maxLines: 3,
            hint: _reasonHint(draft),
          ),
          // What the cancelled ticket is still worth. Only Cancel and open
          // ticket asks for it — the ticket stays alive, so its validity and
          // the terms it can be reissued on travel with the amendment.
          if (draft.isCancelAndOpen) ...[
            const SizedBox(height: 10.0),
            _textField(
              label: "Ticket Validity / Reissue Note",
              controller: draft.validityNote,
              fontSettings: fontSettings,
              maxLines: 3,
              hint: "How long the ticket stays valid and on what terms it "
                  "can be reissued",
            ),
          ],
          const SizedBox(height: 10.0),
          _textField(
            label: "Additional Remark",
            controller: draft.additionalRemark,
            fontSettings: fontSettings,
            maxLines: 4,
            hint: "Enter additional details...",
          ),
        ],
      ],
    );
  }

  Widget _ticketCard(
    int index,
    ReservationBallys reservation,
    _AmendableTicket ticket,
    FontSettings fontSettings,
  ) {
    final draft = _draftFor(index);
    final isSelected = _selectedTickets.contains(index);

    return Card(
      // A ticked ticket lifts out of the grey, the same way a ticked guest
      // does, so the tickets in the amendment read at a glance.
      color: isSelected
          ? const Color.fromARGB(255, 245, 233, 208)
          : const Color.fromARGB(255, 228, 224, 224),
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        // Outlined once the ticket is ticked, and more heavily once its
        // amendment is filled in, so a long list shows at a glance which
        // tickets have been dealt with.
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
            onTap: () => _toggleTicket(index),
            borderRadius: BorderRadius.circular(4),
            child: _ticketSummary(
              index,
              ticket,
              draft,
              isSelected,
              fontSettings,
            ),
          ),
          // A ticket that is not in the amendment has nothing to pick under
          // it, so the guests and the amendment come with the tick.
          if (isSelected) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _guestPicker(index, ticket, draft, fontSettings),
                  if (ticket.guests.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _amendmentFields(index, reservation, ticket, draft, fontSettings),
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
    final selectedFlights = ref.watch(selectedFlightBallysProvider);
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
        title: const Text(
          "Air Ticket Amendment",
          style: TextStyle(fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Back goes to the reservation detail view, which still owns the
            // selection providers this screen read from.
            if (context.canPop()) {
              context.pop();
            } else {
              context
                  .go('/reservationMain/reservations/reservation-view-ballys');
            }
          },
        ),
      ),
      body: reservation == null
          ? const Center(child: Text('No reservation selected.'))
          : Builder(
              builder: (context) {
                final tickets = _tickets(reservation, selectedFlights);

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Whose reservation this is. The guests themselves are
                        // picked per ticket below, not here.
                        AmendmentGuestHeaderBallys(
                          reservation: reservation,
                          showGuests: false,
                        ),
                        const SizedBox(height: 10.0),

                        // ── Air tickets ──────────────────────────────────
                        Text(
                          tickets.length == 1
                              ? "Air Ticket"
                              : "Air Tickets (${tickets.length})",
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // if (tickets.isNotEmpty) ...[
                        //   const SizedBox(height: 2),
                        //   Text(
                        //     _guestAndTicketCounts(
                        //       tickets.map((t) => t.flight).toList(),
                        //     ),
                        //     style: TextStyle(
                        //       fontSize: fontSettings.fontSize - 3,
                        //       color: Colors.grey.shade700,
                        //     ),
                        //   ),
                        //   const SizedBox(height: 2),
                        //   Text(
                        //     // Says what to do while nothing is ticked, then
                        //     // gives way to how much of the reservation the
                        //     // amendment now covers.
                        //     _selectedTickets.isEmpty
                        //         ? "Tick each ticket to amend, then pick its "
                        //             "guests and raise the amendment for it."
                        //         : "Selected: ${_selectedTickets.length} of "
                        //             "${tickets.length} tickets",
                        //     style: TextStyle(
                        //       fontSize: fontSettings.fontSize - 3,
                        //       fontWeight: _selectedTickets.isEmpty
                        //           ? FontWeight.normal
                        //           : FontWeight.bold,
                        //       color: _selectedTickets.isEmpty
                        //           ? Colors.grey.shade700
                        //           : Constants.kPrimaryColor,
                        //     ),
                        //   ),
                        // ],
                        // const SizedBox(height: 8.0),

                        if (tickets.isEmpty)
                          const Center(
                            heightFactor: 3.0,
                            child: Text(
                              'No air tickets available.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color.fromARGB(255, 168, 49, 49),
                              ),
                            ),
                          )
                        else
                          ...tickets.asMap().entries.map(
                                (entry) => _ticketCard(
                                  entry.key,
                                  reservation,
                                  entry.value,
                                  fontSettings,
                                ),
                              ),
                        const SizedBox(height: 20.0),

                        // ── Submit ───────────────────────────────────────
                        if (tickets.isNotEmpty)
                          _submitButton(reservation, tickets, fontSettings),
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
