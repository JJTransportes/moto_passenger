import 'package:dio/dio.dart';

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
      throw Exception(e.message ?? 'Erro ao buscar viagem');
    }
  }

  @override
  Future<void> cancelTravel(String travelId, {String? reason}) async {
    try {
      await _dio.post('/api/travels/$travelId/cancel', data: {
        if (reason != null) 'reason': reason,
      });
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Erro ao cancelar viagem');
    }
  }

  @override
  Future<Map<String, dynamic>> getDriverProfile(String driverId) async {
    try {
      final response = await _dio.get('/api/drivers/$driverId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Erro ao buscar perfil do motorista');
    }
  }
}
