import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dropdown_search/dropdown_search.dart';

import 'package:ballys_reservation_app/components/bottom_sheets/member_search-new_sheet.dart';
import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/repositories/hotel_repository.dart';
import 'package:ballys_reservation_app/data/repositories/airport_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/airport_search_response.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/hotels_provider.dart';
import 'package:ballys_reservation_app/providers/airports_provider.dart';
import 'package:ballys_reservation_app/providers/new_reservation_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

// ─── Section enum ─────────────────────────────────────────────────────────────
enum _Section { hotel, airTicket, extension }

// ─── Shared text styles ───────────────────────────────────────────────────────
const TextStyle kInputTextStyle = TextStyle(
  fontSize: 16.5,
  fontWeight: FontWeight.w600,
  color: Colors.black,
);

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
  final _airFormKey   = GlobalKey<FormState>();
  final _extFormKey   = GlobalKey<FormState>();

  bool _isLoading = false;

  // ── Location-aware MID ──────────────────────────────────────────────────────
  bool         _isNumericOnlyLocation = false;
  List<String> _prefixes              = ["BM", "BL", "BN"];
  String       _selectedPrefix        = "BM";

  // ── SHARED guest fields ─────────────────────────────────────────────────────
  final _sharedMemberId   = TextEditingController(); // full MID e.g. BM12345
  final _sharedMidNumber  = TextEditingController(); // number portion only
  final _sharedGuestName  = TextEditingController();
  bool  _sharedGuestCardVisible = false;

  // ── HOTEL fields ────────────────────────────────────────────────────────────
  final _h_packageAmount   = TextEditingController();
  final _h_noOfRooms       = TextEditingController(text: '1');
  final _h_noOfPax         = TextEditingController(text: '1');
  final _h_mealPlan        = TextEditingController();
  final _h_paymentBy       = TextEditingController();
  final _h_remarks         = TextEditingController();
  final _h_marketingPerson = TextEditingController();
  final _h_approvedBy      = TextEditingController();
  final _h_arrivalCtrl     = TextEditingController();
  final _h_departureCtrl   = TextEditingController();

  DateTime? _h_arrivalDate;
  DateTime? _h_departureDate;
  String    _h_eciLco = 'NA';

  // Hotel / Room selections
  Map<String, dynamic>? _selectedHotel;
  String? _selectedHotelName;
  double? _selectedHotelId;

  Map<String, dynamic>? _selectedRoomCategory;
  int?    _selectedRoomCategoryId;
  String? _selectedRoomCategoryName;

  Map<String, dynamic>? _selectedRoomType;
  int?    _selectedRoomTypeId;
  String? _selectedRoomTypeName;

  List<Map<String, dynamic>> _roomCategories = [];
  List<Map<String, dynamic>> _roomTypes      = [];

  Key _hotelDropdownKey        = UniqueKey();
  Key _roomCategoryDropdownKey = UniqueKey();
  Key _roomTypeDropdownKey     = UniqueKey();

  // ── AIR TICKET fields ───────────────────────────────────────────────────────
  final _a_packageAmount = TextEditingController();
  final _a_noOfSeats     = TextEditingController(text: '1');
  final _a_class         = TextEditingController();
  final _a_airlines      = TextEditingController();
  final _a_arrCtrl       = TextEditingController();
  final _a_depCtrl       = TextEditingController();

  DateTime? _a_arrDate;
  DateTime? _a_depDate;

  Airport? _a_fromAirport;
  Airport? _a_toAirport;
  Airport? _a_returnFromAirport;
  Airport? _a_returnToAirport;
  bool     _a_isRoundTrip = false;

  Key _a_fromAirportKey       = UniqueKey();
  Key _a_toAirportKey         = UniqueKey();
  Key _a_returnFromAirportKey = UniqueKey();
  Key _a_returnToAirportKey   = UniqueKey();

  // ── EXTENSION fields ────────────────────────────────────────────────────────
  final _e_packageAmount  = TextEditingController();
  final _e_noOfRooms      = TextEditingController(text: '1');
  final _e_extensionDate  = TextEditingController();
  final _e_earlyDeparture = TextEditingController();
  final _e_approvedBy     = TextEditingController();
  final _e_arrCtrl        = TextEditingController();
  final _e_depCtrl        = TextEditingController();
  DateTime? _e_arrDate;
  DateTime? _e_depDate;
  // ── Colors ──────────────────────────────────────────────────────────────────
  static const _hotelColor = Color(0xFFE65C00);
  static const _airColor   = Color(0xFF0277BD);
  static const _extColor   = Color(0xFF2E7D32);

  Color get _accentColor {
    switch (_activeSection) {
      case _Section.hotel:     return _hotelColor;
      case _Section.airTicket: return _airColor;
      case _Section.extension: return _extColor;
    }
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadHotels();
    _loadAirports();
    _loadLocationPrefix();
  }

  @override
  void dispose() {
    for (final c in [
      _sharedMemberId, _sharedMidNumber, _sharedGuestName,
      _h_packageAmount, _h_noOfRooms, _h_noOfPax,
      _h_mealPlan, _h_paymentBy, _h_remarks, _h_marketingPerson, _h_approvedBy,
      _h_arrivalCtrl, _h_departureCtrl,
      _a_packageAmount, _a_noOfSeats, _a_class,
      _a_airlines, _a_arrCtrl, _a_depCtrl,
      _e_packageAmount, _e_noOfRooms,
      _e_extensionDate, _e_earlyDeparture, _e_approvedBy, _e_arrCtrl,_e_depCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Location prefix loader ───────────────────────────────────────────────────
Future<void> _loadLocationPrefix() async {
  final location = await StorageUtil.getCurrentLocation();
  if (location == null) return;

  final code      = location.code.split('_').first;
  final isNumeric = code == "BELLAGIO";

  // Only rebuild if something actually changed
  if (isNumeric == _isNumericOnlyLocation) return;

  setState(() {
    _isNumericOnlyLocation = isNumeric;
    _prefixes              = isNumeric ? [] : ["BM", "BL", "BN"];
    _selectedPrefix        = isNumeric ? "" : "BM";
  });
}

  // ── MID field sync ───────────────────────────────────────────────────────────
  /// Splits a full MID (e.g. "BM12345") into prefix + number and updates
  /// both controllers, mirroring NewReservationScreen behaviour.
  void _updateMemberIdFields(String fullMemberId) {
    if (fullMemberId.isEmpty) return;

    if (_isNumericOnlyLocation) {
      setState(() {
        _sharedMidNumber.text = fullMemberId;
        _sharedMemberId.text  = fullMemberId;
      });
      return;
    }

    String prefix     = 'BM';
    String numberPart = fullMemberId;

    if (fullMemberId.startsWith('BM')) {
      prefix     = 'BM';
      numberPart = fullMemberId.substring(2);
    } else if (fullMemberId.startsWith('BL')) {
      prefix     = 'BL';
      numberPart = fullMemberId.substring(2);
    } else if (fullMemberId.startsWith('BN')) {
      prefix     = 'BN';
      numberPart = fullMemberId.substring(2);
    }

    setState(() {
      _selectedPrefix       = prefix;
      _sharedMidNumber.text = numberPart;
      _sharedMemberId.text  = fullMemberId;
    });
  }

  // ── API loaders ─────────────────────────────────────────────────────────────
  Future<void> _loadHotels() async {
    final hotels = ref.read(hotelsProvider);
    if (hotels.isEmpty) {
      await ref.read(hotelsProvider.notifier).getAllHotels();
    }
  }

Future<void> _loadAirports() async {
  try {
    final airports = ref.read(airportsProvider);
    if (airports.isEmpty) {
      await ref.read(airportsProvider.notifier).getAllAirports();
    }
  } catch (_) {
    // fail silently — airports load in background
  }
}

  Future<void> _loadRoomCategories(double hotelId) async {
    try {
      final repo   = HotelRepository(ApiService(const FlutterSecureStorage()));
      final result = await repo.getSelectedHotelRoomCategories(hotelId);
      setState(() {
        _roomCategories           = result.map((c) => c.toJson()).toList();
        _selectedRoomCategory     = null;
        _selectedRoomCategoryId   = null;
        _selectedRoomCategoryName = null;
        _selectedRoomType         = null;
        _selectedRoomTypeId       = null;
        _selectedRoomTypeName     = null;
        _roomTypes                = [];
        _roomCategoryDropdownKey  = UniqueKey();
        _roomTypeDropdownKey      = UniqueKey();
      });
    } catch (_) {
      setState(() => _roomCategories = []);
    }
  }

  Future<void> _loadRoomTypes(double hotelId, int categoryId) async {
    try {
      final repo   = HotelRepository(ApiService(const FlutterSecureStorage()));
      final result = await repo.getSelectedHotelCategoryRoomTypes(hotelId, categoryId);
      setState(() {
        _roomTypes            = result.map((t) => t.toJson()).toList();
        _selectedRoomType     = null;
        _selectedRoomTypeId   = null;
        _selectedRoomTypeName = null;
        _roomTypeDropdownKey  = UniqueKey();
      });
    } catch (_) {
      setState(() => _roomTypes = []);
    }
  }

  // ── Guest search ─────────────────────────────────────────────────────────────
  Future<void> _openGuestSearch({
    required int iid,
    required VoidCallback onCardVisible,
  }) async {
    final repo = GuestRepository(ApiService(const FlutterSecureStorage()));
    final term = iid == 8002 ? _sharedMemberId.text : _sharedGuestName.text;

    if (term.length < 3) {
      _showSearchSheet([], term, iid, onCardVisible);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final guests = await repo.searchGuest(iid, term);
      setState(() => _isLoading = false);
      _showSearchSheet(guests, term, iid, onCardVisible);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }
/// Fetches full guest data first, THEN shows the card.
/// The card will not appear until image/rating/lastVisit are ready.
Future<void> _fetchAndSetGuest({
  required String mid,
  required String name,
  required VoidCallback onReady,
}) async {
  try {
    final repo   = GuestRepository(ApiService(const FlutterSecureStorage()));
    final guests = await repo.searchGuest(9021, mid);

    if (!mounted) return;

    if (guests.isNotEmpty) {
      final g = guests.first;
      ref.read(selectedGuestProvider.notifier).setSelectedGuest(
        Guest(
          mid:           g.mid             ?? mid,
          memberName:    g.mName           ?? name,
          country:       '',
          lastVisitDate: g.lvd?.toString() ?? '',
        
          age:           0,
          gRating:       g.gRating         ?? '',
          mGroup:        '',
          gName:         g.gName           ?? '',
          memImage2:     g.memImage2,
        ),
      );
    } else {
      // No result — set bare guest
      _setGuest(mid: mid, name: name);
    }
  } catch (_) {
    if (!mounted) return;
    _setGuest(mid: mid, name: name);
  }

  // Only reveal the card after provider is fully populated
  onReady();
}
  void _showSearchSheet(
    List<GuestSearchResponse> guests,
    String term,
    int iid,
    VoidCallback onCardVisible,
  ) {
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
          try {
            final repo = GuestRepository(ApiService(const FlutterSecureStorage()));
            final r    = await repo.searchGuest(newIid, newTerm);
            Navigator.of(ctx).pop();
            _showSearchSheet(r, newTerm, newIid, onCardVisible);
          } catch (_) {}
        },
      ),
    );

 ref.listenManual(newReservationProvider, (_, next) {
  if (next.bmNumber != null) {
    _updateMemberIdFields(next.bmNumber!);
    _sharedGuestName.text = next.guestName ?? '';
    // Pass onCardVisible so card only shows AFTER full data is ready
    _fetchAndSetGuest(
      mid: next.bmNumber!,
      name: next.guestName ?? '',
      onReady: onCardVisible,
    );
    ref.read(newReservationProvider.notifier).resetState();
  }
});
  }

void _setGuest({required String mid, required String name}) {
  ref.read(selectedGuestProvider.notifier).setSelectedGuest(Guest(
    mid: mid,
    memberName: name,
    country: '',
    lastVisitDate: '',
   
    age: 0,
    gRating: '',
    mGroup: '',
    gName: '',
  ));
}

Future<void> _navigateToProfile(String mid, String name) async {
  if (mid.isEmpty) return;

  // ── If selectedGuestProvider already has this guest's full data,
  //    navigate immediately — no API call needed.
  final currentGuest = ref.read(selectedGuestProvider);
  if (currentGuest != null && currentGuest.mid == mid) {
    if (mounted) context.push('/home/profile');
    return;
  }

  // ── Otherwise fetch (edge case: profile tapped before card loaded)
  setState(() => _isLoading = true);
  try {
    final repo   = GuestRepository(ApiService(const FlutterSecureStorage()));
    final guests = await repo.searchGuest(9021, mid);
    setState(() => _isLoading = false);

    if (guests.isNotEmpty) {
      final g = guests.first;
      ref.read(selectedGuestProvider.notifier).setSelectedGuest(Guest(
        mid:           g.mid             ?? mid,
        memberName:    g.mName           ?? name,
        country:       '',
        lastVisitDate: g.lvd?.toString() ?? '',
      
        age:           0,
        gRating:       g.gRating         ?? '',
        mGroup:        '',
        gName:         g.gName           ?? '',
        memImage2:     g.memImage2,
      ));
    } else {
      _setGuest(mid: mid, name: name);
    }
  } catch (_) {
    setState(() => _isLoading = false);
    _setGuest(mid: mid, name: name);
  }

  if (mounted) context.push('/home/profile');
}
  // ── Date picker ─────────────────────────────────────────────────────────────
  Future<DateTime?> _pickDate(
    BuildContext context, {
    String label   = 'Select Date',
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
          Row(children: [
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
                onPressed: () { result = picked; Navigator.pop(context); },
                child: const Text('Confirm',
                    style: TextStyle(
                        color: Colors.blue, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ],
      ),
    );
    return result;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Message builders ─────────────────────────────────────────────────────────
  String _buildHotelText() => '''
*HOTEL RESERVATION REQUEST*
Name of the Guest    : ${_sharedGuestName.text}
Membership No         : ${_sharedMemberId.text}
Package Amount       : ${_h_packageAmount.text}
Name of the Hotel    : ${_selectedHotelName ?? ''}
Arrival                        : ${_h_arrivalCtrl.text}
Departure                  : ${_h_departureCtrl.text}
No of Room/s           : ${_h_noOfRooms.text}
No Of Pax                 : ${_h_noOfPax.text}
Room Type               : ${_selectedRoomTypeName ?? ''}
Room Category         : ${_selectedRoomCategoryName ?? ''}
ECI/LCO Facility      : $_h_eciLco
Meal Plan                  : ${_h_mealPlan.text}
Payment By              : ${_h_paymentBy.text}
Remarks                    : ${_h_remarks.text}
Marketing Person    : ${_h_marketingPerson.text}
Approved by.            : ${_h_approvedBy.text}
*Please send the confirmation''';

  String _buildAirText() {
    final fromCode = _a_fromAirport?.airportCode ?? '';
    final fromCity = _a_fromAirport?.cityName    ?? '';
    final toCode   = _a_toAirport?.airportCode   ?? '';
    final toCity   = _a_toAirport?.cityName      ?? '';
    String sector  = (fromCode.isNotEmpty && toCode.isNotEmpty)
        ? '$fromCity ($fromCode) → $toCity ($toCode)'
        : '';
    if (_a_isRoundTrip &&
        _a_returnFromAirport != null &&
        _a_returnToAirport   != null) {
      final rFromCode = _a_returnFromAirport!.airportCode ?? '';
      final rFromCity = _a_returnFromAirport!.cityName    ?? '';
      final rToCode   = _a_returnToAirport!.airportCode   ?? '';
      final rToCity   = _a_returnToAirport!.cityName      ?? '';
      sector += '\n                         $rFromCity ($rFromCode) → $rToCity ($rToCode)';
    }
    return '''
*AIR TICKET REQUEST*
BM                       : ${_sharedMemberId.text}
Guest Name        : ${_sharedGuestName.text}
Package Amount : ${_a_packageAmount.text}
Sector                  : $sector
Arr Date              : ${_a_arrCtrl.text}
Dep Date             : ${_a_depCtrl.text}
No of Seats         : ${_a_noOfSeats.text}
Class                    : ${_a_class.text}
Airlines               : ${_a_airlines.text}
Round Trip           : ${_a_isRoundTrip ? 'Yes' : 'No'}''';
  }

  String _buildExtText() => '''
*EXTENSION*
Name of the Guest              : ${_sharedGuestName.text}
Membership No                   : ${_sharedMemberId.text}
Package Amount                 : ${_e_packageAmount.text}
Arrival                                  : ${_e_arrCtrl.text}
Departure                            : ${_e_depCtrl.text}
No of Room/s                      : ${_e_noOfRooms.text}
Extension Date                   : ${_e_extensionDate.text}
Early Departure                  : ${_e_earlyDeparture.text}
Extension Approved By     : ${_e_approvedBy.text}''';

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Text('Copied to clipboard'),
      ]),
      backgroundColor: _accentColor,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _onCopy() {
    switch (_activeSection) {
      case _Section.hotel:     _copyToClipboard(_buildHotelText()); break;
      case _Section.airTicket: _copyToClipboard(_buildAirText());   break;
      case _Section.extension: _copyToClipboard(_buildExtText());   break;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.watch(fontSettingsProvider);

    return Stack(children: [
      Scaffold(
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
        body: Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.copyWith(
                  titleMedium: kInputTextStyle,
                ),
          ),
          child: Column(children: [
            // ── Section selector ──────────────────────────────────────────
            Container(
              color: _accentColor,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Row(children: [
                _sectionTab(_Section.hotel,     Icons.hotel_rounded,      'Hotel'),
                const SizedBox(width: 8),
                _sectionTab(_Section.airTicket, Icons.flight_rounded,     'Air Ticket'),
                const SizedBox(width: 8),
                _sectionTab(_Section.extension, Icons.date_range_rounded, 'Extension'),
              ]),
            ),
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
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _onCopy,
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.save),
          label: const Text('Save',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      // ── Loading overlay ───────────────────────────────────────────────
      if (_isLoading)
        Container(
          color: const Color.fromARGB(120, 0, 0, 0),
          child: const Center(
              child: CircularProgressIndicator(color: Colors.white)),
        ),
    ]);
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: active ? _accentColor : Colors.white),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? _accentColor : Colors.white)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper functions
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _fieldDeco(String label,
    {IconData? icon, Color accent = const Color(0xFFE65C00)}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 15.5,
    ),
    floatingLabelStyle: const TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 17,
    ),
    hintStyle: const TextStyle(
      color: Colors.black87,
      fontWeight: FontWeight.bold,
      fontSize: 15,
    ),
    prefixIcon: icon != null ? Icon(icon, size: 20, color: accent) : null,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent, width: 1.8)),
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
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Text(title,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 15)),
    ]),
  );
}

