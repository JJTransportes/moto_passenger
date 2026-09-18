import 'package:moto_passenger/modules/auth/domain/repositories/i_auth_repository.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_request_password_reset_usecase.dart';
import 'package:result_dart/result_dart.dart';

class RequestPasswordResetUsecase implements IRequestPasswordResetUsecase {
  final IAuthRepository _repository;

  RequestPasswordResetUsecase(this._repository);

  @override
  AsyncResult<Unit> call(String email) => _repository.requestPasswordReset(email);
}
