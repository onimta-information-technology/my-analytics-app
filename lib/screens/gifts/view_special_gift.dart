import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/member_search_provider.dart';
import 'package:ballys_reservation_app/providers/new_reservation_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/special_gift_provider.dart';
import 'package:ballys_reservation_app/utils/formatter.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ViewSpecificGiftRequest extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;
  final SpecialGiftRequest? gift;
  final bool isPending;
  final bool isApproved;
  const ViewSpecificGiftRequest({
    super.key,
    required this.giftsRepository,
    this.gift,
    this.isPending = false,
    this.isApproved = false,
  });

  @override
  ConsumerState<ViewSpecificGiftRequest> createState() =>
      _NewGiftRequestState();
}

class _NewGiftRequestState extends ConsumerState<ViewSpecificGiftRequest> {
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _arrivalDateController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _chipController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  //final TextEditingController _giftForController = TextEditingController();
  String? _selectedGift;
  String? _chipType;
  String _remarks = "";
  String? userName = "";
  double drop = 0.0;
  double cashout = 0.0;
  double res = 0.0;
  double actdrop = 0.0;
  double mcoupen = 0.0;
  double paidcom = 0.0;
  double gpoints = 0.0;
  double gflushcoupen = 0.0;
  double tcoupon = 0.0;
  double flushactdrop = 0.0;
  double avgbet = 0.0;
int? _selectedValidDays;

  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final bool _showGuestData = false;
  bool _isEditable = false;

