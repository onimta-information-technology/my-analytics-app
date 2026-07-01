import 'package:ballys_reservation_app/components/bottom_sheets/airport_search_bottom_sheet.dart';
import 'package:ballys_reservation_app/models/airport_search_response.dart';
import 'package:ballys_reservation_app/providers/airports_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomAirportField extends ConsumerStatefulWidget {
  final String label;
  final IconData prefixIcon;
  final IconData suffixIcon;
  final Function(Airport) onAirportSelected;
  final String? cityCountryText;
  final String? airportNameText;
  final bool hasError;

  const CustomAirportField({
    super.key,
    required this.label,
    required this.prefixIcon,
    required this.suffixIcon,
    required this.onAirportSelected,
    this.cityCountryText,
    this.airportNameText,
    this.hasError = false,
  });

  @override
  ConsumerState<CustomAirportField> createState() => _CustomAirportFieldState();
}

class _CustomAirportFieldState extends ConsumerState<CustomAirportField> {
  String? selectedCityCountry;
  String? selectedAirportName;

  @override
  void initState() {
    super.initState();
    selectedCityCountry = widget.cityCountryText;
    selectedAirportName = widget.airportNameText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
              fontSize: 14.0, color: Color.fromARGB(255, 87, 86, 86)),
        ),
        const SizedBox(height: 8.0),
        GestureDetector(
          onTap: () {
            _openAirportSearchBottomSheet((selectedAirport) {
              setState(() {
                selectedCityCountry =
                    "${selectedAirport.cityName} - ${selectedAirport.country}";
                selectedAirportName = selectedAirport.airportCode;
              });
              widget.onAirportSelected(selectedAirport);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 8.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.hasError ? Colors.red : Colors.grey,
                width: widget.hasError ? 2.0 : 1.0,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Icon(
                  widget.prefixIcon,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedCityCountry?.toLowerCase() ?? "City - Country",
                        style: TextStyle(
                          fontSize: 14.0,
                          color: selectedCityCountry == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 0),
                      Text(
                        selectedAirportName ?? "Select Airport",
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: selectedAirportName == null
                              ? FontWeight.normal
                              : FontWeight.bold,
                          color: selectedAirportName == null
                              ? Colors.grey[600]
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  widget.suffixIcon,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (widget.hasError)
          const Padding(
            padding: EdgeInsets.only(top: 6.0, left: 8.0),
            child: Text(
              "Required",
              style: TextStyle(fontSize: 12.0, color: Colors.red),
            ),
          ),
      ],
    );
  }

  void _openAirportSearchBottomSheet(Function(Airport) onAirportSelected) {
    ref.read(airportsProvider.notifier).filterAirports("");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return AirportSearchBottomSheet(onAirportSelected: onAirportSelected);
      },
    );
  }
}
