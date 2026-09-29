import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/auth/domain/entities/password_policy_entity.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';

abstract class IAuthRepository {
  Future<Result<UserEntity>> signIn(String email, String password);

  Future<Result<UserEntity>> refreshToken(String refreshToken);

  AsyncResult<Unit> requestPasswordReset(String email);

  AsyncResult<String> verifyPasswordResetCode({
    required String email,
    required String code,
  });

  AsyncResult<Unit> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  });

  AsyncResult<PasswordPolicy> getPasswordPolicy();
}
