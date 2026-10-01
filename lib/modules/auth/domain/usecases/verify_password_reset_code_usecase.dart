import 'package:moto_passenger/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_verify_password_reset_code_usecase.dart';
import 'package:result_dart/result_dart.dart';

class VerifyPasswordResetCodeUsecase implements IVerifyPasswordResetCodeUsecase {
  final IAuthRepository _repository;

  VerifyPasswordResetCodeUsecase(this._repository);

  @override
  AsyncResult<String> call({
    required String email,
    required String code,
  }) {
    return _repository.verifyPasswordResetCode(email: email, code: code);
  }
}
