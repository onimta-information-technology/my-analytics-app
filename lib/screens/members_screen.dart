import 'dart:convert';

import 'package:ballys_reservation_app/components/bottom_sheets/member_search_by_mid_bottom_sheet.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

class MembersScreen extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;

  const MembersScreen({super.key, required this.giftsRepository});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  String selectedDateOption = "1";
  String selectedBuyInOption = "1";
  bool _isLoading = false;
  List<GuestSearchResponse> guests = [];

  final TextEditingController _memberIdController = TextEditingController();
  String _selectedPrefix = "BM"; // Default prefix

  // List of available prefixes
  final List<String> _prefixes = ["BM", "BL", "BN"];

  List<Guest> originalMembers = [];
  List<Guest> inactiveMembers = [];

  @override
  void initState() {
    super.initState();
  }

  void _applyFilter() async {
    setState(() {
      _isLoading = true;
    });
    final giftMembers_ = await widget.giftsRepository.getGiftMembers();

    setState(() {
      originalMembers = giftMembers_;
      inactiveMembers = List<Guest>.from(originalMembers);
      _isLoading = false;
    });
  }

  void _showSearchBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  if (value.isEmpty) {
                    inactiveMembers = List<Guest>.from(originalMembers);
                  } else {
                    inactiveMembers = originalMembers.where((guest) {
                      return guest.memberName.toLowerCase().contains(
                            value.toLowerCase(),
                          ) ||
                          guest.mid.toLowerCase().contains(value.toLowerCase());
                    }).toList();
                  }
                });
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
        );
      },
    );
  }

  Future<void> _openMemberSearchBottomSheet(int iid) async {
    GuestRepository guestRepository = GuestRepository(
      ApiService(const FlutterSecureStorage()),
    );

    String searchTerm = "";

    // Combine prefix with the typed number
    String fullMemberId = "$_selectedPrefix ${_memberIdController.text}";
    searchTerm = fullMemberId;

    if (_memberIdController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      guests = await guestRepository.searchGuest(iid, searchTerm);

      setState(() {
        _isLoading = false;
      });

      // showModalBottomSheet(
      //   context: context,
      //   isScrollControlled: true,
      //   shape: const RoundedRectangleBorder(
      //     borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      //   ),
      //   builder: (BuildContext context) {
      //     return MemberSearchBottomSheet(
      //       guests: guests,
      //       navigateToProfile: true,
      //       profilePath: "/home/profile",
      //     );
      //   },
      // );
    } catch (e) {

    }
  }

  final Map<String, String> ratingImageMap = {
    "CLASSIC": "assets/images/ratings/CLASSIC.png",
    "DIAMOND": "assets/images/ratings/DIAMOND.png",
    "GOLD": "assets/images/ratings/GOLD.png",
    "INFINITY": "assets/images/ratings/INFINITY.png",
    "PLATINUM": "assets/images/ratings/PLATINUM.png",
    "SILVER": "assets/images/ratings/SILVER.png",
  };

  Widget _buildMemberIdInput() {
    final FocusNode memberIdFocusNode = FocusNode();

    return Row(
      children: [
        // Prefix Dropdown
        Container(
          height: 56, // Match TextFormField height
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPrefix,
              items: _prefixes.map((String prefix) {
                return DropdownMenuItem<String>(
                  value: prefix,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      prefix,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedPrefix = newValue;
                  });
                }
              },
              icon: const Icon(Icons.arrow_drop_down),
              iconSize: 24,
              elevation: 8,
              style: const TextStyle(color: Colors.black),
              dropdownColor: Colors.white,
            ),
          ),
        ),
        // Member ID Input Field
        Expanded(
          child: TextFormField(
            keyboardType: const TextInputType.numberWithOptions(),
            autofocus: false,
            focusNode: memberIdFocusNode,
            controller: _memberIdController,
            decoration: InputDecoration(
              labelText: "Member ID",
              //hintText: "001, 003, 0002...",
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  FocusScope.of(context).requestFocus(FocusNode());
                  _openMemberSearchBottomSheet(8002);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Members'),leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/menu');
      }
    },
  ),),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          _buildMemberIdInput(),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: MediaQuery.of(context).size.height - 220,
                            child: ListView.builder(
                              itemCount: guests.length,
                              itemBuilder: (context, index) {
                                return InkWell(
                                  onTap: () {
                                    final guest = guests[index];
                                    ref
                                        .read(selectedGuestProvider.notifier)
                                        .setSelectedGuest(
                                          Guest(
                                            mid: guest.mid,
                                            memberName: guest.mName,
                                            country: "",
                                            lastVisitDate: guest.lvd.toString(),
                                            age: 0,
                                            gRating: "",
                                            mGroup: "",
                                            gName: guest.gName ?? "",
                                          ),
                                        );
                                
                                    context.push("/home/profile");
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 2.0,
                                      horizontal: 2.0,
                                    ),
                                    elevation: 4.0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 5.0,
                                            horizontal: 8.0,
                                          ),
                                      leading: CircleAvatar(
                                        backgroundImage: MemoryImage(
                                          base64Decode(guests[index].memImage2),
                                        ),
                                        radius: 24.0,
                                      ),
                                      title: Text(
                                        guests[index].mid,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
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
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(135, 117, 115, 115),
                  ),
                  child: const Center(
                    child: RefreshProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Constants.kSecondaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            const Watermark(),
          ],
        ),
      ),
    );
  }
}
