import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/guest_reservation_entryBallys.dart';
import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Points at one person on the reservation: a guest entry itself
/// ([memberIndex] null), or one of the members sharing that guest's package.
///
/// Positions rather than BM numbers: a guest entry can come back with a blank
/// `mid`, which would make several of them share one key.
@immutable
class AmendmentGuestRef {
  const AmendmentGuestRef(this.guestIndex, [this.memberIndex]);

  /// Position within `reservation.guests`.
  final int guestIndex;

  /// Position within that guest's `accompanyingMembers`, or null when the ref
  /// is the guest itself.
  final int? memberIndex;

  bool get isMember => memberIndex != null;

  @override
  bool operator ==(Object other) =>
      other is AmendmentGuestRef &&
      other.guestIndex == guestIndex &&
      other.memberIndex == memberIndex;

  @override
  int get hashCode => Object.hash(guestIndex, memberIndex);
}

/// Reservation + guest block shared by the two amendment screens
/// (`HotelAmendmentBallysScreen` / `AirTicketAmendmentBallysScreen`).
///
/// Both amendment screens open on top of `ReservationViewScreenBallys`, so the
/// reservation identity and the guests it carries have to read the same on all
/// three — this keeps that block in one place. Everything here is read-only and
/// comes from the `ReservationBallys` the list screen already parsed.
class AmendmentGuestHeaderBallys extends ConsumerWidget {
  const AmendmentGuestHeaderBallys({
    super.key,
    required this.reservation,
    this.isGuestLoading = false,
    this.showGuests = true,
    this.selectable = false,
    this.selectedGuests = const <AmendmentGuestRef>{},
    this.onGuestToggled,
  });

  final ReservationBallys reservation;

  /// True while the member's profile card is still being fetched, so the card
  /// can show its own spinner instead of an empty avatar.
  final bool isGuestLoading;

  /// Whether the reservation's guests are listed under the member card. Off on
  /// screens that pick their guests somewhere else — the air ticket amendment
  /// picks them per ticket, where the ticket says who it is booked for — so the
  /// block is only the reservation's identity.
  final bool showGuests;

  /// When true every person on the reservation — each guest and each member
  /// sharing a guest's package — carries their own checkbox, so an amendment
  /// can be raised against a subset of them rather than the whole booking.
  final bool selectable;

  /// The people ticked. See [AmendmentGuestRef] for why they are addressed by
  /// position rather than BM number.
  final Set<AmendmentGuestRef> selectedGuests;

  /// Fired with the person's ref when their checkbox (or row) is tapped. The
  /// parent owns the selection, so it decides what a tap means.
  final ValueChanged<AmendmentGuestRef>? onGuestToggled;

