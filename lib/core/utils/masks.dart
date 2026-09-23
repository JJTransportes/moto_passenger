import 'package:flutter/services.dart';

/// Strips everything but digits.
String unmaskDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Strips everything but digits and the letter X (used in some RG check digits).
String unmaskRg(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');

/// Masks an e-mail for read-only display, e.g. `i***@gmail.com`.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  return '${email.substring(0, 1)}***${email.substring(at)}';
}

/// Masks a phone for read-only display, e.g. `(11) *****-5678`.
String maskPhone(String phone) {
  if (phone.isEmpty) return phone;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return phone;
  final ddd = digits.substring(0, 2);
  final rest = digits.substring(2);
  final splitAt = rest.length > 8 ? 5 : 4;
  final last4 = rest.substring(rest.length - 4);
  return '($ddd) ${'*' * splitAt}-$last4';
}

/// Formats phone digits as the user types: `(00) 0000-0000` (landline, up to
/// 10 digits) or `(00) 00000-0000` (mobile, 11 digits — split switches from
/// 4+4 to 5+4 as soon as the 9th local digit is typed).
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = formatPhoneDigits(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formats raw [digits] into `(00) 0000-0000` / `(00) 00000-0000`.
String formatPhoneDigits(String digits) {
  if (digits.isEmpty) return '';
  if (digits.length <= 2) return '($digits';

  final ddd = digits.substring(0, 2);
  final rest = digits.substring(2);
  final splitAt = rest.length > 8 ? 5 : 4;
  if (rest.length <= splitAt) return '($ddd) $rest';
  return '($ddd) ${rest.substring(0, splitAt)}-${rest.substring(splitAt)}';
}

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

/// Restricts input to letters and digits (optionally capped at [maxLength]) —
/// no dots, dashes, slashes or spaces. Used for RG e Matrícula: o backend
/// rejeita qualquer pontuação nesses dois campos (regex alfanumérico puro), e o
/// RG varia de formato por estado (letras misturadas, tamanhos diferentes),
/// então uma máscara fixa não serve para nenhum dos dois.
class AlphanumericInputFormatter extends TextInputFormatter {
  AlphanumericInputFormatter({this.maxLength});

  final int? maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final cap = maxLength;
    if (cap != null && text.length > cap) {
      text = text.substring(0, cap);
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
