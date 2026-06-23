import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_passenger/modules/auth/data/models/sign_in_response_model.dart';
import 'package:moto_passenger/modules/auth/data/repositories/auth_repository.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';
import 'package:result_dart/result_dart.dart';

void main() {
  late MockAuthDatasource mockDatasource;
  late AuthRepository repository;

  setUp(() {
    mockDatasource = MockAuthDatasource();
    repository = AuthRepository(mockDatasource);
  });

  group('signIn', () {
    final model = SignInResponseModel(
      accessToken: 'tok_123',
      expiresAt: DateTime(2026, 6, 9, 0, 15),
      userId: 'user_1',
      roles: ['Passenger'],
    );

    test('returns Success with UserEntity on datasource success', () async {
      when(() => mockDatasource.signIn(any(), any())).thenAnswer((_) async => model);

      final result = await repository.signIn('maria@moto.com', '123456');

      expect(result, isA<Result<UserEntity>>());
      result.fold(
        (user) {
          expect(user.id, 'user_1');
          expect(user.token, 'tok_123');
          expect(user.roles, ['Passenger']);
          expect(user.isPassenger, isTrue);
        },
        (_) => fail('Expected success'),
      );
    });

    test('returns Failure on UnauthorizedException', () async {
      when(() => mockDatasource.signIn(any(), any())).thenThrow(
        const UnauthorizedException('E-mail ou senha inválidos'),
      );

      final result = await repository.signIn('maria@moto.com', 'wrong');

      expect(result, isA<Result<UserEntity>>());
      result.fold(
        (_) => fail('Expected failure'),
        (error) {
          expect(error, isA<UnauthorizedException>());
          expect(error.toString(), 'E-mail ou senha inválidos');
        },
      );
    });

    test('returns Failure on NetworkException', () async {
      when(() => mockDatasource.signIn(any(), any())).thenThrow(const NetworkException());

      final result = await repository.signIn('maria@moto.com', '123');

      expect(result, isA<Result<UserEntity>>());
      result.fold(
        (_) => fail('Expected failure'),
        (error) => expect(error, isA<NetworkException>()),
      );
    });
  });
}

class MockAuthDatasource extends Mock implements IAuthDatasource {}
