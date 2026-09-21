import 'dart:convert';
import 'dart:math' as math;

import 'package:ballys_reservation_app/components/bottom_sheets/member_search-new_sheet.dart';
import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/components/location_search_field.dart';
import 'package:ballys_reservation_app/data/repositories/quick_reservation_repository.dart';
import 'package:ballys_reservation_app/models/authorization_level.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/quick_reservation_provider_ballys.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Transport dropdown options — kept in step with the Quick Reservation
// transport tab.
const List<String> _kCarTypes = [
  'Normal Car',
  'SUV / Jeep',
  'Voxy',
  'Prado',
  'Benz',
  'Limousine',
  'Alphard',
];

const List<String> _kHireTypes = [
  'Airport Pickup',
  'Airport Drop',
  'Other',
];

// Airport gate route — asked only for Airport Pickup / Airport Drop hires.
const List<String> _kGateRoutes = [
  'Normal Route',
  'Silk Route',
  'Gold Route',
];

// Digit count allowed in the contact number, excluding the country code.
const int _kMinContactDigits = 9;
const int _kMaxContactDigits = 10;

const TextStyle _kInputTextStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  color: Colors.black,
);

const Color _accent = Color(0xFF2E7D32);

/// Bally's "Add Transport", opened from the + on the transport list.
///
/// Same form and the same `TransportReservation/Insert` call as the Quick
/// Reservation transport tab. A successful save pops `true` so the list can
/// reload.
class TransportAddBallysScreen extends ConsumerStatefulWidget {
  const TransportAddBallysScreen({super.key});

  @override
  ConsumerState<TransportAddBallysScreen> createState() =>
      _TransportAddBallysScreenState();
}

