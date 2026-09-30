import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Country-aware mobile number validation backed by libphonenumber metadata.
class MobileNumberUtil {
  MobileNumberUtil._();

  /// Longest input a mobile field accepts: the E.164 limit of 15 digits, plus
  /// one for a leading trunk '0'.
  static const int maxDigits = 16;

  /// Parses [input] as a national number of [country]. Returns null when the
  /// country is unknown or the input unparsable.
  static PhoneNumber? parse(String input, Country country) {
    final iso = IsoCode.values
        .where((c) => c.name == country.countryCode)
        .firstOrNull;
    if (iso == null) return null;
    try {
      return PhoneNumber.parse(input.trim(), destinationCountry: iso);
    } on PhoneNumberException {
      return null;
    }
  }

  /// Number to save, in E.164 form (e.g. +94712345678).
  static String format(String input, Country country) =>
      parse(input, country)?.international ??
      '+${country.phoneCode}${input.trim().replaceFirst(RegExp(r'^0+'), '')}';

  /// Error message for [input] as a [country] mobile number, or null when valid.
  static String? validate(String input, Country country) {
    if (input.trim().isEmpty) return 'Contact Number is required';
    final phone = parse(input, country);
    if (phone == null || !phone.isValid(type: PhoneNumberType.mobile)) {
      return 'Enter a valid ${country.name} mobile number';
    }
    return null;
  }
}
