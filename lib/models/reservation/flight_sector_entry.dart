import 'package:ballys_reservation_app/models/airport_search_response.dart';
import 'package:flutter/foundation.dart';

/// One transit stop being edited on screen, for guests with no direct flight.
///
/// The [key] keeps a stop's airport picker bound to its own row as rows are
/// added and removed — without it Flutter reuses the picker state and a deleted
/// stop's airport shows up on the next row.
class FlightSectorEntry {
  FlightSectorEntry({this.airport});

  final Key key = UniqueKey();
  Airport? airport;
}
