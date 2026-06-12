import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';

// ─── Section enum ─────────────────────────────────────────────────────────────
enum _Section { hotel, airTicket, extension }

class QuickReservationScreen extends ConsumerStatefulWidget {
  const QuickReservationScreen({super.key});

  @override
  ConsumerState<QuickReservationScreen> createState() =>
      _QuickReservationScreenState();
}

class _QuickReservationScreenState
    extends ConsumerState<QuickReservationScreen>
    with TickerProviderStateMixin, ConnectivityMixin {
  // ── Active section ──────────────────────────────────────────────────────────
  _Section _activeSection = _Section.hotel;

  // ── Shared ──────────────────────────────────────────────────────────────────
  final _hotelFormKey = GlobalKey<FormState>();
  final _airFormKey = GlobalKey<FormState>();
  final _extFormKey = GlobalKey<FormState>();

  // ── HOTEL fields ────────────────────────────────────────────────────────────
  final _h_guestName = TextEditingController();
  final _h_memberId = TextEditingController();
  final _h_packageAmount = TextEditingController();
  final _h_hotelName = TextEditingController();
  final _h_noOfRooms = TextEditingController(text: '1');
  final _h_noOfPax = TextEditingController(text: '1');
  final _h_roomType = TextEditingController();
  final _h_roomCategory = TextEditingController();
  final _h_mealPlan = TextEditingController();
  final _h_paymentBy = TextEditingController();
  final _h_remarks = TextEditingController();
  final _h_marketingPerson = TextEditingController();
  final _h_approvedBy = TextEditingController();
  DateTime? _h_arrivalDate;
  DateTime? _h_departureDate;
  final _h_arrivalCtrl = TextEditingController();
  final _h_departureCtrl = TextEditingController();
  String _h_eciLco = 'NA';

  // ── AIR TICKET fields ───────────────────────────────────────────────────────
  final _a_memberId = TextEditingController();
  final _a_guestName = TextEditingController();
  final _a_packageAmount = TextEditingController();
  final _a_sector = TextEditingController();
  final _a_noOfSeats = TextEditingController(text: '1');
  final _a_class = TextEditingController();
  final _a_airlines = TextEditingController();
  DateTime? _a_arrDate;
  DateTime? _a_depDate;
  final _a_arrCtrl = TextEditingController();
  final _a_depCtrl = TextEditingController();

  // ── EXTENSION fields ────────────────────────────────────────────────────────
  final _e_guestName = TextEditingController();
  final _e_memberId = TextEditingController();
  final _e_packageAmount = TextEditingController();
  final _e_noOfRooms = TextEditingController(text: '1');
  final _e_extensionDate = TextEditingController();
  final _e_earlyDeparture = TextEditingController();
  final _e_approvedBy = TextEditingController();
  DateTime? _e_arrDate;
  final _e_arrCtrl = TextEditingController();

  // ── Colors ──────────────────────────────────────────────────────────────────
  static const _hotelColor = Color(0xFFE65C00);
  static const _airColor = Color(0xFF0277BD);
  static const _extColor = Color(0xFF2E7D32);

  Color get _accentColor {
    switch (_activeSection) {
      case _Section.hotel:
        return _hotelColor;
      case _Section.airTicket:
        return _airColor;
      case _Section.extension:
        return _extColor;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _h_guestName, _h_memberId, _h_packageAmount, _h_hotelName,
      _h_noOfRooms, _h_noOfPax, _h_roomType, _h_roomCategory,
      _h_mealPlan, _h_paymentBy, _h_remarks, _h_marketingPerson,
      _h_approvedBy, _h_arrivalCtrl, _h_departureCtrl,
      _a_memberId, _a_guestName, _a_packageAmount, _a_sector,
      _a_noOfSeats, _a_class, _a_airlines, _a_arrCtrl, _a_depCtrl,
      _e_guestName, _e_memberId, _e_packageAmount, _e_noOfRooms,
      _e_extensionDate, _e_earlyDeparture, _e_approvedBy,
      _e_arrCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Date picker (iOS wheel) ─────────────────────────────────────────────────
  Future<DateTime?> _pickDate(
    BuildContext context, {
    String label = 'Select Date',
    DateTime? initial,
    DateTime? minDate,
  }) async {
    DateTime picked = initial ?? minDate ?? DateTime.now();
    DateTime? result;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 220,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: picked,
              minimumDate: minDate ?? DateTime(2000),
              maximumDate: DateTime(2101),
              onDateTimeChanged: (d) => picked = d,
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    result = picked;
                    Navigator.pop(context);
                  },
                  child: const Text('Confirm',
                      style: TextStyle(color: Colors.blue, fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    return result;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Generate WhatsApp-style text ────────────────────────────────────────────
  String _buildHotelText() => '''
*HOTEL RESERVATION REQUEST*
Name of the Guest    : ${_h_guestName.text}
Membership No         : ${_h_memberId.text}
Package Amount       : ${_h_packageAmount.text}
Name of the Hotel    : ${_h_hotelName.text}
Arrival                        : ${_h_arrivalCtrl.text}
Departure                  : ${_h_departureCtrl.text}
No of Room/s           : ${_h_noOfRooms.text}
No Of Pax                 : ${_h_noOfPax.text}
Room Type               : ${_h_roomType.text}
Room Category         : ${_h_roomCategory.text}
ECI/LCO Facility      : $_h_eciLco
Meal Plan                  : ${_h_mealPlan.text}
Payment By              : ${_h_paymentBy.text}
Remarks                    : ${_h_remarks.text}
Marketing Person    : ${_h_marketingPerson.text}
Approved by.            : ${_h_approvedBy.text}
*Please send the confirmation''';

  String _buildAirText() => '''
*AIR TICKET REQUEST*
BM                       : ${_a_memberId.text}
Guest Name        : ${_a_guestName.text}
Package Amount : ${_a_packageAmount.text}
Sector                  : ${_a_sector.text}
Arr Date              : ${_a_arrCtrl.text}
Dep Date             : ${_a_depCtrl.text}
No of Seats         : ${_a_noOfSeats.text}
Class                    : ${_a_class.text}
Airlines               : ${_a_airlines.text}''';

  String _buildExtText() => '''
*EXTENSION*
Name of the Guest              : ${_e_guestName.text}
Membership No                   : ${_e_memberId.text}
Package Amount                 : ${_e_packageAmount.text}
Arrival                                  : ${_e_arrCtrl.text}
No of Room/s                      : ${_e_noOfRooms.text}
Extension Date                   : ${_e_extensionDate.text}
Early Departure                  : ${_e_earlyDeparture.text}
Extension Approved By     : ${_e_approvedBy.text}''';

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        backgroundColor: _accentColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onCopy() {
    switch (_activeSection) {
      case _Section.hotel:
        _copyToClipboard(_buildHotelText());
        break;
      case _Section.airTicket:
        _copyToClipboard(_buildAirText());
        break;
      case _Section.extension:
        _copyToClipboard(_buildExtText());
        break;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.watch(fontSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Quick Reservation',
            style: TextStyle(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) context.pop();
            else context.go('/reservationMain');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy message',
            onPressed: _onCopy,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Section selector ──────────────────────────────────────────────
          Container(
            color: _accentColor,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              children: [
                _sectionTab(_Section.hotel, Icons.hotel_rounded, 'Hotel'),
                const SizedBox(width: 8),
                _sectionTab(_Section.airTicket, Icons.flight_rounded, 'Air Ticket'),
                const SizedBox(width: 8),
                _sectionTab(_Section.extension, Icons.date_range_rounded, 'Extension'),
              ],
            ),
          ),

          // ── Form body ─────────────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _activeSection == _Section.hotel
                  ? _HotelForm(key: const ValueKey('hotel'), state: this)
                  : _activeSection == _Section.airTicket
                      ? _AirForm(key: const ValueKey('air'), state: this)
                      : _ExtForm(key: const ValueKey('ext'), state: this),
            ),
          ),
        ],
      ),

      // ── Copy FAB ──────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onCopy,
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.copy_rounded),
        label: const Text('Copy Message',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _sectionTab(_Section section, IconData icon, String label) {
    final active = _activeSection == section;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSection = section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 20,
                  color: active ? _accentColor : Colors.white),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? _accentColor : Colors.white,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _fieldDeco(String label, {IconData? icon, Color accent = const Color(0xFFE65C00)}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon != null ? Icon(icon, size: 20, color: accent) : null,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: accent, width: 1.8),
    ),
  );
}

