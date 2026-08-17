import 'package:ballys_reservation_app/components/air_ticket_class_count_selector.dart';
import 'package:ballys_reservation_app/components/amendment_guest_header_ballys.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/reservation/air_ticket_class_count.dart';
import 'package:ballys_reservation_app/models/guest_reservation_entryBallys.dart';
import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/models/reservation/assigned_guest.dart';
import 'package:ballys_reservation_app/models/reservation/flight_bookng_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selectedReservationforBallys_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider_ballys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// One air ticket on the reservation together with the people it may be
/// amended for.
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
  List<AirTicketClassCount> newClasses = const [];

  final TextEditingController upgradeReason = TextEditingController();
  final TextEditingController additionalRemark = TextEditingController();

  bool get isCabinUpgrade =>
      category == _AirTicketAmendmentBallysScreenState._exchange &&
      type == _AirTicketAmendmentBallysScreenState._cabinUpgrade;

  /// A ticket counts as amended once someone is picked and the amendment is
  /// named — the detail below the type is asked for per type, not always.
  bool get isComplete => guests.isNotEmpty && category != null && type != null;

  void clearCabinUpgrade() {
    newClasses = const [];
    upgradeReason.clear();
    additionalRemark.clear();
  }

  void dispose() {
    upgradeReason.dispose();
    additionalRemark.dispose();
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
  // dropdowns are driven off one map rather than three parallel lists. Void
  // carries a single type, which is why it still gets a type dropdown — it just
  // has nothing else in it.
  static const String _exchange = 'Exchange';
  static const String _voidCategory = 'Void';
  static const String _routeCancellation = 'Cancellation';

  static const String _cabinUpgrade = 'Cabin Upgrade';

  static const Map<String, List<String>> _typesByCategory = {
    _exchange: [_cabinUpgrade, 'Date Change', 'Route Change'],
    _voidCategory: ['Void'],
    _routeCancellation: ['Cancel and open ticket', 'Cancel & refund ticket'],
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
      draft.clearCabinUpgrade();
    });
  }

  void _onTypeChanged(int ticketIndex, String? value) {
    final draft = _draftFor(ticketIndex);
    if (value == draft.type) return;
    setState(() {
      draft.type = value;
      if (value != _cabinUpgrade) draft.clearCabinUpgrade();
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
          items: _typesByCategory.keys
              .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
              .toList(),
          onChanged: (value) => _onCategoryChanged(index, value),
        ),

        // ── Amendment type ───────────────────────────────────────────────
        //
        // Only appears once a category is picked, since its contents are the
        // category's.
        if (draft.category != null) ...[
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
          const SizedBox(height: 10.0),
          _textField(
            label: "Reason for Upgrade",
            controller: draft.upgradeReason,
            fontSettings: fontSettings,
            maxLines: 3,
            hint: "Why is this ticket being upgraded?",
          ),
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
                    _amendmentFields(index, ticket, draft, fontSettings),
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
                        if (tickets.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _guestAndTicketCounts(
                              tickets.map((t) => t.flight).toList(),
                            ),
                            style: TextStyle(
                              fontSize: fontSettings.fontSize - 3,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // Says what to do while nothing is ticked, then
                            // gives way to how much of the reservation the
                            // amendment now covers.
                            _selectedTickets.isEmpty
                                ? "Tick each ticket to amend, then pick its "
                                    "guests and raise the amendment for it."
                                : "Selected: ${_selectedTickets.length} of "
                                    "${tickets.length} tickets",
                            style: TextStyle(
                              fontSize: fontSettings.fontSize - 3,
                              fontWeight: _selectedTickets.isEmpty
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              color: _selectedTickets.isEmpty
                                  ? Colors.grey.shade700
                                  : Constants.kPrimaryColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8.0),

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
                                  entry.value,
                                  fontSettings,
                                ),
                              ),
                        const SizedBox(height: 16.0),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
