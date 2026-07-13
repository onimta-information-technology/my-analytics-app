/// Helpers for normalising user-facing amount strings before they are sent to
/// the backend.
library;

/// Converts a package-amount display string (e.g. `"IND 10,000"`,
/// `"USD 25,000"`, `"12,500.50"`) into a plain integer string (`"10000"`,
/// `"25000"`, `"12500"`).
///
/// Strips any currency prefix, thousands separators and decimals so the API
/// receives a bare integer. Returns an empty string when there is no numeric
/// content, matching the previous fallback for an empty amount.
String packageAmountToInt(String? raw) {
  if (raw == null) return '';
  // Keep only digits and the decimal point (drops currency, spaces, commas).
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return '';
  final value = double.tryParse(cleaned);
  if (value == null) return '';
  return value.toInt().toString();
}

/// Extracts the currency prefix of a package-amount display string, e.g.
/// `"IND 10,000"` -> `"IND"`, `"USD 25,000"` -> `"USD"`.
///
/// Returns an empty string when the amount carries no currency (a bare number
/// typed into the fallback field), so the API receives `""` rather than null.
String packageAmountCurrency(String? raw) {
  if (raw == null) return '';
  final match = RegExp(r'^\s*([A-Za-z]+)').firstMatch(raw);
  return match?.group(1)?.toUpperCase() ?? '';
}
