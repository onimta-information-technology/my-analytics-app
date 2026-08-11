import 'dart:typed_data';

import 'package:ballys_reservation_app/components/flight_card_ballys.dart';
import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_reservation_entryBallys.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/models/reservation/flight_bookng_ballys.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc_ballys.dart';
import 'package:ballys_reservation_app/models/reservation/reservation_passport_image_ballys.dart';
//  import 'package:ballys_reservation_app/models/reservation/reservation_passport_image.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/hotels_provider.dart';
import 'package:ballys_reservation_app/providers/reservation_provider_ballys.dart';
import 'package:ballys_reservation_app/providers/selectedReservationforBallys_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider_ballys.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider_ballys.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Ballys copy of `ReservationViewScreen`: read-only detail view of the
/// `ReservationBallys` selected in `ReservationScreenBallys`, plus the
/// check / approve / reject / reverse actions.
///
/// Everything it renders comes from the `Reservation_GetAllReservations`
/// payload the list screen already parsed — `guests`, `room_details`,
/// `air_ticket_details` and `passport_images`.
class ReservationViewScreenBallys extends ConsumerStatefulWidget {
  const ReservationViewScreenBallys({super.key});

  @override
  ConsumerState<ReservationViewScreenBallys> createState() =>
      _ReservationViewScreenBallysState();
}

