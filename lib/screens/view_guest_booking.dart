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
import 'package:ballys_reservation_app/providers/guest_booking_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';

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
  final TextEditingController _memberNameController = TextEditingController();
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
      _memberNameController.text = booking.mname;
      _pkgStartController.text = _formatDate(booking.pkgStart);
      _pkgEndController.text = _formatDate(booking.pkgEnd);
      _insertDateController.text = _formatDateTime(booking.insertDate);
    }
  }

  @override
  void dispose() {
    _memberIdController.dispose();
    _memberNameController.dispose();
    _pkgStartController.dispose();
    _pkgEndController.dispose();
    _insertDateController.dispose();
    super.dispose();
  }

  // ── Credential loader ──────────────────────────────────────────────────
  Future<void> _loadUserCredentials() async {
    final name = await StorageUtil.getUserName();
    if (mounted) {
      setState(() => userName = name);
    }
  }

  // ── Date formatters ────────────────────────────────────────────────────
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

  // ── Guest data loader ──────────────────────────────────────────────────
  Future<void> _loadGuestDataForView() async {
    if (_memberIdController.text.isEmpty || _guestDataLoaded) return;

    try {
      setState(() => _isGuestLoading = true);

      final GuestRepository guestRepository = GuestRepository(
        ApiService(SecureStorage.instance),
      );

      final List<GuestSearchResponse> guests =
          await guestRepository.searchGuest(
        9021,
        _memberIdController.text,
      );

      if (guests.isNotEmpty) {
        final guestResponse = guests.first;
        ref.read(selectedGuestProvider.notifier).setSelectedGuest(
              Guest(
                mid: guestResponse.mid ?? _memberIdController.text,
                memberName: _memberNameController.text,
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

      _guestDataLoaded = true;
      if (mounted) setState(() => _isGuestLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isGuestLoading = false);
    }
  }

  // ── Remarks Dialog ─────────────────────────────────────────────────────
  Future<String?> _showRemarksDialog() async {
    final TextEditingController remarksController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
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
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 38,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Accept Booking',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please provide remarks to continue.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: remarksController,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Enter your remarks here...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.green,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(remarksController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Accept booking handler ─────────────────────────────────────────────
  Future<void> _handleAcceptBooking() async {
    if (widget.booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking not found")),
      );
      return;
    }

    final remarks = await _showRemarksDialog();
    if (remarks == null) return;

    setState(() => _isLoading = true);

    try {
      final success = await ref
          .read(guestBookingProvider.notifier)
          .acceptBooking(
            mid: widget.booking!.mid,
            bookingId: widget.booking!.bookingId,
            remark: remarks,
          );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Booking Accepted Successfully"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to accept booking"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Input text style ───────────────────────────────────────────────────
  TextStyle _inputTextStyle(FontSettings fontSettings) {
    return TextStyle(
      fontSize: fontSettings.fontSize,
      fontWeight: fontSettings.fontWeight,
    );
  }

  // ── Accepted Info Card ─────────────────────────────────────────────────
  Widget _buildAcceptedInfoCard(FontSettings fontSettings) {
    final booking = widget.booking!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Acceptance Details',
                  style: TextStyle(
                    fontSize: fontSettings.fontSize + 1,
                    fontWeight: FontWeight.w900,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),

          // ── Card Body ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Accepted By
                _buildInfoRow(
                  icon: Icons.person_outline,
                  label: 'Accepted By',
                  value: booking.acceptUser ?? 'N/A',
                  fontSettings: fontSettings,
                ),
                _buildDivider(),

                // Accepted At
                _buildInfoRow(
                  icon: Icons.schedule,
                  label: 'Accepted At',
                  value: _formatDateTime(booking.acceptTime),
                  fontSettings: fontSettings,
                ),

                // Remark (only if present)
                if (booking.remark != null &&
                    booking.remark!.trim().isNotEmpty) ...[
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.comment_outlined,
                    label: 'Remark',
                    value: booking.remark!,
                    fontSettings: fontSettings,
                    expanded: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required FontSettings fontSettings,
    bool expanded = false,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSettings.fontSize - 1,
            color: const Color.fromARGB(255, 0, 0, 0),
            fontWeight: FontWeight.w900,
          ),
        ),
        // const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSettings.fontSize + 1,
            fontWeight: FontWeight.w700,
            color: Colors.green.shade800,
          ),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green, size: 20),
        const SizedBox(width: 10),
        expanded ? Expanded(child: content) : content,
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: Colors.green.shade200, height: 1),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
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
      //   title: Text(
      //     'Guest Booking Details',
      //     style: TextStyle(
      //       fontSize: fontSettings.fontSize,
      //       fontWeight: fontSettings.fontWeight,
      //     ),
      //   ),
      // ),
        title: Row(
          children: [
            Text(
              'Guest Booking Details',
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.isPending
                    ? Colors.orange
                    : Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isPending
                        ? Icons.hourglass_bottom
                        : Icons.check_circle,
                       
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isPending
                        ? 'Pending'
                        : 'Approved',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // ── Main content ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Guest Display Card ─────────────────────────────────
                  GuestDisplayCardById(
                    memberId: widget.booking?.mid ?? "",
                    showLastVisitDate: true,
                  ),
                  const SizedBox(height: 16),

                  // ── Member ID + Profile Search Button ──────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          keyboardType:
                              const TextInputType.numberWithOptions(),
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
                              color: const Color.fromARGB(255, 0, 0, 0),
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
                      const SizedBox(width: 8),
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
                            final existingGuest =
                                ref.read(selectedGuestProvider);
                            if (existingGuest == null ||
                                existingGuest.mid !=
                                    _memberIdController.text) {
                              setState(() => _isLoading = true);
                              await _loadGuestDataForView();
                              setState(() => _isLoading = false);
                            }
                            context.push('/home/profile');
                          } catch (e) {
                            setState(() => _isLoading = false);
                          }
                        },
                        child: const Icon(Icons.person_search, size: 25),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Arrival Date ───────────────────────────────────────
                  TextFormField(
                    controller: _pkgStartController,
                    readOnly: true,
                    style: _inputTextStyle(fontSettings),
                    decoration: InputDecoration(
                      labelText: "Arrival Date",
                      labelStyle: TextStyle(
                        color: const Color.fromARGB(255, 0, 0, 0),
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

                  // ── Departure Date ─────────────────────────────────────
                  TextFormField(
                    controller: _pkgEndController,
                    readOnly: true,
                    style: _inputTextStyle(fontSettings),
                    decoration: InputDecoration(
                      labelText: "Departure Date",
                      labelStyle: TextStyle(
                        color: const Color.fromARGB(255, 0, 0, 0),
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                      prefixIcon:
                          const Icon(Icons.event, color: Colors.red),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: -5.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Requested Date & Time ──────────────────────────────
                  TextFormField(
                    controller: _insertDateController,
                    readOnly: true,
                    style: _inputTextStyle(fontSettings),
                    decoration: InputDecoration(
                      labelText: "Requested Date & Time",
                      labelStyle: TextStyle(
                        color: const Color.fromARGB(255, 0, 0, 0),
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
if (widget.booking?.peRemark != null &&
    widget.booking!.peRemark!.trim().isNotEmpty) ...[
  TextFormField(
    initialValue: widget.booking!.peRemark,
    readOnly: true,
    style: _inputTextStyle(fontSettings),
    maxLines: 3,
    decoration: InputDecoration(
      labelText: "Remark",
      labelStyle: TextStyle(
        color: const Color.fromARGB(255, 0, 0, 0),
        fontSize: fontSettings.fontSize,
        fontWeight: fontSettings.fontWeight,
      ),
    //  prefixIcon: const Icon(Icons.star_outline, color: Colors.amber),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 8.0,
      ),
    ),
  ),
  const SizedBox(height: 16),
],
                  // ── Accepted Info Card (only when accepted) ────────────
                  if (!widget.isPending && widget.booking != null) ...[
                    _buildAcceptedInfoCard(fontSettings),
                    const SizedBox(height: 16),
                  ],

                  // ── Accept Button (only when pending) ──────────────────
                  if (widget.isPending)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleAcceptBooking,
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
                ],
              ),
            ),
          ),

          // ── Loading overlay ────────────────────────────────────────────
          // if (_isLoading)
          //   Positioned.fill(
          //     child: Container(
          //       color: const Color.fromARGB(135, 117, 115, 115),
          //       child: const Center(
          //         child: CircularProgressIndicator(
          //           valueColor: AlwaysStoppedAnimation<Color>(
          //             Constants.kSecondaryColor,
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
 if (_isLoading)
            Positioned.fill(
              child: Container(
                color: const Color.fromARGB(135, 117, 115, 115),
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
    );
  }
}