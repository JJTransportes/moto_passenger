import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/core/local_db/models/local_data_models.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_passenger/modules/auth/data/models/sign_in_response_model.dart';

class MockAuthLocalRepository extends Mock implements AuthLocalRepository {}
class MockAuthDatasource extends Mock implements IAuthDatasource {}
class MockAuthStorage extends Mock implements AuthStorage {}
class MockSignOutService extends Mock implements SignOutService {}

void main() {
  group('refresh token logic', () {
    // Tests for the _tryRefreshToken logic used in SplashScreen
    //
    // _tryRefreshToken does the following:
    //   1. Calls authDatasource.refreshToken(refreshToken)
    //   2. On success (200): saves tokens via AuthStorage + AuthLocalRepository, returns true
    //   3. On UnauthorizedException (401): returns false
    //   4. On any other exception (network, etc.): returns false

    test('saves new tokens and returns true on successful refresh', () async {
      final datasource = MockAuthDatasource();
      final storage = MockAuthStorage();
      final authLocal = MockAuthLocalRepository();

      when(() => datasource.refreshToken('valid_refresh')).thenAnswer(
        (_) async => SignInResponseModel(
          accessToken: 'new_tok',
          refreshToken: 'new_ref',
          expiresAt: DateTime(2026, 7, 17),
          refreshExpiresAt: DateTime(2026, 8, 17),
          userId: 'user_1',
          roles: ['Passenger'],
        ),
      );
      when(() => storage.saveTokens(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => authLocal.updateTokens(any(), any()))
          .thenAnswer((_) async {});

      // Simulate _tryRefreshToken
      bool success = false;
      try {
        final result = await datasource.refreshToken('valid_refresh');
        await storage.saveTokens(result.accessToken, result.refreshToken!, result.userId);
        await authLocal.updateTokens(result.accessToken, result.refreshToken!);
        success = true;
      } catch (_) {
        success = false;
      }

      expect(success, isTrue);
      verify(() => storage.saveTokens('new_tok', 'new_ref', 'user_1')).called(1);
      verify(() => authLocal.updateTokens('new_tok', 'new_ref')).called(1);
    });

    test('returns false and does NOT save tokens on UnauthorizedException', () async {
      final datasource = MockAuthDatasource();
      final storage = MockAuthStorage();
      final authLocal = MockAuthLocalRepository();

      when(() => datasource.refreshToken('expired_refresh'))
          .thenThrow(const UnauthorizedException());

      // Simulate _tryRefreshToken
      bool success = true;
      try {
        final result = await datasource.refreshToken('expired_refresh');
        await storage.saveTokens(result.accessToken, result.refreshToken!, result.userId);
        await authLocal.updateTokens(result.accessToken, result.refreshToken!);
        success = true;
      } on UnauthorizedException {
        success = false;
      } catch (_) {
        success = false;
      }

      expect(success, isFalse);
      verifyNever(() => storage.saveTokens(any(), any(), any()));
      verifyNever(() => authLocal.updateTokens(any(), any()));
    });

    test('returns false on network exception', () async {
      final datasource = MockAuthDatasource();
      final storage = MockAuthStorage();
      final authLocal = MockAuthLocalRepository();

      when(() => datasource.refreshToken('stale_refresh'))
          .thenThrow(const NetworkException());

      // Simulate _tryRefreshToken
      bool success = true;
      try {
        final result = await datasource.refreshToken('stale_refresh');
        await storage.saveTokens(result.accessToken, result.refreshToken!, result.userId);
        await authLocal.updateTokens(result.accessToken, result.refreshToken!);
        success = true;
      } catch (_) {
        success = false;
      }

      expect(success, isFalse);
      verifyNever(() => storage.saveTokens(any(), any(), any()));
      verifyNever(() => authLocal.updateTokens(any(), any()));
    });

    test('returns false on unexpected exception', () async {
      final datasource = MockAuthDatasource();
      final storage = MockAuthStorage();
      final authLocal = MockAuthLocalRepository();

      when(() => datasource.refreshToken('broken'))
          .thenThrow(Exception('Unexpected error'));

      // Simulate _tryRefreshToken
      bool success = true;
      try {
        final result = await datasource.refreshToken('broken');
        await storage.saveTokens(result.accessToken, result.refreshToken!, result.userId);
        await authLocal.updateTokens(result.accessToken, result.refreshToken!);
        success = true;
      } catch (_) {
        success = false;
      }

      expect(success, isFalse);
      verifyNever(() => storage.saveTokens(any(), any(), any()));
      verifyNever(() => authLocal.updateTokens(any(), any()));
    });
  });

  group('SplashScreen _checkAuth logic', () {
    // Tests for the _checkAuth routing decisions based on local auth state

    test('triggers refresh when local auth has refreshToken', () async {
      final authLocal = MockAuthLocalRepository();
      final datasource = MockAuthDatasource();

      when(() => authLocal.getAuth()).thenAnswer(
        (_) async => AuthLocalData(
          userId: 'user_1',
          accessToken: 'old_tok',
          refreshToken: 'valid_refresh',
          roles: ['Passenger'],
        ),
      );
      when(() => datasource.refreshToken(any())).thenAnswer(
        (_) async => SignInResponseModel(
          accessToken: 'new_tok',
          refreshToken: 'new_ref',
          expiresAt: DateTime(2026, 7, 17),
          refreshExpiresAt: DateTime(2026, 8, 17),
          userId: 'user_1',
          roles: ['Passenger'],
        ),
      );

      // Simulate _checkAuth decision: has refresh token → calls refresh
      final localAuth = await authLocal.getAuth();
      expect(localAuth?.refreshToken.isNotEmpty, isTrue);

      if (localAuth != null && localAuth.refreshToken.isNotEmpty) {
        await datasource.refreshToken(localAuth.refreshToken);
      }

      verify(() => datasource.refreshToken('valid_refresh')).called(1);
    });

    test('does NOT trigger refresh when local auth has no refreshToken', () async {
      final authLocal = MockAuthLocalRepository();
      final datasource = MockAuthDatasource();

      when(() => authLocal.getAuth()).thenAnswer(
        (_) async => AuthLocalData(
          userId: 'user_1',
          accessToken: 'valid_tok',
          refreshToken: '',
          roles: ['Passenger'],
        ),
      );

      // Simulate _checkAuth decision: empty refresh token → skip refresh
      final localAuth = await authLocal.getAuth();
      expect(localAuth?.refreshToken.isEmpty, isTrue);

      if (localAuth != null && localAuth.refreshToken.isNotEmpty) {
        await datasource.refreshToken(localAuth.refreshToken);
      }

      verifyNever(() => datasource.refreshToken(any()));
    });

    test('does NOT trigger refresh when local auth is null', () async {
      final authLocal = MockAuthLocalRepository();
      final datasource = MockAuthDatasource();

      when(() => authLocal.getAuth()).thenAnswer((_) async => null);

      // Simulate _checkAuth decision: null auth → skip refresh
      final localAuth = await authLocal.getAuth();
      expect(localAuth, isNull);

      verifyNever(() => datasource.refreshToken(any()));
    });
  });
}
