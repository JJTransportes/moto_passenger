import 'package:moto_passenger/modules/auth/domain/entities/password_policy_entity.dart';
import 'package:moto_passenger/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_get_password_policy_usecase.dart';
import 'package:result_dart/result_dart.dart';

class GetPasswordPolicyUsecase implements IGetPasswordPolicyUsecase {
  final IAuthRepository _repository;

  GetPasswordPolicyUsecase(this._repository);

  @override
  AsyncResult<PasswordPolicy> call() => _repository.getPasswordPolicy();
}
