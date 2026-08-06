import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FlightCardBallys extends StatelessWidget {
  final dynamic flight;
  final int index;
  final bool showDelete;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;

  const FlightCardBallys({
    super.key,
    required this.flight,
    required this.index,
    required this.showDelete,
    this.onDoubleTap,
    this.onDelete,
  });

  /// " (Arrival)" / " (Departure)" — blank when the flight carries no leg,
  /// which is the case for anything saved before the facility asked for one.
  static String _leg(String? type) {
    final leg = type?.trim() ?? '';
    return leg.isEmpty ? '' : ' ($leg)';
  }

  /// Costs are only carried by tickets saved while the cost calculator still
  /// existed, so the line is dropped when there is nothing to show.
  static String? _costText(dynamic cost) {
    final text = cost?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', ''));
    if (value == null || value == 0) return null;
    return text;
  }

  /// "BM0012 — John Doe, BM0043 — Mary Doe" — who the ticket is booked for.
  /// Blank on tickets picked before the assignment existed.
  static String _assignedText(dynamic flight) {
    final assigned = flight.assignedGuests as List?;
    if (assigned == null || assigned.isEmpty) return '';
    return assigned.map((g) => g.label as String).join(", ");
  }

  @override
  Widget build(BuildContext context) {
    final assignedText = _assignedText(flight);

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: SizedBox(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Who the ticket is booked for, ahead of the route: a
                    // reservation can carry a ticket per guest.
                    if (assignedText.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.group,
                              size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              assignedText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Bounded so a multi-sector route ("CMB → DXB → LHR")
                        // wraps instead of running into the guest counts.
                        Expanded(
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.flight_takeoff,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    // Includes every transit stop, so the whole
                                    // outbound leg reads in travel order.
                                    flight.departureRouteText,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (flight.airports!.returnFlight != null)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.flight_land,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      flight.returnRouteText,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            Text(
                              // Every class on the ticket with its seat count,
                              // e.g. "Economy x2, Business x1".
                              "Class: ${flight.ticketClassSummary}",
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.person, color: Colors.grey),
                            const SizedBox(height: 4),
                            const Text(
                              "Guests",
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${flight.guestCount}",
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Only worth the space once someone is travelling
                            // with children / infants.
                            if ((flight.childrenCount ?? 0) > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Children: ${flight.childrenCount}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if ((flight.infantCount ?? 0) > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Infants: ${flight.infantCount}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Arrival Date: ${flight.arrivalDate != null ? DateFormat('yyyy-MM-dd').format(flight.arrivalDate!) : 'N/A'}",
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Departure Date: ${flight.departureDate != null ? DateFormat('yyyy-MM-dd').format(flight.departureDate!) : 'N/A'}",
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((flight.airLine as String?)?.trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 5),
                      Text(
                        "Airline: ${flight.airLine}",
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (_costText(flight.selectedCost) != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        "Estimated Cost: ${_costText(flight.selectedCost)}",
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (flight.contactPerson != null &&
                        (flight.contactPerson as String).trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        "Contact Person: ${flight.contactPerson}",
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      "Visa: ${flight.visa == true ? 'Yes' : 'No'}",
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Airport Transportation: ${flight.airportTransportation == 1 ? 'Yes' : 'No'}",
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      // The leg only means something once the facility is on.
                      "Silk Route: ${flight.silkRoute == 1 ? 'Yes${_leg(flight.silkRouteType)}' : 'No'}",
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (flight.isMultiSector == true) ...[
                      const SizedBox(height: 5),
                      const Text(
                        "Multi Sector: Yes",
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (flight.goldRoute) ...[
                      const SizedBox(height: 5),
                      Text(
                        "Gold Route: Yes${_leg(flight.goldRouteType)}",
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (flight.extraLegroomSeat == true) ...[
                      const SizedBox(height: 5),
                      const Text(
                        "Extra Legroom Seat: Yes",
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (flight.meal) ...[
                      const SizedBox(height: 5),
                      Text(
                        flight.mealRemark?.trim().isNotEmpty == true
                            ? "Meal: Yes — ${flight.mealRemark!.trim()}"
                            : "Meal: Yes",
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showDelete)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
