import 'dart:io';
import 'package:moto_passenger/modules/profile_configuration/data/models/profile_model.dart';

abstract class IProfileDatasource {
  Future<ProfileModel> getProfile(String userId);
  Future<ProfileModel> updateProfile(String userId, Map<String, dynamic> data);
  Future<String> uploadPhoto(String userId, File imageFile);
  Future<bool> removePhoto(String userId);
}
