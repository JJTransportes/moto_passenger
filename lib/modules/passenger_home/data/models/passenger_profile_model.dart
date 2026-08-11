import 'package:moto_passenger/modules/passenger_home/domain/entities/passenger_profile_entity.dart';

class PassengerProfileModel {
  final String passengerId;
  final String fullName;
  final String email;
  final String? photoUrl;

  const PassengerProfileModel({
    required this.passengerId,
    required this.fullName,
    required this.email,
    this.photoUrl,
  });

  factory PassengerProfileModel.fromJson(Map<String, dynamic> json) {
    return PassengerProfileModel(
      passengerId: json['passengerId'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  PassengerProfileEntity toEntity() {
    return PassengerProfileEntity(
      id: passengerId,
      fullName: fullName,
      email: email,
      photoUrl: photoUrl,
    );
  }
}
