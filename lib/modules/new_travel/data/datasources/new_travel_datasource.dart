import 'package:dio/dio.dart';

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
      final response = await _dio.post(' ', data: request);
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
}
