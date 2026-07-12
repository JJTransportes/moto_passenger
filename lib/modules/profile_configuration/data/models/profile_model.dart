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
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': fullName,
      'email': email,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
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
