import 'dart:io';
import 'package:dio/dio.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/profile_configuration/data/datasources/i_profile_datasource.dart';
import 'package:moto_passenger/modules/profile_configuration/data/models/profile_model.dart';

class ProfileDatasource implements IProfileDatasource {
  final Dio _dio;

  ProfileDatasource(this._dio);

  @override
  Future<ProfileModel> getProfile(String userId) async {
    try {
      final response = await _dio.get('/api/users/$userId/profile');
      return ProfileModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<ProfileModel> updateProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put(
        '/api/users/$userId/profile',
        data: data,
      );
      return ProfileModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<String> uploadPhoto(String userId, File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });
      final response = await _dio.post(
        '/api/users/$userId/profile/image',
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      return data['photoUrl'] as String;
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<bool> removePhoto(String userId) async {
    try {
      await _dio.delete('/api/users/$userId/profile/image');
      return true;
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Exception _mapException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        final errors = e.response?.data;
        if (errors is Map<String, dynamic> && errors.containsKey('errors')) {
          return ValidationException(errors['errors'].toString());
        }
        return const ValidationException('Dados inválidos. Verifique os campos.');
      case 401:
        return const UnauthorizedException('Sessão expirada. Faça login novamente.');
      case 404:
        return const NotFoundException('Perfil não encontrado.');
      case 409:
        return const ValidationException('Este email já está em uso.');
      case 413:
        return const ValidationException('A imagem é muito grande. Máximo 5MB.');
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
