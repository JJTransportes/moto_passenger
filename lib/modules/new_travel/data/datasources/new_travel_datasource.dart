import 'package:dio/dio.dart';

abstract class INewTravelDatasource {
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> request);
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
      throw Exception(e.message ?? 'Erro ao criar viagem');
    }
  }
}