  @override
  @override
  void initState() {
    super.initState();
    _loadUserCredentials();

    if (widget.gift != null) {
      final g = widget.gift!;
      _memberIdController.text = g.mid ?? "";
      _memberNameController.text = g.mname ?? "";
      _fromDateController.text = _formatDateandTime(g.dateFrom) ?? "";
      _toDateController.text = _formatDateandTime(g.dateTo);
      _arrivalDateController.text = _formatDate(g.arrDate);
      _departureDateController.text = _formatDate(g.dptDate);
      _selectedGift = g.cashierPayType ?? "";
      _chipController.text = g.chipType.replaceAll("_", " ");
      _amountController.text = formatNumber(g.giftDesc.toString()) ?? "";
      _remarksController.text = g.giftCategory ?? "";
      drop = g.mdrop;
      cashout = g.cashout;
      res = g.res;
      actdrop = g.actDrop;
      mcoupen = g.mCoupon;
      paidcom = g.paidComm;
      gpoints = g.gPoints;
      gflushcoupen = g.flushCoupon;
      tcoupon = g.mCoupon + g.flushCoupon;
      flushactdrop = g.flushActDrop;
      avgbet = g.avebet;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadGuestDataForCard();
      });
    }
    // } else {}
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //       _loadGuestDataForCard();
    //     });
    //   }
    Future.microtask(() {
      ref.read(giftProvider.notifier).getGiftForList();
    });
  }

  Future<void> _loadGuestDataForCard() async {
    if (_memberIdController.text.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
      });

      GuestRepository guestRepository = GuestRepository(
        ApiService(const FlutterSecureStorage()),
      );

      List<GuestSearchResponse> guests = await guestRepository.searchGuest(
        9021, // Using 9021 as the search type for MID lookup
        _memberIdController.text,
      );

      if (guests.isNotEmpty) {
        final guestResponse = guests.first;
        ref
            .read(selectedGuestProvider.notifier)
            .setSelectedGuest(
              Guest(
                mid: guestResponse.mid ?? _memberIdController.text,
                memberName: guestResponse.mName ?? _memberNameController.text,
                country: "",
                lastVisitDate: guestResponse.lvd?.toString() ?? "",

                age: 0,
                gRating: guestResponse.gRating ?? "",
                mGroup: guestResponse.mGroup,
                gName: guestResponse.gName ?? "",
                memImage2: guestResponse.memImage2,
              ),
            );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading guest data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserCredentials() async {
    final name = await StorageUtil.getUserName();

    setState(() {
      userName = name;
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return dateString;
    }
  }

  String _formatDateandTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm a').format(date);
    } catch (_) {
      return dateString;
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
  String formatNumber(dynamic value) {
    if (value == null) return "";
    final num? number = num.tryParse(value.toString());
    if (number == null) return value.toString(); // return as-is if not numeric
    return NumberFormat.decimalPattern().format(number);
  }

  Future<void> _pickDateTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    final DateTime dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    controller.text =
        "${dateTime.day}/${dateTime.month}/${dateTime.year} ${time.format(context)}";
  }

  TextStyle _inputTextStyle(FontSettings fontSettings) {
    return TextStyle(
      fontSize: fontSettings.fontSize,
      fontWeight: fontSettings.fontWeight,
    );
  }

  TextStyle _inputTextStylefroammount(FontSettings fontSettings) {
    return TextStyle(
      fontSize: fontSettings.fontSize + 5,
      fontWeight: FontWeight.bold,
    );
  }

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        // title: Text(
        //   'Special Gift Request',
        //   style: TextStyle(
        //     fontSize: fontSettings.fontSize,
        //     fontWeight: fontSettings.fontWeight,
        //   ),
        // ),
        title: Text(
          'Special Gift Request',
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
          ),
        ),

        // /// 🔁 Right-side title (Approve + Reject only)
        // actions: [
        //   if (!widget.isPending)
        //     Padding(
        //       padding: const EdgeInsets.only(right: 12),
        //       child: Center(
        //         child: Container(
        //           padding: const EdgeInsets.symmetric(
        //             horizontal: 6,
        //             vertical: 6,
        //           ),
        //           decoration: BoxDecoration(
        //             color: Colors.orange,
        //             borderRadius: BorderRadius.circular(20),
        //           ),
        //           child: const Text(
        //             'Reverse Gift',
        //             style: TextStyle(
        //               color: Colors.white,
        //               fontWeight: FontWeight.w600,
        //             ),
        //           ),
        //         ),
        //       ), 
        //     ),
        // ],
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                       if (!widget.isPending)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Show confirmation dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Reverse Gift'),
                            content: const Text(
                              'Are you sure you want to reverse this gift?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  // Add your reverse gift API call here
                                  Navigator.pop(context);
                                  
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  
                                  try {
                                    // Example: Call your reverse gift method
                                    // final success = await ref
                                    //     .read(giftProvider.notifier)
                                    //     .reverseGift(
                                    //       reqid: widget.gift!.idNo,
                                    //       userName: userName ?? "",
                                    //     );
                                    
                                    // if (success) {
                                    //   ScaffoldMessenger.of(context).showSnackBar(
                                    //     const SnackBar(
                                    //       content: Text('Gift reversed successfully'),
                                    //     ),
                                    //   );
                                    //   Navigator.of(context).pop(true);
                                    // }
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Gift reversal in progress...'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  } finally {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Reverse'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.undo, size: 20),
                      label: Text(
                        'Reverse Gift',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
          
                      const SizedBox(height: 5.0),
                      TextFormField(
                        controller: (_fromDateController),
                        readOnly: true,

                        style: _inputTextStyle(fontSettings),
                        decoration: InputDecoration(
                          labelText: "From Date & Time",
                          labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: -5.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _toDateController,
                        readOnly: true,
                        style: _inputTextStyle(fontSettings),
                        decoration: InputDecoration(
                          labelText: "To Date & Time",
                          labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: -5.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5.0),
                      // Row(
                      //   children: [
                          // Expanded(
                          //   child: TextFormField(
                          //     keyboardType:
                          //         const TextInputType.numberWithOptions(),
                          //     autofocus: false,
                          //     readOnly: true,
                          //     controller: _memberIdController,
                          //     style: _inputTextStyle(fontSettings),
                          //     decoration: InputDecoration(
                          //       labelText: "Member ID",
                          //       labelStyle: TextStyle(
                          //         fontSize: fontSettings.fontSize,
                          //         fontWeight: fontSettings.fontWeight,
                          //       ),
                          //       border: const OutlineInputBorder(),
                          //       contentPadding: const EdgeInsets.symmetric(
                          //         horizontal: 12.0,
                          //         vertical: -5.0,
                          //       ),
                          //     ),
                          //     onChanged: (value) {
                          //       _memberNameController.text = '';
                          //       ref
                          //           .read(memberSearchProvider.notifier)
                          //           .resetState();
                          //     },
                          //   ),
                          // ),
                          //const SizedBox(width: 16.0),

                          // ElevatedButton(
                          //   style: ElevatedButton.styleFrom(
                          //     backgroundColor: Colors.black,
                          //     foregroundColor: Colors.white,
                          //     padding: const EdgeInsets.symmetric(
                          //       horizontal: 16,
                          //       vertical: 14,
                          //     ),
                          //   ),
                          //   onPressed: _isLoading
                          //       ? null
                          //       : () async {
                          //           // Check if guest data is already loaded
                          //           final selectedGuest = ref.read(
                          //             selectedGuestProvider,
                          //           );

                          //           if (selectedGuest != null &&
                          //               selectedGuest.mid ==
                          //                   _memberIdController.text) {
                          //             // Guest data already loaded, just navigate
                          //             context.push('/home/profile');
                          //             return;
                          //           }

                          //           // Guest data not loaded, fetch it
                          //           try {
                          //             setState(() {
                          //               _isLoading = true;
                          //             });

                          //             GuestRepository guestRepository =
                          //                 GuestRepository(
                          //                   ApiService(
                          //                     const FlutterSecureStorage(),
                          //                   ),
                          //                 );

                          //             // Search for guest by MID
                          //             List<GuestSearchResponse> guests =
                          //                 await guestRepository.searchGuest(
                          //                   9021,
                          //                   _memberIdController.text,
                          //                 );

                          //             setState(() {
                          //               _isLoading = false;
                          //             });

                          //             if (guests.isNotEmpty) {
                          //               final guestResponse = guests.first;
                          //               ref
                          //                   .read(
                          //                     selectedGuestProvider.notifier,
                          //                   )
                          //                   .setSelectedGuest(
                          //                     Guest(
                          //                       mid:
                          //                           guestResponse.mid ??
                          //                           _memberIdController.text,
                          //                       memberName:
                          //                           guestResponse.mName ??
                          //                           _memberNameController.text,
                          //                       country: "",
                          //                       lastVisitDate:
                          //                           guestResponse.lvd
                          //                               ?.toString() ??
                          //                           "",

                          //                       age: 0,
                          //                       gRating:
                          //                           guestResponse.gRating ?? "",
                          //                       mGroup: guestResponse.mGroup,
                          //                       gName:
                          //                           guestResponse.gName ?? "",
                          //                       memImage2:
                          //                           guestResponse.memImage2,
                          //                     ),
                          //                   );
                          //               context.push('/home/profile');
                          //             } else {
                          //               // fallback guest
                          //               ref
                          //                   .read(
                          //                     selectedGuestProvider.notifier,
                          //                   )
                          //                   .setSelectedGuest(
                          //                     Guest(
                          //                       mid: _memberIdController.text,
                          //                       memberName:
                          //                           _memberNameController.text,
                          //                       country: "",
                          //                       lastVisitDate: "1990-01-01",

                          //                       age: 0,
                          //                       gRating: "",
                          //                       mGroup: "",
                          //                       gName: "",
                          //                     ),
                          //                   );
                          //               context.push('/home/profile');
                          //             }
                          //           } catch (e) {
                          //             setState(() {
                          //               _isLoading = false;
                          //             });
                          //           }
                          //         },
                          //   child: _isLoading
                          //       ? const SizedBox(
                          //           width: 20,
                          //           height: 20,
                          //           child: CircularProgressIndicator(
                          //             strokeWidth: 2,
                          //             color: Colors.white,
                          //           ),
                          //         )
                          //       : const Icon(Icons.person_search, size: 25),
                          // ),
                      //   ],
                      // ),

                      // const SizedBox(height: 16.0),
                      // TextFormField(
                      //   autofocus: false,
                      //   readOnly: true,
                      //   controller: _memberNameController,
                      //   style: _inputTextStyle(fontSettings),
                      //   decoration: InputDecoration(
                      //     labelText: "Member Name",
                      //     labelStyle: TextStyle(
                      //       fontSize: fontSettings.fontSize,
                      //       fontWeight: fontSettings.fontWeight,
                      //     ),
                      //     border: const OutlineInputBorder(),
                      //     contentPadding: const EdgeInsets.symmetric(
                      //       horizontal: 12.0,
                      //       vertical: -5.0,
                      //     ),
                      //   ),
                      //   onChanged: (value) {
                      //     _memberIdController.text = '';
                      //     ref.read(memberSearchProvider.notifier).resetState();
                      //   },
                      // ),
                      // // const SizedBox(height: 16.0),
                      // const SizedBox(height: 10.0),
                      GuestDisplayCardSpecialGiftview(
                        memberIdText: _memberIdController.text,
                        memberNameText: _memberNameController.text,
                        showCard:
                            _memberIdController.text.isNotEmpty &&
                            _memberNameController.text.isNotEmpty,
                        isLoading: _isLoading,
                        showLastVisitDate:
                            true, // Enable last visit date display
                      ),
                      const SizedBox(height: 16.0),
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      //   children: [
                      //     const SizedBox(width: 12),
                      //     Expanded(
                      //       child: ElevatedButton.icon(
                      //         onPressed: () {
                      //           final memberId = _memberIdController.text
                      //               .trim();

                      //           if (memberId.isEmpty) {
                      //             ScaffoldMessenger.of(context).showSnackBar(
                      //               const SnackBar(
                      //                 content: Text("Please enter a Member ID"),
                      //               ),
                      //             );
                      //             return;
                      //           }

                      //           // Navigate to PrvGift page with MID as parameter
                      //           context.push(
                      //             '/gifts/special-gift-requests/prv-gifts/$memberId',
                      //           );
                      //         },
                      //         icon: const Icon(Icons.card_giftcard),
                      //         label: Text(
                      //           "Previous Gift",
                      //           style: TextStyle(
                      //             fontSize: fontSettings.fontSize + 2,
                      //             fontWeight: fontSettings.fontWeight,
                      //           ),
                      //         ),
                      //         style: ElevatedButton.styleFrom(
                      //           backgroundColor: Colors.blue,
                      //           foregroundColor: Colors.white,
                      //           shape: RoundedRectangleBorder(
                      //             borderRadius: BorderRadius.circular(12),
                      //           ),
                      //           padding: const EdgeInsets.symmetric(
                      //             vertical: 12,
                      //           ),
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      // ),
Row(
  children: [
    ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onPressed: _isLoading
          ? null
          : () async {
              final selectedGuest = ref.read(selectedGuestProvider);

              if (selectedGuest != null &&
                  selectedGuest.mid == _memberIdController.text) {
                context.push('/home/profile');
                return;
              }

              try {
                setState(() {
                  _isLoading = true;
                });

                GuestRepository guestRepository = GuestRepository(
                  ApiService(const FlutterSecureStorage()),
                );

                List<GuestSearchResponse> guests =
                    await guestRepository.searchGuest(
                      9021,
                      _memberIdController.text,
                    );

                setState(() {
                  _isLoading = false;
                });

                if (guests.isNotEmpty) {
                  final guestResponse = guests.first;
                  ref.read(selectedGuestProvider.notifier).setSelectedGuest(
                    Guest(
                      mid: guestResponse.mid ?? _memberIdController.text,
                      memberName: guestResponse.mName ?? _memberNameController.text,
                      country: "",
                      lastVisitDate: guestResponse.lvd?.toString() ?? "",
                      age: 0,
                      gRating: guestResponse.gRating ?? "",
                      mGroup: guestResponse.mGroup,
                      gName: guestResponse.gName ?? "",
                      memImage2: guestResponse.memImage2,
                    ),
                  );
                  context.push('/home/profile');
                } else {
                  ref.read(selectedGuestProvider.notifier).setSelectedGuest(
                    Guest(
                      mid: _memberIdController.text,
                      memberName: _memberNameController.text,
                      country: "",
                      lastVisitDate: "1990-01-01",
                      age: 0,
                      gRating: "",
                      mGroup: "",
                      gName: "",
                    ),
                  );
                  context.push('/home/profile');
                }
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.person_search, size: 25),
    ),
    const SizedBox(width: 16),
    Expanded(
      child: ElevatedButton.icon(
        onPressed: () {
          final memberId = _memberIdController.text.trim();

          if (memberId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Please enter a Member ID"),
              ),
            );
            return;
          }

          context.push(
            '/gifts/special-gift-requests/prv-gifts/$memberId',
          );
        },
        icon: const Icon(Icons.card_giftcard),
        label: Text(
          "Previous Gift",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    ),
  ],
),

                      // const SizedBox(height: 16.0),

                      // Replace the _showGuestData block with this:
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          "Guest Gift Data",
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final giftState = ref.watch(giftProvider);

                          final rows = [
                            {"Field": "Drop (Est)", "Value": drop},
                            {"Field": "Cash Out (Est)", "Value": cashout},
                            {"Field": "Result (Est)", "Value": res},
                            {"Field": "Actual Drop (Est)", "Value": actdrop},
                            {"Field": "Coupons (Est)", "Value": mcoupen},
                            {
                              "Field": "Commission Paid (Est)",
                              "Value": paidcom,
                            },
                            {"Field": "Points (Est)", "Value": gpoints},
                            {
                              "Field": "Flush Coupon (Est)",
                              "Value": gflushcoupen,
                            },
                            {"Field": "Total Coupon (Est)", "Value": tcoupon},
                            {
                              "Field": "Flush Actual Drop (Est)",
                              "Value": flushactdrop,
                            },
                            {"Field": "Avg Bet (Est)", "Value": avgbet},
                          ];

                          return Container(
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DataTable(
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              headingRowColor: WidgetStateProperty.all(
                                Colors.amber.shade100,
                              ),
                              border: TableBorder.all(
                                color: Colors.grey.shade300,
                              ),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    "Field",
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                //   numeric: true,
                                  label: Text(
                                    "Value",
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize,
                                      fontWeight: fontSettings.fontWeight,
                                    ),
                                  ),
                                ),
                              ],
                              rows: rows.map((row) {
                                final shouldHighlight = [
                                  "Actual Drop (Est)",
                                  "Result (Est)",
                                  "Coupons (Est)",
                                  "Points (Est)",
                                  "Avg Bet (Est)",
                                ].contains(row["Field"]);
                                return DataRow(
                                  color: shouldHighlight
                                      ? WidgetStateProperty.all(
                                          Color(0xFFCCFFCC),
                                        )
                                      : null,
                                  cells: [
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          row["Field"].toString(),

                                          style: TextStyle(
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: shouldHighlight
                                                ? FontWeight.bold
                                                : fontSettings.fontWeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          formatNumber(row["Value"]),
                                          style: TextStyle(
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: shouldHighlight
                                                ? FontWeight.bold
                                                : fontSettings.fontWeight,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16.0),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _arrivalDateController,
                              readOnly: true,
                              style: _inputTextStyle(fontSettings),
                              decoration: InputDecoration(
                                labelText: "Arrival Date",
                                labelStyle: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: -5.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _departureDateController,
                              readOnly: true,
                              style: _inputTextStyle(fontSettings),
                              decoration: InputDecoration(
                                labelText: "Departure Date",
                                labelStyle: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: -5.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),

                          TextFormField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: _selectedGift?.replaceAll("_", ""),
                            ),
                            decoration: InputDecoration(
                              labelText: "Gift For",
                              labelStyle: TextStyle(
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: -5.0,
                              ),
                            ),
                            style: _inputTextStyle(fontSettings),
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _chipController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: "Chip Type ",
                              labelStyle: TextStyle(
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                              ),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: -5.0,
                              ),
                            ),

                            inputFormatters: <TextInputFormatter>[],
                            style: _inputTextStyle(fontSettings),
                          ),
                          if (widget.isPending)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Amount & Remarks",
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize + 2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    setState(() {
                                      _isEditable =
                                          !_isEditable; // toggle edit mode
                                    });
                                  },
                                ),
                              ],
                            ),
                          const SizedBox(height: 16.0),

                          TextFormField(
                            controller: _amountController,
                            readOnly: !_isEditable,
                            style: _inputTextStylefroammount(fontSettings),
                            decoration: InputDecoration(
                              labelText: "Amount",
                              labelStyle: TextStyle(
                                fontSize: fontSettings.fontSize + 2,
                                fontWeight: fontSettings.fontWeight,
                              ),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: -5.0,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              ThousandsSeparatorInputFormatter(),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter amount";
                              }
                              return null;
                            },
                          ),

                        
                        ],
                      ),
