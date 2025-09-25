import 'package:flutter/material.dart';

class AirTicketClassSelector extends StatefulWidget {
  final Function(Map<String, dynamic>?) onClassSelected;
  final Map<String, dynamic>? selectedClass;

  const AirTicketClassSelector({
    super.key,
    required this.onClassSelected,
    required this.selectedClass,
  });

  @override
  State<AirTicketClassSelector> createState() => _ClassSelectorState();
}

class _ClassSelectorState extends State<AirTicketClassSelector> {
  final List<Map<String, dynamic>> _classes = [
    {"id": 1, "type": "Economy"},
    {"id": 2, "type": "Premium Economy"},
    {"id": 3, "type": "Business"},
    {"id": 4, "type": "First"},
  ];

  Map<String, dynamic>? _selectedClass;

  @override
  void initState() {
    super.initState();

    if (widget.selectedClass != null) {
      _selectedClass = _classes.firstWhere(
        (item) => item['id'] == widget.selectedClass!['id'],
        orElse: () => {"id": 0, "type": "Unknown"},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      decoration: InputDecoration(
        labelText: "Class",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        prefixIcon: const Icon(Icons.event_seat_outlined),
      ),
      initialValue: _selectedClass,
      items: _classes
          .map(
            (classItem) => DropdownMenuItem<Map<String, dynamic>>(
              value: classItem,
              child: Text(classItem['type']),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedClass = value;
        });
        widget.onClassSelected(value);
      },
      hint: const Text("Select Class"),
    );
  }
}
