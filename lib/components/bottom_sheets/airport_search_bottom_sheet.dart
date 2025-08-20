import 'package:ballys_reservation_app/models/airport_search_response.dart';
import 'package:ballys_reservation_app/providers/airports_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AirportSearchBottomSheet extends ConsumerWidget {
  final Function(Airport) onAirportSelected;

  const AirportSearchBottomSheet({super.key, required this.onAirportSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airports = ref.watch(airportsProvider);
    final airportsNotifier = ref.read(airportsProvider.notifier);
    final TextEditingController bottomSearchController =
        TextEditingController();

    final FocusNode searchFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchFocusNode.requestFocus();
    });

    return FractionallySizedBox(
      heightFactor: 0.7,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Destination Airport",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              focusNode: searchFocusNode,
              decoration: InputDecoration(
                labelText: "Search Airport",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    final query = bottomSearchController.text.trim();
                    airportsNotifier.filterAirports(query);
                  },
                ),
              ),
              onChanged: (query) {
                airportsNotifier.filterAirports(query);
              },
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: airports.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      final airport = airports[index];
                      onAirportSelected(airport);
                      Navigator.of(context).pop();
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 2.0, horizontal: 2.0),
                      elevation: 4.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 5.0, horizontal: 8.0),
                        title: Text(
                          "${airports[index].airportName ?? "Unknown"} - ${airports[index].country ?? "Unknown"} (${airports[index].airportCode ?? "N/A"})",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
