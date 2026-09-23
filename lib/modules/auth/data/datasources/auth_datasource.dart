import 'package:dio/dio.dart';
import 'package:moto_passenger/core/device/device_platform.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_passenger/modules/auth/data/models/password_policy_model.dart';
import 'package:moto_passenger/modules/auth/data/models/sign_in_response_model.dart';

class AuthDatasource implements IAuthDatasource {
  final Dio _dio;

  AuthDatasource(this._dio);

  @override
  Future<SignInResponseModel> signIn(String email, String password) async {
    try {
      final device = DevicePlatform.type;
      final response = await _dio.post(
        '/api/auth/sign-in',
        data: {
          'email': email,
          'password': password,
          if (device != null) 'device': device,
        },
      );
      return SignInResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<SignInResponseModel> refreshToken(String refreshToken) async {
    try {
      final device = DevicePlatform.type;
      final response = await _dio.post(
        '/api/auth/refresh',
        data: {
          'refreshToken': refreshToken,
          if (device != null) 'device': device,
        },
        options: Options(extra: {'noAuth': true}),
      );
      return SignInResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _dio.post('/api/auth/sign-out');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> registerDeviceToken(String playerId, String platform) async {
    await _dio.post('/api/notifications/register-device', data: {
      'playerId': playerId,
      'platform': platform,
    });
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _dio.post(
        '/api/auth/password-reset/request',
        data: {'email': email, 'expectedRole': 'Passenger'},
      );
    } on DioException catch (e) {
      // 404 (e-mail não cadastrado, ou cadastrado só com outra role) é
      // exposto ao usuário de propósito — decisão de segurança do backend,
      // ver .sdd/checklist-email-nao-cadastrado.md. Usa a mensagem do
      // servidor quando disponível.
      if (e.response?.statusCode == 404) {
        throw NotFoundException(
          _extractErrorMessage(e) ?? 'Email não cadastrado.',
        );
      }
      // 403: conta ainda não aprovada pelo GlobalAdmin — bug real encontrado
      // no checklist manual (era possível resetar senha de conta pendente,
      // mas o login continuava recusando sem explicação). Ver
      // BACKEND_CHANGES_TODO.md.
      if (e.response?.statusCode == 403) {
        throw ForbiddenException(
          _extractErrorMessage(e) ?? 'Sua conta ainda não foi aprovada.',
        );
      }
      // 429: rate limit de pedidos de reset (por e-mail ou por IP) — antes
      // vinha sem corpo, agora vem com mensagem. `_mapDioException` usa
      // RateLimitedException() sem argumento (mensagem genérica fixa), então
      // esse caso precisa de tratamento explícito para repassar a mensagem
      // real. Ver BACKEND_CHANGES_TODO.md.
      if (e.response?.statusCode == 429) {
        throw RateLimitedException(
          _extractErrorMessage(e) ??
              'Muitas solicitações de redefinição de senha. Aguarde um pouco antes de tentar novamente.',
        );
      }
      throw _mapDioException(e);
    }
  }

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/password-reset/verify-code',
        data: {'email': email, 'code': code},
      );
      return (response.data as Map<String, dynamic>)['resetToken'] as String;
    } on DioException catch (e) {
      throw _mapPasswordResetException(e);
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/api/auth/password-reset/confirm',
        data: {
          'resetToken': resetToken,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _mapPasswordResetException(e);
    }
  }

  @override
  Future<PasswordPolicyModel> getPasswordPolicy() async {
    final response = await _dio.get(
      '/api/auth/password-policy',
      options: Options(extra: {'noAuth': true}),
    );
    return PasswordPolicyModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// O 400 de `verify-code`/`confirm` cobre motivos distintos (código/token
  /// inválido ou expirado, ou senha fora da política) — só a mensagem do
  /// servidor (campo `error`) distingue os casos, então ela é repassada como
  /// está em vez de um texto genérico fixo. Reaproveitado pelos dois endpoints
  /// porque têm o mesmo shape de erro.
  Exception _mapPasswordResetException(DioException e) {
    final serverMessage = _extractErrorMessage(e);
    switch (e.response?.statusCode) {
      case 400:
        return ValidationException(
          serverMessage ?? 'Código inválido ou senha não atende aos requisitos.',
        );
      case 409:
        return ConflictException(
          serverMessage ?? 'Este código já foi utilizado.',
        );
      case 429:
        return RateLimitedException(
          serverMessage ?? 'Muitas tentativas. Tente novamente mais tarde.',
        );
      case var code when code != null && code >= 500:
        return const ServerException();
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          return const NetworkException();
        }
        return NetworkException(e.message ?? 'Erro inesperado');
    }
  }

  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return null;
  }

  Exception _mapDioException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        return const ValidationException(
          'Dados inválidos. Verifique as informações.',
        );
      case 401:
        // Conta pendente de aprovação agora vem com corpo {"error": "..."}
        // (antes vinha 401 sem corpo, igual senha errada). Login com senha
        // errada em conta normal continua sem corpo — cai no fallback padrão,
        // sem mudança de comportamento. Ver BACKEND_CHANGES_TODO.md.
        return UnauthorizedException(
          _extractErrorMessage(e) ?? 'Credenciais inválidas',
        );
      case 403:
        return const DeviceMismatchException();
      case 404:
        return const NotFoundException('Usuário não encontrado');
      case 409:
        return const DeviceConflictException();
      case 429:
        return const RateLimitedException();
      case var code when code != null && code >= 500:
        return const ServerException();
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          return const NetworkException();
        }
        return NetworkException(e.message ?? 'Erro inesperado');
    }
  }
}
