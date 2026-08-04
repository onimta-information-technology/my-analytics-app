import 'package:ballys_reservation_app/models/reservation/air_ticket_class_count.dart';
import 'package:flutter/material.dart';

/// Picks the cabin classes on a ticket. A ticket can carry more than one, so
/// each class is ticked on its own and gets its own seat count — Economy x2
/// plus Business x1 is one ticket, not two.
///
/// Fully controlled: [selectedClasses] is what is shown, and every change is
/// handed back through [onChanged].
class AirTicketClassCountSelector extends StatelessWidget {
  final List<AirTicketClassCount> selectedClasses;
  final ValueChanged<List<AirTicketClassCount>> onChanged;
  final bool hasError;

  /// Seats the ticket may hold in total, across every class. Set when the
  /// guests it is booked for bring no family with them — one seat each, so a
  /// lone guest gets one class and one seat. Null means no ceiling, which is
  /// what family members need since their headcount is not known here.
  final int? maxSeats;

  const AirTicketClassCountSelector({
    super.key,
    required this.selectedClasses,
    required this.onChanged,
    this.hasError = false,
    this.maxSeats,
  });

  /// The cabin classes on offer — the same list, in the same order and with the
  /// same ids, as `AirTicketClassSelector`.
  static const List<Map<String, dynamic>> classes = [
    {"id": 1, "type": "Economy"},
    {"id": 2, "type": "Premium Economy"},
    {"id": 3, "type": "Business"},
    {"id": 4, "type": "First"},
  ];

  AirTicketClassCount? _selected(int id) {
    for (final item in selectedClasses) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Ticking a class adds it with one seat; unticking drops it and its count.
  /// The picks stay in [classes] order however they were ticked, so the ticket
  /// always reads the same way.
  void _toggle(int id, String name, bool selected) {
    // A new class needs a seat to sit in, and at the ceiling there is none.
    if (selected && _selected(id) == null && _atLimit) return;
    final next = List<AirTicketClassCount>.from(selectedClasses)
      ..removeWhere((item) => item.id == id);
    if (selected) {
      next.add(AirTicketClassCount(id: id, name: name));
    }
    next.sort((a, b) => _order(a.id).compareTo(_order(b.id)));
    onChanged(next);
  }

  void _setCount(int id, int count) {
    // One seat is the floor — no seats means the class is not on the ticket,
    // which is what unticking it is for.
    if (count < 1) return;
    final current = _selected(id)?.count ?? 0;
    if (count > current && _atLimit) return;
    onChanged(selectedClasses
        .map((item) => item.id == id ? item.copyWith(count: count) : item)
        .toList());
  }

  static int _order(int id) {
    final index = classes.indexWhere((item) => item['id'] == id);
    return index == -1 ? classes.length : index;
  }

  /// Seats already on the ticket, across every class.
  int get _totalSeats =>
      selectedClasses.fold<int>(0, (sum, item) => sum + item.count);

  /// No more seats can go on the ticket, so ticking another class and adding
  /// to a count are both off.
  bool get _atLimit => maxSeats != null && _totalSeats >= maxSeats!;

  @override
  Widget build(BuildContext context) {
    final totalSeats = _totalSeats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: "Class",
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            prefixIcon: const Icon(Icons.event_seat_outlined),
            errorText: hasError ? "Select at least one class" : null,
            helperText: _helperText(totalSeats),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final classItem in classes)
                _classRow(
                  id: classItem['id'] as int,
                  name: classItem['type'] as String,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Says how many seats are on the ticket and, where there is a ceiling, how
  /// many it may hold — a single guest with no family sees "1 of 1" and can go
  /// no further.
  String _helperText(int totalSeats) {
    if (maxSeats != null) {
      final seatWord = maxSeats == 1 ? "ticket" : "tickets";
      if (selectedClasses.isEmpty) {
        return "Pick a class — $maxSeats $seatWord for the guests on this ticket";
      }
      return "Total tickets: $totalSeats of $maxSeats";
    }
    return selectedClasses.isEmpty
        ? "Pick one or more classes"
        : "Total tickets: $totalSeats";
  }

  Widget _classRow({required int id, required String name}) {
    final selected = _selected(id);
    // A class that is not on the ticket can only be ticked while there are
    // seats left for it.
    final canTick = selected != null || !_atLimit;

    return Row(
      children: [
        Checkbox(
          value: selected != null,
          onChanged:
              canTick ? (value) => _toggle(id, name, value ?? false) : null,
        ),
        Expanded(
          child: GestureDetector(
            onTap: canTick ? () => _toggle(id, name, selected == null) : null,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                color: canTick ? null : Colors.grey,
              ),
            ),
          ),
        ),
        // The counter only means anything once the class is on the ticket.
        if (selected != null)
          Row(
            children: [
              _countButton(
                icon: Icons.remove,
                // At one seat there is nothing left to take away — untick the
                // class instead.
                onTap: selected.count > 1
                    ? () => _setCount(id, selected.count - 1)
                    : null,
              ),
              SizedBox(
                width: 36,
                child: Text(
                  "${selected.count}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _countButton(
                icon: Icons.add,
                // Adding a seat is off once the ticket holds a seat for every
                // guest it is booked for.
                onTap: _atLimit ? null : () => _setCount(id, selected.count + 1),
              ),
            ],
          ),
      ],
    );
  }

  Widget _countButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade300 : Colors.grey,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
