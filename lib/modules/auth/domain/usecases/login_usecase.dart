import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_passenger/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_login_usecase.dart';

class LoginUsecase implements ILoginUsecase {
  final IAuthRepository _repository;

  LoginUsecase(this._repository);

  @override
  Future<Result<UserEntity>> call(String email, String password) {
    return _repository.signIn(email, password);
  }
}
