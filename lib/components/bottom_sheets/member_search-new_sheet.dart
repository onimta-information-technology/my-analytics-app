import 'dart:convert';

import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/member_search_provider.dart';
import 'package:ballys_reservation_app/providers/new_reservation_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MemberNewSearchBottomSheet extends ConsumerStatefulWidget {
  final List<GuestSearchResponse> guests;
  final bool navigateToProfile;
  final String profilePath;
  final String initialSearchTerm; // Add this parameter
  final Function(String searchTerm, int iid)? onSearch; // Add search callback
  final int searchIid; // Add search type identifier
  
  const MemberNewSearchBottomSheet({
    super.key,
    required this.guests,
    this.navigateToProfile = false,
    this.profilePath = '/home/profile',
    this.initialSearchTerm = '', // Default empty string
    this.onSearch,
    required this.searchIid, // Make this required
  });

  @override
  ConsumerState<MemberNewSearchBottomSheet> createState() => _MembernewSearchBottomSheetState();
}

class _MembernewSearchBottomSheetState extends ConsumerState<MemberNewSearchBottomSheet> {
  late TextEditingController bottomSearchController;
  List<GuestSearchResponse> filteredGuests = [];
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    // Initialize with the passed search term
    bottomSearchController = TextEditingController(text: widget.initialSearchTerm);
    filteredGuests = widget.guests;
  }

  @override
  void dispose() {
    bottomSearchController.dispose();
    super.dispose();
  }

  void _performSearch() async {
    final searchTerm = bottomSearchController.text.trim();
    if (searchTerm.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least 3 characters to search'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (widget.onSearch != null) {
      setState(() {
        isSearching = true;
      });
      
      await widget.onSearch!(searchTerm, widget.searchIid);
      
      setState(() {
        isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.7,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.searchIid == 8002 
                ? "Search Member By Member ID" 
                : "Search Member By Name",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: bottomSearchController,
              decoration: InputDecoration(
                labelText: widget.searchIid == 8002 ? "Member ID" : "Member Name",
                border: const OutlineInputBorder(),
                suffixIcon: isSearching 
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _performSearch,
                    ),
              ),
              onFieldSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: filteredGuests.isEmpty
                ? const Center(
                    child: Text(
                      'No members found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredGuests.length,
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          final guest = filteredGuests[index];
                          ref.read(selectedGuestProvider.notifier).setSelectedGuest(
                                Guest(
                                  mid: guest.mid,
                                  memberName: guest.mName,
                                  country: "",
                                  lastVisitDate: guest.lvd.toString(),
                                  age: 0,
                                  gRating: guest.gRating,
                                  mGroup: guest.mGroup,
                                  gName: guest.gName,
                                  memImage2:guest.memImage2,
                                ),
                              );
                          if (widget.navigateToProfile) {
                            context.push(widget.profilePath);
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
                                base64Decode(filteredGuests[index].memImage2),
                              ),
                              radius: 24.0,
                            ),
                            title: Text(
                              filteredGuests[index].mid,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(filteredGuests[index].mName),
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