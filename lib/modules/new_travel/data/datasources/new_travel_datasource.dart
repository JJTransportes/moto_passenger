import 'package:dio/dio.dart';

abstract class INewTravelDatasource {
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> request);
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
      // Check for structured 404 — no drivers available for the passenger's secretariat
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
}
