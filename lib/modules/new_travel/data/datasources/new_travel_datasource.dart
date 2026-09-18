import 'package:dio/dio.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';

abstract class INewTravelDatasource {
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> request);
  Future<Map<String, dynamic>> createPriorityOrder(Map<String, dynamic> request);
  Future<Map<String, dynamic>?> getLatestOrder();
  Future<void> cancelOrder(String orderId);
}

class NoDriversAvailableException implements Exception {
  final String partitionAcronym;
  final String message;

  const NoDriversAvailableException({
    required this.partitionAcronym,
    required this.message,
  });

  @override
  String toString() => message;
}

class NewTravelDatasource implements INewTravelDatasource {
  final Dio _dio;

  NewTravelDatasource(this._dio);

  @override
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> request) async {
    try {
      final response = await _dio.post('/api/travels/orders', data: request);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && e.response?.data is Map) {
        final body = e.response!.data as Map<String, dynamic>;
        if (body['type'] == 'no_drivers_available') {
          throw NoDriversAvailableException(
            partitionAcronym: body['partitionAcronym'] as String? ?? '',
            message: body['message'] as String? ?? 'Nenhum motorista disponível',
          );
        }
      }
      if (e.response?.statusCode == 429) {
        throw RateLimitedException(
          _extractErrorMessage(e) ??
              'Muitos pedidos de corrida em pouco tempo. Aguarde alguns minutos e tente novamente.',
        );
      }
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          _extractErrorMessage(e) ?? 'Dados inválidos para criar a viagem.',
        );
      }
      if ((e.response?.statusCode ?? 0) >= 500) {
        throw const ServerException();
      }
      throw Exception(e.message ?? 'Erro ao criar viagem');
    }
  }

  @override
  Future<Map<String, dynamic>> createPriorityOrder(Map<String, dynamic> request) async {
    try {
      final response = await _dio.post('/api/travels/priority-orders', data: request);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && e.response?.data is Map) {
        final body = e.response!.data as Map<String, dynamic>;
        if (body['type'] == 'no_drivers_available') {
          throw NoDriversAvailableException(
            partitionAcronym: body['partitionAcronym'] as String? ?? '',
            message: body['message'] as String? ?? 'Nenhum motorista disponível',
          );
        }
      }
      if (e.response?.statusCode == 429) {
        throw RateLimitedException(
          _extractErrorMessage(e) ??
              'Muitos pedidos de corrida em pouco tempo. Aguarde alguns minutos e tente novamente.',
        );
      }
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          _extractErrorMessage(e) ?? 'Dados inválidos para criar a viagem.',
        );
      }
      if ((e.response?.statusCode ?? 0) >= 500) {
        throw const ServerException();
      }
      throw Exception(e.message ?? 'Erro ao criar viagem');
    }
  }

  @override
  Future<Map<String, dynamic>?> getLatestOrder() async {
    try {
      final response = await _dio.get('/api/travels/orders/latest');
      if (response.statusCode == 204) return null;
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 204) {
        return null;
      }
      throw Exception(e.message ?? 'Erro ao verificar pedidos pendentes');
    }
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    try {
      await _dio.post('/api/travels/orders/$orderId/cancel');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Pedido não encontrado ou já foi processado');
      }
      throw Exception(e.message ?? 'Erro ao cancelar pedido');
    }
  }

  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return null;
  }
}
