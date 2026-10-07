import 'package:dio/dio.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';

abstract class ITravelTrackingDatasource {
  Future<Map<String, dynamic>> getTravel(String travelId);
  Future<void> cancelTravel(String travelId, {String? reason});
  Future<Map<String, dynamic>> getDriverProfile(String driverId);
}

class TravelTrackingDatasource implements ITravelTrackingDatasource {
  final Dio _dio;

  TravelTrackingDatasource(this._dio);

  @override
  Future<Map<String, dynamic>> getTravel(String travelId) async {
    try {
      final response = await _dio.get('/api/travels/$travelId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(
        e,
        fallback: 'Não foi possível carregar a viagem. Tente novamente.',
      );
    }
  }

  @override
  Future<void> cancelTravel(String travelId, {String? reason}) async {
    try {
      await _dio.post(
        '/api/travels/$travelId/cancel',
        data: {
          if (reason != null) 'reason': reason,
        },
      );
    } on DioException catch (e) {
      throw _mapDioException(
        e,
        fallback: 'Não foi possível cancelar a viagem. Tente novamente.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getDriverProfile(String driverId) async {
    try {
      final response = await _dio.get('/api/drivers/$driverId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(
        e,
        fallback: 'Não foi possível carregar os dados do motorista.',
      );
    }
  }

  Exception _mapDioException(
    DioException error, {
    required String fallback,
  }) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const NetworkException(
        'A conexão demorou mais que o esperado. Verifique sua internet e tente novamente. Sua viagem continua ativa.',
      );
    }

    switch (error.response?.statusCode) {
      case 404:
        return const NotFoundException('Viagem não encontrada.');
      case var status when status != null && status >= 500:
        return const ServerException(
          'O serviço está temporariamente indisponível. Tente novamente em alguns instantes.',
        );
      default:
        return Exception(fallback);
    }
  }
}