Widget _dateField(BuildContext context, String label,
    TextEditingController ctrl, Color accent, VoidCallback onTap) {
  return TextFormField(
    controller: ctrl,
    readOnly: true,
    style: kInputTextStyle,
    decoration: _fieldDeco(label,
            icon: Icons.calendar_today_rounded, accent: accent)
        .copyWith(suffixIcon: Icon(Icons.arrow_drop_down, color: accent)),
    onTap: onTap,
  );
}

Widget _rowPair(Widget left, Widget right) {
  return Row(children: [
    Expanded(child: left),
    const SizedBox(width: 10),
    Expanded(child: right),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Location-aware guest identity row
// ─────────────────────────────────────────────────────────────────────────────
Widget _guestIdentityRow({
  required BuildContext context,
  required TextEditingController memberIdCtrl,
  required TextEditingController memberIdNumberCtrl,
  required TextEditingController memberNameCtrl,
  required Color accent,
  required String midLabel,
  required String nameLabel,
  required VoidCallback onSearchById,
  required VoidCallback onSearchByName,
  required VoidCallback onProfileTap,
  required bool profileEnabled,
  // ── Location-aware MID params ────────────────────────────────────────────
  required bool isNumericOnly,
  required List<String> prefixes,
  required String selectedPrefix,
  required ValueChanged<String> onPrefixChanged,
}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(
        child: TextFormField(
          controller: memberIdNumberCtrl,
          style: kInputTextStyle,
          keyboardType: TextInputType.number,
          decoration: _fieldDeco(midLabel, accent: accent).copyWith(
            // ── Prefix dropdown or nothing for numeric-only locations ────
            prefixIcon: isNumericOnly
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPrefix,
                        style: kInputTextStyle,
                        items: prefixes.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(p, style: kInputTextStyle),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            onPrefixChanged(v);
                            // Keep full memberIdCtrl in sync
                            memberIdCtrl.text =
                                '$v${memberIdNumberCtrl.text}';
                          }
                        },
                      ),
                    ),
                  ),
            suffixIcon: IconButton(
              icon: Icon(Icons.search, color: accent),
              onPressed: () {
                // Build full MID before opening search
                memberIdCtrl.text = isNumericOnly
                    ? memberIdNumberCtrl.text
                    : '$selectedPrefix${memberIdNumberCtrl.text}';
                onSearchById();
              },
            ),
          ),
          onChanged: (value) {
            memberNameCtrl.clear();
            // Keep full memberIdCtrl in sync as user types
            memberIdCtrl.text = isNumericOnly
                ? value
                : '$selectedPrefix$value';
          },
        ),
      ),
      const SizedBox(width: 8),
      // ── Profile button ───────────────────────────────────────────────
      ElevatedButton(
        onPressed: profileEnabled ? onProfileTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: profileEnabled
              ? const Color.fromARGB(255, 0, 0, 0)
              : Colors.grey.shade400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        ),
        child: const Icon(Icons.person_search, size: 25),
      ),
    ]),
    const SizedBox(height: 10),
    // ── Guest name field ─────────────────────────────────────────────────
    TextFormField(
      controller: memberNameCtrl,
      style: kInputTextStyle,
      decoration:
          _fieldDeco(nameLabel, icon: Icons.person_outline, accent: accent)
              .copyWith(
        suffixIcon: IconButton(
          icon: Icon(Icons.search, color: accent),
          onPressed: onSearchByName,
        ),
      ),
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => memberIdNumberCtrl.clear(),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Airport dropdown (reads airportsProvider)
// ─────────────────────────────────────────────────────────────────────────────
class _AirportDropdown extends ConsumerWidget {
  final String   label;
  final Color    accent;
  final Airport? selectedAirport;
  final ValueChanged<Airport?> onChanged;

  const _AirportDropdown({
    super.key,
    required this.label,
    required this.accent,
    required this.selectedAirport,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airports = ref.watch(airportsProvider);

    return DropdownSearch<Airport>(
      selectedItem: selectedAirport,
      items: (filter, _) {
        if (filter.isEmpty) return airports;
        final lf = filter.toLowerCase();
        return airports
            .where((a) =>
                (a.airportCode ?? '').toLowerCase().contains(lf) ||
                (a.cityName    ?? '').toLowerCase().contains(lf) ||
                (a.airportName ?? '').toLowerCase().contains(lf) ||
                (a.country     ?? '').toLowerCase().contains(lf))
            .toList();
      },
      itemAsString: (a) =>
          '${a.cityName ?? ''} (${a.airportCode ?? ''}) - ${a.country ?? ''}',
      compareFn: (a, b) => a.airportCode == b.airportCode,
      decoratorProps: DropDownDecoratorProps(
        decoration: _fieldDeco(label,
            icon: Icons.flight_takeoff_rounded, accent: accent),
      ),
      dropdownBuilder: (context, item) {
        if (item == null) return const Text('');
        return Text(
          '${item.cityName ?? ''} (${item.airportCode ?? ''})',
          style: kInputTextStyle,
          overflow: TextOverflow.ellipsis,
        );
      },
      onChanged: onChanged,
      popupProps: PopupProps.dialog(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          autofocus: true,
          style: kInputTextStyle,
          decoration: InputDecoration(
            hintText: 'Search by city, code or country...',
            hintStyle: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 15),
            prefixIcon: const Icon(Icons.search),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        itemBuilder: (ctx, item, isSelected, isFocused) => ListTile(
          leading: CircleAvatar(
            backgroundColor: accent.withOpacity(0.12),
            child: Text(
              (item.airportCode ?? '').length > 3
                  ? (item.airportCode ?? '').substring(0, 3)
                  : (item.airportCode ?? ''),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: accent),
            ),
          ),
          title: Text(
            '${item.cityName ?? ''}, ${item.country ?? ''}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(item.airportName ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          selected: isSelected,
          tileColor: isFocused ? Colors.grey.shade100 : null,
        ),
        dialogProps: DialogProps(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOTEL FORM
// ─────────────────────────────────────────────────────────────────────────────
class _HotelForm extends StatelessWidget {
  final _QuickReservationScreenState state;
  const _HotelForm({super.key, required this.state});

  static String _hotelName(Map<String, dynamic>? item) =>
      (item?['hotel_name'] ?? '') as String;

  static double? _hotelId(Map<String, dynamic>? item) =>
      (item?['hotel'] as num?)?.toDouble();

  @override
  Widget build(BuildContext context) {
    const accent = _QuickReservationScreenState._hotelColor;
    final hotels = state.ref.watch(hotelsProvider);

    return Form(
      key: state._hotelFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          _sectionHeader(
              'Hotel Reservation Request', accent, Icons.hotel_rounded),

          // ── Location-aware guest identity ─────────────────────────────
          _guestIdentityRow(
            context:              context,
            memberIdCtrl:         state._sharedMemberId,
            memberIdNumberCtrl:   state._sharedMidNumber,
            memberNameCtrl:       state._sharedGuestName,
            accent:               accent,
            midLabel:             'Membership No *',
            nameLabel:            'Guest Name *',
            onSearchById: () => state._openGuestSearch(
              iid: 8002,
              onCardVisible: () =>
                  state.setState(() => state._sharedGuestCardVisible = true),
            ),
            onSearchByName: () => state._openGuestSearch(
              iid: 8003,
              onCardVisible: () =>
                  state.setState(() => state._sharedGuestCardVisible = true),
            ),
            onProfileTap: () => state._navigateToProfile(
                state._sharedMemberId.text, state._sharedGuestName.text),
            profileEnabled:  state._sharedGuestCardVisible,
            isNumericOnly:   state._isNumericOnlyLocation,
            prefixes:        state._prefixes,
            selectedPrefix:  state._selectedPrefix,
            onPrefixChanged: (v) => state.setState(() {
              state._selectedPrefix    = v;
              state._sharedMemberId.text =
                  '$v${state._sharedMidNumber.text}';
            }),
          ),
          const SizedBox(height: 12),

          // ── Guest card ────────────────────────────────────────────────
          if (state._sharedGuestCardVisible &&
              state._sharedMemberId.text.isNotEmpty &&
              state._sharedGuestName.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GuestDisplayCardSpecialGiftview(
                memberIdText:      state._sharedMemberId.text,
                memberNameText:    state._sharedGuestName.text,
                showCard:          true,
                showLastVisitDate: true,
              ),
            ),

          // ── Package amount ────────────────────────────────────────────
          TextFormField(
            controller: state._h_packageAmount,
            style: kInputTextStyle,
            decoration: _fieldDeco('Package Amount',
                icon: Icons.currency_rupee, accent: accent),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // ── Hotel dropdown ─────────────────────────────────────────────
          DropdownSearch<Map<String, dynamic>>(
            key: state._hotelDropdownKey,
            items: (filter, _) {
              final mapped = hotels.map((h) => h.toJson()).toList();
              if (filter.isEmpty) return mapped;
              return mapped
                  .where((h) => _hotelName(h)
                      .toLowerCase()
                      .contains(filter.toLowerCase()))
                  .toList();
            },
            itemAsString: (item) => _hotelName(item),
            compareFn:    (a, b) => _hotelId(a) == _hotelId(b),
            selectedItem: state._selectedHotel,
            decoratorProps: DropDownDecoratorProps(
              decoration: _fieldDeco('Hotel Name *',
                  icon: Icons.business_rounded, accent: accent),
            ),
            dropdownBuilder: (context, selectedItem) => Text(
              _hotelName(selectedItem),
              style: kInputTextStyle,
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: (val) {
              state.setState(() {
                state._selectedHotel     = val;
                state._selectedHotelName = _hotelName(val);
                state._selectedHotelId   = _hotelId(val);
              });
              if (state._selectedHotelId != null) {
                state._loadRoomCategories(state._selectedHotelId!);
              }
            },
            popupProps: PopupProps.dialog(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                autofocus: true,
                style: kInputTextStyle,
                decoration: InputDecoration(
                  hintText: 'Search hotel...',
                  hintStyle: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              itemBuilder: (ctx, item, isSelected, isFocused) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withOpacity(0.12),
                  child: Icon(Icons.hotel_rounded, color: accent, size: 18),
                ),
                title: Text(
                  _hotelName(item),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
                selected: isSelected,
                tileColor: isFocused ? Colors.grey.shade100 : null,
              ),
              dialogProps: DialogProps(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Room Category dropdown ─────────────────────────────────────
          DropdownSearch<Map<String, dynamic>>(
            key: state._roomCategoryDropdownKey,
            items: (f, _) => state._roomCategories
                .where((c) => ((c['CatName'] ?? '') as String)
                    .toLowerCase()
                    .contains(f.toLowerCase()))
                .toList(),
            itemAsString: (item) => (item['CatName'] ?? '') as String,
            compareFn:    (a, b) => a['CatCode'] == b['CatCode'],
            selectedItem: state._selectedRoomCategory,
            enabled:      state._roomCategories.isNotEmpty,
            decoratorProps: DropDownDecoratorProps(
              decoration: _fieldDeco(
                state._roomCategories.isEmpty
                    ? 'Room Category  (select hotel first)'
                    : 'Room Category *',
                icon: Icons.category_outlined,
                accent: accent,
              ),
            ),
            dropdownBuilder: (context, selectedItem) => Text(
              (selectedItem?['CatName'] ?? '') as String,
              style: kInputTextStyle,
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: (val) {
              state.setState(() {
                state._selectedRoomCategory     = val;
                state._selectedRoomCategoryId   = val?['CatCode'] as int?;
                state._selectedRoomCategoryName =
                    (val?['CatName'] ?? '') as String;
              });
              if (state._selectedHotelId       != null &&
                  state._selectedRoomCategoryId != null) {
                state._loadRoomTypes(
                    state._selectedHotelId!, state._selectedRoomCategoryId!);
              }
            },
            popupProps: PopupProps.dialog(
              showSearchBox: true,
              itemBuilder: (ctx, item, isSelected, isFocused) => ListTile(
                title: Text((item['CatName'] ?? '') as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                selected: isSelected,
                tileColor: isFocused ? Colors.grey.shade100 : null,
              ),
              dialogProps: DialogProps(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Room Type dropdown ─────────────────────────────────────────
          DropdownSearch<Map<String, dynamic>>(
            key: state._roomTypeDropdownKey,
            items: (f, _) => state._roomTypes
                .where((t) => ((t['RoomType'] ?? '') as String)
                    .toLowerCase()
                    .contains(f.toLowerCase()))
                .toList(),
            itemAsString: (item) =>
                '${(item['RoomType'] ?? '')} - ${(item['MealPlan'] ?? '')}',
            compareFn:    (a, b) => a['ID'] == b['ID'],
            selectedItem: state._selectedRoomType,
            enabled:      state._roomTypes.isNotEmpty,
            decoratorProps: DropDownDecoratorProps(
              decoration: _fieldDeco(
                state._roomTypes.isEmpty
                    ? 'Room Type  (select category first)'
                    : 'Room Type *',
                icon: Icons.bed_outlined,
                accent: accent,
              ),
            ),
            dropdownBuilder: (context, selectedItem) => Text(
              selectedItem == null
                  ? ''
                  : '${selectedItem['RoomType'] ?? ''} - ${selectedItem['MealPlan'] ?? ''}',
              style: kInputTextStyle,
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: (val) {
              state.setState(() {
                state._selectedRoomType     = val;
                state._selectedRoomTypeId   = val?['ID'] as int?;
                state._selectedRoomTypeName =
                    '${val?['RoomType'] ?? ''} - ${val?['MealPlan'] ?? ''}';
              });
            },
            popupProps: PopupProps.dialog(
              showSearchBox: true,
              itemBuilder: (ctx, item, isSelected, isFocused) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withOpacity(0.12),
                  child: Icon(Icons.bed_outlined, color: accent, size: 18),
                ),
                title: Text((item['RoomType'] ?? '') as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text((item['MealPlan'] ?? '') as String,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                selected: isSelected,
                tileColor: isFocused ? Colors.grey.shade100 : null,
              ),
              dialogProps: DialogProps(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Arrival + Departure ───────────────────────────────────────
          // _rowPair(
            _dateField(context, 'Arrival Date *', state._h_arrivalCtrl, accent,
                () async {
              final d = await state._pickDate(context,
                  label: 'Select Arrival Date',
                  initial: state._h_arrivalDate);
              if (d != null) {
                state._h_arrivalDate = d;
                state._h_arrivalCtrl.text = state._fmt(d);
                if (state._h_departureDate != null &&
                    !state._h_departureDate!.isAfter(d)) {
                  state._h_departureDate = null;
                  state._h_departureCtrl.clear();
                }
                // ignore: invalid_use_of_protected_member
                (context as Element).markNeedsBuild();
              }
            }),
               const SizedBox(height: 12),
            _dateField(context, 'Departure Date *', state._h_departureCtrl,
                accent, () async {
              final d = await state._pickDate(context,
                  label: 'Select Departure Date',
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
         // ),
          const SizedBox(height: 12),

          // ── Rooms + Pax ───────────────────────────────────────────────
          _rowPair(
            _StepperField(
              controller: state._h_noOfRooms,
              label: 'No of Rooms',
              icon: Icons.door_back_door_outlined,
              accent: accent,
            ),
            _StepperField(
              controller: state._h_noOfPax,
              label: 'No of Pax',
              icon: Icons.group_outlined,
              accent: accent,
            ),
          ),
          const SizedBox(height: 12),

          // ── ECI / LCO ─────────────────────────────────────────────────
          _LabeledCard(
            label: 'ECI / LCO Facility',
            accent: accent,
            child: _ChipSelector(
              options: const ['NA', 'ECI', 'LCO', 'ECI & LCO'],
              selected: state._h_eciLco,
              accent: accent,
              onChanged: (v) => state.setState(() => state._h_eciLco = v),
            ),
          ),
          const SizedBox(height: 12),

          // ── Meal Plan + Payment By ────────────────────────────────────
          _rowPair(
            TextFormField(
                controller: state._h_mealPlan,
                style: kInputTextStyle,
                decoration: _fieldDeco('Meal Plan',
                    icon: Icons.restaurant_outlined, accent: accent),
                textCapitalization: TextCapitalization.words),
            TextFormField(
                controller: state._h_paymentBy,
                style: kInputTextStyle,
                decoration: _fieldDeco('Payment By',
                    icon: Icons.payment_outlined, accent: accent),
                textCapitalization: TextCapitalization.words),
          ),
          const SizedBox(height: 12),

          // ── Marketing Person + Approved By ────────────────────────────
          _rowPair(
            TextFormField(
                controller: state._h_marketingPerson,
                style: kInputTextStyle,
                decoration: _fieldDeco('Marketing Person',
                    icon: Icons.support_agent_outlined, accent: accent),
                textCapitalization: TextCapitalization.words),
            TextFormField(
                controller: state._h_approvedBy,
                style: kInputTextStyle,
                decoration: _fieldDeco('Approved By',
                    icon: Icons.verified_user_outlined, accent: accent),
                textCapitalization: TextCapitalization.words),
          ),
          const SizedBox(height: 12),

          TextFormField(
              controller: state._h_remarks,
              style: kInputTextStyle,
              decoration: _fieldDeco('Remarks',
                  icon: Icons.notes_rounded, accent: accent),
              maxLines: 3,
              keyboardType: TextInputType.multiline),

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
          _sectionHeader(
              'Air Ticket Request', accent, Icons.flight_rounded),

          // ── Location-aware guest identity ─────────────────────────────
          _guestIdentityRow(
            context:              context,
            memberIdCtrl:         state._sharedMemberId,
            memberIdNumberCtrl:   state._sharedMidNumber,
            memberNameCtrl:       state._sharedGuestName,
            accent:               accent,
            midLabel:             'Membership No *',
            nameLabel:            'Guest Name',
            onSearchById: () => state._openGuestSearch(
              iid: 8002,
              onCardVisible: () =>
                  state.setState(() => state._sharedGuestCardVisible = true),
            ),
            onSearchByName: () => state._openGuestSearch(
              iid: 8003,
              onCardVisible: () =>
                  state.setState(() => state._sharedGuestCardVisible = true),
            ),
            onProfileTap: () => state._navigateToProfile(
                state._sharedMemberId.text, state._sharedGuestName.text),
            profileEnabled:  state._sharedGuestCardVisible,
            isNumericOnly:   state._isNumericOnlyLocation,
            prefixes:        state._prefixes,
            selectedPrefix:  state._selectedPrefix,
            onPrefixChanged: (v) => state.setState(() {
              state._selectedPrefix      = v;
              state._sharedMemberId.text =
                  '$v${state._sharedMidNumber.text}';
            }),
          ),
          const SizedBox(height: 12),

          // ── Guest card ────────────────────────────────────────────────
          if (state._sharedGuestCardVisible &&
              state._sharedMemberId.text.isNotEmpty &&
              state._sharedGuestName.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GuestDisplayCardSpecialGiftview(
                memberIdText:      state._sharedMemberId.text,
                memberNameText:    state._sharedGuestName.text,
                showCard:          true,
                showLastVisitDate: true,
              ),
            ),

          // ── Package amount ────────────────────────────────────────────
          TextFormField(
            controller: state._a_packageAmount,
            style: kInputTextStyle,
            decoration: _fieldDeco('Package Amount',
                icon: Icons.currency_rupee, accent: accent),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // ── Departure airports ────────────────────────────────────────
          _LabeledCard(
            label: 'Departure Flight',
            accent: accent,
            child: Column(children: [
              _AirportDropdown(
                key: state._a_fromAirportKey,
                label: 'From (Departure Airport)',
                accent: accent,
                selectedAirport: state._a_fromAirport,
                onChanged: (a) => state.setState(() {
                  state._a_fromAirport = a;
                  if (state._a_isRoundTrip) {
                    state._a_returnToAirport    = a;
                    state._a_returnToAirportKey = UniqueKey();
                  }
                }),
              ),
              const SizedBox(height: 10),
              _AirportDropdown(
                key: state._a_toAirportKey,
                label: 'To (Arrival Airport)',
                accent: accent,
                selectedAirport: state._a_toAirport,
                onChanged: (a) => state.setState(() {
                  state._a_toAirport = a;
                  if (state._a_isRoundTrip) {
                    state._a_returnFromAirport    = a;
                    state._a_returnFromAirportKey = UniqueKey();
                  }
                }),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Round trip toggle ─────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(children: [
              Icon(Icons.compare_arrows_rounded, color: accent, size: 20),
              const SizedBox(width: 10),
              const Text('Round Trip',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                      color: Colors.black)),
              const Spacer(),
              Switch(
                value: state._a_isRoundTrip,
                activeColor: accent,
                onChanged: (v) => state.setState(() {
                  state._a_isRoundTrip = v;
                  if (v) {
                    state._a_returnFromAirport    = state._a_toAirport;
                    state._a_returnToAirport      = state._a_fromAirport;
                    state._a_returnFromAirportKey = UniqueKey();
                    state._a_returnToAirportKey   = UniqueKey();
                  } else {
                    state._a_returnFromAirport = null;
                    state._a_returnToAirport   = null;
                  }
                }),
              ),
            ]),
          ),

          // ── Return airports ───────────────────────────────────────────
          if (state._a_isRoundTrip) ...[
            const SizedBox(height: 12),
            _LabeledCard(
              label: 'Return Flight',
              accent: accent,
              child: Column(children: [
                _AirportDropdown(
                  key: state._a_returnFromAirportKey,
                  label: 'Return From',
                  accent: accent,
                  selectedAirport: state._a_returnFromAirport,
                  onChanged: (a) =>
                      state.setState(() => state._a_returnFromAirport = a),
                ),
                const SizedBox(height: 10),
                _AirportDropdown(
                  key: state._a_returnToAirportKey,
                  label: 'Return To',
                  accent: accent,
                  selectedAirport: state._a_returnToAirport,
                  onChanged: (a) =>
                      state.setState(() => state._a_returnToAirport = a),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 12),

          // ── Dates ─────────────────────────────────────────────────────
        //  _rowPair(
            _dateField(context, 'Arrival Date', state._a_arrCtrl, accent,
                () async {
              final d = await state._pickDate(context,
                  label: 'Select Arrival Date', initial: state._a_arrDate);
              if (d != null) {
                state._a_arrDate = d;
                state._a_arrCtrl.text = state._fmt(d);
                // ignore: invalid_use_of_protected_member
                (context as Element).markNeedsBuild();
              }
            }),
              const SizedBox(height: 12),
            _dateField(context, 'Departure Date', state._a_depCtrl, accent,
                () async {
              final d = await state._pickDate(context,
                  label: 'Select Departure Date',
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
        //  ),
          const SizedBox(height: 12),

          // ── Seats + Class ─────────────────────────────────────────────
          _rowPair(
            _StepperField(
                controller: state._a_noOfSeats,
               // style: kInputTextStyle,
                label: 'No of Seats',
                    icon: Icons.event_seat_outlined, accent: accent),
               // keyboardType: TextInputType.number,
               // inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
            TextFormField(
                controller: state._a_class,
                style: kInputTextStyle,
                decoration: _fieldDeco('Class',
                    icon: Icons.class_outlined, accent: accent),
                textCapitalization: TextCapitalization.words),
          ),
          const SizedBox(height: 12),

          // ── Airlines ──────────────────────────────────────────────────
          TextFormField(
            controller: state._a_airlines,
            style: kInputTextStyle,
            decoration: _fieldDeco('Airlines',
                icon: Icons.airplanemode_active_rounded, accent: accent),
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
          _sectionHeader(
              'Extension / Early Departure', accent, Icons.date_range_rounded),

          // ── Location-aware guest identity ─────────────────────────────
          _guestIdentityRow(
            context:              context,
            memberIdCtrl:         state._sharedMemberId,
            memberIdNumberCtrl:   state._sharedMidNumber,
            memberNameCtrl:       state._sharedGuestName,
            accent:               accent,
            midLabel:             'Membership No *',
            nameLabel:            'Guest Name',
            onSearchById: () => state._openGuestSearch(
              iid: 8002,
              onCardVisible: () =>
                  state.setState(() => state._sharedGuestCardVisible = true),
            ),
            onSearchByName: () => state._openGuestSearch(
              iid: 8003,
              onCardVisible: () =>
                  state.setState(() => state._sharedGuestCardVisible = true),
            ),
            onProfileTap: () => state._navigateToProfile(
                state._sharedMemberId.text, state._sharedGuestName.text),
            profileEnabled:  state._sharedGuestCardVisible,
            isNumericOnly:   state._isNumericOnlyLocation,
            prefixes:        state._prefixes,
            selectedPrefix:  state._selectedPrefix,
            onPrefixChanged: (v) => state.setState(() {
              state._selectedPrefix      = v;
              state._sharedMemberId.text =
                  '$v${state._sharedMidNumber.text}';
            }),
          ),
          const SizedBox(height: 12),

          // ── Guest card ────────────────────────────────────────────────
          if (state._sharedGuestCardVisible &&
              state._sharedMemberId.text.isNotEmpty &&
              state._sharedGuestName.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GuestDisplayCardSpecialGiftview(
                memberIdText:      state._sharedMemberId.text,
                memberNameText:    state._sharedGuestName.text,
                showCard:          true,
                showLastVisitDate: true,
              ),
            ),
// _rowPair(
            TextFormField(
                controller: state._e_packageAmount,
                style: kInputTextStyle,
                decoration: _fieldDeco('Package Amount',
                    icon: Icons.currency_rupee, accent: accent),
                keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          // ── Package Amount + Rooms ────────────────────────────────────
          //_rowPair(
            // TextFormField(
            //     controller: state._e_packageAmount,
            //     style: kInputTextStyle,
            //     decoration: _fieldDeco('Package Amount',
            //         icon: Icons.currency_rupee, accent: accent),
            //     keyboardType: TextInputType.number),
            _StepperField(
                controller: state._e_noOfRooms,
                // style: kInputTextStyle,
                label: 'No of Rooms',
                    icon: Icons.door_back_door_outlined, accent: accent,
                // keyboardType: TextInputType.number,
                // inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                            // ),
          ),
          const SizedBox(height: 12),

          _dateField(context, 'Arrival Date', state._e_arrCtrl, accent,
              () async {
            final d = await state._pickDate(context,
                label: 'Select Arrival Date', initial: state._e_arrDate);
            if (d != null) {
              state._e_arrDate = d;
              state._e_arrCtrl.text = state._fmt(d);
              // ignore: invalid_use_of_protected_member
              (context as Element).markNeedsBuild();
            }
          }),
                    const SizedBox(height: 12),
          _dateField(context, 'Departure Date', state._e_depCtrl, accent,
              () async {
            final d = await state._pickDate(context,
                label: 'Select Departure Date', initial: state._e_depDate);
            if (d != null) {
              state._e_depDate = d;
              state._e_depCtrl.text = state._fmt(d);
              // ignore: invalid_use_of_protected_member
              (context as Element).markNeedsBuild();
            }
          }),
          const SizedBox(height: 12),

          _rowPair(
            TextFormField(
                controller: state._e_extensionDate,
                style: kInputTextStyle,
                decoration: _fieldDeco('Extension + Days',
                        icon: Icons.add_circle_outline, accent: accent)
                    .copyWith(hintText: '+ 1 Day')),
            TextFormField(
                controller: state._e_earlyDeparture,
                style: kInputTextStyle,
                decoration: _fieldDeco('Early Departure - Days',
                    icon: Icons.remove_circle_outline, accent: accent)),
          ),
          const SizedBox(height: 12),

          TextFormField(
              controller: state._e_approvedBy,
              style: kInputTextStyle,
              decoration: _fieldDeco(
                  'Extension Approved By\n(Required above 3 nights)',
                  icon: Icons.verified_user_outlined,
                  accent: accent),
              textCapitalization: TextCapitalization.words),

          const SizedBox(height: 16),
          _PreviewCard(text: state._buildExtText(), accent: accent),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip selector
// ─────────────────────────────────────────────────────────────────────────────
class _ChipSelector extends StatefulWidget {
  final List<String>         options;
  final String               selected;
  final Color                accent;
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
            fontSize: 14.5,
            color: active ? Colors.white : Colors.black,
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
          ),
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
// Stepper field
// ─────────────────────────────────────────────────────────────────────────────
class _StepperField extends StatelessWidget {
  final TextEditingController controller;
  final String   label;
  final IconData icon;
  final Color    accent;
  final int      min;
  final int      max;

  const _StepperField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.accent,
    this.min = 1,
    this.max = 99,
  });

  int get _value => int.tryParse(controller.text) ?? min;

  void _change(int delta, VoidCallback rebuild) {
    final next = (_value + delta).clamp(min, max);
    controller.text = next.toString();
    rebuild();
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
              Row(children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _StepButton(
                  icon: Icons.remove,
                  accent: accent,
                  enabled: _value > min,
                  onTap: () => _change(-1, () => setState(() {})),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      controller.text,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: accent),
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add,
                  accent: accent,
                  enabled: _value < max,
                  onTap: () => _change(1, () => setState(() {})),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData    icon;
  final Color       accent;
  final bool        enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? accent.withOpacity(0.1) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? accent : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Labeled card
// ─────────────────────────────────────────────────────────────────────────────
class _LabeledCard extends StatelessWidget {
  final String label;
  final Color  accent;
  final Widget child;
  const _LabeledCard(
      {required this.label, required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview card
// ─────────────────────────────────────────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  final String text;
  final Color  accent;
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
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.preview_rounded, size: 16, color: accent),
          const SizedBox(width: 6),
          Text('Message Preview',
              style: TextStyle(
                  fontSize: 13,
                  color: accent,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Text(text,
            style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                fontFamily: 'monospace',
                color: Color(0xFF2C3E50))),
      ]),
    );
  }
}