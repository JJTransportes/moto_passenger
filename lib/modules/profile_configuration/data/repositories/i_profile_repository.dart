import 'dart:io';
import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/update_profile_request.dart';

abstract class IProfileRepository {
  AsyncResult<ProfileEntity> getProfile(String userId);
  AsyncResult<ProfileEntity> updateProfile(
      String userId, UpdateProfileRequest request);
  AsyncResult<String> uploadPhoto(String userId, File imageFile);
  AsyncResult<bool> removePhoto(String userId);
}
