import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';

class ProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? photoUrl;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.photoUrl,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    var photoUrl = json['photoUrl'] as String?;
    if (photoUrl != null &&
        photoUrl.isNotEmpty &&
        !photoUrl.startsWith('http://') &&
        !photoUrl.startsWith('https://')) {
      photoUrl = '${AppConfig.getBaseUrl()}$photoUrl';
    }
    return ProfileModel(
      id: json['passengerId'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      photoUrl: photoUrl,
    );
  }

  ProfileEntity toEntity() {
    return ProfileEntity(
      id: id,
      fullName: fullName,
      email: email,
      phone: phone,
      photoUrl: photoUrl,
    );
  }
}
