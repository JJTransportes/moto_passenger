import 'package:moto_passenger/modules/passenger_home/domain/entities/passenger_profile_entity.dart';

class PassengerProfileModel {
  final String passengerId;
  final String fullName;
  final String email;

  const PassengerProfileModel({
    required this.passengerId,
    required this.fullName,
    required this.email,
  });

  factory PassengerProfileModel.fromJson(Map<String, dynamic> json) {
    return PassengerProfileModel(
      passengerId: json['passengerId'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
    );
  }

  PassengerProfileEntity toEntity() {
    return PassengerProfileEntity(
      id: passengerId,
      fullName: fullName,
      email: email,
    );
  }
}
