import 'package:ballys_reservation_app/providers/package_amounts_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A package-amount picker backed by the `GetPackageAmounts_MyAnalytics` API.
///
/// Behaviour:
///   * Shows the predefined amounts (e.g. `"IND 10,000"`) in a dropdown.
///   * A currency filter row (All / IND / USD / …) narrows the dropdown to a
///     single currency. Currencies are derived from the fetched values.
///
/// The selected value (a display string like `"IND 10,000"`) is written
/// straight into [controller] and sent to the backend as-is (the
/// `package_amount` column is a varchar), preserving the currency.
///
/// While the amounts are loading — or if the request fails — the widget falls
/// back to a plain numeric text field bound to [controller] so the form is
/// never blocked.
class PackageAmountFieldBallys extends ConsumerStatefulWidget {
  final TextEditingController controller;

  /// Base decoration applied to the dropdown and the "other" text field. Its
  /// `labelText` is reused for both.
  final InputDecoration decoration;
  final TextStyle? textStyle;
  final String? Function(String?)? validator;

  /// When false, the field is read-only (e.g. edit mode).
  final bool enabled;

  /// Accent colour for the selected currency filter chip.
  final Color accent;

  const PackageAmountFieldBallys({
    super.key,
    required this.controller,
    required this.decoration,
    this.textStyle,
    this.validator,
    this.enabled = true,
    this.accent = const Color(0xFFCC963A),
  });

  @override
  ConsumerState<PackageAmountFieldBallys> createState() => _PackageAmountFieldState();
}

class _PackageAmountFieldState extends ConsumerState<PackageAmountFieldBallys> {
  /// Currency filter, `null` == "All".
  String? _currencyFilter;

  /// The amount currently selected from the list (`null` when none).
  String? _selected;

  /// One-time reconciliation with any pre-existing controller value once the
  /// amounts have loaded.
  bool _initialisedFromController = false;

  void _syncFromController() {
    if (_initialisedFromController) return;
    _initialisedFromController = true;

    final text = widget.controller.text.trim();
    // A value the list doesn't offer — e.g. one saved before an amount was
    // retired — is still shown so editing never silently drops it.
    _selected = text.isEmpty ? null : text;
  }

  List<String> _currenciesOf(List<String> amounts) {
    final set = <String>{};
    for (final a in amounts) {
      final parts = a.split(' ');
      if (parts.length > 1) set.add(parts.first);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final asyncAmounts = ref.watch(packageAmountsProvider);

    return asyncAmounts.when(
      loading: () => _fallbackField(hint: 'Loading amounts…'),
      error: (_, __) => _fallbackField(),
      data: (amounts) {
        if (amounts.isEmpty) return _fallbackField();
        final currencies = _currenciesOf(amounts);
        _syncFromController();
        return _dropdownUi(amounts, currencies);
      },
    );
  }

  Widget _dropdownUi(List<String> amounts, List<String> currencies) {
    final filtered = _currencyFilter == null
        ? amounts
        : amounts
            .where((a) => a.startsWith('${_currencyFilter!} '))
            .toList();

    // The dropdown value must exist in its items, so always include the
    // current selection even if the active filter would hide it.
    final valueSet = <String>{...filtered};
    if (_selected != null) valueSet.add(_selected!);

    final items = valueSet
        .map(
          (a) => DropdownMenuItem<String>(
            value: a,
            child: Text(a, style: widget.textStyle),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currencies.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              children: [
                _filterChip('All', null),
                ...currencies.map((c) => _filterChip(c, c)),
              ],
            ),
          ),
        DropdownButtonFormField<String>(
          value: _selected,
          isExpanded: true,
          style: widget.textStyle,
          decoration: widget.decoration,
          items: items,
          onChanged: widget.enabled
              ? (value) {
                  setState(() {
                    _selected = value;
                    widget.controller.text = value ?? '';
                  });
                }
              : null,
          validator: widget.validator,
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _currencyFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: widget.accent.withOpacity(0.20),
      onSelected: widget.enabled
          ? (_) => setState(() {
                _currencyFilter = value;
                // Changing the currency filter must clear a previously picked
                // amount that belongs to a different currency, otherwise the
                // stale value stays selected and written to the controller.
                if (value != null &&
                    _selected != null &&
                    !_selected!.startsWith('$value ')) {
                  _selected = null;
                  widget.controller.text = '';
                }
              })
          : null,
    );
  }

  /// Plain numeric field used while loading, on error, or when the API returns
  /// no amounts — keeps the form usable.
  Widget _fallbackField({String? hint}) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      style: widget.textStyle,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: hint != null
          ? widget.decoration.copyWith(hintText: hint)
          : widget.decoration,
      validator: widget.validator,
    );
  }
}
