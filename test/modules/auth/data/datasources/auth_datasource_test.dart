import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/device/device_platform.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/data/datasources/auth_datasource.dart';
import 'package:moto_passenger/modules/auth/data/models/sign_in_response_model.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AuthDatasource datasource;

  setUp(() {
    mockDio = MockDio();
    datasource = AuthDatasource(mockDio);
  });

  tearDown(() {
    DevicePlatform.clearOverride();
  });

  const validResponse = {
    'accessToken': 'tok_123',
    'expiresAt': '2026-06-09T00:15:00Z',
    'userId': 'user_1',
    'roles': ['Passenger'],
  };

  group('signIn', () {
    test('returns SignInResponseModel on success', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: validResponse,
          statusCode: 200,
        ),
      );

      final result = await datasource.signIn('maria@moto.com', '123456');

      expect(result, isA<SignInResponseModel>());
      expect(result.accessToken, 'tok_123');
      expect(result.userId, 'user_1');
      expect(result.roles, ['Passenger']);
      expect(result.expiresAt, DateTime.utc(2026, 6, 9, 0, 15));

      verify(() => mockDio.post(
            '/api/auth/sign-in',
            data: {'email': 'maria@moto.com', 'password': '123456'},
          )).called(1);
    });

    test('throws UnauthorizedException on 401', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 401,
          ),
        ),
      );

      expect(
        () => datasource.signIn('maria@moto.com', 'wrong'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws NotFoundException on 404', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 404,
          ),
        ),
      );

      expect(
        () => datasource.signIn('unknown@moto.com', '123'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('throws ValidationException on 400', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 400,
          ),
        ),
      );

      expect(
        () => datasource.signIn('', ''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws RateLimitedException on 429', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 429,
          ),
        ),
      );

      expect(
        () => datasource.signIn('maria@moto.com', '123'),
        throwsA(isA<RateLimitedException>()),
      );
    });

    test('throws ServerException on 500', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 500,
          ),
        ),
      );

      expect(
        () => datasource.signIn('maria@moto.com', '123'),
        throwsA(isA<ServerException>()),
      );
    });

    test('includes device in request body on mobile platform', () async {
      DevicePlatform.overrideForTesting('android');
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: validResponse,
          statusCode: 200,
        ),
      );

      await datasource.signIn('maria@moto.com', '123456');

      verify(() => mockDio.post(
            '/api/auth/sign-in',
            data: {'email': 'maria@moto.com', 'password': '123456', 'device': 'android'},
          )).called(1);
    });

    test('throws DeviceConflictException on 409 (session on other device type)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 409,
          ),
        ),
      );

      expect(
        () => datasource.signIn('maria@moto.com', '123456'),
        throwsA(isA<DeviceConflictException>()),
      );
    });

    test('throws NetworkException on connection error', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => datasource.signIn('maria@moto.com', '123'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('refreshToken', () {
    const refreshResponse = {
      'accessToken': 'new_tok_456',
      'refreshToken': 'new_ref_789',
      'expiresAt': '2026-07-16T12:00:00Z',
      'refreshExpiresAt': '2026-08-16T12:00:00Z',
      'userId': 'user_1',
      'roles': ['Passenger'],
    };

    test('returns SignInResponseModel on success', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: refreshResponse,
          statusCode: 200,
        ),
      );

      final result = await datasource.refreshToken('old_ref_123');

      expect(result, isA<SignInResponseModel>());
      expect(result.accessToken, 'new_tok_456');
      expect(result.refreshToken, 'new_ref_789');
      expect(result.userId, 'user_1');
      expect(result.refreshExpiresAt, DateTime.utc(2026, 8, 16, 12, 0));

      final captured = verify(() => mockDio.post(
            captureAny(),
            data: captureAny(named: 'data'),
            options: captureAny(named: 'options'),
          )).captured;

      expect(captured[0], '/api/auth/refresh');
      expect(captured[1], {'refreshToken': 'old_ref_123'});
      final options = captured[2] as Options;
      expect(options.extra?['noAuth'], isTrue);
    });

    test('throws UnauthorizedException on 401', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 401,
          ),
        ),
      );

      expect(
        () => datasource.refreshToken('expired_ref'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('includes device in request body on mobile platform', () async {
      DevicePlatform.overrideForTesting('ios');
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: refreshResponse,
          statusCode: 200,
        ),
      );

      await datasource.refreshToken('old_ref_123');

      final captured = verify(() => mockDio.post(
            captureAny(),
            data: captureAny(named: 'data'),
            options: captureAny(named: 'options'),
          )).captured;

      expect(captured[0], '/api/auth/refresh');
      expect(captured[1], {'refreshToken': 'old_ref_123', 'device': 'ios'});
      final options = captured[2] as Options;
      expect(options.extra?['noAuth'], isTrue);
    });

    test('throws DeviceMismatchException on 403 (token bound to other device type)', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 403,
          ),
        ),
      );

      expect(
        () => datasource.refreshToken('old_ref'),
        throwsA(isA<DeviceMismatchException>()),
      );
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => datasource.refreshToken('old_ref'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws NetworkException on connection error', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => datasource.refreshToken('old_ref'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('signOut', () {
    test('calls POST /api/auth/sign-out and succeeds on 204', () async {
      when(() => mockDio.post(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 204,
        ),
      );

      await datasource.signOut();

      verify(() => mockDio.post('/api/auth/sign-out')).called(1);
    });

    test('throws UnauthorizedException on 401 (expired access token)', () async {
      when(() => mockDio.post(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 401,
          ),
        ),
      );

      expect(
        () => datasource.signOut(),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}
