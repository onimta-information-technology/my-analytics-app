import 'package:ballys_reservation_app/components/amendment_guest_header_ballys.dart';
import 'package:ballys_reservation_app/components/flight_card_ballys.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/models/reservation/flight_bookng_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selectedReservationforBallys_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider_ballys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Air ticket side of the reservation amendment flow.
///
/// Reached from the Amendment button on `ReservationViewScreenBallys` (Pending
/// only) after choosing "Air Ticket". Shows the guest block plus every ticket
/// booked on the reservation, read from `selectedFlightBallysProvider` which the
/// detail view already populated.
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
  static const String _routeCancellation = 'Route Cancellation';

  static const String _cabinUpgrade = 'Cabin Upgrade';

  static const Map<String, List<String>> _typesByCategory = {
    _exchange: [_cabinUpgrade, 'Date Change', 'Route Change'],
    _voidCategory: ['Void'],
    _routeCancellation: ['Cancel and open ticket', 'Cancel & refund ticket'],
  };

  /// Cabin classes, matching `AirTicketClassSelector` so an upgrade reads in the
  /// same terms the ticket was booked in.
  static const List<String> _cabinClasses = [
    'Economy',
    'Premium Economy',
    'Business',
    'First',
  ];

  String? _category;
  String? _type;

  // ── Guest selection ────────────────────────────────────────────────────
  //
  // An amendment is raised against particular guests, not the whole booking, so
  // the guests are picked first. Indexes into `reservation.guests` — see the
  // header component for why not BM numbers.
  final Set<int> _selectedGuestIndexes = <int>{};

  /// How many of the selected guests this amendment covers. Stepped by hand
  /// rather than derived, so it can be set to fewer than the guests ticked.
  int _guestCount = 0;

  void _toggleGuest(int index) {
    setState(() {
      if (!_selectedGuestIndexes.remove(index)) {
        _selectedGuestIndexes.add(index);
      }
    });
  }

  /// Guests ticked, and the tickets they hold between them. Each guest entry
  /// carries its own `flights`, so a subset of guests is a subset of tickets.
  ({int guests, int tickets}) _selectedCounts(ReservationBallys reservation) {
    int guests = 0;
    int tickets = 0;
    for (final index in _selectedGuestIndexes) {
      if (index < 0 || index >= reservation.guests.length) continue;
      guests++;
      tickets += reservation.guests[index].flights.length;
    }
    return (guests: guests, tickets: tickets);
  }

  /// Tickets behind the ticked guests, shown as context under the stepper.
  /// Older payloads carry the tickets only at reservation level and leave each
  /// guest's `flights` empty, so fall back to the reservation's own list.
  int _selectedTickets(
    ReservationBallys reservation,
    List<FlightBookingBallys> reservationFlights,
  ) {
    if (_selectedGuestIndexes.isEmpty) return 0;
    final fromGuests = _selectedCounts(reservation).tickets;
    return fromGuests > 0 ? fromGuests : reservationFlights.length;
  }

  /// One square of the guest-count stepper. A null [onTap] greys it out — the
  /// button stays in place so the row doesn't reflow at the ends of the range.
  Widget _stepperButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? Constants.kPrimaryColor : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? Colors.white : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  static String _countsLabel(int guests, int tickets) {
    final guestText = guests == 1 ? "$guests GUEST" : "$guests GUESTS";
    final ticketText = tickets == 1 ? "$tickets TICKET" : "$tickets TICKETS";
    return "$guestText, $ticketText";
  }

  // ── Cabin upgrade detail ───────────────────────────────────────────────
  // Only collected for Exchange → Cabin Upgrade; cleared whenever the type
  // moves away from it so a later submit can't carry stale values.
  String? _previousClass;
  String? _newClass;
  final TextEditingController _upgradeReasonController =
      TextEditingController();
  final TextEditingController _additionalRemarkController =
      TextEditingController();

  bool get _isCabinUpgrade => _category == _exchange && _type == _cabinUpgrade;

  @override
  void dispose() {
    _upgradeReasonController.dispose();
    _additionalRemarkController.dispose();
    super.dispose();
  }

  List<String> get _typesForCategory =>
      _typesByCategory[_category] ?? const <String>[];

  void _onCategoryChanged(String? value) {
    if (value == _category) return;
    setState(() {
      _category = value;
      final types = _typesByCategory[value] ?? const <String>[];
      // A single-type category (Void) has nothing to choose, so it is filled in
      // rather than left blank for the user to open and pick the only entry.
      _type = types.length == 1 ? types.first : null;
      _clearCabinUpgradeFields();
    });
  }

  void _onTypeChanged(String? value) {
    if (value == _type) return;
    setState(() {
      _type = value;
      if (value != _cabinUpgrade) _clearCabinUpgradeFields();
    });
  }

  void _clearCabinUpgradeFields() {
    _previousClass = null;
    _newClass = null;
    _upgradeReasonController.clear();
    _additionalRemarkController.clear();
  }

  Widget _classDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    required FontSettings fontSettings,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      style: TextStyle(
        fontSize: fontSettings.fontSize,
        fontWeight: fontSettings.fontWeight,
        color: Colors.black,
      ),
      decoration: _dropdownDeco(label, fontSettings),
      hint: Text(
        "Select class",
        style: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
        ),
      ),
      items: _cabinClasses
          .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
          .toList(),
      onChanged: onChanged,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 12.0,
        ),
      ),
    );
  }

  InputDecoration _dropdownDeco(String label, FontSettings fontSettings) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: fontSettings.fontSize,
        fontWeight: fontSettings.fontWeight,
      ),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 4.0,
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
      body: Stack(
        children: [
          reservation == null
              ? const Center(child: Text('No reservation selected.'))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AmendmentGuestHeaderBallys(
                          reservation: reservation,
                          selectable: true,
                          selectedGuestIndexes: _selectedGuestIndexes,
                          onGuestToggled: _toggleGuest,
                        ),
                        const SizedBox(height: 10.0),

                        // ── Guest count ──────────────────────────────────
                        //
                        // Stepped by hand. The guests ticked above only set the
                        // ceiling — how many of them this amendment actually
                        // covers is the user's call.
                        Builder(
                          builder: (context) {
                            final counts = _selectedCounts(reservation);
                            final available = counts.guests;
                            final tickets =
                                _selectedTickets(reservation, selectedFlights);
                            // A count left over from a wider selection would sit
                            // above the new ceiling, so trim it as we render.
                            final count = _guestCount.clamp(0, available);

                            return InputDecorator(
                              decoration: _dropdownDeco(
                                "Guest Count",
                                fontSettings,
                              ).copyWith(
                                helperText: available == 0
                                    ? "Select a guest first"
                                    : "Selected: ${_countsLabel(available, tickets)}",
                                helperStyle: TextStyle(
                                  fontSize: fontSettings.fontSize - 3,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              child: Row(
                                children: [
                                  _stepperButton(
                                    icon: Icons.remove,
                                    // Nothing below zero, and nothing to step
                                    // through until a guest is ticked.
                                    onTap: count > 0
                                        ? () => setState(
                                              () => _guestCount = count - 1,
                                            )
                                        : null,
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        count == 1
                                            ? "1 GUEST"
                                            : "$count GUESTS",
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: FontWeight.bold,
                                          color: count == 0
                                              ? Colors.grey.shade600
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _stepperButton(
                                    icon: Icons.add,
                                    onTap: count < available
                                        ? () => setState(
                                              () => _guestCount = count + 1,
                                            )
                                        : null,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10.0),

                        // ── Amendment category ───────────────────────────
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                            color: Colors.black,
                          ),
                          decoration:
                              _dropdownDeco("Amendment Category", fontSettings),
                          hint: Text(
                            "Select category",
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                            ),
                          ),
                          items: _typesByCategory.keys
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: _onCategoryChanged,
                        ),

                        // ── Amendment type ───────────────────────────────
                        //
                        // Only appears once a category is picked, since its
                        // contents are the category's.
                        if (_category != null) ...[
                          const SizedBox(height: 10.0),
                          DropdownButtonFormField<String>(
                            initialValue: _type,
                            isExpanded: true,
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: fontSettings.fontWeight,
                              color: Colors.black,
                            ),
                            decoration:
                                _dropdownDeco("Amendment Type", fontSettings),
                            hint: Text(
                              "Select type",
                              style: TextStyle(
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                              ),
                            ),
                            items: _typesForCategory
                                .map(
                                  (t) => DropdownMenuItem<String>(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: _onTypeChanged,
                          ),
                        ],

                        // ── Cabin upgrade detail ─────────────────────────
                        //
                        // The class the ticket holds now, the class it moves to,
                        // and why — only asked for on Exchange → Cabin Upgrade.
                        if (_isCabinUpgrade) ...[
                          const SizedBox(height: 10.0),
                          _classDropdown(
                            label: "Previous Class",
                            value: _previousClass,
                            fontSettings: fontSettings,
                            onChanged: (value) =>
                                setState(() => _previousClass = value),
                          ),
                          const SizedBox(height: 10.0),
                          _classDropdown(
                            label: "New Class",
                            value: _newClass,
                            fontSettings: fontSettings,
                            onChanged: (value) =>
                                setState(() => _newClass = value),
                          ),
                          const SizedBox(height: 10.0),
                          _textField(
                            label: "Reason for Upgrade",
                            controller: _upgradeReasonController,
                            fontSettings: fontSettings,
                            maxLines: 3,
                            hint: "Why is this ticket being upgraded?",
                          ),
                          const SizedBox(height: 10.0),
                          _textField(
                            label: "Additional Remark",
                            controller: _additionalRemarkController,
                            fontSettings: fontSettings,
                            maxLines: 4,
                            hint: "Enter additional details...",
                          ),
                        ],
                        const SizedBox(height: 10.0),

                        // ── Air ticket summary ───────────────────────────
                        // TextFormField(
                        //   readOnly: true,
                        //   controller: TextEditingController(
                        //     text: _guestAndTicketCounts(selectedFlights),
                        //   ),
                        //   style: TextStyle(
                        //     fontSize: fontSettings.fontSize,
                        //     fontWeight: fontSettings.fontWeight,
                        //   ),
                        //   decoration: InputDecoration(
                        //     labelText: "Air Tickets",
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
                        // ),
                        // const SizedBox(height: 10.0),

                        // ── Air ticket cards ─────────────────────────────
                        //   if (selectedFlights.isEmpty)
                        //     const Center(
                        //       heightFactor: 3.0,
                        //       child: Text(
                        //         'No air tickets available.',
                        //         style: TextStyle(
                        //           fontSize: 16,
                        //           color: Color.fromARGB(255, 168, 49, 49),
                        //         ),
                        //       ),
                        //     )
                        //   else
                        //     ...selectedFlights.asMap().entries.map(
                        //           (entry) => FlightCardBallys(
                        //             flight: entry.value,
                        //             index: entry.key,
                        //             showDelete: false,
                        //           ),
                        //         ),
                        //   const SizedBox(height: 16.0),
                      ],
                    ),
                  ),
                ),
          //  const Watermark(),
        ],
      ),
    );
  }
}
