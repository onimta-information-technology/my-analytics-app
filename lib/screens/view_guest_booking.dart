import 'package:ballys_reservation_app/components/guestDisplayCardById.dart';

import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/guest_booking_repository.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/Guest/guest_booking.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ViewGuestBooking extends ConsumerStatefulWidget {
  final GuestBookingRepository bookingRepository;
  final GuestBooking? booking;
  final bool isPending;

  const ViewGuestBooking({
    super.key,
    required this.bookingRepository,
    this.booking,
    this.isPending = false,
  });

  @override
  ConsumerState<ViewGuestBooking> createState() => _ViewGuestBookingState();
}

class _ViewGuestBookingState extends ConsumerState<ViewGuestBooking> {
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _pkgStartController = TextEditingController();
  final TextEditingController _pkgEndController = TextEditingController();
  final TextEditingController _insertDateController = TextEditingController();

  String? userName = "";
  bool _isLoading = false;
  bool _guestDataLoaded = false;
  bool _isGuestLoading = false;
  @override
  void initState() {
    super.initState();
    _loadUserCredentials();

    if (widget.booking != null) {
      final booking = widget.booking!;
      _memberIdController.text = booking.mid;
      _pkgStartController.text = _formatDate(booking.pkgStart);
      _pkgEndController.text = _formatDate(booking.pkgEnd);
      _insertDateController.text = _formatDateTime(booking.insertDate);
    }
  }

