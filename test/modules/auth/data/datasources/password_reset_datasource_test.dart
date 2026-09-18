import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/data/datasources/auth_datasource.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AuthDatasource datasource;

  setUp(() {
    mockDio = MockDio();
    datasource = AuthDatasource(mockDio);
  });

  DioException dioError(int statusCode, {Object? data}) => DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: statusCode,
          data: data,
        ),
      );

  group('requestPasswordReset', () {
    test('completa sem erro no 202', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 202,
        ),
      );

      await expectLater(
        datasource.requestPasswordReset('maria@moto.com'),
        completes,
      );

      verify(() => mockDio.post(
            '/api/auth/password-reset/request',
            data: {'email': 'maria@moto.com', 'expectedRole': 'Passenger'},
          )).called(1);
    });

    test('lança NotFoundException com a mensagem do servidor no 404', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        dioError(404, data: {'error': 'Email não cadastrado.'}),
      );

      expect(
        () => datasource.requestPasswordReset('desconhecido@moto.com'),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.message,
            'message',
            'Email não cadastrado.',
          ),
        ),
      );
    });

    test('lança RateLimitedException no 429', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenThrow(dioError(429));

      expect(
        () => datasource.requestPasswordReset('maria@moto.com'),
        throwsA(isA<RateLimitedException>()),
      );
    });

    test('lança NetworkException em connectionError', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => datasource.requestPasswordReset('maria@moto.com'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('verifyPasswordResetCode', () {
    test('retorna o resetToken no 200', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {'resetToken': 'token-abc'},
        ),
      );

      final resetToken = await datasource.verifyPasswordResetCode(
        email: 'maria@moto.com',
        code: '123456',
      );

      expect(resetToken, 'token-abc');
      verify(() => mockDio.post(
            '/api/auth/password-reset/verify-code',
            data: {'email': 'maria@moto.com', 'code': '123456'},
          )).called(1);
    });

    test('lança ValidationException com a mensagem do servidor no 400', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        dioError(400, data: {'error': 'Invalid or expired code.'}),
      );

      expect(
        () => datasource.verifyPasswordResetCode(
          email: 'maria@moto.com',
          code: '000000',
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Invalid or expired code.',
          ),
        ),
      );
    });

    test('lança ConflictException no 409', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        dioError(409, data: {'error': 'Code already used.'}),
      );

      expect(
        () => datasource.verifyPasswordResetCode(
          email: 'maria@moto.com',
          code: '123456',
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test('lança RateLimitedException no 429', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        dioError(429, data: {'error': 'Too many attempts.'}),
      );

      expect(
        () => datasource.verifyPasswordResetCode(
          email: 'maria@moto.com',
          code: '123456',
        ),
        throwsA(isA<RateLimitedException>()),
      );
    });
  });

  group('confirmPasswordReset', () {
    test('completa sem erro no 200', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
        ),
      );

      await expectLater(
        datasource.confirmPasswordReset(
          resetToken: 'token-abc',
          newPassword: 'NovaSenha!',
        ),
        completes,
      );

      verify(() => mockDio.post(
            '/api/auth/password-reset/confirm',
            data: {
              'resetToken': 'token-abc',
              'newPassword': 'NovaSenha!',
            },
          )).called(1);
    });

    test('lança ValidationException com a mensagem do servidor no 400', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        dioError(400, data: {'error': 'Invalid or expired token.'}),
      );

      expect(
        () => datasource.confirmPasswordReset(
          resetToken: 'token-expirado',
          newPassword: 'x',
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Invalid or expired token.',
          ),
        ),
      );
    });

    test('lança ConflictException no 409', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        dioError(409, data: {'error': 'Token already used.'}),
      );

      expect(
        () => datasource.confirmPasswordReset(
          resetToken: 'token-abc',
          newPassword: 'x',
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test('lança RateLimitedException no 429', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenThrow(dioError(429));

      expect(
        () => datasource.confirmPasswordReset(
          resetToken: 'token-abc',
          newPassword: 'x',
        ),
        throwsA(isA<RateLimitedException>()),
      );
    });

    test('lança ServerException no 500', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenThrow(dioError(500));

      expect(
        () => datasource.confirmPasswordReset(
          resetToken: 'token-abc',
          newPassword: 'x',
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('lança NetworkException em timeout', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(
        () => datasource.confirmPasswordReset(
          resetToken: 'token-abc',
          newPassword: 'x',
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('getPasswordPolicy', () {
    test('parseia a política a partir do 200', () async {
      when(() => mockDio.get(any(), options: any(named: 'options'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'minLength': 8,
            'maxLength': 72,
            'requireUppercase': true,
            'requireLowercase': true,
            'requireDigit': true,
            'requireSpecialChar': true,
          },
        ),
      );

      final policy = await datasource.getPasswordPolicy();

      expect(policy.minLength, 8);
      expect(policy.maxLength, 72);
      expect(policy.requireUppercase, true);
      expect(policy.requireSpecialChar, true);
    });
  });
}
