import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/update_profile_request.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_update_profile_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/data/repositories/i_profile_repository.dart';

class UpdateProfileUsecase implements IUpdateProfileUsecase {
  final IProfileRepository _repository;

  UpdateProfileUsecase(this._repository);

  @override
  AsyncResult<ProfileEntity> call(String userId, UpdateProfileRequest request) {
    return _repository.updateProfile(userId, request);
  }
}
