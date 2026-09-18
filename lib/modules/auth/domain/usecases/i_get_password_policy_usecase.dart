import 'package:moto_passenger/modules/auth/domain/entities/password_policy_entity.dart';
import 'package:result_dart/result_dart.dart';

abstract class IGetPasswordPolicyUsecase {
  AsyncResult<PasswordPolicy> call();
}
