import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SalesPersonsScreen extends ConsumerStatefulWidget {
  final Map<String, List<Guest>> salesPersons;
  final String title;

  const SalesPersonsScreen({
    super.key,
    required this.salesPersons,
    required this.title,
  });

  @override
  ConsumerState<SalesPersonsScreen> createState() => _SalesPersonsScreenState();
}

class _SalesPersonsScreenState extends ConsumerState<SalesPersonsScreen> {
  List<MapEntry<String, List<Guest>>> _filteredSalesPersons = [];

  @override
  void initState() {
    super.initState();
    _filteredSalesPersons = widget.salesPersons.entries.toList();
  }

  void _filterSalesPersons(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSalesPersons = widget.salesPersons.entries.toList();
      } else {
        _filteredSalesPersons = widget.salesPersons.entries
            .where(
              (entry) => entry.value[0].gName!.toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  onChanged: (value) {
                    _filterSalesPersons(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredSalesPersons.length,
                  itemBuilder: (context, index) {
                    final entry = _filteredSalesPersons[index];
                    final guests = entry.value;

                    return Card(
                      margin: const EdgeInsets.all(10.0),
                      child: ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                entry.value[0].gName ?? '',
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color.fromARGB(255, 152, 98, 6)
                                  .withAlpha(90),
                              child: Text(
                                entry.value[0].mid == ''
                                    ? '0'
                                    : guests.length.toString(),
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                            ),
                          ],
                        ),

                        onTap: () {
                          if (entry.value[0].mid == '') return;
                          context.push(
                            '/home/member-visits',
                            extra: {
                              'title':
                                  '${entry.value[0].gName} - Today Member Visits',
                              'guestList': guests,
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const Watermark(),
        ],
      ),
    );
  }
}
