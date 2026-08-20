import 'package:moto_passenger/modules/auth/data/datasources/i_auth_datasource.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_passenger/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:result_dart/result_dart.dart';

class AuthRepository implements IAuthRepository {
  final IAuthDatasource _datasource;

  AuthRepository(this._datasource);

  @override
  AsyncResult<UserEntity> signIn(
    String email,
    String password,
  ) async {
    try {
      final model = await _datasource.signIn(email, password);
      return Success(model.toEntity());
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<UserEntity> refreshToken(String refreshToken) async {
    try {
      final model = await _datasource.refreshToken(refreshToken);
      return Success(model.toEntity());
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<Unit> requestPasswordReset(String email) async {
    try {
      await _datasource.requestPasswordReset(email);
      return Success(unit);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<Unit> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _datasource.confirmPasswordReset(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      return Success(unit);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