class _TransportAddBallysScreenState
    extends ConsumerState<TransportAddBallysScreen> with ConnectivityMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  /// Captured in [initState] rather than read through `ref` at each use: it is
  /// touched after awaits, by which point the screen may be gone.
  late final QuickReservationBallysNotifier _quickNotifier;

  QuickReservationBallysState get _quick => _quickNotifier.current;
  bool get _isLoading => _quick.isBusy;
  void _setBusy(bool busy) => _quickNotifier.setBusy(busy);
  bool get _isNumericOnlyLocation => _quick.isNumericOnlyLocation;
  List<String> get _prefixes => _quick.prefixes;
  String get _selectedPrefix => _quick.selectedPrefix;

  // ── Guest ───────────────────────────────────────────────────────────────────
  final _memberId = TextEditingController();
  final _midNumber = TextEditingController();
  final _guestName = TextEditingController();
  bool _guestCardVisible = false;

  /// Extra members travelling on the same request: they share its pickup,
  /// vehicles and dates, so they only carry who they are.
  final List<_ExtraMember> _extraMembers = [];

  // ── Transport ───────────────────────────────────────────────────────────────
  final _pickupDateCtrl = TextEditingController();
  final _pickupTimeCtrl = TextEditingController();
  final _pickupLocationCtrl = TextEditingController();
  final _dropLocationCtrl = TextEditingController();
  final _noOfVehicles = TextEditingController(text: '1');
  final _contactNumber = TextEditingController();
  final _flightNoCtrl = TextEditingController();

  Country _country = _defaultCountry();
  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;

  // One Car Type + passenger count per vehicle, resized with "No of Vehicles".
  List<String?> _carTypes = ['Normal Car'];
  List<TextEditingController> _passengerCtrls = [
    TextEditingController(text: '1'),
  ];

  String? _hireType;
  String? _gate;
  bool get _isAirportHire =>
      _hireType == 'Airport Pickup' || _hireType == 'Airport Drop';
  String _pickupPlaceId = '';
  String _dropPlaceId = '';

  AuthorizationLevel? _approver;

  @override
  void initState() {
    super.initState();
    _quickNotifier = ref.read(quickReservationBallysProvider.notifier);
    // Deferred past the first frame: these loaders write provider state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _quickNotifier.loadLocationPrefix();
      _loadAuthorizationLevels();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _memberId,
      _midNumber,
      _guestName,
      _pickupDateCtrl,
      _pickupTimeCtrl,
      _pickupLocationCtrl,
      _dropLocationCtrl,
      _noOfVehicles,
      _contactNumber,
      _flightNoCtrl,
      ..._passengerCtrls,
    ]) {
      c.dispose();
    }
    for (final row in _extraMembers) {
      row.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// A failure only empties the list — the request still saves without an
  /// approver.
  Future<void> _loadAuthorizationLevels() async {
    await _quickNotifier.loadAuthorizationLevels();
    if (!mounted) return;
    setState(() {
      if (_approver != null && !_quick.authorizationLevels.contains(_approver)) {
        _approver = null;
      }
    });
  }

  static Country _defaultCountry() => Country(
        phoneCode: '94',
        countryCode: 'LK',
        e164Sc: 0,
        geographic: true,
        level: 1,
        name: 'Sri Lanka',
        example: '712345678',
        displayName: 'Sri Lanka (LK) [+94]',
        displayNameNoCountryCode: 'Sri Lanka (LK)',
        e164Key: '',
      );

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country country) => setState(() => _country = country),
      countryListTheme: CountryListThemeData(
        borderRadius: BorderRadius.circular(8),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  /// Keeps one Car Type + Passengers pair per vehicle. Growing appends
  /// defaults; shrinking trims from the end and disposes what it drops.
  void _syncVehicleDetailsWithCount() {
    final n = int.tryParse(_noOfVehicles.text) ?? 1;
    if (n == _carTypes.length) return;
    setState(() {
      if (n > _carTypes.length) {
        _carTypes.addAll(List<String?>.filled(n - _carTypes.length, 'Normal Car'));
        _passengerCtrls.addAll(List.generate(
          n - _passengerCtrls.length,
          (_) => TextEditingController(text: '1'),
        ));
      } else {
        _carTypes.removeRange(n, _carTypes.length);
        for (final c in _passengerCtrls.sublist(n)) {
          c.dispose();
        }
        _passengerCtrls.removeRange(n, _passengerCtrls.length);
      }
    });
  }

  // ── Guest search ────────────────────────────────────────────────────────────

  void _updateMemberIdFields(String fullMemberId) {
    if (fullMemberId.isEmpty) return;
    final (prefix, numberPart) = _quickNotifier.splitMemberId(fullMemberId);
    if (!_isNumericOnlyLocation) _quickNotifier.selectPrefix(prefix);
    setState(() {
      _midNumber.text = numberPart;
      _memberId.text = fullMemberId;
    });
  }

  Future<void> _openGuestSearch(int iid) async {
    final term = iid == 8002 ? _memberId.text : _guestName.text;
    if (term.length < 3) {
      _showSearchSheet([], term, iid);
      return;
    }
    _setBusy(true);
    final guests = await _quickNotifier.searchGuest(iid, term);
    _setBusy(false);
    if (!mounted) return;
    _showSearchSheet(guests, term, iid);
  }

  void _showSearchSheet(List<GuestSearchResponse> guests, String term, int iid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => MemberNewSearchBottomSheet(
        guests: guests,
        initialSearchTerm: term,
        searchIid: iid,
        onSearch: (newTerm, newIid) async {
          if (newTerm.length < 3) return;
          final r = await _quickNotifier.searchGuest(newIid, newTerm);
          if (!mounted) return;
          Navigator.of(ctx).pop();
          _showSearchSheet(r, newTerm, newIid);
        },
        onGuestSelected: (guest) async {
          _updateMemberIdFields(guest.mid);
          setState(() => _guestName.text = guest.mName);
          final details = await _quickNotifier.fetchGuestDetails(guest.mid);
          if (!mounted) return;
          _publishGuest(details, mid: guest.mid, name: guest.mName);
          setState(() => _guestCardVisible = true);
        },
      ),
    );
  }

  /// Member search for an extra-member row; the pick comes back by row.
  Future<void> _openExtraMemberSearch(int index, int iid) async {
    FocusScope.of(context).unfocus();

    final row = _extraMembers[index];
    final term = iid == 8002
        ? row.fullMid(numericOnly: _isNumericOnlyLocation)
        : row.nameController.text.trim();

    void showSheet(List<GuestSearchResponse> guests) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => MemberNewSearchBottomSheet(
          guests: guests,
          initialSearchTerm: term,
          searchIid: iid,
          onSearch: (newTerm, newIid) async {
            if (newTerm.length < 3) return;
            final r = await _quickNotifier.searchGuest(newIid, newTerm);
            if (!mounted) return;
            Navigator.of(ctx).pop();
            showSheet(r);
          },
          onGuestSelected: (guest) {
            final (prefix, number) = _quickNotifier.splitMemberId(guest.mid);
            setState(() {
              row.prefix = prefix;
              row.midNumberController.text = number;
              row.nameController.text = guest.mName;
            });
          },
        ),
      );
    }

    if (term.length < 3) {
      showSheet([]);
      return;
    }

    _setBusy(true);
    final guests = await _quickNotifier.searchGuest(iid, term);
    _setBusy(false);
    if (!mounted) return;
    showSheet(guests);
  }

  /// Puts the picked member on [selectedGuestProvider] so the profile button
  /// has something to open.
  void _publishGuest(GuestSearchResponse? g,
      {required String mid, required String name}) {
    ref.read(selectedGuestProvider.notifier).setSelectedGuest(
          Guest(
            mid: g?.mid ?? mid,
            memberName: g?.mName ?? name,
            country: '',
            lastVisitDate: g?.lvd?.toString() ?? '',
            age: 0,
            gRating: g?.gRating ?? '',
            mGroup: '',
            gName: g?.gName ?? '',
            memImage2: g?.memImage2,
          ),
        );
  }

  Future<void> _navigateToProfile() async {
    final mid = _memberId.text;
    if (mid.isEmpty) return;
    final currentGuest = ref.read(selectedGuestProvider);
    if (currentGuest == null || currentGuest.mid != mid) {
      _setBusy(true);
      final guest = await _quickNotifier.fetchGuestDetails(mid);
      _setBusy(false);
      _publishGuest(guest, mid: mid, name: _guestName.text);
    }
    if (mounted) context.push('/home/profile');
  }

  // ── Extra members ───────────────────────────────────────────────────────────

  void _addExtraMember() {
    FocusScope.of(context).unfocus();
    setState(() {
      _extraMembers.add(
        _ExtraMember(prefix: _isNumericOnlyLocation ? '' : _selectedPrefix),
      );
    });
  }

  void _removeExtraMember(int index) {
    setState(() => _extraMembers.removeAt(index).dispose());
  }

  /// Rejects half-filled and duplicate rows. A blank row is skipped.
  bool _validateExtraMembers() {
    final primaryMid = _memberId.text.trim();
    final seen = <String>{if (primaryMid.isNotEmpty) primaryMid};

    for (var i = 0; i < _extraMembers.length; i++) {
      final row = _extraMembers[i];
      final mid = row.fullMid(numericOnly: _isNumericOnlyLocation);
      final name = row.nameController.text.trim();

      if (mid.isEmpty && name.isEmpty) continue;
      if (mid.isEmpty || name.isEmpty) {
        _showSaveErrorSnack(
            'Guest ${i + 2}: both Membership No and Guest Name are required');
        return false;
      }
      if (!seen.add(mid)) {
        _showSaveErrorSnack('$mid is already added to this reservation');
        return false;
      }
    }
    return true;
  }

  List<Map<String, dynamic>> _captureExtraMembers() {
    final out = <Map<String, dynamic>>[];
    for (final row in _extraMembers) {
      final mid = row.fullMid(numericOnly: _isNumericOnlyLocation);
      final name = row.nameController.text.trim();
      if (mid.isEmpty && name.isEmpty) continue;
      out.add({
        'memberId': mid,
        'guestName': name,
        'packageAmount': '',
        'sharedPackage': false,
        'hasFamilyMembers': false,
      });
    }
    return out;
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// The form as the member map [QuickReservationRepository.buildTransportBody]
  /// expects — the same shape the Quick Reservation transport tab sends.
  Map<String, dynamic> _captureTransportMember() {
    return {
      'guestName': _guestName.text,
      'memberId': _memberId.text,
      'packageAmount': '',
      'sharedPackage': false,
      'extraMembers': _captureExtraMembers(),
      'pickupDate': _pickupDateCtrl.text,
      'pickupTime': _pickupTimeCtrl.text,
      'hireType': _hireType ?? '',
      'gate': _isAirportHire ? (_gate ?? '') : '',
      'flightNo': _isAirportHire ? _flightNoCtrl.text.trim() : '',
      'pickupLocation': _pickupLocationCtrl.text,
      'dropLocation': _dropLocationCtrl.text,
      'vehicleDetails': List.generate(_carTypes.length, (i) {
        return {
          'carType': _carTypes[i] ?? '',
          'noOfPassengers': _passengerCtrls[i].text,
        };
      }),
      'contactNumber': _contactNumber.text.trim().isEmpty
          ? ''
          : '+${_country.phoneCode}${_contactNumber.text.trim()}',
      'silkRoute': 'No',
      'airportPickup': 'No',
      'pickupDateObj': _pickupDate,
      'pickupTimeObj': _pickupTime,
      'pickupPlaceId': _pickupPlaceId,
      'dropPlaceId': _dropPlaceId,
    };
  }

  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_validateExtraMembers()) return;

    final result = await _quickNotifier.saveTransportReservation(
      members: [_captureTransportMember()],
      approver: _approver,
      log: _logLong,
    );
    _handleSaveResult(result);
  }

  void _handleSaveResult(QuickReservationResult result) {
    if (!mounted) return;
    if (!result.success) {
      _showSaveErrorSnack(
          result.message ?? 'Failed to save transport reservation');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
              result.message ?? 'Transport reservation saved successfully'),
        ),
      ]),
      backgroundColor: Colors.green.shade700,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
    context.pop(true);
  }

  void _showSaveErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // debugPrint truncates long lines, so emit the payload in chunks.
  void _logLong(String label, Object? payload) {
    final text = const JsonEncoder.withIndent('  ').convert(payload);
    debugPrint('===== $label =====');
    for (final line in text.split('\n')) {
      for (var i = 0; i < line.length; i += 800) {
        debugPrint(line.substring(i, math.min(i + 800, line.length)));
      }
    }
    debugPrint('===== end $label =====');
  }

  // ── Copy ────────────────────────────────────────────────────────────────────

  String _buildTransportText() {
    final m = _captureTransportMember();
    final vehicles = (m['vehicleDetails'] as List).cast<Map>();
    final buf = StringBuffer()
      ..writeln('*TRANSPORT REQUEST*')
      ..writeln('Membership No      : ${m['memberId']}')
      ..writeln('Guest Name         : ${m['guestName']}')
      ..writeln('Pickup Date        : ${m['pickupDate']}')
      ..writeln('Pickup Time        : ${m['pickupTime']}');
    for (int i = 0; i < vehicles.length; i++) {
      final prefix = vehicles.length > 1 ? 'Vehicle ${i + 1} ' : '';
      final carTypeLabel = '${prefix}Car Type'.padRight(19);
      final passengersLabel = '${prefix}Passengers'.padRight(19);
      buf
        ..writeln('$carTypeLabel: ${vehicles[i]['carType']}')
        ..writeln('$passengersLabel: ${vehicles[i]['noOfPassengers']}');
    }
    buf.writeln('Hire Type          : ${m['hireType']}');
    if ((m['gate'] as String).isNotEmpty) {
      buf.writeln('Gate               : ${m['gate']}');
    }
    if ((m['flightNo'] as String).isNotEmpty) {
      buf.writeln('Flight Number      : ${m['flightNo']}');
    }
    buf
      ..writeln('Pickup Location    : ${m['pickupLocation']}')
      ..writeln('Drop Location      : ${m['dropLocation']}')
      ..writeln('No of Vehicles     : ${vehicles.length}')
      ..write('Contact Number     : ${m['contactNumber']}');
    final extras = (m['extraMembers'] as List).cast<Map<String, dynamic>>();
    for (int i = 0; i < extras.length; i++) {
      buf
        ..write('\n*Guest ${i + 2}*')
        ..write('\nMembership No      : ${extras[i]['memberId']}')
        ..write('\nGuest Name         : ${extras[i]['guestName']}');
    }
    return buf.toString();
  }

  void _onCopy() {
    Clipboard.setData(ClipboardData(text: _buildTransportText()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        backgroundColor: _accent,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Pickers ─────────────────────────────────────────────────────────────────

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${h12.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
  }

  Future<DateTime?> _pickDate({
    required String label,
    DateTime? initial,
    DateTime? minDate,
  }) async {
    DateTime picked = initial ?? minDate ?? DateTime.now();
    // The picker asserts its initial value sits inside the allowed range.
    if (minDate != null && picked.isBefore(minDate)) picked = minDate;
    DateTime? result;
    await _showPickerSheet(
      label: label,
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: picked,
        minimumDate: minDate ?? DateTime(2000),
        maximumDate: DateTime(2101),
        onDateTimeChanged: (d) => picked = d,
      ),
      onConfirm: (sheetContext) {
        result = picked;
        return true;
      },
    );
    return result;
  }

  Future<TimeOfDay?> _pickTime({
    required String label,
    TimeOfDay? initial,
    TimeOfDay? minTime,
  }) async {
    final now = DateTime.now();
    DateTime picked = DateTime(now.year, now.month, now.day,
        initial?.hour ?? now.hour, initial?.minute ?? now.minute);
    // Cupertino's time mode ignores minimumDate, so clamp the initial value
    // forward and enforce the minimum again on Confirm.
    int minutesOf(int h, int m) => h * 60 + m;
    if (minTime != null &&
        minutesOf(picked.hour, picked.minute) <
            minutesOf(minTime.hour, minTime.minute)) {
      picked =
          DateTime(now.year, now.month, now.day, minTime.hour, minTime.minute);
    }
    TimeOfDay? result;
    await _showPickerSheet(
      label: label,
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: picked,
        use24hFormat: false,
        onDateTimeChanged: (d) => picked = d,
      ),
      onConfirm: (sheetContext) {
        if (minTime != null &&
            minutesOf(picked.hour, picked.minute) <
                minutesOf(minTime.hour, minTime.minute)) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            const SnackBar(content: Text('Pickup time cannot be in the past')),
          );
          return false;
        }
        result = TimeOfDay(hour: picked.hour, minute: picked.minute);
        return true;
      },
    );
    return result;
  }

  /// Bottom sheet around a Cupertino picker. [onConfirm] returns false to keep
  /// the sheet open.
  Future<void> _showPickerSheet({
    required String label,
    required Widget picker,
    required bool Function(BuildContext sheetContext) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          SizedBox(height: 220, child: picker),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    if (onConfirm(sheetContext)) Navigator.pop(sheetContext);
                  },
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(fontSettingsProvider);
    // Prefix rules, approvers and the in-flight flag live on the provider.
    ref.watch(quickReservationBallysProvider);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Add Transport',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/reservationMain/transport-ballys');
                }
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
          body: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.copyWith(
                    titleMedium: _kInputTextStyle,
                  ),
            ),
            child: Form(
              key: _formKey,
              // A Column (not a lazy ListView) so every field stays mounted and
              // Form.validate() reaches all of them.
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._guestSection(context),
                    const SizedBox(height: 16),
                    ..._scheduleSection(context),
                    ..._vehicleSection(),
                    ..._hireSection(),
                    _locationsCard(),
                    const SizedBox(height: 12),
                    _contactRow(),
                    const SizedBox(height: 12),
                    _approverDropdown(
                      value: _approver,
                      levels: _quick.authorizationLevels,
                      loading: _quick.authorizationLevelsLoading,
                      onChanged: (v) => setState(() => _approver = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.save_alt),
                        label: const Text(
                          'Confirm Reservation',
                          style: TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: const Color.fromARGB(120, 0, 0, 0),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  List<Widget> _guestSection(BuildContext context) {
    return [
      _guestIdentityRow(),
      const SizedBox(height: 12),
      if (_guestCardVisible &&
          _memberId.text.isNotEmpty &&
          _guestName.text.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GuestDisplayCardSpecialGiftview(
            memberIdText: _memberId.text,
            memberNameText: _guestName.text,
            showCard: true,
            showLastVisitDate: true,
          ),
        ),
      for (var i = 0; i < _extraMembers.length; i++) _extraMemberCard(i),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _addExtraMember,
          style: OutlinedButton.styleFrom(
            foregroundColor: _accent,
            side: const BorderSide(color: _accent, width: 1.6),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.group_add, size: 18),
          label: const Text(
            'Add More Guest',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ];
  }

  Widget _guestIdentityRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _midNumber,
                style: _kInputTextStyle,
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Membership No is required'
                    : null,
                decoration: _fieldDeco('Membership No *').copyWith(
                  prefixIcon: _isNumericOnlyLocation
                      ? null
                      : _prefixDropdown(
                          value: _selectedPrefix,
                          onChanged: (v) {
                            _quickNotifier.selectPrefix(v);
                            setState(() =>
                                _memberId.text = '$v${_midNumber.text}');
                          },
                        ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: _accent),
                    onPressed: () {
                      _memberId.text = _isNumericOnlyLocation
                          ? _midNumber.text
                          : '$_selectedPrefix${_midNumber.text}';
                      _openGuestSearch(8002);
                    },
                  ),
                ),
                onChanged: (value) {
                  _guestName.clear();
                  _memberId.text =
                      _isNumericOnlyLocation ? value : '$_selectedPrefix$value';
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _guestCardVisible ? _navigateToProfile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _guestCardVisible
                    ? const Color.fromARGB(255, 0, 0, 0)
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              ),
              child: const Icon(Icons.person_search, size: 25),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _guestName,
          style: _kInputTextStyle,
          decoration:
              _fieldDeco('Guest Name', icon: Icons.person_outline).copyWith(
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, color: _accent),
              onPressed: () => _openGuestSearch(8003),
            ),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _midNumber.clear(),
        ),
      ],
    );
  }

  Widget _prefixDropdown({
    required String? value,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          style: _kInputTextStyle,
          items: _prefixes
              .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p, style: _kInputTextStyle),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _extraMemberCard(int index) {
    final row = _extraMembers[index];
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _accent.withOpacity(0.35)),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  child: Text('${index + 2}',
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guest ${index + 2} — Same Request',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2430),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _removeExtraMember(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: row.midNumberController,
              style: _kInputTextStyle,
              keyboardType: TextInputType.number,
              decoration: _fieldDeco('Membership No').copyWith(
                prefixIcon: _isNumericOnlyLocation
                    ? null
                    : _prefixDropdown(
                        value: _prefixes.contains(row.prefix)
                            ? row.prefix
                            : (_prefixes.isEmpty ? null : _prefixes.first),
                        onChanged: (v) => setState(() => row.prefix = v),
                      ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: _accent),
                  onPressed: () => _openExtraMemberSearch(index, 8002),
                ),
              ),
              // The name belongs to the old ID — clear it so a stale pairing
              // is never submitted.
              onChanged: (_) => setState(() => row.nameController.clear()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: row.nameController,
              style: _kInputTextStyle,
              decoration: _fieldDeco('Guest Name').copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: _accent),
                  onPressed: () => _openExtraMemberSearch(index, 8003),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _scheduleSection(BuildContext context) {
    return [
      TextFormField(
        key: ValueKey('pickupDate|${_pickupDateCtrl.text}'),
        controller: _pickupDateCtrl,
        readOnly: true,
        style: _kInputTextStyle,
        decoration: _fieldDeco(
          'Pickup/ Drop Date *',
          icon: Icons.calendar_today_rounded,
        ).copyWith(
          suffixIcon: const Icon(Icons.arrow_drop_down, color: _accent),
        ),
        onTap: () async {
          final now = DateTime.now();
          final d = await _pickDate(
            label: 'Select Pickup/ Drop Date',
            initial: _pickupDate,
            minDate: DateTime(now.year, now.month, now.day),
          );
          if (d != null) {
            setState(() {
              _pickupDate = d;
              _pickupDateCtrl.text = _fmt(d);
            });
          }
        },
        validator: (value) => (value == null || value.trim().isEmpty)
            ? 'Pickup/ Drop Date is required'
            : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _pickupTimeCtrl,
        readOnly: true,
        style: _kInputTextStyle,
        decoration: _fieldDeco(
          'Pickup/ Drop Time *',
          icon: Icons.access_time_rounded,
        ).copyWith(
          suffixIcon: const Icon(Icons.arrow_drop_down, color: _accent),
        ),
        onTap: () async {
          // Past times are only blocked when the pickup is today.
          final now = DateTime.now();
          final pickupDate = _pickupDate;
          final isToday = pickupDate == null ||
              (pickupDate.year == now.year &&
                  pickupDate.month == now.month &&
                  pickupDate.day == now.day);
          final t = await _pickTime(
            label: 'Select Pickup/ Drop Time',
            initial: _pickupTime,
            minTime:
                isToday ? TimeOfDay(hour: now.hour, minute: now.minute) : null,
          );
          if (t != null) {
            setState(() {
              _pickupTime = t;
              _pickupTimeCtrl.text = _fmtTime(t);
            });
          }
        },
        validator: (value) => (value == null || value.trim().isEmpty)
            ? 'Pickup/ Drop Time is required'
            : null,
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _vehicleSection() {
    return [
      // Vehicle count comes before Car Type: bumping it grows the Car Type +
      // Passengers pairs below to one per vehicle.
      _StepperField(
        controller: _noOfVehicles,
        label: 'No of Vehicles',
        icon: Icons.local_taxi_outlined,
        onChanged: _syncVehicleDetailsWithCount,
      ),
      const SizedBox(height: 12),
      for (int i = 0; i < _carTypes.length; i++) ...[
        if (_carTypes.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Vehicle ${i + 1}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _accent,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _carTypes[i],
                style: _kInputTextStyle,
                isExpanded: true,
                decoration: _fieldDeco('Car Type *'),
                items: _kCarTypes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _carTypes[i] = v),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Car Type is required'
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StepperField(
                controller: _passengerCtrls[i],
                label: 'Passengers',
                icon: Icons.group_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> _hireSection() {
    return [
      DropdownButtonFormField<String>(
        value: _hireType,
        style: _kInputTextStyle,
        isExpanded: true,
        decoration: _fieldDeco('Hire Type *', icon: Icons.assignment_outlined),
        items: _kHireTypes
            .map((h) => DropdownMenuItem(value: h, child: Text(h)))
            .toList(),
        onChanged: (v) => setState(() => _hireType = v),
        validator: (value) => (value == null || value.trim().isEmpty)
            ? 'Hire Type is required'
            : null,
      ),
      const SizedBox(height: 12),
      // Gate + flight number, airport hires only.
      if (_isAirportHire) ...[
        DropdownButtonFormField<String>(
          value: _gate,
          style: _kInputTextStyle,
          isExpanded: true,
          decoration: _fieldDeco('Gate *', icon: Icons.meeting_room_outlined),
          items: _kGateRoutes
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _gate = v),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Gate is required'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _flightNoCtrl,
          style: _kInputTextStyle,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDeco('Flight Number *', icon: Icons.flight_rounded),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Flight Number is required'
              : null,
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _locationsCard() {
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
          const Text(
            'Locations',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LocationSearchField(
            controller: _pickupLocationCtrl,
            textStyle: _kInputTextStyle,
            accent: _accent,
            sheetTitle: 'Search Pickup Location',
            decoration: _fieldDeco(
              'Pickup Location *',
              icon: Icons.my_location_rounded,
            ),
            onSelected: (description, placeId) => setState(() {
              _pickupLocationCtrl.text = description;
              _pickupPlaceId = placeId;
            }),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Pickup Location is required'
                : null,
          ),
          const SizedBox(height: 10),
          LocationSearchField(
            controller: _dropLocationCtrl,
            textStyle: _kInputTextStyle,
            accent: _accent,
            sheetTitle: 'Search Drop Location',
            decoration: _fieldDeco(
              'Drop Location *',
              icon: Icons.place_rounded,
            ),
            onSelected: (description, placeId) => setState(() {
              _dropLocationCtrl.text = description;
              _dropPlaceId = placeId;
            }),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Drop Location is required'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _contactRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _showCountryPicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_country.flagEmoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  '+${_country.phoneCode}',
                  style: _kInputTextStyle.copyWith(fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.arrow_drop_down, color: _accent, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _contactNumber,
            style: _kInputTextStyle,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_kMaxContactDigits),
            ],
            decoration:
                _fieldDeco('Contact Number *', icon: Icons.phone_rounded),
            validator: (value) {
              final digits = (value ?? '').trim();
              if (digits.isEmpty) return 'Contact Number is required';
              if (digits.length < _kMinContactDigits) {
                return 'Enter at least $_kMinContactDigits digits';
              }
              if (digits.length > _kMaxContactDigits) {
                return 'Enter no more than $_kMaxContactDigits digits';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}

// ── Shared form pieces ────────────────────────────────────────────────────────

Widget _approverDropdown({
  required AuthorizationLevel? value,
  required List<AuthorizationLevel> levels,
  required bool loading,
  required ValueChanged<AuthorizationLevel?> onChanged,
}) {
  return InputDecorator(
    isEmpty: value == null,
    decoration: _fieldDeco(
      'Request Approval From',
      icon: Icons.verified_user_outlined,
    ).copyWith(
      suffixIcon: loading
          ? const Padding(
              padding: EdgeInsets.all(14.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : (value != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear',
                  onPressed: () => onChanged(null),
                )
              : null),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<AuthorizationLevel>(
        value: value,
        isExpanded: true,
        style: _kInputTextStyle,
        selectedItemBuilder: (context) => levels
            .map(
              (level) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  level.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _kInputTextStyle,
                ),
              ),
            )
            .toList(),
        items: levels
            .map(
              (level) => DropdownMenuItem<AuthorizationLevel>(
                value: level,
                child: Text(
                  level.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: levels.isEmpty ? null : onChanged,
      ),
    ),
  );
}

InputDecoration _fieldDeco(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    ),
    floatingLabelStyle: const TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 17,
    ),
    hintStyle: const TextStyle(
      color: Colors.black87,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    ),
    prefixIcon: icon != null ? Icon(icon, size: 20, color: _accent) : null,
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
      borderSide: const BorderSide(color: _accent, width: 1.8),
    ),
  );
}

/// One extra guest on the request.
class _ExtraMember {
  final TextEditingController midNumberController;
  final TextEditingController nameController;
  String prefix;

  _ExtraMember({this.prefix = 'BM'})
      : midNumberController = TextEditingController(),
        nameController = TextEditingController();

  /// Prefixed everywhere except the numeric-only locations.
  String fullMid({required bool numericOnly}) {
    final number = midNumberController.text.trim();
    if (number.isEmpty) return '';
    return numericOnly ? number : '$prefix$number';
  }

  void dispose() {
    midNumberController.dispose();
    nameController.dispose();
  }
}

/// − / + counter used for vehicles and passengers.
class _StepperField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  static const int min = 1;
  static const int max = 99;

  /// Called after the value changes, so the parent can react.
  final VoidCallback? onChanged;

  const _StepperField({
    required this.controller,
    required this.label,
    required this.icon,
    this.onChanged,
  });

  int get _value => int.tryParse(controller.text) ?? min;

  void _change(int delta, VoidCallback rebuild) {
    controller.text = (_value + delta).clamp(min, max).toString();
    rebuild();
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: _accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StepButton(
                    icon: Icons.remove,
                    enabled: _value > min,
                    onTap: () => _change(-1, () => setState(() {})),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        controller.text,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    enabled: _value < max,
                    onTap: () => _change(1, () => setState(() {})),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? _accent.withOpacity(0.1) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? _accent : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