  /// A guest's package amount as it should be shown, matching
  /// `ReservationViewScreenBallys` so the same person reads the same on the
  /// view screen and on the amendment screens opened on top of it.
  ///
  /// Guests who carry no package of their own come back as a bare `0.00` with
  /// a blank currency, which reads as travelling on someone else's package.
  /// The amount arrives as `"<currency> <number>"` — the currency is kept as
  /// it is and the number is shown whole, grouped in thousands: `IND 10,000`.
  ///
  /// [shared] is the person's own `IsSharedAmount` tick, which the payload
  /// sends in its own right: an amount can be both real and shared with the
  /// members on the package, so the tick is shown next to the amount rather
  /// than replacing it.
  static String _packageLabel(String raw, {bool shared = false}) {
    final amount = raw.trim();
    final numeric = amount.isEmpty
        ? null
        : double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), ''));
    // No package of their own — they travel on another guest's package.
    if (numeric == null || numeric == 0) return 'Shared';

    final currency = amount.replaceAll(RegExp(r'[0-9.,]'), '').trim();
    final formatted = NumberFormat('#,##0').format(numeric);
    final label = currency.isEmpty ? formatted : '$currency $formatted';
    return shared ? '$label (Shared)' : label;
  }

  Widget _readOnlyField(
    String label,
    String value,
    FontSettings fontSettings, {
    int maxLines = 1,
  }) {
    return TextFormField(
      readOnly: true,
      maxLines: maxLines,
      controller: TextEditingController(text: value),
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
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: -5.0,
        ),
      ),
    );
  }

  /// One person's card — a guest, or a member sharing a guest's package. Both
  /// read the same and sit at the same level, so every person on the
  /// reservation is ticked in their own right rather than through the guest
  /// they happen to hang off.
  ///
  /// [position] draws the numbered avatar used when nothing is selectable;
  /// [sharedWith] names the guest whose package this person is on, shown only
  /// for members. [extra] carries anything else that belongs under the card.
  Widget _personCard({
    required AmendmentGuestRef ref,
    required String name,
    required String mid,
    required String packageLabel,
    required bool hasFamilyMembers,
    required FontSettings fontSettings,
    int? position,
    String? sharedWith,
    List<Widget> extra = const [],
  }) {
    final isSelected = selectedGuests.contains(ref);

    final card = Card(
      // A ticked person lifts out of the grey so the chosen ones read at a
      // glance without having to scan the checkboxes.
      color: selectable && isSelected
          ? const Color.fromARGB(255, 245, 233, 208)
          : const Color.fromARGB(255, 228, 224, 224),
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: selectable && isSelected
            ? const BorderSide(color: Constants.kPrimaryColor, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selectable)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: isSelected,
                      activeColor: Constants.kPrimaryColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: onGuestToggled == null
                          ? null
                          : (_) => onGuestToggled!(ref),
                    ),
                  )
                else if (position != null)
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black,
                    child: Text(
                      "$position",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            if (mid.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                mid,
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              "Package: $packageLabel",
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasFamilyMembers
                  ? "Family members: Included"
                  : "Family members: Not included",
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
            ...extra,
          ],
        ),
      ),
    );

    // Tapping anywhere on the card toggles it — the checkbox alone is a small
    // target for a card this size.
    if (!selectable || onGuestToggled == null) return card;
    return InkWell(
      onTap: () => onGuestToggled!(ref),
      borderRadius: BorderRadius.circular(4),
      child: card,
    );
  }

  Widget _buildGuestsSection(
    List<GuestReservationEntryBallys> guests,
    FontSettings fontSettings,
  ) {
    if (guests.isEmpty) return const SizedBox.shrink();

    final cards = <Widget>[];
    for (var index = 0; index < guests.length; index++) {
      final guest = guests[index];

      cards.add(
        _personCard(
          ref: AmendmentGuestRef(index),
          name: guest.guestName.isNotEmpty ? guest.guestName : "Unnamed guest",
          mid: guest.mid,
          packageLabel: _packageLabel(
            guest.packageAmount,
            shared: guest.sharedPackage,
          ),
          hasFamilyMembers: guest.hasFamilyMembers,
          fontSettings: fontSettings,
          position: index + 1,
          // With no selection on, members stay summarised on the guest's own
          // card; the cards below only exist while each person is pickable.
          extra: selectable
              ? const []
              : guest.accompanyingMembers
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "Same package: ${m.guestName} (${m.mid})"
                        " · ${_packageLabel(m.packageAmount, shared: m.sharedPackage)}"
                        "${m.hasFamilyMembers ? ' · Family members included' : ''}",
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      );

      if (!selectable) continue;

      // Each member sharing this guest's package gets a card of its own, right
      // after the guest they belong to, so an amendment can be raised against
      // one member without touching the rest of the package.
      for (var m = 0; m < guest.accompanyingMembers.length; m++) {
        final member = guest.accompanyingMembers[m];
        cards.add(
          _personCard(
            ref: AmendmentGuestRef(index, m),
            name: member.guestName.isNotEmpty
                ? member.guestName
                : "Unnamed member",
            mid: member.mid,
            packageLabel: _packageLabel(
              member.packageAmount,
              shared: member.sharedPackage,
            ),
            hasFamilyMembers: member.hasFamilyMembers,
            fontSettings: fontSettings,
            sharedWith: guest.guestName.isNotEmpty
                ? guest.guestName
                : "guest ${index + 1}",
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cards.length == 1 ? "Guest" : "Guests (${cards.length})",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6.0),
        ...cards,
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // _readOnlyField("Reservation No", reservation.reservNo, fontSettings),
        // const SizedBox(height: 10.0),
        // _readOnlyField("Member ID", reservation.mid, fontSettings),
        // const SizedBox(height: 10.0),
        // _readOnlyField("Member Name", reservation.mName, fontSettings),
        // const SizedBox(height: 10.0),

        // ── Guest card ─────────────────────────────────────────────────────
        GuestDisplayCardSpecialGiftview(
          memberIdText: reservation.mid,
          memberNameText: reservation.mName,
          showCard: reservation.mid.isNotEmpty && reservation.mName.isNotEmpty,
          isLoading: isGuestLoading,
          showLastVisitDate: true,
        ),
        const SizedBox(height: 10.0),

        // ── All guests on this reservation ─────────────────────────────────
        if (showGuests) _buildGuestsSection(reservation.guests, fontSettings),
        // const SizedBox(height: 10.0),

        // Row(
        //   children: [
        //     Expanded(
        //       child: _readOnlyField(
        //         "Arrival Date",
        //         dateFormat.format(reservation.arrDate),
        //         fontSettings,
        //       ),
        //     ),
        //     const SizedBox(width: 10),
        //     Expanded(
        //       child: _readOnlyField(
        //         "Departure Date",
        //         dateFormat.format(reservation.depDate),
        //         fontSettings,
        //       ),
        //     ),
        //   ],
        // ),
      ],
    );
  }
}
