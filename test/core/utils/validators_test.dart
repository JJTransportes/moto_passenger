import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/utils/validators.dart';

void main() {
  group('validateRg', () {
    test('aceita 7 caracteres alfanuméricos (limite inferior)', () {
      expect(validateRg('1234567'), isNull);
    });

    test('aceita 12 caracteres alfanuméricos (limite superior)', () {
      expect(validateRg('12345678901X'), isNull);
    });

    test('aceita dígito verificador com letra', () {
      expect(validateRg('12345678X'), isNull);
    });

    test('rejeita menos de 7 caracteres', () {
      expect(validateRg('123456'), isNotNull);
    });

    test('rejeita mais de 12 caracteres', () {
      expect(validateRg('1234567890123'), isNotNull);
    });

    test('rejeita vazio como obrigatório', () {
      expect(validateRg(''), 'RG obrigatório.');
      expect(validateRg('   '), 'RG obrigatório.');
    });

    test('rejeita pontuação', () {
      expect(validateRg('12.345.678-9'), isNotNull);
    });
  });

  group('validateAlphanumericFormat (Matrícula)', () {
    test('aceita alfanumérico dentro do limite', () {
      expect(validateAlphanumericFormat('ABC123', 'Matrícula', 30), isNull);
    });

    test('aceita até o máximo de 30', () {
      expect(
        validateAlphanumericFormat('A' * 30, 'Matrícula', 30),
        isNull,
      );
    });

    test('rejeita acima do máximo', () {
      expect(
        validateAlphanumericFormat('A' * 31, 'Matrícula', 30),
        isNotNull,
      );
    });

    test('rejeita pontuação', () {
      expect(
        validateAlphanumericFormat('123-45', 'Matrícula', 30),
        isNotNull,
      );
    });
  });
}
