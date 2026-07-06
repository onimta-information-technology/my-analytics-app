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
///   * An **Other amount** dropdown entry reveals a free-text numeric field so
///     the user can enter a custom amount.
///
/// The selected value (a display string like `"IND 10,000"` or a manually
/// typed number) is written straight into [controller] and sent to the backend
/// as-is (the `package_amount` column is a varchar), preserving the currency.
///
/// While the amounts are loading — or if the request fails — the widget falls
/// back to a plain numeric text field bound to [controller] so the form is
/// never blocked.
class PackageAmountField extends ConsumerStatefulWidget {
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

  const PackageAmountField({
    super.key,
    required this.controller,
    required this.decoration,
    this.textStyle,
    this.validator,
    this.enabled = true,
    this.accent = const Color(0xFFCC963A),
  });

  @override
  ConsumerState<PackageAmountField> createState() => _PackageAmountFieldState();
}

class _PackageAmountFieldState extends ConsumerState<PackageAmountField> {
  static const String _kOther = '__other_amount__';

  final TextEditingController _manualController = TextEditingController();

  /// Currency filter, `null` == "All".
  String? _currencyFilter;

  /// The amount currently selected from the list (`null` when none / other).
  String? _selected;

  /// Whether the user chose "Other amount".
  bool _isOther = false;

  /// Currency prepended to a custom ("Other amount") value, e.g. `IND` / `USD`.
  String? _otherCurrency;

  /// One-time reconciliation with any pre-existing controller value once the
  /// amounts have loaded.
  bool _initialisedFromController = false;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  void _syncFromController(List<String> amounts, List<String> currencies) {
    if (_initialisedFromController) return;
    _initialisedFromController = true;

    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      _selected = null;
      _isOther = false;
    } else if (amounts.contains(text)) {
      _selected = text;
      _isOther = false;
    } else {
      // Custom value — split off a leading currency (e.g. "IND 12345") so the
      // currency selector and amount field pre-fill correctly.
      _isOther = true;
      final parts = text.split(' ');
      if (parts.length > 1 && currencies.contains(parts.first)) {
        _otherCurrency = parts.first;
        _manualController.text = parts.sublist(1).join(' ');
      } else {
        _otherCurrency = currencies.isNotEmpty ? currencies.first : null;
        _manualController.text = text;
      }
    }
  }

  /// The currency to default a fresh "Other amount" entry to: the active
  /// filter when it names a currency, otherwise the first available currency.
  String? _defaultOtherCurrency(List<String> currencies) =>
      _currencyFilter ?? (currencies.isNotEmpty ? currencies.first : null);

  /// Rebuilds the controller value from the currency + typed amount, e.g.
  /// `"IND 12345"`. Empty amount clears the field.
  void _updateOtherValue() {
    final amount = _manualController.text.trim();
    if (amount.isEmpty) {
      widget.controller.text = '';
    } else if (_otherCurrency != null && _otherCurrency!.isNotEmpty) {
      widget.controller.text = '$_otherCurrency $amount';
    } else {
      widget.controller.text = amount;
    }
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
        _syncFromController(amounts, currencies);
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

    final items = <DropdownMenuItem<String>>[
      ...valueSet.map(
        (a) => DropdownMenuItem<String>(
          value: a,
          child: Text(a, style: widget.textStyle,),
        ),
      ),
      DropdownMenuItem<String>(
        value: _kOther,
        child: Text('Other amount', style: widget.textStyle),
      ),
    ];

    final currentValue = _isOther ? _kOther : _selected;

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
          value: currentValue,
          isExpanded: true,
          style: widget.textStyle,
          decoration: widget.decoration,
          items: items,
          onChanged: widget.enabled
              ? (value) {
                  setState(() {
                    if (value == _kOther) {
                      _isOther = true;
                      _selected = null;
                      _otherCurrency ??= _defaultOtherCurrency(currencies);
                      _updateOtherValue();
                    } else {
                      _isOther = false;
                      _selected = value;
                      widget.controller.text = value ?? '';
                    }
                  });
                }
              : null,
          validator: (value) {
            if (widget.validator == null) return null;
            return _isOther
                ? widget.validator!(_manualController.text)
                : widget.validator!(value);
          },
        ),
        if (_isOther) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currencies.isNotEmpty) ...[
                _otherCurrencySelector(currencies),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextFormField(
                  controller: _manualController,
                  enabled: widget.enabled,
                  style: widget.textStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: widget.decoration.copyWith(
                    labelText: 'Enter amount',
                  ),
                  onChanged: (_) => _updateOtherValue(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Currency dropdown shown beside the custom-amount field so an "Other
  /// amount" value is still tagged with IND / USD.
  Widget _otherCurrencySelector(List<String> currencies) {
    final value = _otherCurrency ?? currencies.first;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: currencies.contains(value) ? value : currencies.first,
        style: widget.textStyle,
        items: currencies
            .map((c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(c, style: widget.textStyle),
                ))
            .toList(),
        onChanged: widget.enabled
            ? (v) => setState(() {
                  _otherCurrency = v;
                  _updateOtherValue();
                })
            : null,
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _currencyFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: widget.accent.withOpacity(0.20),
      onSelected: widget.enabled
          ? (_) => setState(() => _currencyFilter = value)
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
