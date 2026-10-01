import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';

class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final storage = Modular.get<AuthStorage>();
    final token = await storage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Extra key set on retried requests to avoid a second refresh attempt (and
/// therefore an infinite loop) if the retried request also comes back 401
/// (e.g. the freshly-refreshed token is itself rejected by the backend).
const _retriedAfterRefreshKey = 'retriedAfterRefresh';

/// Paths that must never trigger a token-refresh attempt on 401: the
/// refresh call itself would recurse, and a 401 on sign-in simply means
/// wrong credentials (not an expired session).
bool _isAuthEndpoint(String path) => path.contains('/api/auth/');

/// Catches 401 responses from any authenticated endpoint during normal app
/// usage (not just the cold-start flow in `splash_screen.dart`), tries to
/// silently renew the session via [IAuthDatasource.refreshToken] (reusing
/// the same storage-update steps as `SplashScreen._tryRefreshToken`), and
/// retries the original request with the new access token. If the refresh
/// itself fails, forces logout and navigates to `/login` with a message
/// explaining that the session expired.
///
/// Extends [QueuedInterceptor] so concurrent 401s (e.g. several requests
/// in flight when the access token expires) are handled one at a time —
/// only the first triggers a refresh; the others are queued and, once it
/// resolves, retried with the token it produced instead of each starting
/// their own refresh.
class AuthErrorInterceptor extends QueuedInterceptor {
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final requestOptions = err.requestOptions;

    final isUnauthorized = response?.statusCode == 401;
    final isAuthEndpoint = _isAuthEndpoint(requestOptions.path);
    final alreadyRetried =
        requestOptions.extra[_retriedAfterRefreshKey] == true;

    if (!isUnauthorized || isAuthEndpoint || alreadyRetried) {
      handler.next(err);
      return;
    }

    final refreshed = await _tryRefreshToken();
    if (!refreshed) {
      await Modular.get<SignOutService>().signOut(
        message: 'Sua sessão expirou, faça login novamente.',
      );
      handler.next(err);
      return;
    }

    try {
      final storage = Modular.get<AuthStorage>();
      final newToken = await storage.getToken();
      final dio = Modular.get<Dio>();

      final retryOptions = requestOptions.copyWith(
        extra: {
          ...requestOptions.extra,
          _retriedAfterRefreshKey: true,
        },
        headers: {
          ...requestOptions.headers,
          if (newToken != null) 'Authorization': 'Bearer $newToken',
        },
      );

      final retryResponse = await dio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      // Retry itself failed (e.g. still unauthorized, or a network error) —
      // surface the original error to the caller instead of masking it.
      handler.next(err);
    }
  }

  /// Renews the access token using the stored refresh token. Mirrors
  /// `SplashScreen._tryRefreshToken`, which performs the same steps on cold
  /// start; this is the mid-session counterpart. Returns true on success.
  Future<bool> _tryRefreshToken() async {
    try {
      final storage = Modular.get<AuthStorage>();
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final authDatasource = Modular.get<IAuthDatasource>();
      final result = await authDatasource.refreshToken(refreshToken);
      final newRefreshToken = result.refreshToken;
      if (newRefreshToken == null || newRefreshToken.isEmpty) return false;

      final authLocal = Modular.get<AuthLocalRepository>();

      await storage.saveTokens(
        result.accessToken,
        newRefreshToken,
        result.userId,
      );
      await authLocal.updateTokens(
        result.accessToken,
        newRefreshToken,
      );
      return true;
    } on UnauthorizedException {
      // Refresh token expired or revoked — not recoverable.
      return false;
    } on DeviceMismatchException {
      // Token bound to a different device type — not recoverable here.
      return false;
    } catch (_) {
      // Network or other transient error — treat as failed refresh; the
      // caller falls back to forcing logout rather than looping.
      return false;
    }
  }
}

class DioClient {
  DioClient._();

  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.getBaseUrl(),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(AuthInterceptor());
    dio.interceptors.add(AuthErrorInterceptor());
    // Só loga corpo de requisição/resposta em debug. Em release, `requestBody`
    // vazaria dados sensíveis em texto puro (ex.: `newPassword` no fluxo de
    // redefinição de senha, tokens no login).
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
        ),
      );
    }

    return dio;
  }
}
