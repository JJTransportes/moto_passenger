import 'package:dio/dio.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/usage_terms/data/datasources/i_usage_terms_datasource.dart';

class UsageTermsDatasource implements IUsageTermsDatasource {
  final Dio _dio;

  UsageTermsDatasource(this._dio);

  @override
  Future<Map<String, dynamic>> getAcceptanceStatus() async {
    try {
      final response = await _dio.get('/api/usage-terms/acceptance-status');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getActiveTerms() async {
    try {
      final response = await _dio.get('/api/usage-terms/active');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> acceptTerms() async {
    try {
      await _dio.post('/api/usage-terms/accept');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        return const ValidationException(
          'Dados inválidos. Verifique as informações.',
        );
      case 401:
        return const UnauthorizedException();
      case 404:
        return const NotFoundException('Termos não encontrados');
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
