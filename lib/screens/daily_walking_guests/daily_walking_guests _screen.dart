import 'dart:convert';

import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/models/Guest/daily_walking_guest.dart';
import 'package:ballys_reservation_app/providers/daily_walking_provider.dart';

class DailyWalkingGuestScreen extends ConsumerStatefulWidget {
  const DailyWalkingGuestScreen({super.key});

  @override
  ConsumerState<DailyWalkingGuestScreen> createState() =>
      _DailyWalkingGuestScreenState();
}

class _DailyWalkingGuestScreenState
    extends ConsumerState<DailyWalkingGuestScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch data on page load
    Future.microtask(() {
      ref.read(dailyWalkingProvider.notifier).getDailyWalkingGuests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final guests = ref.watch(dailyWalkingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Walking Guests"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(dailyWalkingProvider.notifier).getDailyWalkingGuests();
            },
          ),
        ],
      ),
      body: Stack(children: [
        
      
      Padding(
        padding: const EdgeInsets.all(12),
        child: guests.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Guests count
                  Row(
                    children: [
                      const Text(
                        "Total Guests: ",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        guests.length.toString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Guest details list
                  Expanded(
                    child: ListView.builder(
                      itemCount: guests.length,
                      itemBuilder: (context, index) {
                        final guest = guests[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image + Details
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          detailRow("MID", guest.mId),
                                          detailRow("Member Name", guest.mname),
                                          detailRow("Country", guest.country),
                                          detailRow("Contact No", guest.phone),
                                          detailRow("Register Date", guest.rdt),
                                          detailRow("Latest Visit", "Today"),
                                          detailRow("Type", "WALKING"),
                                          detailRow("DTL", guest.dlt.toString()),
                                          detailRow("ADT", guest.adt.toString()),
                                        ],
                                      ),
                                    ),
                                     const SizedBox(width: 12),
                          // Guest image (base64 or placeholder)
                          Hero(
                            tag: "guest-image-$index",
                            child: guest.menImage2.isNotEmpty
                                ? Image.memory(
                                    base64Decode(guest.menImage2),
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    'assets/images/placeholder_image.jpg',
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                          ),

                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      const Watermark(),
      ])
    );
  }

  Widget detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
