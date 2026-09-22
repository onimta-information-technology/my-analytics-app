import 'dart:convert';
import 'dart:math' as math;

import 'package:ballys_reservation_app/components/bottom_sheets/member_search-new_sheet.dart';
import 'package:ballys_reservation_app/components/passport_upload_widget_ballys.dart';
import 'package:ballys_reservation_app/data/repositories/quick_reservation_repository.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/quick_reservation_provider_ballys.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const TextStyle _kInputTextStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  color: Colors.black,
);

const Color _accent = Color(0xFF6A1B9A);

/// Bally's "Add Visa Request", opened from the + on the visa list.
///
/// Same form and the same `VisaRequest/Insert` call as the Quick Reservation
/// visa tab: every guest is an equal card with their own passport bio data
/// page, and all of them arrive on one date. A successful save pops `true` so
/// the list can reload.
class VisaAddBallysScreen extends ConsumerStatefulWidget {
  const VisaAddBallysScreen({super.key});

  @override
  ConsumerState<VisaAddBallysScreen> createState() =>
      _VisaAddBallysScreenState();
}

class _VisaAddBallysScreenState extends ConsumerState<VisaAddBallysScreen>
    with ConnectivityMixin {
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

  // ── Guests ──────────────────────────────────────────────────────────────────
  // No main guest: the screen opens with one card and "Add More Guest" adds
  // the rest. Uploads are held under the card itself — a card's MID can still
  // change after upload.
  final List<_VisaGuest> _guests = [_VisaGuest()];
  final Map<_VisaGuest, List<PassportFileBallys>> _passportsByRow = {};

  /// Set by a save that found a guest without a passport, so the missing
  /// uploaders are outlined in red until something is picked.
  bool _showPassportErrors = false;

  // ── Arrival ─────────────────────────────────────────────────────────────────
  final _arrivalCtrl = TextEditingController();
  DateTime? _arrivalDate;

  @override
  void initState() {
    super.initState();
    _quickNotifier = ref.read(quickReservationBallysProvider.notifier);
    // Deferred past the first frame: the loader writes provider state.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _quickNotifier.loadLocationPrefix();
      if (!mounted) return;
      // The first card was built before the location's prefix was known.
      setState(() {
        for (final row in _guests) {
          if (row.midNumberController.text.isEmpty) {
            row.prefix = _isNumericOnlyLocation ? '' : _selectedPrefix;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _arrivalCtrl.dispose();
    for (final row in _guests) {
      row.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Guests ──────────────────────────────────────────────────────────────────

  void _addGuest() {
    FocusScope.of(context).unfocus();
    setState(() {
      _guests.add(
        _VisaGuest(prefix: _isNumericOnlyLocation ? '' : _selectedPrefix),
      );
    });
  }

  void _removeGuest(int index) {
    setState(() {
      _passportsByRow.remove(_guests[index]);
      _guests.removeAt(index).dispose();
    });
  }

  /// Member search for a guest card; the pick comes back by row.
  Future<void> _openGuestSearch(int index, int iid) async {
    FocusScope.of(context).unfocus();

    final row = _guests[index];
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

  /// Every guest on the request, in card order, as the maps
  /// [QuickReservationRepository.buildVisaBody] expects.
  List<Map<String, dynamic>> _captureGuests() {
    return [
      for (final row in _guests)
        {
          'memberId': row.fullMid(numericOnly: _isNumericOnlyLocation),
          'guestName': row.nameController.text.trim(),
          'passportFiles': _passportsByRow[row] ?? const <PassportFileBallys>[],
        },
    ];
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// Every field is mandatory: each guest's Membership No, Guest Name and
  /// passport bio data page, plus the arrival date. A blank guest card is an
  /// error rather than skipped.
  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;

    final guests = _captureGuests();
    final missingPassport =
        guests.indexWhere((g) => (g['passportFiles'] as List).isEmpty);
    if (missingPassport != -1) setState(() => _showPassportErrors = true);

    if (!formValid) return;

    final seen = <String>{};
    for (var i = 0; i < guests.length; i++) {
      final g = guests[i];
      if ((g['memberId'] as String).isEmpty ||
          (g['guestName'] as String).isEmpty) {
        _showSaveErrorSnack(
            'Guest ${i + 1}: both Membership No and Guest Name are required');
        return;
      }
      if (!seen.add(g['memberId'] as String)) {
        _showSaveErrorSnack('${g['memberId']} is already added to this request');
        return;
      }
    }

    if (missingPassport != -1) {
      _showSaveErrorSnack('Guest ${missingPassport + 1}: '
          'please upload the passport bio data page');
      return;
    }

    final arrival = _arrivalDate;
    if (arrival == null) {
      _showSaveErrorSnack('Arrival Date is required');
      return;
    }

    final result = await _quickNotifier.saveVisaRequest(
      guests: guests,
      arrivalDate: arrival,
      log: _logLong,
    );
    _handleSaveResult(result);
  }

  void _handleSaveResult(QuickReservationResult result) {
    if (!mounted) return;
    if (!result.success) {
      _showSaveErrorSnack(result.message ?? 'Failed to save visa request');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(result.message ?? 'Visa request saved successfully'),
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

  /// Replaces base64 blobs with a short `<base64: n chars>` marker so a logged
  /// payload stays readable — an uploaded passport page is otherwise hundreds
  /// of thousands of characters and buries the rest of the body.
  Object? _shortenForLog(Object? value) {
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(
          k,
          k == 'Base64Data' && v is String
              ? '<base64: ${v.length} chars>'
              : _shortenForLog(v),
        ),
      );
    }
    if (value is List) return value.map(_shortenForLog).toList();
    return value;
  }

  // debugPrint truncates long lines, so emit the payload in chunks.
  void _logLong(String label, Object? payload) {
    final text =
        const JsonEncoder.withIndent('  ').convert(_shortenForLog(payload));
    debugPrint('===== $label =====');
    for (final line in text.split('\n')) {
      for (var i = 0; i < line.length; i += 800) {
        debugPrint(line.substring(i, math.min(i + 800, line.length)));
      }
    }
    debugPrint('===== end $label =====');
  }

  // ── Copy ────────────────────────────────────────────────────────────────────

  String _buildVisaText() {
    final guests = _captureGuests();
    final buf = StringBuffer('*Visa Request*\n');
    for (var i = 0; i < guests.length; i++) {
      final g = guests[i];
      final files = (g['passportFiles'] as List<PassportFileBallys>)
          .map((f) => f.fileName)
          .join(', ');
      buf.write('''
Guest ${i + 1}
Membership No  : ${g['memberId']}
Guest Name     : ${g['guestName']}
Passport File/s: ${files.isEmpty ? 'None' : files}
''');
    }
    buf.write('Arrival Date   : ${_arrivalCtrl.text}');
    return buf.toString();
  }

  void _onCopy() {
    Clipboard.setData(ClipboardData(text: _buildVisaText()));
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

  // ── Picker ──────────────────────────────────────────────────────────────────

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DateTime?> _pickDate({
    required String label,
    DateTime? initial,
    DateTime? minDate,
  }) async {
    DateTime picked = initial ?? minDate ?? DateTime.now();
    // The picker asserts its initial value sits inside the allowed range.
    if (minDate != null && picked.isBefore(minDate)) picked = minDate;
    DateTime? result;
    await showModalBottomSheet(
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
                    result = picked;
                    Navigator.pop(sheetContext);
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
    return result;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(fontSettingsProvider);
    // Prefix rules and the in-flight flag live on the provider.
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
              'Add Visa Request',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/reservationMain/visa-ballys');
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
                    for (int i = 0; i < _guests.length; i++) ...[
                      _guestCard(i),
                      _passportBox(
                        missing: _showPassportErrors &&
                            (_passportsByRow[_guests[i]] ?? const []).isEmpty,
                        child: PassportUploadWidgetBallys(
                          key: ObjectKey(_guests[i]),
                          title: 'Passport Bio Data Page — Guest ${i + 1} *',
                          initialFiles:
                              _passportsByRow[_guests[i]] ?? const [],
                          onFilesChanged: (files) => setState(() =>
                              _passportsByRow[_guests[i]] = List.from(files)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _addMoreGuestButton(),
                    const SizedBox(height: 16),
                    _arrivalDateField(),
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
                          'Submit Visa Request',
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

  Widget _guestCard(int index) {
    final row = _guests[index];
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
                  child: Text('${index + 1}',
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guest ${index + 1}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2430),
                    ),
                  ),
                ),
                // The last card cannot go — a request needs one guest.
                if (_guests.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _removeGuest(index),
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
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Membership No is required'
                  : null,
              decoration: _fieldDeco('Membership No *').copyWith(
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
                  onPressed: () => _openGuestSearch(index, 8002),
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
              textCapitalization: TextCapitalization.words,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Guest Name is required'
                  : null,
              decoration: _fieldDeco('Guest Name *').copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: _accent),
                  onPressed: () => _openGuestSearch(index, 8003),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The white card each passport uploader sits in, outlined in red once a
  /// save has found it empty.
  Widget _passportBox({required bool missing, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: missing ? Colors.red.shade700 : _accent.withOpacity(0.35),
          width: missing ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          if (missing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Passport bio data page is required',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addMoreGuestButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addGuest,
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
    );
  }

  Widget _arrivalDateField() {
    return TextFormField(
      key: ValueKey('arrivalDate|${_arrivalCtrl.text}'),
      controller: _arrivalCtrl,
      readOnly: true,
      style: _kInputTextStyle,
      decoration: _fieldDeco(
        'Arrival Date *',
        icon: Icons.calendar_today_rounded,
      ).copyWith(
        suffixIcon: const Icon(Icons.arrow_drop_down, color: _accent),
      ),
      onTap: () async {
        final now = DateTime.now();
        final d = await _pickDate(
          label: 'Select Arrival Date',
          initial: _arrivalDate,
          minDate: DateTime(now.year, now.month, now.day),
        );
        if (d != null) {
          setState(() {
            _arrivalDate = d;
            _arrivalCtrl.text = _fmt(d);
          });
        }
      },
      validator: (value) => (value == null || value.trim().isEmpty)
          ? 'Arrival Date is required'
          : null,
    );
  }
}

// ── Shared form pieces ────────────────────────────────────────────────────────

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

/// One guest on the visa request.
class _VisaGuest {
  final TextEditingController midNumberController;
  final TextEditingController nameController;
  String prefix;

  _VisaGuest({this.prefix = 'BM'})
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
