import 'package:dio/dio.dart';
import 'package:moto_passenger/core/device/device_platform.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
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

  Exception _mapDioException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        return const ValidationException(
          'Dados inválidos. Verifique as informações.',
        );
      case 401:
        return const UnauthorizedException();
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
