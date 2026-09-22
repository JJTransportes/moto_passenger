import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_get_profile_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/data/repositories/i_profile_repository.dart';

class GetProfileUsecase implements IGetProfileUsecase {
  final IProfileRepository _repository;

  GetProfileUsecase(this._repository);

  @override
  AsyncResult<ProfileEntity> call(String userId) {
    return _repository.getProfile(userId);
  }
}
