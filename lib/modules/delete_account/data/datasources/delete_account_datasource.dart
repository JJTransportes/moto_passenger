import 'package:dio/dio.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';

abstract class IDeleteAccountDatasource {
  /// Calls DELETE /api/account with the user's password for verification.
  /// Throws [InvalidPasswordException] on 401,
  /// [ValidationException] on 409 (active travels / already inactive),
  /// or [NetworkException]/[ServerException] on other failures.
  Future<void> deleteAccount(String password);
}

class DeleteAccountDatasource implements IDeleteAccountDatasource {
  final Dio _dio;

  DeleteAccountDatasource(this._dio);

  @override
  Future<void> deleteAccount(String password) async {
    try {
      await _dio.delete(
        '/api/account',
        data: {'password': password},
      );
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Exception _mapException(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        return const ValidationException('Dados inválidos. Verifique os campos.');
      case 401:
        return const UnauthorizedException('Senha incorreta.');
      case 409:
        return const ValidationException(
          'Não é possível excluir a conta enquanto houver viagens em andamento.',
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
}
