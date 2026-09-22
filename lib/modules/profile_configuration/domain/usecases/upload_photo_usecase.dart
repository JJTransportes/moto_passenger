import 'dart:io';
import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_upload_photo_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/data/repositories/i_profile_repository.dart';

class UploadPhotoUsecase implements IUploadPhotoUsecase {
  final IProfileRepository _repository;

  UploadPhotoUsecase(this._repository);

  @override
  AsyncResult<String> call(String userId, File imageFile) {
    return _repository.uploadPhoto(userId, imageFile);
  }
}
