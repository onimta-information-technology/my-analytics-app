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

  @override
  Widget build(BuildContext context) {
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
                              "Class: ${flight.airTicketClassName}",
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
                    const SizedBox(height: 5),
                    Text(
                      "Estimated Cost: ${flight.selectedCost}",
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
