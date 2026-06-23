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
}
