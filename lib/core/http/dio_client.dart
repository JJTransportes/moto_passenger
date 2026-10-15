import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ObservabilityInterceptor extends Interceptor {
  static final _uuidSegment = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  String _normalizedPath(Uri uri) => uri.pathSegments
      .map(
        (segment) =>
            _uuidSegment.hasMatch(segment) || int.tryParse(segment) != null
            ? '{id}'
            : segment,
      )
      .join('/');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(
      'X-Correlation-ID',
      () => '${DateTime.now().microsecondsSinceEpoch}-${options.hashCode}',
    );
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    if (status == null || status >= 500) {
      Sentry.captureException(
        StateError('HTTP request failed: ${err.type.name}'),
        stackTrace: err.stackTrace,
        withScope: (scope) {
          scope.setTag('http.method', err.requestOptions.method);
          scope.setTag('http.path', _normalizedPath(err.requestOptions.uri));
          scope.setTag('http.status_code', status?.toString() ?? 'network');
          scope.setTag(
            'correlation_id',
            err.requestOptions.headers['X-Correlation-ID']?.toString() ?? '',
          );
        },
      );
    }
    handler.next(err);
  }
}

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

enum _RefreshOutcome { success, invalidSession, transientFailure }

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

    final refreshOutcome = await _tryRefreshToken();
    if (refreshOutcome == _RefreshOutcome.invalidSession) {
      await Modular.get<SignOutService>().signOut(
        message: 'Sua sessão expirou, faça login novamente.',
      );
      handler.next(err);
      return;
    }
    if (refreshOutcome == _RefreshOutcome.transientFailure) {
      // Sem internet/timeout/erro 5xx não significa sessão expirada. Mantém
      // tokens, viagem ativa e identificação do push para tentar novamente
      // quando a conexão voltar.
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
  /// start; this is the mid-session counterpart. Distingue rejeição definitiva
  /// do token de indisponibilidade temporária da rede/servidor.
  Future<_RefreshOutcome> _tryRefreshToken() async {
    try {
      final storage = Modular.get<AuthStorage>();
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return _RefreshOutcome.invalidSession;
      }

      final authDatasource = Modular.get<IAuthDatasource>();
      final result = await authDatasource.refreshToken(refreshToken);
      final newRefreshToken = result.refreshToken;
      if (newRefreshToken == null || newRefreshToken.isEmpty) {
        return _RefreshOutcome.invalidSession;
      }

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
      return _RefreshOutcome.success;
    } on UnauthorizedException {
      // Refresh token expired or revoked — not recoverable.
      return _RefreshOutcome.invalidSession;
    } on ValidationException {
      // O backend responde 400 para refresh expirado/inválido/reutilizado.
      return _RefreshOutcome.invalidSession;
    } on DeviceMismatchException {
      // Token bound to a different device type — not recoverable here.
      return _RefreshOutcome.invalidSession;
    } catch (_) {
      return _RefreshOutcome.transientFailure;
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
    dio.interceptors.add(ObservabilityInterceptor());
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
