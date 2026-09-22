import 'dart:io';
import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/profile_configuration/data/datasources/i_profile_datasource.dart';
import 'package:moto_passenger/modules/profile_configuration/data/repositories/i_profile_repository.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/update_profile_request.dart';

class ProfileRepository implements IProfileRepository {
  final IProfileDatasource _datasource;

  ProfileRepository(this._datasource);

  @override
  AsyncResult<ProfileEntity> getProfile(String userId) async {
    try {
      final model = await _datasource.getProfile(userId);
      return Success(model.toEntity());
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<ProfileEntity> updateProfile(
    String userId,
    UpdateProfileRequest request,
  ) async {
    try {
      final model = await _datasource.updateProfile(userId, request.toJson());
      return Success(model.toEntity());
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<String> uploadPhoto(String userId, File imageFile) async {
    try {
      final photoUrl = await _datasource.uploadPhoto(userId, imageFile);
      return Success(photoUrl);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<bool> removePhoto(String userId) async {
    try {
      await _datasource.removePhoto(userId);
      return const Success(true);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
