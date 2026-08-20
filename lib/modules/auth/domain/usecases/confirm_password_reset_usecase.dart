import 'package:moto_passenger/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_confirm_password_reset_usecase.dart';
import 'package:result_dart/result_dart.dart';

class ConfirmPasswordResetUsecase implements IConfirmPasswordResetUsecase {
  final IAuthRepository _repository;

  ConfirmPasswordResetUsecase(this._repository);

  @override
  AsyncResult<Unit> call({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _repository.confirmPasswordReset(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }
}
