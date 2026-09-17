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
      final response = await _dio.get('/api/passengers/me');
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
        '/api/passengers/$userId/profile',
        data: data,
      );
      return ProfileModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Este endpoint exige a senha atual (confirm_password_dialog) para
      // autorizar a alteração — um 401 aqui significa senha incorreta, não
      // sessão expirada (diferente dos outros métodos deste datasource, que
      // não enviam senha). Usar a mensagem genérica de "_mapException" aqui
      // confundia o usuário: parecia que nada tinha acontecido.
      if (e.response?.statusCode == 401) {
        throw UnauthorizedException(_extractErrorMessage(e) ?? 'Senha incorreta.');
      }
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
        '/api/passengers/$userId/profile/image',
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
      await _dio.delete('/api/passengers/$userId/profile/image');
      return true;
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      for (final key in ['error', 'message', 'detail', 'title']) {
        if (data[key] is String) return data[key] as String;
      }
    }
    return null;
  }

  Exception _mapException(DioException e) {
    final serverMessage = _extractErrorMessage(e);
    switch (e.response?.statusCode) {
      case 400:
        return ValidationException(
          serverMessage ?? 'Dados inválidos. Verifique as informações e tente novamente.',
        );
      case 401:
        return const UnauthorizedException('Sessão expirada. Faça login novamente.');
      case 403:
        return ValidationException(
          serverMessage ?? 'Você só pode editar o próprio perfil.',
        );
      case 404:
        return const NotFoundException('Perfil não encontrado.');
      case 409:
        return const ValidationException('Este email já está em uso.');
      case 413:
        return const ValidationException('Arquivo muito grande. Envie uma imagem menor.');
      case 415:
        return const ValidationException(
          'Formato de arquivo não suportado. Use JPEG ou PNG.',
        );
      case var code when code != null && code >= 500:
        return const ServerException('Erro interno do servidor. Tente novamente mais tarde.');
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