Widget _sectionHeader(String title, Color color, IconData icon) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    ),
  );
}

Widget _dateField(
  BuildContext context,
  String label,
  TextEditingController ctrl,
  Color accent,
  VoidCallback onTap,
) {
  return TextFormField(
    controller: ctrl,
    readOnly: true,
    decoration: _fieldDeco(label, icon: Icons.calendar_today_rounded, accent: accent).copyWith(
      suffixIcon: Icon(Icons.arrow_drop_down, color: accent),
    ),
    onTap: onTap,
  );
}

Widget _rowPair(Widget left, Widget right) {
  return Row(
    children: [
      Expanded(child: left),
      const SizedBox(width: 10),
      Expanded(child: right),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HOTEL FORM
// ─────────────────────────────────────────────────────────────────────────────
class _HotelForm extends StatelessWidget {
  final _QuickReservationScreenState state;
  const _HotelForm({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    const accent = _QuickReservationScreenState._hotelColor;

    return Form(
      key: state._hotelFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          _sectionHeader('Hotel Reservation Request', accent, Icons.hotel_rounded),

          // Guest name + Member ID
          _rowPair(
            TextFormField(
              controller: state._h_guestName,
              decoration: _fieldDeco('Guest Name *', icon: Icons.person_outline, accent: accent),
              textCapitalization: TextCapitalization.words,
            ),
            TextFormField(
              controller: state._h_memberId,
              decoration: _fieldDeco('Membership No *', icon: Icons.badge_outlined, accent: accent),
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          const SizedBox(height: 12),

          // Package amount + Hotel name
          _rowPair(
            TextFormField(
              controller: state._h_packageAmount,
              decoration: _fieldDeco('Package Amount', icon: Icons.currency_rupee, accent: accent),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: state._h_hotelName,
              decoration: _fieldDeco('Hotel Name *', icon: Icons.business_rounded, accent: accent),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 12),

          // Arrival + Departure
          _rowPair(
            _dateField(context, 'Arrival Date *', state._h_arrivalCtrl, accent, () async {
              final d = await state._pickDate(context, label: 'Select Arrival Date',
                  initial: state._h_arrivalDate);
              if (d != null) {
                state._h_arrivalDate = d;
                state._h_arrivalCtrl.text = state._fmt(d);
                // reset departure if earlier
                if (state._h_departureDate != null &&
                    !state._h_departureDate!.isAfter(d)) {
                  state._h_departureDate = null;
                  state._h_departureCtrl.clear();
                }
                // ignore: invalid_use_of_protected_member
                (context as Element).markNeedsBuild();
              }
            }),
            _dateField(context, 'Departure Date *', state._h_departureCtrl, accent, () async {
              final d = await state._pickDate(context, label: 'Select Departure Date',
                  initial: state._h_departureDate,
                  minDate: state._h_arrivalDate != null
                      ? state._h_arrivalDate!.add(const Duration(days: 1))
                      : null);
              if (d != null) {
                state._h_departureDate = d;
                state._h_departureCtrl.text = state._fmt(d);
                // ignore: invalid_use_of_protected_member
                (context as Element).markNeedsBuild();
              }
            }),
          ),
          const SizedBox(height: 12),

          // Rooms + Pax
          _rowPair(
            TextFormField(
              controller: state._h_noOfRooms,
              decoration: _fieldDeco('No of Rooms', icon: Icons.door_back_door_outlined, accent: accent),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            TextFormField(
              controller: state._h_noOfPax,
              decoration: _fieldDeco('No of Pax', icon: Icons.group_outlined, accent: accent),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          const SizedBox(height: 12),

          // Room Type + Room Category
          _rowPair(
            TextFormField(
              controller: state._h_roomType,
              decoration: _fieldDeco('Room Type', icon: Icons.bed_outlined, accent: accent),
              textCapitalization: TextCapitalization.characters,
            ),
            TextFormField(
              controller: state._h_roomCategory,
              decoration: _fieldDeco('Room Category', icon: Icons.category_outlined, accent: accent),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 12),

          // ECI/LCO (radio chips)
          _LabeledCard(
            label: 'ECI / LCO Facility',
            accent: accent,
            child: _ChipSelector(
              options: const ['NA', 'ECI', 'LCO', 'ECI & LCO'],
              selected: state._h_eciLco,
              accent: accent,
              onChanged: (v) {
                state._h_eciLco = v;
                // rebuild via setState inside parent
                // We trigger it via a local stateful wrapper below
              },
            ),
          ),
          const SizedBox(height: 12),

          // Meal Plan + Payment By
          _rowPair(
            TextFormField(
              controller: state._h_mealPlan,
              decoration: _fieldDeco('Meal Plan', icon: Icons.restaurant_outlined, accent: accent),
              textCapitalization: TextCapitalization.words,
            ),
            TextFormField(
              controller: state._h_paymentBy,
              decoration: _fieldDeco('Payment By', icon: Icons.payment_outlined, accent: accent),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 12),

          // Marketing Person + Approved By
          _rowPair(
            TextFormField(
              controller: state._h_marketingPerson,
              decoration: _fieldDeco('Marketing Person', icon: Icons.support_agent_outlined, accent: accent),
              textCapitalization: TextCapitalization.words,
            ),
            TextFormField(
              controller: state._h_approvedBy,
              decoration: _fieldDeco('Approved By', icon: Icons.verified_user_outlined, accent: accent),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 12),

          // Remarks
          TextFormField(
            controller: state._h_remarks,
            decoration: _fieldDeco('Remarks', icon: Icons.notes_rounded, accent: accent),
            maxLines: 3,
            keyboardType: TextInputType.multiline,
          ),

          const SizedBox(height: 16),
          _PreviewCard(text: state._buildHotelText(), accent: accent),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AIR TICKET FORM
// ─────────────────────────────────────────────────────────────────────────────
class _AirForm extends StatelessWidget {
  final _QuickReservationScreenState state;
  const _AirForm({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    const accent = _QuickReservationScreenState._airColor;

    return Form(
      key: state._airFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          _sectionHeader('Air Ticket Request', accent, Icons.flight_rounded),

          // BM + Guest Name
          _rowPair(
            TextFormField(
              controller: state._a_memberId,
              decoration: _fieldDeco('BM No', icon: Icons.badge_outlined, accent: accent),
              textCapitalization: TextCapitalization.characters,
            ),
            TextFormField(
              controller: state._a_guestName,
              decoration: _fieldDeco('Guest Name', icon: Icons.person_outline, accent: accent),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 12),

          // Package Amount + Sector
          _rowPair(
            TextFormField(
              controller: state._a_packageAmount,
              decoration: _fieldDeco('Package Amount', icon: Icons.currency_rupee, accent: accent),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: state._a_sector,
              decoration: _fieldDeco('Sector', icon: Icons.connecting_airports_rounded, accent: accent),
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          const SizedBox(height: 12),

          // Arr + Dep dates
          _rowPair(
            _dateField(context, 'Arrival Date', state._a_arrCtrl, accent, () async {
              final d = await state._pickDate(context, label: 'Select Arrival Date',
                  initial: state._a_arrDate);
              if (d != null) {
                state._a_arrDate = d;
                state._a_arrCtrl.text = state._fmt(d);
                // ignore: invalid_use_of_protected_member
                (context as Element).markNeedsBuild();
              }
            }),
            _dateField(context, 'Departure Date', state._a_depCtrl, accent, () async {
              final d = await state._pickDate(context, label: 'Select Departure Date',
                  initial: state._a_depDate,
                  minDate: state._a_arrDate != null
                      ? state._a_arrDate!.add(const Duration(days: 1))
                      : null);
              if (d != null) {
                state._a_depDate = d;
                state._a_depCtrl.text = state._fmt(d);
                // ignore: invalid_use_of_protected_member
                (context as Element).markNeedsBuild();
              }
            }),
          ),
          const SizedBox(height: 12),

          // Seats + Class + Airlines
          _rowPair(
            TextFormField(
              controller: state._a_noOfSeats,
              decoration: _fieldDeco('No of Seats', icon: Icons.event_seat_outlined, accent: accent),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            TextFormField(
              controller: state._a_class,
              decoration: _fieldDeco('Class', icon: Icons.class_outlined, accent: accent),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: state._a_airlines,
            decoration: _fieldDeco('Airlines', icon: Icons.airplanemode_active_rounded, accent: accent),
            textCapitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 16),
          _PreviewCard(text: state._buildAirText(), accent: accent),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTENSION FORM
// ─────────────────────────────────────────────────────────────────────────────
class _ExtForm extends StatelessWidget {
  final _QuickReservationScreenState state;
  const _ExtForm({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    const accent = _QuickReservationScreenState._extColor;

    return Form(
      key: state._extFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          _sectionHeader('Extension / Early Departure', accent, Icons.date_range_rounded),

          // Guest name + Member ID
          _rowPair(
            TextFormField(
              controller: state._e_guestName,
              decoration: _fieldDeco('Guest Name', icon: Icons.person_outline, accent: accent),
              textCapitalization: TextCapitalization.words,
            ),
            TextFormField(
              controller: state._e_memberId,
              decoration: _fieldDeco('Membership No', icon: Icons.badge_outlined, accent: accent),
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          const SizedBox(height: 12),

          // Package Amount + No of Rooms
          _rowPair(
            TextFormField(
              controller: state._e_packageAmount,
              decoration: _fieldDeco('Package Amount', icon: Icons.currency_rupee, accent: accent),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: state._e_noOfRooms,
              decoration: _fieldDeco('No of Rooms', icon: Icons.door_back_door_outlined, accent: accent),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          const SizedBox(height: 12),

          // Arrival
          _dateField(context, 'Arrival Date', state._e_arrCtrl, accent, () async {
            final d = await state._pickDate(context, label: 'Select Arrival Date',
                initial: state._e_arrDate);
            if (d != null) {
              state._e_arrDate = d;
              state._e_arrCtrl.text = state._fmt(d);
              // ignore: invalid_use_of_protected_member
              (context as Element).markNeedsBuild();
            }
          }),
          const SizedBox(height: 12),

          // Extension Date + Early Departure
          _rowPair(
            TextFormField(
              controller: state._e_extensionDate,
              decoration: _fieldDeco('Extension + Days', icon: Icons.add_circle_outline, accent: accent)
                  .copyWith(hintText: '+ 1 Day'),
              keyboardType: TextInputType.text,
            ),
            TextFormField(
              controller: state._e_earlyDeparture,
              decoration: _fieldDeco('Early Departure - Days', icon: Icons.remove_circle_outline, accent: accent),
              keyboardType: TextInputType.text,
            ),
          ),
          const SizedBox(height: 12),

          // Approved By
          TextFormField(
            controller: state._e_approvedBy,
            decoration: _fieldDeco('Extension Approved By\n(Required above 3 nights)',
                icon: Icons.verified_user_outlined, accent: accent),
            textCapitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 16),
          _PreviewCard(text: state._buildExtText(), accent: accent),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip selector (ECI/LCO)
// ─────────────────────────────────────────────────────────────────────────────
class _ChipSelector extends StatefulWidget {
  final List<String> options;
  final String selected;
  final Color accent;
  final ValueChanged<String> onChanged;

  const _ChipSelector({
    required this.options,
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  @override
  State<_ChipSelector> createState() => _ChipSelectorState();
}

class _ChipSelectorState extends State<_ChipSelector> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: widget.options.map((opt) {
        final active = _selected == opt;
        return ChoiceChip(
          label: Text(opt),
          selected: active,
          selectedColor: widget.accent,
          labelStyle: TextStyle(
              color: active ? Colors.white : Colors.black87,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal),
          onSelected: (_) {
            setState(() => _selected = opt);
            widget.onChanged(opt);
          },
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Labeled card wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _LabeledCard extends StatelessWidget {
  final String label;
  final Color accent;
  final Widget child;

  const _LabeledCard({
    required this.label,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live preview card
// ─────────────────────────────────────────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  final String text;
  final Color accent;

  const _PreviewCard({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Text('Message Preview',
                  style: TextStyle(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  fontFamily: 'monospace',
                  color: Color(0xFF2C3E50))),
        ],
      ),
    );
  }
}