  Future<void> _loadGuestDataForView() async {
    if (_memberIdController.text.isEmpty || _guestDataLoaded) return;

    try {
      setState(() {
        _isGuestLoading = true;
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
                memberName: guestResponse.mName ?? "",
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

      // Mark guest data as loaded
      _guestDataLoaded = true;

      setState(() {
        _isGuestLoading = false;
      });
    } catch (e) {
      setState(() {
        _isGuestLoading = false;
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

  String _formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm a').format(date);
    } catch (_) {
      return dateString;
    }
  }

  TextStyle _inputTextStyle(FontSettings fontSettings) {
    return TextStyle(
      fontSize: fontSettings.fontSize,
      fontWeight: fontSettings.fontWeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/guest-bookings');
            }
          },
        ),
        title: Text(
          'Guest Booking Details',
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking ID Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Constants.kPrimaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.confirmation_number,
                              size: 30,
                              color: Constants.kPrimaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Booking ID',
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '#${widget.booking?.idNo ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize + 4,
                                  fontWeight: FontWeight.bold,
                                  color: Constants.kPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // const SizedBox(height: 24),
                  GuestDisplayCardById(
                    memberId: widget.booking?.mid ?? "",
                    showLastVisitDate: true,
                  ),

                  const SizedBox(height: 16.0),
                  // Member ID
                  // TextFormField(
                  //   controller: _memberIdController,
                  //   readOnly: true,
                  //   style: _inputTextStyle(fontSettings),
                  //   decoration: InputDecoration(
                  //     labelText: "Member ID",
                  //     labelStyle: TextStyle(
                  //       fontSize: fontSettings.fontSize,
                  //       fontWeight: fontSettings.fontWeight,
                  //     ),
                  //     prefixIcon: const Icon(Icons.person),
                  //     border: const OutlineInputBorder(),
                  //     contentPadding: const EdgeInsets.symmetric(
                  //       horizontal: 12.0,
                  //       vertical: 16.0,
                  //     ),
                  //   ),
                  // ),
                  Row(
                    children: [
                      // Member ID field
                      Expanded(
                        child: TextFormField(
                          keyboardType: const TextInputType.numberWithOptions(),
                          autofocus: false,
                          controller: _memberIdController,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Member ID",
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
                      const SizedBox(
                        width: 8,
                      ), // spacing between field and button
                      // Search Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () async {
                          try {
                            // Check if guest data is already loaded in the provider
                            final existingGuest = ref.read(
                              selectedGuestProvider,
                            );

                            // Only fetch if not already available
                            if (existingGuest == null ||
                                existingGuest.mid != _memberIdController.text) {
                              setState(() {
                                _isLoading = true;
                              });

                              await _loadGuestDataForView();

                              setState(() {
                                _isLoading = false;
                              });
                            }

                            // Navigate to profile
                            context.push('/home/profile');
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        },
                        child: const Icon(Icons.person_search, size: 25),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Package Start Date
                  TextFormField(
                    controller: _pkgStartController,
                    readOnly: true,
                    style: _inputTextStyle(fontSettings),
                    decoration: InputDecoration(
                      labelText: "Package Start Date",
                      labelStyle: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                      prefixIcon: const Icon(
                        Icons.calendar_today,
                        color: Colors.blue,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: -5.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Package End Date
                  TextFormField(
                    controller: _pkgEndController,
                    readOnly: true,
                    style: _inputTextStyle(fontSettings),
                    decoration: InputDecoration(
                      labelText: "Package End Date",
                      labelStyle: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                      prefixIcon: const Icon(Icons.event, color: Colors.red),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: -5.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Insert Date
                  TextFormField(
                    controller: _insertDateController,
                    readOnly: true,
                    style: _inputTextStyle(fontSettings),
                    decoration: InputDecoration(
                      labelText: "Created Date & Time",
                      labelStyle: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                      prefixIcon: const Icon(
                        Icons.access_time,
                        color: Colors.grey,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: -5.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Status Indicator
                  // Container(
                  //   padding: const EdgeInsets.all(16),
                  //   decoration: BoxDecoration(
                  //     color: widget.isPending
                  //         ? Colors.orange.withOpacity(0.1)
                  //         : Colors.green.withOpacity(0.1),
                  //     borderRadius: BorderRadius.circular(12),
                  //     border: Border.all(
                  //       color: widget.isPending ? Colors.orange : Colors.green,
                  //       width: 2,
                  //     ),
                  //   ),
                  // child: Row(
                  //   children: [
                  //     Icon(
                  //       widget.isPending ? Icons.pending : Icons.check_circle,
                  //       color: widget.isPending ? Colors.orange : Colors.green,
                  //       size: 30,
                  //     ),
                  //     const SizedBox(width: 12),
                  //     Text(
                  //       'Status: ${widget.isPending ? 'Pending' : 'Accepted'}',
                  //       style: TextStyle(
                  //         fontSize: fontSettings.fontSize + 2,
                  //         fontWeight: FontWeight.bold,
                  //         color: widget.isPending ? Colors.orange : Colors.green,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  // ),

                  // const SizedBox(height: 24),

                  // Action Buttons (only show if pending)
                  if (widget.isPending) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (widget.booking == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Booking not found"),
                                  ),
                                );
                                return;
                              }

                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Accept Booking'),
                                  content: const Text(
                                    'Are you sure you want to accept this booking?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        dialogContext,
                                      ).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed != true) return;

                              setState(() {
                                _isLoading = true;
                              });

                              try {
                                // final success = await ref
                                //     .read(guestBookingProvider.notifier)
                                //     .acceptBooking(
                                //       idNo: widget.booking!.idNo,
                                //       userName: userName ?? "",
                                //     );

                                // if (success) {
                                //   if (!mounted) return;
                                //   ScaffoldMessenger.of(context).showSnackBar(
                                //     const SnackBar(
                                //       content: Text("Booking Accepted Successfully"),
                                //       backgroundColor: Colors.green,
                                //     ),
                                //   );
                                //   Navigator.of(context).pop(true);
                                // } else {
                                //   if (!mounted) return;
                                //   ScaffoldMessenger.of(context).showSnackBar(
                                //     const SnackBar(
                                //       content: Text("Failed to accept booking"),
                                //       backgroundColor: Colors.red,
                                //     ),
                                //   );
                                // }
                              } catch (e) {
                                if (!mounted) return;
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
                            label: const Text(
                              "ACCEPT",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        //const SizedBox(width: 16),
                        // Expanded(
                        //   child: ElevatedButton.icon(
                        //     onPressed: () async {
                        //       if (widget.booking == null) {
                        //         ScaffoldMessenger.of(context).showSnackBar(
                        //           const SnackBar(
                        //             content: Text("Booking not found"),
                        //           ),
                        //         );
                        //         return;
                        //       }

                        //       final confirmed = await showDialog<bool>(
                        //         context: context,
                        //         builder: (dialogContext) => AlertDialog(
                        //           title: const Text('Reject Booking'),
                        //           content: const Text(
                        //             'Are you sure you want to reject this booking?',
                        //           ),
                        //           actions: [
                        //             TextButton(
                        //               onPressed: () => Navigator.of(dialogContext).pop(false),
                        //               child: const Text('Cancel'),
                        //             ),
                        //             ElevatedButton(
                        //               onPressed: () => Navigator.of(dialogContext).pop(true),
                        //               style: ElevatedButton.styleFrom(
                        //                 backgroundColor: Colors.red,
                        //                 foregroundColor: Colors.white,
                        //               ),
                        //               child: const Text('Reject'),
                        //             ),
                        //           ],
                        //         ),
                        //       );

                        //       if (confirmed != true) return;

                        //       setState(() {
                        //         _isLoading = true;
                        //       });

                        //       try {
                        //         final success = await ref
                        //             .read(guestBookingProvider.notifier)
                        //             .rejectBooking(
                        //               idNo: widget.booking!.idNo,
                        //               userName: userName ?? "",
                        //             );

                        //         if (success) {
                        //           if (!mounted) return;
                        //           ScaffoldMessenger.of(context).showSnackBar(
                        //             const SnackBar(
                        //               content: Text("Booking Rejected Successfully"),
                        //               backgroundColor: Colors.orange,
                        //             ),
                        //           );
                        //           Navigator.of(context).pop(true);
                        //         } else {
                        //           if (!mounted) return;
                        //           ScaffoldMessenger.of(context).showSnackBar(
                        //             const SnackBar(
                        //               content: Text("Failed to reject booking"),
                        //               backgroundColor: Colors.red,
                        //             ),
                        //           );
                        //         }
                        //       } catch (e) {
                        //         if (!mounted) return;
                        //         ScaffoldMessenger.of(context).showSnackBar(
                        //           SnackBar(content: Text("Error: $e")),
                        //         );
                        //       } finally {
                        //         setState(() {
                        //           _isLoading = false;
                        //         });
                        //       }
                        //     },
                        //     icon: const Icon(Icons.close),
                        //     label: const Text("REJECT"),
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: Colors.red,
                        //       foregroundColor: Colors.white,
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(12),
                        //       ),
                        //       padding: const EdgeInsets.symmetric(vertical: 16),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: const Color.fromARGB(135, 117, 115, 115),
                child: const Center(
                  child: CircularProgressIndicator(
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
    );
  }
}
