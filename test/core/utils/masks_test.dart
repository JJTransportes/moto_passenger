import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/utils/masks.dart';

TextEditingValue _format(TextInputFormatter f, String input) =>
    f.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: input),
    );

void main() {
  group('AlphanumericInputFormatter', () {
    test('remove pontuação e espaços ao digitar', () {
      final f = AlphanumericInputFormatter(maxLength: 12);
      expect(_format(f, '12.345.678-9').text, '123456789');
    });

    test('respeita o maxLength', () {
      final f = AlphanumericInputFormatter(maxLength: 12);
      expect(_format(f, '1234567890123456').text, '123456789012');
    });

    test('preserva letras', () {
      final f = AlphanumericInputFormatter(maxLength: 30);
      expect(_format(f, 'ABC-123').text, 'ABC123');
    });
  });

  group('unmask', () {
    test('unmaskDigits mantém só dígitos', () {
      expect(unmaskDigits('000.000.000-00'), '00000000000');
    });

    test('unmaskRg mantém dígitos e X', () {
      expect(unmaskRg('12.345.678-x'), '12345678X');
    });
  });
}
