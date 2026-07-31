import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/guest_reservation_entryBallys.dart';
import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    this.selectable = false,
    this.selectedGuestIndexes = const <int>{},
    this.onGuestToggled,
  });

  final ReservationBallys reservation;

  /// True while the member's profile card is still being fetched, so the card
  /// can show its own spinner instead of an empty avatar.
  final bool isGuestLoading;

  /// When true each guest card carries a checkbox, so an amendment can be
  /// raised against a subset of the reservation's guests rather than all of it.
  final bool selectable;

  /// Positions within `reservation.guests` that are ticked. Indexes rather than
  /// BM numbers: a guest entry can come back with a blank `mid`, which would
  /// make several of them share one key.
  final Set<int> selectedGuestIndexes;

  /// Fired with the guest's index when its checkbox (or card) is tapped. The
  /// parent owns the selection, so it decides what a tap means.
  final ValueChanged<int>? onGuestToggled;

  /// A guest's package amount as it should be shown. Guests who carry no
  /// package of their own come back as a bare `0.00` with a blank currency —
  /// they travel on another guest's package.
  static String _packageLabel(String raw) {
    final amount = raw.trim();
    final numeric = amount.isEmpty
        ? null
        : double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (numeric == null || numeric == 0) return 'Shared';
    return amount;
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

  Widget _buildGuestsSection(
    List<GuestReservationEntryBallys> guests,
    FontSettings fontSettings,
  ) {
    if (guests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          guests.length == 1 ? "Guest" : "Guests (${guests.length})",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6.0),
        ...guests.asMap().entries.map((entry) {
          final index = entry.key;
          final guest = entry.value;
          final packageLabel = _packageLabel(guest.packageAmount);
          final isSelected = selectedGuestIndexes.contains(index);

          final card = Card(
            // A ticked guest lifts out of the grey so the chosen ones read at a
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
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: onGuestToggled == null
                                ? null
                                : (_) => onGuestToggled!(index),
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black,
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
                        child: Text(
                          guest.guestName.isNotEmpty
                              ? guest.guestName
                              : "Unnamed guest",
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (guest.mid.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      guest.mid,
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
                    guest.hasFamilyMembers
                        ? "Family members: Included"
                        : "Family members: Not included",
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                  // Members on this guest's package hold no rooms or tickets of
                  // their own, so they only show up here.
                  ...guest.accompanyingMembers.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "Same package: ${m.guestName} (${m.mid})"
                        " · ${_packageLabel(m.packageAmount)}"
                        "${m.hasFamilyMembers ? ' · Family members included' : ''}",
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          // Tapping anywhere on the card toggles it — the checkbox alone is a
          // small target for a card this size.
          if (!selectable || onGuestToggled == null) return card;
          return InkWell(
            onTap: () => onGuestToggled!(index),
            borderRadius: BorderRadius.circular(4),
            child: card,
          );
        }),
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
        _buildGuestsSection(reservation.guests, fontSettings),
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
