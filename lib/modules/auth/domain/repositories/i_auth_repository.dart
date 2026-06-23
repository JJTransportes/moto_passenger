import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';

abstract class IAuthRepository {
  Future<Result<UserEntity>> signIn(String email, String password);
}
