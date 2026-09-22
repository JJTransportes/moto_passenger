import 'package:moto_passenger/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_confirm_password_reset_usecase.dart';
import 'package:result_dart/result_dart.dart';

class ConfirmPasswordResetUsecase implements IConfirmPasswordResetUsecase {
  final IAuthRepository _repository;

  ConfirmPasswordResetUsecase(this._repository);

  @override
  AsyncResult<Unit> call({
    required String resetToken,
    required String newPassword,
  }) {
    return _repository.confirmPasswordReset(
      resetToken: resetToken,
      newPassword: newPassword,
    );
  }
}
