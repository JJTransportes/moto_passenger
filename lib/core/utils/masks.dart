import 'package:flutter/services.dart';

/// Strips everything but digits.
String unmaskDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Strips everything but digits and the letter X (used in some RG check digits).
String unmaskRg(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');

/// Formats as the user types: 000.000.000-00
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = unmaskDigits(newValue.text).substring(
      0,
      unmaskDigits(newValue.text).length > 11
          ? 11
          : unmaskDigits(newValue.text).length,
    );

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 2 || i == 5) {
        if (i != digits.length - 1) buffer.write('.');
      } else if (i == 8) {
        if (i != digits.length - 1) buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formats as the user types: 00.000.000-0
class RgInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = unmaskRg(newValue.text);
    final digits = raw.substring(0, raw.length > 9 ? 9 : raw.length);

    final p1 = digits.substring(0, digits.length > 2 ? 2 : digits.length);
    final p2 = digits.length > 2
        ? digits.substring(2, digits.length > 5 ? 5 : digits.length)
        : '';
    final p3 = digits.length > 5
        ? digits.substring(5, digits.length > 8 ? 8 : digits.length)
        : '';
    final p4 = digits.length > 8 ? digits.substring(8) : '';

    var formatted = p1;
    if (p2.isNotEmpty) formatted += '.$p2';
    if (p3.isNotEmpty) formatted += '.$p3';
    if (p4.isNotEmpty) formatted += '-$p4';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
