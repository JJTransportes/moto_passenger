import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/domain/entities/password_policy_entity.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_get_password_policy_usecase.dart';
import 'package:moto_passenger/modules/auth/presentation/cubits/password_policy_cubit.dart';
import 'package:result_dart/result_dart.dart';

class MockGetPasswordPolicyUsecase extends Mock
    implements IGetPasswordPolicyUsecase {}

void main() {
  late MockGetPasswordPolicyUsecase mockUsecase;

  setUp(() {
    mockUsecase = MockGetPasswordPolicyUsecase();
  });

  group('PasswordPolicyCubit', () {
    test('estado inicial é o fallback', () {
      final cubit = PasswordPolicyCubit(mockUsecase);
      expect(cubit.state, PasswordPolicy.fallback);
    });

    blocTest<PasswordPolicyCubit, PasswordPolicy>(
      'emite a política do servidor quando a busca tem sucesso',
      build: () {
        const serverPolicy = PasswordPolicy(
          minLength: 10,
          maxLength: 64,
          requireUppercase: true,
          requireLowercase: true,
          requireDigit: true,
          requireSpecialChar: false,
        );
        when(() => mockUsecase.call())
            .thenAnswer((_) async => const Success(serverPolicy));
        return PasswordPolicyCubit(mockUsecase);
      },
      act: (cubit) => cubit.load(),
      expect: () => const [
        PasswordPolicy(
          minLength: 10,
          maxLength: 64,
          requireUppercase: true,
          requireLowercase: true,
          requireDigit: true,
          requireSpecialChar: false,
        ),
      ],
    );

    blocTest<PasswordPolicyCubit, PasswordPolicy>(
      'emite o fallback quando a busca falha',
      build: () {
        when(() => mockUsecase.call())
            .thenAnswer((_) async => const Failure(NetworkException()));
        return PasswordPolicyCubit(mockUsecase);
      },
      act: (cubit) => cubit.load(),
      expect: () => const [PasswordPolicy.fallback],
    );
  });
}
