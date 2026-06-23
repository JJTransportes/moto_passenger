import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';

abstract class ILoginUsecase {
  Future<Result<UserEntity>> call(String email, String password);
}
