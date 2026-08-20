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
            data: {'email': 'maria@moto.com'},
          )).called(1);
    });

    test('trata 404 como sucesso (anti-enumeração) — não lança', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenThrow(dioError(404));

      await expectLater(
        datasource.requestPasswordReset('desconhecido@moto.com'),
        completes,
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
          email: 'maria@moto.com',
          code: '123456',
          newPassword: 'NovaSenha!',
        ),
        completes,
      );

      verify(() => mockDio.post(
            '/api/auth/password-reset/confirm',
            data: {
              'email': 'maria@moto.com',
              'code': '123456',
              'newPassword': 'NovaSenha!',
            },
          )).called(1);
    });

    test('lança ValidationException com a mensagem do servidor no 400', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        dioError(400, data: {'error': 'Invalid or expired code.'}),
      );

      expect(
        () => datasource.confirmPasswordReset(
          email: 'maria@moto.com',
          code: '000000',
          newPassword: 'x',
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
        () => datasource.confirmPasswordReset(
          email: 'maria@moto.com',
          code: '123456',
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
          email: 'maria@moto.com',
          code: '123456',
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
          email: 'maria@moto.com',
          code: '123456',
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
          email: 'maria@moto.com',
          code: '123456',
          newPassword: 'x',
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
