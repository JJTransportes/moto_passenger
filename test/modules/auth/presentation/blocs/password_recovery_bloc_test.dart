import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_request_password_reset_usecase.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/password_recovery_bloc.dart';
import 'package:result_dart/result_dart.dart';

class MockRequestPasswordResetUsecase extends Mock
    implements IRequestPasswordResetUsecase {}

void main() {
  late MockRequestPasswordResetUsecase mockUsecase;

  setUp(() {
    mockUsecase = MockRequestPasswordResetUsecase();
  });

  const email = 'maria@moto.com';

  group('PasswordRecoveryBloc', () {
    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'emite [Loading, Sent] em caso de sucesso',
      build: () {
        when(() => mockUsecase.call(any()))
            .thenAnswer((_) async => Success(unit));
        return PasswordRecoveryBloc(mockUsecase);
      },
      act: (bloc) => bloc.add(const RequestCodeSubmitted(email)),
      expect: () => const [
        PasswordRecoveryLoading(),
        PasswordRecoverySent(email),
      ],
      verify: (_) {
        verify(() => mockUsecase.call(email)).called(1);
      },
    );

    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'emite [Loading, Error] com a mensagem de rate limit no 429',
      build: () {
        when(() => mockUsecase.call(any())).thenAnswer(
          (_) async => Failure(const RateLimitedException()),
        );
        return PasswordRecoveryBloc(mockUsecase);
      },
      act: (bloc) => bloc.add(const RequestCodeSubmitted(email)),
      expect: () => const [
        PasswordRecoveryLoading(),
        PasswordRecoveryError('Muitas tentativas. Tente novamente mais tarde.'),
      ],
    );

    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'emite [Loading, Error] genérico em falha de rede',
      build: () {
        when(() => mockUsecase.call(any())).thenAnswer(
          (_) async => Failure(const NetworkException()),
        );
        return PasswordRecoveryBloc(mockUsecase);
      },
      act: (bloc) => bloc.add(const RequestCodeSubmitted(email)),
      expect: () => const [
        PasswordRecoveryLoading(),
        PasswordRecoveryError(
          'Erro ao enviar o código. Verifique sua conexão e tente novamente.',
        ),
      ],
    );
  });
}
