import 'package:flutter/material.dart';

class FlightCard extends StatelessWidget {
  final dynamic flight;
  final int index;
  final bool showDelete;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;

  const FlightCard({
    super.key,
    required this.flight,
    required this.index,
    required this.showDelete,
    this.onDoubleTap,
    this.onDelete,
  });

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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.flight_takeoff,
                                    color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  "${flight.airports!.departure!.dFrom.airportCode} → ${flight.airports!.departure!.dTo.airportCode}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (flight.airports!.returnFlight != null)
                              Row(
                                children: [
                                  const Icon(Icons.flight_land,
                                      color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${flight.airports!.returnFlight!.rFrom.airportCode} → ${flight.airports!.returnFlight!.rTo.airportCode}",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            Text(
                              "Class: ${flight.airTicketClassName}",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.person, color: Colors.grey),
                            const SizedBox(height: 4),
                            const Text(
                              "Guests",
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${flight.guestCount}",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Estimated Cost: ${flight.selectedCost}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
