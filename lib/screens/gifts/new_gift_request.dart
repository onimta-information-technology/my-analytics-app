import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/member_search_provider.dart';
import 'package:ballys_reservation_app/providers/new_reservation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:ballys_reservation_app/components/bottom_sheets/member_search_by_mid_bottom_sheet.dart';

class NewGiftRequest extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;

  const NewGiftRequest({super.key, required this.giftsRepository});

  @override
  ConsumerState<NewGiftRequest> createState() => _NewGiftRequestState();
}

class _NewGiftRequestState extends ConsumerState<NewGiftRequest> {
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _openMemberSearchBottomSheet(int iid) async {
    GuestRepository guestRepository =
        GuestRepository(ApiService(const FlutterSecureStorage()));

    String searchTerm = "";

    if (iid == 8002) {
      searchTerm = _memberIdController.text;
    } else {
      searchTerm = _memberNameController.text;
    }

    if (searchTerm.length < 3) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<GuestSearchResponse> guests =
          await guestRepository.searchGuest(iid, searchTerm);

      setState(() {
        _isLoading = false;
      });

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext context) {
          return MemberSearchBottomSheet(
            guests: guests,
          );
        },
      );
    } catch (e) {
      print("Error searching guests: $e");
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

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final newReservation = ref.watch(memberSearchProvider);
    if (newReservation.mid != "" &&
        _memberIdController.text != newReservation.mid) {
      _memberIdController.text = newReservation.mid;
      _memberNameController.text = newReservation.memberName;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Special Gift Request'),
      ),
      body: PopScope(
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          ref.read(newReservationProvider.notifier).resetState();
          ref.read(memberSearchProvider.notifier).resetState();
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            keyboardType:
                                const TextInputType.numberWithOptions(),
                            autofocus: false,
                            controller: _memberIdController,
                            decoration: InputDecoration(
                              labelText: "Member ID",
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  _openMemberSearchBottomSheet(8002);
                                },
                              ),
                            ),
                            onChanged: (value) {
                              _memberNameController.text = '';
                              ref
                                  .read(memberSearchProvider.notifier)
                                  .resetState();
                            },
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        ElevatedButton.icon(
                          onPressed:
                              // newReservation.bmNumber == null
                              //     ? null
                              //     :
                              () {
                            context.push('/home/profile');
                          },
                          icon: const Icon(Icons.person),
                          label: const Text("Guest Details"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: false
                                ? Colors.grey.shade400
                                : const Color.fromARGB(255, 70, 70, 70),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      autofocus: false,
                      controller: _memberNameController,
                      decoration: InputDecoration(
                        labelText: "Member Name",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            FocusScope.of(context).requestFocus(FocusNode());
                            _openMemberSearchBottomSheet(8003);
                          },
                        ),
                      ),
                      onChanged: (value) {
                        _memberIdController.text = '';
                        ref.read(memberSearchProvider.notifier).resetState();
                      },
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Select Festival",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Christmas",
                          child: Text("Christmas"),
                        ),
                        DropdownMenuItem(
                          value: "Ramadan",
                          child: Text("Ramadan"),
                        ),
                        DropdownMenuItem(
                          value: "Aid",
                          child: Text("Aid"),
                        ),
                        DropdownMenuItem(
                          value: "Diwali",
                          child: Text("Diwali"),
                        ),
                        DropdownMenuItem(
                          value: "Easter",
                          child: Text("Easter"),
                        ),
                        DropdownMenuItem(
                          value: "Other",
                          child: Text("Other"),
                        ),
                      ],
                      onChanged: (value) {
                        // Handle change
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      decoration: InputDecoration(
                        alignLabelWithHint: true,
                        labelText: "Remarks",
                        hintText: "Enter additional details...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      onChanged: (value) {
                        print("Textarea content: $value");
                      },
                    ),
                    const SizedBox(height: 16.0),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.kSecondaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.done, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "Send Request",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
                          Constants.kSecondaryColor),
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
