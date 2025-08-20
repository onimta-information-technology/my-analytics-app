import 'dart:convert';

import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/member_search_provider.dart';
import 'package:ballys_reservation_app/providers/new_reservation_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MemberSearchBottomSheet extends ConsumerWidget {
  final List<GuestSearchResponse> guests;
  final bool navigateToProfile;
  final String profilePath;
  const MemberSearchBottomSheet(
      {super.key,
      required this.guests,
      this.navigateToProfile = false,
      this.profilePath = '/home/profile'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextEditingController bottomSearchController =
        TextEditingController();

    return FractionallySizedBox(
      heightFactor: 0.7,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Search Member By Member ID",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: bottomSearchController,
              decoration: InputDecoration(
                labelText: "Search Member",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    print("Searching member: ${bottomSearchController.text}");
                  },
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: guests.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      final guest = guests[index];
                      ref.read(selectedGuestProvider.notifier).setSelectedGuest(
                            Guest(
                              mid: guest.mid,
                              memberName: guest.mName,
                              country: "",
                              lastVisitDate: "1990-01-01",
                              age: 0,
                              gRating: "",
                              mGroup: "",
                              gName: "",
                            ),
                          );
                      if (navigateToProfile) {
                        context.push(profilePath);
                        return;
                      } else {
                        ref
                            .read(memberSearchProvider.notifier)
                            .updateMemberInfo(guest.mid, guest.mName);
                        ref
                            .read(newReservationProvider.notifier)
                            .updateMemberInfo(guest.mid, guest.mName);
                        Navigator.of(context).pop();
                      }
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
                        leading: CircleAvatar(
                          backgroundImage: MemoryImage(
                            base64Decode(guests[index].memImage2),
                          ),
                          radius: 24.0,
                        ),
                        title: Text(
                          guests[index].mid,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(guests[index].mName),
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
