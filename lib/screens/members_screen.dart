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
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
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

class _MembersScreenState extends ConsumerState<MembersScreen> with ConnectivityMixin{
  String selectedDateOption = "1";
  String selectedBuyInOption = "1";
  bool _isLoading = false;
  List<GuestSearchResponse> guests = [];

  final TextEditingController _memberIdController = TextEditingController();
  //String _selectedPrefix = "BM"; // Default prefix
final FocusNode _memberIdFocusNode = FocusNode();
  // List of available prefixes
  //final List<String> _prefixes = ["BM", "BL", "BN"];
String _selectedPrefix = "";
List<String> _prefixes = [];

  List<Guest> originalMembers = [];
  List<Guest> inactiveMembers = [];
bool _isNumericOnlyLocation = false;

  // ── Profile access gating (mirrors MarketingDetailPage) ──
  bool? _memProfSH;
  String? _userMarketingCode;
  String? _userSalesCode;
  bool _accessStatus = false;

  @override
  void initState() {
    super.initState();
    _loadLocationPrefix();
    _loadAccessSettings();
  }

  Future<void> _loadAccessSettings() async {
    final memProfSH = await StorageUtil.getMemProfSH();
    final userMarketingCode = await StorageUtil.getMarketingCode();
    final userSalesCode = await StorageUtil.getSalesCode();
    final accessStatus = await StorageUtil.getAccessStatus();
    if (mounted) {
      setState(() {
        _memProfSH = memProfSH;
        _userMarketingCode = userMarketingCode;
        _userSalesCode = userSalesCode;
        _accessStatus = accessStatus;
      });
    }
  }

  // Sales code AD001 can view every member profile.
  // Otherwise, when memProfSH is null or true, every member is accessible.
  // When memProfSH is false, only members in the logged-in user's
  // marketing group can be opened.
  bool _hasPermissionToViewMember(String? mGroup) {
    // ReturnSatetus "True" from Iid 646 — access isn't limited to the user's
    // own marketing group, so nothing here should be denied.
    if (_accessStatus) {
      return true;
    }

    if (_userSalesCode == 'AD001') {
      return true;
    }

    // if (_memProfSH == null || _memProfSH == true) {
    //   return true;
    // }

    if (_userSalesCode != "AD001") {
      return _userMarketingCode != null &&
          (mGroup ?? '').isNotEmpty &&
          _userMarketingCode == mGroup;
    }

    return true;
  }

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 50,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Access Denied",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Got It",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
Future<void> _loadLocationPrefix() async {
  final location = await StorageUtil.getCurrentLocation();
  if (location != null) {
    final code = location.code.split('_').first; // "BELLAGIO"
    final isNumeric = ["BELLAGIO"].contains(code);
    setState(() {
      _prefixes = isNumeric ? [] : ["BM", "BL", "BN"]; // or load from API
      _selectedPrefix = isNumeric ? "" : "BM";
      _isNumericOnlyLocation = isNumeric;
    });
  }
}
  @override
  void dispose() {
    _memberIdController.dispose();
    _memberIdFocusNode.dispose(); // ✅ always dispose
    super.dispose();
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

  // Future<void> _openMemberSearchBottomSheet(int iid) async {
  //   GuestRepository guestRepository = GuestRepository(
  //     ApiService(const FlutterSecureStorage()),
  //   );

  //   String searchTerm = "";

  //   // Combine prefix with the typed number
  // String fullMemberId = isNumericOnly 
  //   ? _memberIdController.text 
  //   : "$_selectedPrefix ${_memberIdController.text}";
  //   searchTerm = fullMemberId;

  //   if (_memberIdController.text.isEmpty) return;

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
   
  //     guests = await guestRepository.searchGuest(iid, searchTerm);

  //     setState(() {
  //       _isLoading = false;
  //     });

  //     // showModalBottomSheet(
  //     //   context: context,
  //     //   isScrollControlled: true,
  //     //   shape: const RoundedRectangleBorder(
  //     //     borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //     //   ),
  //     //   builder: (BuildContext context) {
  //     //     return MemberSearchBottomSheet(
  //     //       guests: guests,
  //     //       navigateToProfile: true,
  //     //       profilePath: "/home/profile",
  //     //     );
  //     //   },
  //     // );
  //   } catch (e) {

  //   }
  // }
Future<void> _openMemberSearchBottomSheet(int iid) async {
  GuestRepository guestRepository = GuestRepository(
    ApiService(const FlutterSecureStorage()),
  );

  if (_memberIdController.text.isEmpty) return;

  // Bellagio = number only, Bally's = prefix + number
  String searchTerm = _isNumericOnlyLocation
      ? _memberIdController.text
      : "$_selectedPrefix ${_memberIdController.text}";

  setState(() {
    _isLoading = true;
  });

  try {
    guests = await guestRepository.searchGuest(iid, searchTerm);

    setState(() {
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
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
  // final FocusNode memberIdFocusNode = FocusNode();
  final bool showPrefix = _prefixes.isNotEmpty && 
      !(_prefixes.length == 1 && RegExp(r'^\d').hasMatch(_selectedPrefix == "" ? "0" : "0"));

  // Hide prefix for locations that use numeric-only IDs (like Bellagio)
  final bool isNumericOnly = _selectedPrefix.isEmpty || 
      ["BELLAGIO"].contains(_selectedPrefix);

  return Row(
    children: [
      if (!isNumericOnly)
        Container(
          height: 50,
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
                        fontSize: 20,
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
            ),
          ),
        ),
      Expanded(
        child: TextFormField(
           focusNode: _memberIdFocusNode,
          keyboardType: const TextInputType.numberWithOptions(),
          style: const TextStyle(fontSize: 22),
          autofocus: false,
          //focusNode: memberIdFocusNode,
          controller: _memberIdController,
          decoration: InputDecoration(
            labelText: "Member ID",
            labelStyle: const TextStyle(fontSize: 18, color: Colors.black),
            border: OutlineInputBorder(
              borderRadius: isNumericOnly
                  ? BorderRadius.circular(4)
                  : const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: -5.0,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                _memberIdFocusNode.unfocus();
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
                                    if (!_hasPermissionToViewMember(
                                        guest.mGroup)) {
                                      _showAccessDeniedDialog();
                                      return;
                                    }
                                    ref
                                        .read(selectedGuestProvider.notifier)
                                        .setSelectedGuest(
                                          Guest(
                                            mid: guest.mid,
                                            memberName: guest.mName,
                                            country: "",
                                            lastVisitDate: guest.lvd.toString(),
                                            age: 0,
                                            gRating: guest.gRating ?? "",
                                            mGroup: guest.mGroup,
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
