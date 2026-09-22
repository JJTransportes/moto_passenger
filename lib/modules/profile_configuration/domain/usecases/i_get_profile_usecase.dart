import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';

abstract class IGetProfileUsecase {
  AsyncResult<ProfileEntity> call(String userId);
}
