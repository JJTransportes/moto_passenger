import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';

abstract class IAuthRepository {
  Future<Result<UserEntity>> signIn(String email, String password);

  Future<Result<UserEntity>> refreshToken(String refreshToken);

  AsyncResult<Unit> requestPasswordReset(String email);

  AsyncResult<Unit> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}
