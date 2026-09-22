import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_remove_photo_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/data/repositories/i_profile_repository.dart';

class RemovePhotoUsecase implements IRemovePhotoUsecase {
  final IProfileRepository _repository;

  RemovePhotoUsecase(this._repository);

  @override
  AsyncResult<bool> call(String userId) {
    return _repository.removePhoto(userId);
  }
}
