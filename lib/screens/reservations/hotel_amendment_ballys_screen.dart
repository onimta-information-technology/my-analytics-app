import 'package:ballys_reservation_app/components/amendment_guest_header_ballys.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc_ballys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selectedReservationforBallys_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider_ballys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Hotel side of the reservation amendment flow.
///
/// Reached from the Amendment button on `ReservationViewScreenBallys` (Pending
/// only) after choosing "Hotel". Shows the guest block plus every room booked
/// on the reservation, read from the same `selectedHotelBallysProvider` the
/// detail view populated — so no refetch and no extra arguments to pass.
class HotelAmendmentBallysScreen extends ConsumerWidget {
  const HotelAmendmentBallysScreen({super.key});

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

    String txt =
        totalGuests == 1 ? "$totalGuests GUEST" : "$totalGuests GUESTS";
    txt += totalRooms == 1 ? ", $totalRooms ROOM" : ", $totalRooms ROOMS";
    return txt;
  }

  Widget _buildHotelCard(HotelDescipBallys hotel, FontSettings fontSettings) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: const Color.fromARGB(255, 228, 224, 224),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hotel.hotelName ?? '',
                style: TextStyle(
                  fontSize: fontSettings.fontSize,
                  fontWeight: fontSettings.fontWeight,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Category: ",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: fontSettings.fontSize + 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: hotel.roomCategoryName,
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Room Type: ",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: fontSettings.fontSize + 2,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                    TextSpan(
                      text: hotel.roomTypeName,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Guests: ${hotel.guestCount}",
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    "Nights: ${hotel.noOfNights}",
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    "Rooms: ${hotel.roomCount}",
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: const Text(
          "Hotel Amendment",
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
                        AmendmentGuestHeaderBallys(reservation: reservation),
                        const SizedBox(height: 10.0),

                        // ── Hotel & Rooms summary ────────────────────────
                        // TextFormField(
                        //   readOnly: true,
                        //   controller: TextEditingController(
                        //     text: _guestAndRoomCounts(selectedHotels),
                        //   ),
                        //   style: TextStyle(
                        //     fontSize: fontSettings.fontSize,
                        //     fontWeight: fontSettings.fontWeight,
                        //   ),
                        //   decoration: InputDecoration(
                        //     labelText: "Hotels & Rooms",
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

                        // // ── Hotel cards ──────────────────────────────────
                        // if (selectedHotels.isEmpty)
                        //   const Center(
                        //     heightFactor: 3.0,
                        //     child: Text(
                        //       'No hotels selected.',
                        //       style: TextStyle(
                        //         fontSize: 16,
                        //         color: Color.fromARGB(255, 168, 49, 49),
                        //       ),
                        //     ),
                        //   )
                        // else
                        //   ...selectedHotels.map(
                        //     (hotel) => _buildHotelCard(hotel, fontSettings),
                        //   ),
                        // const SizedBox(height: 16.0),
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
