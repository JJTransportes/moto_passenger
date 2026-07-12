import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/update_profile_request.dart';

abstract class IUpdateProfileUsecase {
  AsyncResult<ProfileEntity> call(String userId, UpdateProfileRequest request);
}
