import 'package:dio/dio.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/passenger_registration/data/datasources/i_registration_datasource.dart';

class RegistrationDatasource implements IRegistrationDatasource {
  final Dio _dio;

  RegistrationDatasource(this._dio);

  @override
  Future<List<Map<String, dynamic>>> getPublicPartitions() async {
    try {
      final response = await _dio.get('/api/public-partitions/list');
      return (response.data as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<Map<String, dynamic>> selfRegister(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '/api/registrations',
        data: data,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        return ValidationException(
          _extractErrorMessage(e) ?? 'Dados inválidos. Verifique as informações.',
        );
      case 409:
        return ConflictException(
          _extractErrorMessage(e) ?? 'Este e-mail ou CPF já está cadastrado.',
        );
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

  /// O `409` de `/api/registrations` distingue o campo duplicado só pela
  /// mensagem do servidor (campo `error`: "E-mail já cadastrado.", "CPF já
  /// cadastrado.", "RG já cadastrado.", "Matrícula já cadastrada." —
  /// confirmado via chamada real ao backend local) — repassada como está para
  /// a UI destacar o campo específico.
  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return null;
  }
}
