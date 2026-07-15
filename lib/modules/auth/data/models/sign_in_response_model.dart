import 'package:moto_passenger/modules/auth/domain/entities/user_entity.dart';

class SignInResponseModel {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final DateTime? refreshExpiresAt;
  final String userId;
  final List<String> roles;

  const SignInResponseModel({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    this.refreshExpiresAt,
    required this.userId,
    required this.roles,
  });

  factory SignInResponseModel.fromJson(Map<String, dynamic> json) {
    return SignInResponseModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      refreshExpiresAt: json['refreshExpiresAt'] != null
          ? DateTime.parse(json['refreshExpiresAt'] as String)
          : null,
      userId: json['userId'] as String,
      roles: List<String>.from(json['roles'] as List),
    );
  }

  UserEntity toEntity() {
    return UserEntity(
      id: userId,
      token: accessToken,
      refreshToken: refreshToken,
      roles: roles,
    );
  }
}
