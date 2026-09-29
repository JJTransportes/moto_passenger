import 'package:flutter_test/flutter_test.dart';
import 'package:moto_passenger/core/utils/password_policy_validator.dart';
import 'package:moto_passenger/modules/auth/domain/entities/password_policy_entity.dart';

void main() {
  const policy = PasswordPolicy.fallback;

  group('unmetPasswordRequirements', () {
    test('retorna vazio quando a senha atende a todos os requisitos', () {
      expect(unmetPasswordRequirements('Abcdef1!', policy), isEmpty);
    });

    test('acusa tamanho mínimo não atingido', () {
      expect(
        unmetPasswordRequirements('Ab1!', policy),
        contains('Entre 8 e 72 caracteres'),
      );
    });

    test('acusa tamanho máximo excedido', () {
      final tooLong = 'Ab1!${'a' * 70}';
      expect(
        unmetPasswordRequirements(tooLong, policy),
        contains('Entre 8 e 72 caracteres'),
      );
    });

    test('acusa falta de maiúscula', () {
      expect(
        unmetPasswordRequirements('abcdef1!', policy),
        contains('Pelo menos 1 letra maiúscula'),
      );
    });

    test('acusa falta de minúscula', () {
      expect(
        unmetPasswordRequirements('ABCDEF1!', policy),
        contains('Pelo menos 1 letra minúscula'),
      );
    });

    test('acusa falta de número', () {
      expect(
        unmetPasswordRequirements('Abcdefg!', policy),
        contains('Pelo menos 1 número'),
      );
    });

    test('acusa falta de caractere especial', () {
      expect(
        unmetPasswordRequirements('Abcdefg1', policy),
        contains('Pelo menos 1 caractere especial (ex: ! @ # \$ % &)'),
      );
    });

    test('não exige regras desabilitadas na política', () {
      const looseAndPolicy = PasswordPolicy(
        minLength: 4,
        maxLength: 20,
        requireUppercase: false,
        requireLowercase: false,
        requireDigit: false,
        requireSpecialChar: false,
      );
      expect(unmetPasswordRequirements('abcd', looseAndPolicy), isEmpty);
    });
  });

  group('passwordRequirementsStatus', () {
    test('retorna a lista completa de requisitos, com met por item', () {
      final status = passwordRequirementsStatus('abcdef1!', policy);

      expect(status, hasLength(5));
      expect(
        status.map((r) => r.met).toList(),
        [true, false, true, true, true],
      );
    });
  });
}