if (widget.isPending) ...[
  const SizedBox(height: 16),

  DropdownButtonFormField<int>(
    value: _selectedValidDays,
    style: TextStyle(
      fontSize: fontSettings.fontSize + 2,
      fontWeight: FontWeight.bold, // ✅ Selected value bold
      color: Colors.black,
    ),
    decoration: InputDecoration(
      labelText: "Valid Days",
      labelStyle: TextStyle(
        fontSize: fontSettings.fontSize,
        fontWeight: fontSettings.fontWeight,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
    ),
    items: const [
      DropdownMenuItem(
        value: 30,
        child: Text(
          "30 Days",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      DropdownMenuItem(
        value: 60,
        child: Text(
          "60 Days",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      DropdownMenuItem(
        value: 90,
        child: Text(
          "90 Days",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ],
    onChanged: (value) {
      setState(() {
        _selectedValidDays = value;
      });
    },
    validator: (value) {
      if (value == null) {
        return "Please select valid days";
      }
      return null;
    },
  ),
],
 const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarksController,
                        readOnly: !_isEditable,
                        style: _inputTextStyle(fontSettings),
                        decoration: InputDecoration(
                          alignLabelWithHint: true,
                          labelText: "Remarks",
                          labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          hintText: "Enter additional details...",
                          hintStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        onChanged: (value) => _remarks = value,
                      ),
                      const SizedBox(height: 16.0),
                      if (widget.isPending)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (widget.gift == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Gift request not found"),
                                      ),
                                    );
                                    return;
                                  }

                                  final reqid = widget.gift!.idNo;
                                  final remarks = _remarksController.text;
                                  final amount = _amountController.text;
                                  final uname = userName ?? "";

                                  setState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    final success = await ref
                                        .read(giftProvider.notifier)
                                        .sendApprovedSpecialGiftFromUI(
                                          reqid: reqid,
                                          remarks: remarks,
                                          amount: amount,
                                          userName: uname,
                                        );

                                    if (success) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Request Approved Successfully ",
                                          ),
                                        ),
                                      );

                                      Navigator.of(context).pop(true);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Approval Failed "),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: $e")),
                                    );
                                  } finally {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.check),
                                label: const Text("APPROVE"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (widget.gift == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Gift request not found"),
                                      ),
                                    );
                                    return;
                                  }

                                  final reqid = widget.gift!.idNo;

                                  final uname = userName ?? "";

                                  setState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    final success = await ref
                                        .read(giftProvider.notifier)
                                        .rejectSpecialGiftFromUI(
                                          reqid: reqid,
                                          userName: uname,
                                        );

                                    if (success) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Request Reject Successfully ",
                                          ),
                                        ),
                                      );
                                      await ref
                                          .read(giftProvider.notifier)
                                          .getGiftForList();
                                      Navigator.of(context).pop(true);
                                      // go back after approval
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Reject Failed "),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: $e")),
                                    );
                                  } finally {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.close),
                                label: const Text("REJECT"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      if (widget.isApproved)
                        Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.send),
                              label: Text(
                                "Send Gift Details via WhatsApp",
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF25D366,
                                ), // WhatsApp green color
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
