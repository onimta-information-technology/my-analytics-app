import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "Payment By" options, per brand. Bellagio (bty.world) bills through
/// Beyond Borders, so it gets its own wording — the values are the ones the
/// back office already stores, trailing space included. Kept in step with the
/// new reservation screen's dropdown.
const List<String> _hamoosOptions = [
  'By Guest',
  'By Hamoos ',
  'By Guest & Hamoos',
];

const List<String> _bellagioOptions = [
  'By Guest',
  'By Beyond Borders',
  'By Guest & Beyond',
];

String _labelFor(String value) =>
    value == 'By Guest & Beyond' ? 'By Guest & Beyond Borders' : value.trim();

/// What [reservation] is paid by now. Older rows only carry it on their hotel
/// lines, so those stand in when the reservation itself holds none — the same
/// fallback the reservation view uses.
String? currentPaymentByBallys(ReservationBallys reservation) {
  for (final value in [
    reservation.paymentBy,
    ...reservation.hotelDescip.map((h) => h.paymentBy),
  ]) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return value;
  }
  return null;
}

/// Lets a modification update who pays for the reservation. Used by the
/// Payment By popup on the reservation view.
///
/// [value] is owned by the caller, which seeds it with the reservation's
/// current Payment By. A stored value is matched ignoring surrounding spaces,
/// since older rows were saved without the trailing space on 'By Hamoos '.
class AmendmentPaymentByFieldBallys extends ConsumerStatefulWidget {
  const AmendmentPaymentByFieldBallys({
    super.key,
    required this.value,
    required this.onChanged,
    this.current,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  /// What the reservation is paid by now, shown beneath the field.
  final String? current;

  @override
  ConsumerState<AmendmentPaymentByFieldBallys> createState() =>
      _AmendmentPaymentByFieldBallysState();
}

class _AmendmentPaymentByFieldBallysState
    extends ConsumerState<AmendmentPaymentByFieldBallys> {
  bool _isBellagio = false;

  @override
  void initState() {
    super.initState();
    _loadBrand();
  }

  Future<void> _loadBrand() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    if (!mounted) return;
    setState(() => _isBellagio = apiUrl.contains('bty.world'));
  }

  List<String> get _options => _isBellagio ? _bellagioOptions : _hamoosOptions;

  /// The offered value [value] stands for, or null when it matches none.
  String? _match(String? value) {
    final wanted = value?.trim();
    if (wanted == null || wanted.isEmpty) return null;
    for (final option in _options) {
      if (option.trim() == wanted) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final current = widget.current?.trim();

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Payment By',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
        ),
        helperText: current == null || current.isEmpty
            ? null
            : 'Currently: $current',
        helperStyle: TextStyle(
          fontSize: fontSettings.fontSize - 3,
          color: Colors.grey.shade700,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _match(widget.value),
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
            color: Colors.black,
          ),
          hint: Text(
            'Select payment by',
            style: TextStyle(
              fontSize: fontSettings.fontSize,
              fontWeight: fontSettings.fontWeight,
              color: Colors.grey.shade600,
            ),
          ),
          items: _options
              .map((o) =>
                  DropdownMenuItem<String>(value: o, child: Text(_labelFor(o))))
              .toList(),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
