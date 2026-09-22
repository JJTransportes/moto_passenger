import 'package:dio/dio.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/passenger_home/data/datasources/i_passenger_home_datasource.dart';
import 'package:moto_passenger/modules/passenger_home/data/models/passenger_profile_model.dart';
import 'package:moto_passenger/modules/passenger_home/data/models/travel_summary_model.dart';

class PassengerHomeDatasource implements IPassengerHomeDatasource {
  final Dio _dio;

  PassengerHomeDatasource(this._dio);

  @override
  Future<PassengerProfileModel> getProfile() async {
    try {
      final response = await _dio.get('/api/passengers/me');
      final data = response.data as Map<String, dynamic>;
      // Backend retorna path relativo (ex: /api/files/{id}) — resolver com baseUrl
      var photoUrl = data['photoUrl'] as String?;
      if (photoUrl != null && photoUrl.isNotEmpty &&
          !photoUrl.startsWith('http://') && !photoUrl.startsWith('https://')) {
        data['photoUrl'] = '${AppConfig.getBaseUrl()}$photoUrl';
      }
      return PassengerProfileModel.fromJson(data);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<PaginatedTravelListModel> getPassengerTravels({
    required List<String> status,
    int page = 1,
    int pageSize = 5,
  }) async {
    try {
      final response = await _dio.get(
        '/api/travels/passenger',
        queryParameters: {
          'status': status,
          'page': page,
          'pageSize': pageSize,
        },
      );
      return PaginatedTravelListModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<Map<String, dynamic>?> getActiveTravel() async {
    try {
      final response = await _dio.get('/api/travels/active');
      if (response.statusCode == 204) return null; // No Content = sem viagem
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Exception _mapException(DioException e) {
    switch (e.response?.statusCode) {
      case 401:
        return UnauthorizedException(e.message ?? 'Credenciais inválidas');
      case 404:
        return NotFoundException(e.message ?? 'Recurso não encontrado');
      default:
        return NetworkException(e.message ?? 'Erro de conexão');
    }
  }
}
