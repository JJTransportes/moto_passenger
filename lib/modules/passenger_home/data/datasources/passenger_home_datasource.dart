import 'package:dio/dio.dart';
import 'package:moto_passenger/modules/passenger_home/data/datasources/i_passenger_home_datasource.dart';
import 'package:moto_passenger/modules/passenger_home/data/models/passenger_profile_model.dart';
import 'package:moto_passenger/modules/passenger_home/data/models/travel_summary_model.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';

class PassengerHomeDatasource implements IPassengerHomeDatasource {
  final Dio _dio;

  PassengerHomeDatasource(this._dio);

  @override
  Future<PassengerProfileModel> getProfile() async {
    try {
      final response = await _dio.get('/api/passengers/me');
      return PassengerProfileModel.fromJson(response.data as Map<String, dynamic>);
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
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapException(e);
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
