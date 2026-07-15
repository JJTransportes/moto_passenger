import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_login_usecase.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:result_dart/result_dart.dart';

void main() {
  late MockLoginUsecase mockUsecase;
  late MockAuthStorage mockAuthStorage;
  late MockAuthLocalRepository mockAuthLocal;

  setUp(() {
    mockUsecase = MockLoginUsecase();
    mockAuthStorage = MockAuthStorage();
    mockAuthLocal = MockAuthLocalRepository();
  });

  const user = UserEntity(
    id: 'user_1',
    token: 'tok_123',
    roles: ['Passenger'],
  );

  group('LoginBloc', () {
    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginSuccess] when login succeeds and persists token',
      build: () {
        when(() => mockUsecase.call(any(), any()))
            .thenAnswer((_) async => Success(user));
        when(() => mockAuthStorage.saveTokens(any(), any(), any()))
            .thenAnswer((_) async {});
        when(() => mockAuthLocal.saveAuth(
              userId: any(named: 'userId'),
              accessToken: any(named: 'accessToken'),
              refreshToken: any(named: 'refreshToken'),
              roles: any(named: 'roles'),
            )).thenAnswer((_) async {});
        return LoginBloc(mockUsecase, mockAuthStorage, mockAuthLocal);
      },
      act: (bloc) => bloc.add(
        const LoginSubmitted(email: 'maria@moto.com', password: '123456'),
      ),
      expect: () => [
        const LoginLoading(),
        isA<LoginSuccess>(),
      ],
      verify: (_) {
        verify(() => mockAuthStorage.saveTokens('tok_123', '', 'user_1'))
            .called(1);
        verify(() => mockAuthLocal.saveAuth(
              userId: 'user_1',
              accessToken: 'tok_123',
              refreshToken: '',
              roles: ['Passenger'],
            )).called(1);
      },
    );

    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginFailure] when login fails and does not persist',
      build: () {
        when(() => mockUsecase.call(any(), any())).thenAnswer(
          (_) async => Failure(Exception('E-mail ou senha inválidos')),
        );
        return LoginBloc(mockUsecase, mockAuthStorage, mockAuthLocal);
      },
      act: (bloc) => bloc.add(
        const LoginSubmitted(email: 'maria@moto.com', password: 'wrong'),
      ),
      expect: () => [
        const LoginLoading(),
        isA<LoginFailure>(),
      ],
      verify: (_) {
        verifyNever(() => mockAuthStorage.saveTokens(any(), any(), any()));
        verifyNever(() => mockAuthLocal.saveAuth(
              userId: any(named: 'userId'),
              accessToken: any(named: 'accessToken'),
              refreshToken: any(named: 'refreshToken'),
              roles: any(named: 'roles'),
            ));
      },
    );

    blocTest<LoginBloc, LoginState>(
      'calls usecase with correct credentials',
      build: () {
        when(() => mockUsecase.call(any(), any()))
            .thenAnswer((_) async => Success(user));
        when(() => mockAuthStorage.saveTokens(any(), any(), any()))
            .thenAnswer((_) async {});
        when(() => mockAuthLocal.saveAuth(
              userId: any(named: 'userId'),
              accessToken: any(named: 'accessToken'),
              refreshToken: any(named: 'refreshToken'),
              roles: any(named: 'roles'),
            )).thenAnswer((_) async {});
        return LoginBloc(mockUsecase, mockAuthStorage, mockAuthLocal);
      },
      act: (bloc) => bloc.add(
        const LoginSubmitted(
          email: 'passenger@moto.com',
          password: 'secret123',
        ),
      ),
      verify: (_) {
        verify(() => mockUsecase.call('passenger@moto.com', 'secret123'))
            .called(1);
      },
    );
  });
}

class MockAuthStorage extends Mock implements AuthStorage {}

class MockAuthLocalRepository extends Mock implements AuthLocalRepository {}

class MockLoginUsecase extends Mock implements ILoginUsecase {}
