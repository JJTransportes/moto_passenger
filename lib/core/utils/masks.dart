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
