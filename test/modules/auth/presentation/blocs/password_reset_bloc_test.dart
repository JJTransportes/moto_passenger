import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_confirm_password_reset_usecase.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/password_reset_bloc.dart';
import 'package:result_dart/result_dart.dart';

class MockConfirmPasswordResetUsecase extends Mock
    implements IConfirmPasswordResetUsecase {}

void main() {
  late MockConfirmPasswordResetUsecase mockUsecase;

  setUp(() {
    mockUsecase = MockConfirmPasswordResetUsecase();
  });

  const email = 'maria@moto.com';

  PasswordResetBloc buildBloc() =>
      PasswordResetBloc(mockUsecase, email: email);

  group('PasswordResetBloc', () {
    blocTest<PasswordResetBloc, PasswordResetState>(
      'emite [Submitting, Success] em caso de sucesso',
      build: () {
        when(() => mockUsecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer((_) async => Success(unit));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const ResetConfirmSubmitted(code: '123456', newPassword: 'NovaSenha!'),
      ),
      expect: () => const [
        PasswordResetSubmitting(),
        PasswordResetSuccess(),
      ],
      verify: (_) {
        verify(() => mockUsecase.call(
              email: email,
              code: '123456',
              newPassword: 'NovaSenha!',
            )).called(1);
      },
    );

    blocTest<PasswordResetBloc, PasswordResetState>(
      'emite Error com codeConsumed:true no 409 (ConflictException)',
      build: () {
        when(() => mockUsecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer(
          (_) async => Failure(const ConflictException('Este código já foi utilizado.')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const ResetConfirmSubmitted(code: '123456', newPassword: 'NovaSenha!'),
      ),
      expect: () => const [
        PasswordResetSubmitting(),
        PasswordResetError('Este código já foi utilizado.', codeConsumed: true),
      ],
    );

    blocTest<PasswordResetBloc, PasswordResetState>(
      'emite Error com codeConsumed:false no 400 (ValidationException)',
      build: () {
        when(() => mockUsecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
              newPassword: any(named: 'newPassword'),
            )).thenAnswer(
          (_) async => Failure(const ValidationException('Invalid or expired code.')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const ResetConfirmSubmitted(code: '000000', newPassword: 'x'),
      ),
      expect: () => const [
        PasswordResetSubmitting(),
        PasswordResetError('Invalid or expired code.', codeConsumed: false),
      ],
    );
  });
}
