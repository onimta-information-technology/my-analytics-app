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

  const AirTicketClassCountSelector({
    super.key,
    required this.selectedClasses,
    required this.onChanged,
    this.hasError = false,
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
    onChanged(selectedClasses
        .map((item) => item.id == id ? item.copyWith(count: count) : item)
        .toList());
  }

  static int _order(int id) {
    final index = classes.indexWhere((item) => item['id'] == id);
    return index == -1 ? classes.length : index;
  }

  @override
  Widget build(BuildContext context) {
    final totalSeats =
        selectedClasses.fold<int>(0, (sum, item) => sum + item.count);

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
            helperText: selectedClasses.isEmpty
                ? "Pick one or more classes"
                : "Total tickets: $totalSeats",
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

  Widget _classRow({required int id, required String name}) {
    final selected = _selected(id);

    return Row(
      children: [
        Checkbox(
          value: selected != null,
          onChanged: (value) => _toggle(id, name, value ?? false),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _toggle(id, name, selected == null),
            child: Text(
              name,
              style: const TextStyle(fontSize: 16),
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
                onTap: () => _setCount(id, selected.count + 1),
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