class _ReservationViewScreenBallysState
    extends ConsumerState<ReservationViewScreenBallys> with ConnectivityMixin {
  final TextEditingController _reservationNoController =
      TextEditingController();
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();

  final ValueNotifier<String> hotelRoomNotifier = ValueNotifier<String>("");
  final ValueNotifier<String> airTicketsNotifier = ValueNotifier<String>("");

  final TextEditingController _arrivalDateController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _reservationnewnumberController =
      TextEditingController();
  final TextEditingController _packageAmountController =
      TextEditingController();
  String _airTicketRequisition = "No";
  bool _isLoading = false;
  bool _isGuestLoading = false;
  bool _guestDataLoaded = false;

  bool _hasResChk = false;
  bool _hasResApp = false;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _getHotels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
      final selectedReservation = ref.read(selectedReservationBallysProvider);
      ref.read(selectedHotelBallysProvider.notifier).setHotels(
            selectedReservation != null ? selectedReservation.hotelDescip : [],
          );
      ref.read(selectedFlightBallysProvider.notifier).setFlights(
            selectedReservation != null
                ? selectedReservation.airticketDescrip
                : [],
          );

      if (selectedReservation != null && !_guestDataLoaded) {
        _loadGuestDataForView();
      }
    });
  }

  Future<void> _loadPermissions() async {
    final resChk = await StorageUtil.getResChk();
    final resApp = await StorageUtil.getResApp();
    final userName = await StorageUtil.getUserName();

    if (mounted) {
      setState(() {
        _hasResChk = resChk == true;
        _hasResApp = resApp == true;
        _currentUserName = userName;
      });
    }
  }

  @override
  void dispose() {
    _reservationNoController.dispose();
    _memberIdController.dispose();
    _memberNameController.dispose();
    _arrivalDateController.dispose();
    _departureDateController.dispose();
    _remarksController.dispose();
    _reservationnewnumberController.dispose();
    _packageAmountController.dispose();
    super.dispose();
  }

  bool get _canCheckOrReject => _hasResChk;
  bool get _canApproveOrRejectChecked => _hasResApp;

  // Reverse is allowed for anyone who can check or approve reservations.
  bool get _canReverse => _hasResChk || _hasResApp;

  // The edit icon belongs to whoever raised the request — nobody else can
  // change the reservation's contents.
  bool _isRequester(String? reqBy) {
    final user = (_currentUserName ?? '').trim();
    if (user.isEmpty) return false;
    return user.toLowerCase() == (reqBy ?? '').trim().toLowerCase();
  }

  // ── Format DateTime ────────────────────────────────────────────────────
  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final hourStr = hour12.toString().padLeft(2, '0');
    return '$day/$month/$year  $hourStr:$minute $period';
  }

  // ── Status helpers ─────────────────────────────────────────────────────
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Checked':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Color _getStatusDarkColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green[700]!;
      case 'Rejected':
        return Colors.red[700]!;
      case 'Checked':
        return Colors.blue[700]!;
      default:
        return Colors.orange[700]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle_outline;
      case 'Rejected':
        return Icons.cancel_outlined;
      case 'Checked':
        return Icons.fact_check_outlined;
      default:
        return Icons.hourglass_bottom;
    }
  }

  // A stage (checked/approved/rejected) is worth showing when any of its
  // audit fields carries data.
  bool _hasStageData(
    String? status,
    String? by,
    DateTime? time,
    String? remark,
  ) {
    return (status != null && status.trim().isNotEmpty) ||
        (by != null && by.trim().isNotEmpty) ||
        time != null ||
        (remark != null && remark.trim().isNotEmpty);
  }

  // ── Action Info Card ───────────────────────────────────────────────────
  Widget _buildActionInfoCard(
    String status,
    String? actionBy,
    DateTime? actionTime,
    String actionRemarks,
    double fontSize,
    FontWeight fontWeight,
  ) {
    final color = _getStatusColor(status);
    final darkColor = _getStatusDarkColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  '$status Information',
                  style: TextStyle(
                    fontSize: fontSize + 4,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action By
                _buildCardRow(
                  icon: Icons.person_outline,
                  iconColor: color,
                  label: '$status By',
                  value: actionBy ?? 'N/A',
                  valueColor: darkColor,
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                ),
                const SizedBox(height: 8),

                // Action Time
                _buildCardRow(
                  icon: Icons.access_time_outlined,
                  iconColor: color,
                  label: '$status On',
                  value:
                      actionTime != null ? _formatDateTime(actionTime) : 'N/A',
                  valueColor: darkColor,
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                ),

                // Remarks
                if (actionRemarks.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment_outlined, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remarks',
                              style: TextStyle(
                                fontSize: fontSize - 1,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              actionRemarks,
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: fontWeight,
                                color: darkColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Request Info Card ──────────────────────────────────────────────────
  //
  // Who raised the reservation and when, from the `user_name`, `sales_code`,
  // `selected_marketing_person` and `created_date` the payload carries. The
  // stage cards below cover what happened to it afterwards.
  Widget _buildRequestInfoCard(
    ReservationBallys reservation,
    double fontSize,
    FontWeight fontWeight,
  ) {
    const color = Constants.kPrimaryColor;
    final requestedBy = reservation.reqBy.trim();
    final marketingPerson = reservation.selectedMarketingPerson?.trim() ?? '';
    final salesCode = reservation.salesCode?.trim() ?? '';

    if (requestedBy.isEmpty && marketingPerson.isEmpty && salesCode.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_outlined, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Request Information',
                  style: TextStyle(
                    fontSize: fontSize + 4,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (requestedBy.isNotEmpty) ...[
                  _buildCardRow(
                    icon: Icons.person_outline,
                    iconColor: color,
                    label: 'Requested By',
                    // The sales code the request was raised under, when the
                    // payload names one.
                    value: salesCode.isEmpty
                        ? requestedBy
                        : '$requestedBy ($salesCode)',
                    valueColor: Colors.black87,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                  const SizedBox(height: 8),
                ],
                _buildCardRow(
                  icon: Icons.access_time_outlined,
                  iconColor: color,
                  label: 'Requested On',
                  value: _formatDateTime(reservation.insertDate),
                  valueColor: Colors.black87,
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                ),
                // Only raised on someone else's behalf, so blank on most rows.
                if (marketingPerson.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildCardRow(
                    icon: Icons.badge_outlined,
                    iconColor: color,
                    label: 'Marketing Person',
                    value: marketingPerson,
                    valueColor: Colors.black87,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Card row helper ────────────────────────────────────────────────────
  Widget _buildCardRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: const Color.fromARGB(255, 0, 0, 0),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Access Denied Dialog ───────────────────────────────────────────────
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.kPrimaryColor,
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

  // ── Remarks Dialog ─────────────────────────────────────────────────────
  Future<String?> _showRemarksDialog(
    String title,
    Color accentColor,
    IconData icon,
  ) async {
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
                      color: accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 38, color: accentColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please provide remarks to continue.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
                        borderSide: BorderSide(color: accentColor, width: 1.5),
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
                            backgroundColor: accentColor,
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

  // ── Guest data loader ──────────────────────────────────────────────────
  Future<void> _loadGuestDataForView() async {
    if (_memberIdController.text.isEmpty || _guestDataLoaded) return;

    try {
      setState(() => _isGuestLoading = true);

      GuestRepository guestRepository = GuestRepository(
        ApiService(const FlutterSecureStorage()),
      );

      List<GuestSearchResponse> guests = await guestRepository.searchGuest(
        9021,
        _memberIdController.text,
      );

      if (guests.isNotEmpty) {
        final guestResponse = guests.first;
        ref.read(selectedGuestProvider.notifier).setSelectedGuest(
              Guest(
                mid: guestResponse.mid,
                memberName: guestResponse.mName,
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
      if (!mounted) return;
      setState(() => _isGuestLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGuestLoading = false);
    }
  }

  Future<void> _getHotels() async {
    final hotels = ref.read(hotelsProvider);
    if (hotels.isEmpty) {
      await ref.read(hotelsProvider.notifier).getAllHotels();
    }
  }

  String getGuestAndRoomCounts(List<HotelDescipBallys> hotels) {
    final totalGuests = hotels.fold<int>(
      0,
      (sum, hotel) => sum + (hotel.guestCount ?? 0),
    );
    final totalRooms = hotels.fold<int>(
      0,
      (sum, hotel) => sum + (hotel.roomCount ?? 0),
    );

    String txt =
        totalGuests == 1 ? "$totalGuests GUEST" : "$totalGuests GUESTS";
    txt += totalRooms == 1 ? ", $totalRooms ROOM" : ", $totalRooms ROOMS";
    return txt;
  }

  String getGuestAndTicketCounts(List<FlightBookingBallys> flights) {
    final totalGuests = flights.fold<int>(0, (sum, f) => sum + f.guestCount);
    final totalTickets = flights.length;

    String txt =
        totalGuests == 1 ? "$totalGuests GUEST" : "$totalGuests GUESTS";
    txt += totalTickets == 1
        ? ", $totalTickets TICKET"
        : ", $totalTickets TICKETS";
    return txt;
  }

  /// A guest's package amount as it should be shown. Guests who carry no
  /// package of their own come back as a bare `0.00` with a blank currency,
  /// which reads as travelling on someone else's package.
  ///
  /// The amount arrives as `"<currency> <number>"` — the currency is kept as
  /// it is and the number is shown whole, grouped in thousands: `IND 10,000`.
  ///
  /// [shared] is the guest's own `IsSharedAmount` tick, which the payload now
  /// sends in its own right: an amount can be both real and shared with the
  /// members on the package, so the tick is shown next to it rather than
  /// inferred from a missing amount.
  String _packageLabel(String raw, {bool shared = false}) {
    final amount = raw.trim();
    final numeric = amount.isEmpty
        ? null
        : double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), ''));
    // No package of their own — they travel on another guest's package.
    if (numeric == null || numeric == 0) return 'Shared';

    final currency = amount.replaceAll(RegExp(r'[0-9.,]'), '').trim();
    final formatted = NumberFormat('#,##0').format(numeric);
    final label = currency.isEmpty ? formatted : '$currency $formatted';
    return shared ? '$label (Shared)' : label;
  }

  /// A guest's / room's own stay, shown only when it differs from the
  /// reservation's — the payload repeats the reservation dates on every guest
  /// and every room, so printing them each time would say nothing.
  String? _stayLabel(
    DateTime? arrival,
    DateTime? departure,
    DateTime? reservationArrival,
    DateTime? reservationDeparture,
  ) {
    if (arrival == null && departure == null) return null;

    bool sameDay(DateTime? a, DateTime? b) =>
        a != null &&
        b != null &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;

    if (sameDay(arrival, reservationArrival) &&
        sameDay(departure, reservationDeparture)) {
      return null;
    }

    final format = DateFormat('yyyy-MM-dd');
    final from = arrival != null ? format.format(arrival) : '—';
    final to = departure != null ? format.format(departure) : '—';
    return '$from → $to';
  }

  // ── Guests section ─────────────────────────────────────────────────────
  //
  // A reservation number can carry more than one guest (the `guests` array of
  // the payload). The list shows a single card per reservation; here every
  // guest gets a card of their own — one per row of `guests`, members sharing
  // someone's package included. The model hangs a shared member off the guest
  // whose package they are on, but a card is per person, so those are flattened
  // back out here and the member's card names whose package it is.
  //
  // Each card carries only that person's own details — name, BM number, package
  // amount, whether family members travel with them, and their own passport
  // images (matched on `GuestBMNumber`). The rooms, air tickets and dates they
  // were booked against are shown once, further down the screen.
  Widget _buildGuestsSection(
    List<GuestReservationEntryBallys> guests,
    List<ReservationPassportImageBallys> passportImages,
    FontSettings fontSettings, {
    DateTime? reservationArrival,
    DateTime? reservationDeparture,
  }) {
    if (guests.isEmpty) return const SizedBox.shrink();

    final cards = <({
      String mid,
      String name,
      String package,
      bool hasFamilyMembers,
      String? stay,
      // Whose package this person is on — null for a guest on their own.
      String? sharesWith,
      // This person's own passports, empty when they uploaded none.
      List<ReservationPassportImageBallys> passports,
    })>[];

    // A person's passports are the ones tagged with their BM number. A blank
    // BM number would otherwise sweep up every untagged image, so it matches
    // nothing and those fall through to the unmatched section instead.
    List<ReservationPassportImageBallys> passportsFor(String mid) {
      if (mid.trim().isEmpty) return const [];
      return passportImages.where((p) => p.guestBmNumber == mid).toList();
    }

    for (final guest in guests) {
      // Members travel on the owner's dates, so both carry the same stay.
      final stay = _stayLabel(
        guest.arrivalDate,
        guest.departureDate,
        reservationArrival,
        reservationDeparture,
      );
      final owner = guest.guestName.trim().isNotEmpty
          ? guest.guestName.trim()
          : guest.mid;

      cards.add((
        mid: guest.mid,
        name: guest.guestName,
        package: _packageLabel(
          guest.packageAmount,
          shared: guest.sharedPackage,
        ),
        hasFamilyMembers: guest.hasFamilyMembers,
        stay: stay,
        sharesWith: null,
        passports: passportsFor(guest.mid),
      ));

      for (final member in guest.accompanyingMembers) {
        cards.add((
          mid: member.mid,
          name: member.guestName,
          package: _packageLabel(
            member.packageAmount,
            shared: member.sharedPackage,
          ),
          hasFamilyMembers: member.hasFamilyMembers,
          stay: stay,
          sharesWith: owner,
          passports: passportsFor(member.mid),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cards.length == 1 ? "Guest" : "Guests (${cards.length})",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6.0),
        ...cards.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;
          final isMember = card.sharesWith != null;

          return Card(
            color: const Color.fromARGB(255, 228, 224, 224),
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        // A member reads as one of the party rather than a
                        // guest standing on their own.
                        backgroundColor:
                            isMember ? Colors.blueGrey : Colors.black,
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          card.name.isNotEmpty ? card.name : "Unnamed guest",
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (card.mid.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      card.mid,
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                  ],
                  // The rooms, tickets and dates sit on the guest whose package
                  // this member is on, so the card says whose that is.
                  // if (isMember) ...[
                  //   const SizedBox(height: 2),
                  //   Row(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       const Icon(Icons.link, size: 16, color: Colors.blueGrey),
                  //       const SizedBox(width: 6),
                  //       Expanded(
                  //         child: Text(
                  //           "Shared package with ${card.sharesWith}",
                  //           style: TextStyle(
                  //             fontSize: fontSettings.fontSize,
                  //             fontWeight: FontWeight.w600,
                  //             color: Colors.blueGrey,
                  //           ),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ],
                  const SizedBox(height: 2),
                  Text(
                    "Package: ${card.package}",
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.hasFamilyMembers
                        ? "Family members: Included"
                        : "Family members: Not included",
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                  // A guest travelling on their own dates rather than the
                  // reservation's.
                  if (card.stay != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      "Stay: ${card.stay}",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                  ],
                  // This person's own passports, so whose passport is whose
                  // needs no separate label.
                  if (card.passports.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      card.passports.length == 1
                          ? "Passport"
                          : "Passports (${card.passports.length})",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildPassportThumbnails(card.passports, fontSettings),
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10.0),
      ],
    );
  }

  // ── Unmatched passports ────────────────────────────────────────────────
  //
  // A passport belongs on its owner's guest card, matched on `GuestBMNumber`.
  // Anything tagged with a BM number that matches nobody on the reservation —
  // or with no BM number at all — has no card to sit on, so it lands here
  // rather than being silently dropped.
  Widget _buildPassportsSection(
    List<GuestReservationEntryBallys> guests,
    List<ReservationPassportImageBallys> passportImages,
    FontSettings fontSettings,
  ) {
    if (passportImages.isEmpty) return const SizedBox.shrink();

    // Members sharing a package included, since each carries a passport of its
    // own under its own BM number.
    final mids = <String>{
      for (final guest in guests) ...[
        guest.mid,
        for (final member in guest.accompanyingMembers) member.mid,
      ],
    }..removeWhere((mid) => mid.trim().isEmpty);

    final orphans = passportImages
        .where((p) => !mids.contains(p.guestBmNumber))
        .toList();
    if (orphans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          orphans.length == 1 ? "Passport" : "Passports (${orphans.length})",
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6.0),
        _buildPassportThumbnails(orphans, fontSettings),
        const SizedBox(height: 10.0),
      ],
    );
  }

  /// Renders passport images as tappable thumbnails and PDFs as labelled
  /// chips. Returns an empty widget when there are none. The heading comes
  /// from the guest card, or from [_buildPassportsSection] for unmatched ones.
  Widget _buildPassportThumbnails(
    List<ReservationPassportImageBallys> images,
    FontSettings fontSettings,
  ) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: images.map((img) {
            final bytes = img.bytes;

            if (img.isPdf || bytes == null) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      img.isPdf
                          ? Icons.picture_as_pdf
                          : Icons.insert_drive_file,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        img.fileName.isNotEmpty ? img.fileName : "Document",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: fontSettings.fontSize - 4),
                      ),
                    ),
                  ],
                ),
              );
            }

            return GestureDetector(
              onTap: () => _showPassportPreview(bytes, img.fileName),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  bytes,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            );
      }).toList(),
    );
  }

  /// Full-screen, zoomable preview of a passport image.
  void _showPassportPreview(Uint8List bytes, String fileName) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) =>
          _PassportPreviewDialog(bytes: bytes, fileName: fileName),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  /// Re-posts the reservation with [status] and pops back to the list on
  /// success, so the list reloads it into its new bucket.
  Future<void> _postStatus({
    required String status,
    required String remarks,
    required String successMessage,
    required Color successColor,
    required String failureVerb,
  }) async {
    final selectedReservation = ref.read(selectedReservationBallysProvider);
    if (selectedReservation == null) return;

    try {
      setState(() => _isLoading = true);
      final success = await ref
          .read(reservationBallysProvider.notifier)
          .updateReservationStatus(
            reservation: selectedReservation,
            status: status,
            remarks: remarks,
          );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: successColor,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Failed to $failureVerb reservation');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to $failureVerb reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkReservation() async {
    if (!_canCheckOrReject) {
      _showAccessDeniedDialog();
      return;
    }

    if (ref.read(selectedReservationBallysProvider) == null) return;

    final remarks = await _showRemarksDialog(
      'Check Reservation',
      Colors.blue,
      Icons.fact_check_outlined,
    );
    if (remarks == null) return;

    await _postStatus(
      status: "Checked",
      remarks: remarks,
      successMessage: 'Reservation checked successfully',
      successColor: Colors.blue,
      failureVerb: 'check',
    );
  }

  Future<void> _approveReservation() async {
    if (!_canApproveOrRejectChecked) {
      _showAccessDeniedDialog();
      return;
    }

    if (ref.read(selectedReservationBallysProvider) == null) return;

    final remarks = await _showRemarksDialog(
      'Approve Reservation',
      Colors.green,
      Icons.check_circle_outline,
    );
    if (remarks == null) return;

    await _postStatus(
      status: "Approved",
      remarks: remarks,
      successMessage: 'Reservation approved successfully',
      successColor: Colors.green,
      failureVerb: 'approve',
    );
  }

  /// Reject from the For-Approval tab: needs the approve permission.
  Future<void> _rejectReservation() async {
    final selectedReservation = ref.read(selectedReservationBallysProvider);
    if (selectedReservation == null) return;

    final isPending = selectedReservation.requestStatus == 'Pending';
    final hasPermission =
        isPending ? _canCheckOrReject : _canApproveOrRejectChecked;

    if (!hasPermission) {
      _showAccessDeniedDialog();
      return;
    }

    final remarks = await _showRemarksDialog(
      'Reject Reservation',
      Colors.red,
      Icons.cancel_outlined,
    );
    if (remarks == null) return;

    await _postStatus(
      status: "Rejected",
      remarks: remarks,
      successMessage: 'Reservation rejected successfully',
      successColor: Colors.orange,
      failureVerb: 'reject',
    );
  }

  /// Reject from the Pending tab: the requester can withdraw their own request
  /// on top of whoever holds the check/approve permission.
  Future<void> _rejectReservationinpendingtab() async {
    final selectedReservation = ref.read(selectedReservationBallysProvider);
    if (selectedReservation == null) return;

    final isPending = selectedReservation.requestStatus == 'Pending';
    final hasPermission =
        isPending ? _canCheckOrReject : _canApproveOrRejectChecked;
    final currentUserName = await StorageUtil.getUserName();
    final isRequester = (currentUserName ?? '').trim().toLowerCase() ==
        selectedReservation.reqBy.trim().toLowerCase();

    if (!hasPermission && !isRequester) {
      _showAccessDeniedDialog();
      return;
    }

    final remarks = await _showRemarksDialog(
      'Reject Reservation',
      Colors.red,
      Icons.cancel_outlined,
    );
    if (remarks == null) return;

    await _postStatus(
      status: "Rejected",
      remarks: remarks,
      successMessage: 'Reservation rejected successfully',
      successColor: Colors.orange,
      failureVerb: 'reject',
    );
  }

  // ── Reverse: send the reservation back to Pending ──────────────────────
  Future<void> _reverseReservation() async {
    if (!_canReverse) {
      _showAccessDeniedDialog();
      return;
    }

    if (ref.read(selectedReservationBallysProvider) == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reverse Reservation'),
        content: const Text(
          'Are you sure you want to reverse this reservation back to Pending?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _postStatus(
      status: "Pending",
      remarks: _remarksController.text,
      successMessage: 'Reservation reversed to Pending',
      successColor: Colors.orange,
      failureVerb: 'reverse',
    );
  }

  /// Clears the selected reservation + its hotels/flights so the next
  /// "New Reservation" doesn't inherit them (Update mode / stale hotel &
  /// air-ticket data).
  void _clearSelection() {
    ref
        .read(selectedReservationBallysProvider.notifier)
        .clearSelectedBallysReservation();
    ref.read(selectedHotelBallysProvider.notifier).setHotels([]);
    ref.read(selectedFlightBallysProvider.notifier).setFlights([]);
  }

  // ── Amendment ──────────────────────────────────────────────────────────
  //
  // A reservation carries two amendable parts, and each has its own screen, so
  // the button asks which one first. Both screens read the selection providers
  // this screen already populated, hence nothing to pass along.
  //
  // Only the parts the reservation actually holds are offered: a stay with no
  // air tickets gets no AIR TICKET option, and vice versa.
  Future<void> _showAmendmentTypeDialog({
    required bool hasHotels,
    required bool hasAirTickets,
  }) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Amendment',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'What would you like to amend?',
            style: TextStyle(fontSize: 15),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              children: [
                if (hasHotels) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(dialogContext).pop('hotel'),
                      icon: const Icon(Icons.hotel, size: 20),
                      label: const Text(
                        'HOTEL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (hasAirTickets)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop('air-ticket'),
                      icon: const Icon(Icons.flight_takeoff, size: 20),
                      label: const Text(
                        'AIR TICKET',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
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
              ],
            ),
          ],
        );
      },
    );

    if (choice == null || !mounted) return;

    await context.push(
      choice == 'hotel'
          ? '/reservationMain/reservations/hotel-amendment-ballys'
          : '/reservationMain/reservations/air-ticket-amendment-ballys',
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final selectedReservation = ref.watch(selectedReservationBallysProvider);
    final selectedHotels = ref.watch(selectedHotelBallysProvider);
    hotelRoomNotifier.value = getGuestAndRoomCounts(selectedHotels);
    final selectedFlights = ref.watch(selectedFlightBallysProvider);
    airTicketsNotifier.value = getGuestAndTicketCounts(selectedFlights);

    if (selectedReservation != null) {
      _reservationNoController.text = selectedReservation.reservNo;
      _memberIdController.text = selectedReservation.mid;
      _memberNameController.text = selectedReservation.mName;
      final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
      _arrivalDateController.text = dateFormat.format(
        selectedReservation.arrDate,
      );
      _departureDateController.text = dateFormat.format(
        selectedReservation.depDate,
      );

      final String status = selectedReservation.airticketReservationStatus
          .toString()
          .toUpperCase()
          .trim();
      final bool hasAirTickets = status == "T" ||
          status == "TRUE" ||
          status == "YES" ||
          status == "Y" ||
          status == "1";
      _airTicketRequisition = hasAirTickets ? "Yes" : "No";
      _remarksController.text = selectedReservation.remarks;
      _reservationnewnumberController.text =
          selectedReservation.reservationnewnumber ?? '';
      _packageAmountController.text = selectedReservation.packageAmountDisplay;
    }

    final fontSettings = ref.watch(fontSettingsProvider);

    // Determine if this reservation has been actioned
    final String currentStatus = selectedReservation?.requestStatus ?? '';
    final bool isActioned = currentStatus == 'Checked' ||
        currentStatus == 'Approved' ||
        currentStatus == 'Rejected';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _clearSelection();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/MenuScreen');
            }
          },
        ),
        title: Row(
          children: [
            const Text("Reservation", style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: currentStatus == 'Approved'
                    ? Colors.green
                    : currentStatus == 'Checked'
                        ? const Color.fromARGB(255, 92, 17, 255)
                        : currentStatus == 'Pending'
                            ? Colors.orange
                            : Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentStatus.isEmpty
                        ? 'Pending'
                        : currentStatus == 'Pending'
                            ? 'Pending & Checked'
                            : currentStatus == 'Checked'
                                ? 'For Approval'
                                : currentStatus,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // actions: [
        //   PopScope(
        //     onPopInvokedWithResult: (bool didPop, dynamic result) {
        //       _clearSelection();
        //     },
        //     child: Padding(
        //       padding: const EdgeInsets.only(right: 8.0),
        //       child: (selectedReservation?.requestStatus == 'Pending' &&
        //               _isRequester(selectedReservation?.reqBy))
        //           ? IconButton(
        //               onPressed: () async {
        //                 Future<void> navigateToEdit() async {
        //                   final reservationBeforeEdit = ref.read(
        //                     selectedReservationBallysProvider,
        //                   );
        //                   final result = await context.push(
        //                     "/reservationMain/reservations/new-reservation-ballys",
        //                   );
        //                   if (!mounted) return;
        //                   if (result == true) {
        //                     Navigator.of(context).pop(true);
        //                     return;
        //                   }
        //                   // Cancelled: NewReservationBallysScreen clears the
        //                   // shared selection providers on pop, so put them back
        //                   // or this screen renders with no reservation and no
        //                   // guest.
        //                   if (reservationBeforeEdit != null) {
        //                     ref
        //                         .read(
        //                           selectedReservationBallysProvider.notifier,
        //                         )
        //                         .setSelectedBallysReservation(
        //                           reservationBeforeEdit,
        //                         );
        //                     ref
        //                         .read(selectedHotelBallysProvider.notifier)
        //                         .setHotels(reservationBeforeEdit.hotelDescip);
        //                     ref
        //                         .read(selectedFlightBallysProvider.notifier)
        //                         .setFlights(
        //                           reservationBeforeEdit.airticketDescrip,
        //                         );
        //                     _guestDataLoaded = false;
        //                     await _loadGuestDataForView();
        //                   }
        //                 }

        //                 if (_memberIdController.text.isNotEmpty &&
        //                     !_guestDataLoaded) {
        //                   await _loadGuestDataForView();
        //                   await navigateToEdit();
        //                 } else {
        //                   await navigateToEdit();
        //                 }
        //               },
        //               icon: const Icon(Icons.mode_edit_outline_sharp),
        //             )
        //           : const SizedBox.shrink(),
        //     ),
        //   ),
        // ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // ── Reservation No ───────────────────────────────────
                  TextFormField(
                    autofocus: false,
                    readOnly: true,
                    controller: _reservationNoController,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    decoration: InputDecoration(
                      labelText: "Reservation No",
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
                  const SizedBox(height: 10.0),

                  // ── Member ID + Search ───────────────────────────────
                  Row(
                    children: [
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
                            if (!_guestDataLoaded &&
                                _memberIdController.text.isNotEmpty) {
                              setState(() => _isLoading = true);
                              await _loadGuestDataForView();
                              if (!mounted) return;
                              setState(() => _isLoading = false);
                            }
                            if (!mounted) return;
                            context.push('/home/profile');
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _isLoading = false);
                          }
                        },
                        child: const Icon(Icons.person_search, size: 25),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),

                  // ── Member Name ──────────────────────────────────────
                  TextFormField(
                    autofocus: false,
                    readOnly: true,
                    controller: _memberNameController,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    decoration: InputDecoration(
                      labelText: "Member Name",
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
                  const SizedBox(height: 10.0),



                  // ── Guest card ───────────────────────────────────────
                  GuestDisplayCardSpecialGiftview(
                    memberIdText: _memberIdController.text,
                    memberNameText: _memberNameController.text,
                    showCard: _memberIdController.text.isNotEmpty &&
                        _memberNameController.text.isNotEmpty,
                    isLoading: _isGuestLoading,
                    showLastVisitDate: true,
                  ),
                  const SizedBox(height: 10.0),

                  // ── All guests on this reservation, each with their own
                  //    passports on the card ───────────────────────────
                  _buildGuestsSection(
                    selectedReservation?.guests ?? const [],
                    selectedReservation?.passportImages ?? const [],
                    fontSettings,
                    reservationArrival: selectedReservation?.arrDate,
                    reservationDeparture: selectedReservation?.depDate,
                  ),

                  // ── Passports belonging to nobody on the reservation ──
                  _buildPassportsSection(
                    selectedReservation?.guests ?? const [],
                    selectedReservation?.passportImages ?? const [],
                    fontSettings,
                  ),

                  // ── Hotel & Rooms summary ────────────────────────────
                  ValueListenableBuilder<String>(
                    valueListenable: hotelRoomNotifier,
                    builder: (context, value, child) {
                      return TextFormField(
                        controller: TextEditingController(text: value),
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Select Hotels & Rooms",
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
                      );
                    },
                  ),
                  const SizedBox(height: 10.0),

                  // ── Hotel cards ──────────────────────────────────────
                  selectedHotels.isEmpty
                      ? const Center(
                          heightFactor: 3.0,
                          child: Text(
                            'No hotels selected.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color.fromARGB(255, 168, 49, 49),
                            ),
                          ),
                        )
                      : Column(
                          children: selectedHotels.map((hotel) {
                            final roomStayLabel = _stayLabel(
                              hotel.arrivalDate,
                              hotel.departureDate,
                              selectedReservation?.arrDate,
                              selectedReservation?.depDate,
                            );
                            return SizedBox(
                              width: double.infinity,
                              child: Card(
                                color: const Color.fromARGB(255, 228, 224, 224),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 8,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hotel.hotelName ?? '',
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: fontSettings.fontWeight,
                                        ),
                                      ),
                                      // The rooms are listed once for the whole
                                      // reservation, so each one names the
                                      // guest(s) it was booked for.
                                      if (hotel.assignedGuests.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.group,
                                                size: 16,
                                                color: Colors.blueGrey),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                hotel.assignedGuests
                                                    .map((g) => g.label)
                                                    .join(", "),
                                                style: TextStyle(
                                                  fontSize:
                                                      fontSettings.fontSize,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: "Category: ",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize:
                                                    fontSettings.fontSize + 2,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: hotel.roomCategoryName,
                                              style: TextStyle(
                                                fontSize: fontSettings.fontSize,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: "Room Type: ",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize:
                                                    fontSettings.fontSize + 2,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                              ),
                                            ),
                                            TextSpan(
                                              text: hotel.roomTypeName,
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: fontSettings.fontSize,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Wrapped rather than a fixed row: the
                                      // children count only joins the line once
                                      // the room carries one, and four counts
                                      // no longer fit at the larger font
                                      // settings.
                                      Wrap(
                                        spacing: 20,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            "Guests: ${hotel.guestCount}",
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                          if ((hotel.childrenCount ?? 0) > 0)
                                            Text(
                                              "Children: ${hotel.childrenCount}",
                                              style: TextStyle(
                                                fontSize: fontSettings.fontSize,
                                                fontWeight:
                                                    fontSettings.fontWeight,
                                              ),
                                            ),
                                          Text(
                                            "Nights: ${hotel.noOfNights}",
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                          Text(
                                            "Rooms: ${hotel.roomCount}",
                                            style: TextStyle(
                                              fontSize: fontSettings.fontSize,
                                              fontWeight:
                                                  fontSettings.fontWeight,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // A room booked over its own dates —
                                      // an amendment can move one room without
                                      // moving the reservation.
                                      if (roomStayLabel != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          "Stay: $roomStayLabel",
                                          style: TextStyle(
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        "Estimated Cost: ${hotel.selectedCost}",
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize + 2,
                                          fontWeight: fontSettings.fontWeight,
                                        ),
                                      ),
                                      if (hotel.ecLcoFacility != null &&
                                          hotel.ecLcoFacility!
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          "EC/LCO Facility: ${hotel.ecLcoFacility}",
                                          style: TextStyle(
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ],
                                      if (hotel.paymentBy != null &&
                                          hotel.paymentBy!
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          "Payment By: ${hotel.paymentBy}",
                                          style: TextStyle(
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: fontSettings.fontWeight,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 10.0),

                  // ── Arrival Date ─────────────────────────────────────
                  TextFormField(
                    controller: _arrivalDateController,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Arrival Date",
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: -5.0,
                      ),
                      labelStyle: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Departure Date ───────────────────────────────────
                  TextFormField(
                    controller: _departureDateController,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    readOnly: true,
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
                  const SizedBox(height: 10),

                  // ── Air Ticket Requisition ───────────────────────────
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      "Air Ticket Requisition",
                      style: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Radio<String>(
                        value: "Yes",
                        groupValue: _airTicketRequisition,
                        onChanged: (value) =>
                            setState(() => _airTicketRequisition = value!),
                      ),
                      const Text("Yes", style: TextStyle(fontSize: 16)),
                      Radio<String>(
                        value: "No",
                        groupValue: _airTicketRequisition,
                        onChanged: (value) =>
                            setState(() => _airTicketRequisition = value!),
                      ),
                      const Text("No", style: TextStyle(fontSize: 16)),
                    ],
                  ),

                  if (_airTicketRequisition == "Yes") ...[
                    const SizedBox(height: 10.0),
                    ValueListenableBuilder<String>(
                      valueListenable: airTicketsNotifier,
                      builder: (context, value, child) {
                        return TextFormField(
                          controller: TextEditingController(text: value),
                          readOnly: true,
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          decoration: InputDecoration(
                            labelText: "Select Air Tickets",
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
                        );
                      },
                    ),
                    const SizedBox(height: 10.0),
                    selectedFlights.isEmpty
                        ? const Center(
                            heightFactor: 6.0,
                            child: Text(
                              'No air tickets available.',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : Column(
                            children: selectedFlights.map((flight) {
                              return FlightCardBallys(
                                flight: flight,
                                index: selectedFlights.indexOf(flight),
                                showDelete: false,
                              );
                            }).toList(),
                          ),
                  ],

                  const SizedBox(height: 10.0),

                  // ── Remarks ──────────────────────────────────────────
                  TextFormField(
                    readOnly: true,
                    controller: _remarksController,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                    decoration: InputDecoration(
                      alignLabelWithHint: true,
                      labelText: "Remarks",
                      labelStyle: TextStyle(
                        fontSize: fontSettings.fontSize,
                        fontWeight: fontSettings.fontWeight,
                      ),
                      hintText: "Enter additional details...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 16.0),

                  // ── Who raised the request, and when ─────────────────
                  if (selectedReservation != null)
                    _buildRequestInfoCard(
                      selectedReservation,
                      fontSettings.fontSize,
                      fontSettings.fontWeight,
                    ),

                  // ════════════════════════════════════════════════════
                  // ── Action Info Cards (Checked / Approved / Rejected) ─
                  // ════════════════════════════════════════════════════
                  // Each workflow stage carries its own actioner, time and
                  // remark. Show a card for every stage that has happened so
                  // the full audit trail is visible.
                  if (selectedReservation != null &&
                      selectedReservation.requestStatus != 'Pending') ...[
                    if (selectedReservation.requestStatus != 'Rejected' &&
                        _hasStageData(
                          selectedReservation.checkedStatus,
                          selectedReservation.checkedBy,
                          selectedReservation.checkedTime,
                          selectedReservation.checkedRemark,
                        ))
                      _buildActionInfoCard(
                        'Checked',
                        selectedReservation.checkedBy,
                        selectedReservation.checkedTime,
                        selectedReservation.checkedRemark ?? '',
                        fontSettings.fontSize,
                        fontSettings.fontWeight,
                      ),
                    if (selectedReservation.requestStatus != 'Checked' &&
                        selectedReservation.requestStatus != 'Rejected' &&
                        _hasStageData(
                          selectedReservation.approvedStatus,
                          selectedReservation.approvedBy,
                          selectedReservation.approvedTime,
                          selectedReservation.approvedRemark,
                        ))
                      _buildActionInfoCard(
                        'Approved',
                        selectedReservation.approvedBy,
                        selectedReservation.approvedTime,
                        selectedReservation.approvedRemark ?? '',
                        fontSettings.fontSize,
                        fontSettings.fontWeight,
                      ),
                    // Only a genuinely rejected reservation gets the rejected
                    // card. An approved one can still carry stale rejected*
                    // audit fields from the API, and showing them here made the
                    // Approved tab look like a rejection.
                    if (selectedReservation.requestStatus == 'Rejected' &&
                        _hasStageData(
                          selectedReservation.rejectedStatus,
                          selectedReservation.rejectedBy,
                          selectedReservation.rejectedTime,
                          selectedReservation.rejectedRemark,
                        ))
                      _buildActionInfoCard(
                        'Rejected',
                        selectedReservation.rejectedBy,
                        selectedReservation.rejectedTime,
                        selectedReservation.rejectedRemark ?? '',
                        fontSettings.fontSize,
                        fontSettings.fontWeight,
                      ),
                    // Fallback for the legacy response shape that only carries
                    // a single is-approved audit field.
                    if (isActioned &&
                        !_hasStageData(
                          selectedReservation.checkedStatus,
                          selectedReservation.checkedBy,
                          selectedReservation.checkedTime,
                          selectedReservation.checkedRemark,
                        ) &&
                        !_hasStageData(
                          selectedReservation.approvedStatus,
                          selectedReservation.approvedBy,
                          selectedReservation.approvedTime,
                          selectedReservation.approvedRemark,
                        ) &&
                        !_hasStageData(
                          selectedReservation.rejectedStatus,
                          selectedReservation.rejectedBy,
                          selectedReservation.rejectedTime,
                          selectedReservation.rejectedRemark,
                        ))
                      _buildActionInfoCard(
                        currentStatus,
                        selectedReservation.isAppBy,
                        selectedReservation.isAppTime,
                        selectedReservation.isAppRemarks,
                        fontSettings.fontSize,
                        fontSettings.fontWeight,
                      ),
                  ],

                  // ── Pending: Amendment ───────────────────────────────
                  //
                  // Only a pending reservation can still be amended; once it is
                  // checked/approved/rejected the workflow has moved on. With
                  // neither hotels nor air tickets on the reservation there is
                  // nothing to amend, so the button stays hidden too.
                  if (selectedReservation?.requestStatus != 'Rejected' &&
                      (selectedHotels.isNotEmpty ||
                          selectedFlights.isNotEmpty)) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAmendmentTypeDialog(
                          hasHotels: selectedHotels.isNotEmpty,
                          hasAirTickets: selectedFlights.isNotEmpty,
                        ),
                        icon: const Icon(Icons.edit_note, size: 20),
                        label: Text(
                          'AMENDMENT',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize + 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.kPrimaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Pending: Check + Reject ──────────────────────────
                  if (selectedReservation?.requestStatus == 'Pending')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _checkReservation,
                            icon: const Icon(Icons.fact_check, size: 20),
                            label: const Text(
                              "CHECK",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _rejectReservationinpendingtab,
                            icon: const Icon(Icons.cancel, size: 20),
                            label: const Text(
                              "REJECT",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                          ),
                        ),
                      ],
                    ),

                  // ── Checked: Approve + Reject ────────────────────────
                  if (selectedReservation?.requestStatus == 'Checked')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _approveReservation,
                            icon: const Icon(Icons.done, size: 20),
                            label: const Text(
                              "APPROVE",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _rejectReservation,
                            icon: const Icon(Icons.cancel, size: 20),
                            label: const Text(
                              "REJECT",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                          ),
                        ),
                      ],
                    ),

                  // ── Reverse: send an actioned reservation back to Pending ─
                  if (isActioned && _canReverse) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _reverseReservation,
                        icon: const Icon(Icons.undo, size: 20),
                        label: const Text(
                          "REVERSE",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Full-screen loading overlay ──────────────────────────────
          if (_isLoading && !_isGuestLoading)
            Container(
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
          const Watermark(),
        ],
      ),
    );
  }
}

/// Full-screen passport viewer with pinch-zoom and in-app rotation.
///
/// The phone itself stays locked to portrait (iPhone only declares portrait in
/// Info.plist), so a landscape passport is turned inside the viewer instead:
/// it opens already rotated a quarter turn so the page fills the screen, and
/// the rotate button turns it further.
class _PassportPreviewDialog extends StatefulWidget {
  const _PassportPreviewDialog({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  @override
  State<_PassportPreviewDialog> createState() => _PassportPreviewDialogState();
}

class _PassportPreviewDialogState extends State<_PassportPreviewDialog> {
  final TransformationController _transformation = TransformationController();
  int _quarterTurns = 0;

  @override
  void initState() {
    super.initState();
    _turnIfLandscape();
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  /// Decodes just enough of the image to learn its aspect ratio. The listener
  /// can fire synchronously when the thumbnail already warmed the image cache,
  /// so the turn is applied after the frame rather than during initState.
  void _turnIfLandscape() {
    final stream = MemoryImage(
      widget.bytes,
    ).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final isLandscape = info.image.width > info.image.height;
      info.dispose();
      stream.removeListener(listener);
      if (!isLandscape) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _quarterTurns = 1);
      });
    }, onError: (_, __) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _transformation.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      widget.fileName.isNotEmpty
                          ? widget.fileName
                          : "Passport",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "Rotate",
                  icon: const Icon(
                    Icons.rotate_90_degrees_cw,
                    color: Colors.white,
                  ),
                  onPressed: _rotate,
                ),
                IconButton(
                  tooltip: "Close",
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                transformationController: _transformation,
                maxScale: 5,
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: Image.memory(
                    widget.bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
