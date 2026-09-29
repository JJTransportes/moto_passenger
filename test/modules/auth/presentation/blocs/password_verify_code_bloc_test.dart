import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_verify_password_reset_code_usecase.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/password_verify_code_bloc.dart';
import 'package:result_dart/result_dart.dart';

class MockVerifyPasswordResetCodeUsecase extends Mock
    implements IVerifyPasswordResetCodeUsecase {}

void main() {
  late MockVerifyPasswordResetCodeUsecase mockUsecase;

  setUp(() {
    mockUsecase = MockVerifyPasswordResetCodeUsecase();
  });

  const email = 'maria@moto.com';

  PasswordVerifyCodeBloc buildBloc() =>
      PasswordVerifyCodeBloc(mockUsecase, email: email);

  group('PasswordVerifyCodeBloc', () {
    blocTest<PasswordVerifyCodeBloc, PasswordVerifyCodeState>(
      'emite [Submitting, Success(resetToken)] em caso de sucesso',
      build: () {
        when(() => mockUsecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
            )).thenAnswer((_) async => Success('token-abc'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CodeSubmitted('123456')),
      expect: () => const [
        PasswordVerifyCodeSubmitting(),
        PasswordVerifyCodeSuccess('token-abc'),
      ],
      verify: (_) {
        verify(() => mockUsecase.call(email: email, code: '123456')).called(1);
      },
    );

    blocTest<PasswordVerifyCodeBloc, PasswordVerifyCodeState>(
      'emite Error com requestNewCode:true no 409 (ConflictException)',
      build: () {
        when(() => mockUsecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
            )).thenAnswer(
          (_) async => Failure(const ConflictException('Este código já foi utilizado.')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CodeSubmitted('123456')),
      expect: () => const [
        PasswordVerifyCodeSubmitting(),
        PasswordVerifyCodeError(
          'Este código já foi utilizado.',
          requestNewCode: true,
        ),
      ],
    );

    blocTest<PasswordVerifyCodeBloc, PasswordVerifyCodeState>(
      'emite Error com requestNewCode:true no 429 (RateLimitedException)',
      build: () {
        when(() => mockUsecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
            )).thenAnswer(
          (_) async => Failure(const RateLimitedException('Muitas tentativas.')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CodeSubmitted('123456')),
      expect: () => const [
        PasswordVerifyCodeSubmitting(),
        PasswordVerifyCodeError('Muitas tentativas.', requestNewCode: true),
      ],
    );

    blocTest<PasswordVerifyCodeBloc, PasswordVerifyCodeState>(
      'emite Error com requestNewCode:false no 400 (ValidationException)',
      build: () {
        when(() => mockUsecase.call(
              email: any(named: 'email'),
              code: any(named: 'code'),
            )).thenAnswer(
          (_) async => Failure(const ValidationException('Invalid or expired code.')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CodeSubmitted('000000')),
      expect: () => const [
        PasswordVerifyCodeSubmitting(),
        PasswordVerifyCodeError('Invalid or expired code.', requestNewCode: false),
      ],
    );
  });
}
