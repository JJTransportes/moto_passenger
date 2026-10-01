import 'package:moto_passenger/modules/auth/domain/entities/password_policy_entity.dart';

class PasswordPolicyModel {
  final int minLength;
  final int maxLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireDigit;
  final bool requireSpecialChar;

  const PasswordPolicyModel({
    required this.minLength,
    required this.maxLength,
    required this.requireUppercase,
    required this.requireLowercase,
    required this.requireDigit,
    required this.requireSpecialChar,
  });

  factory PasswordPolicyModel.fromJson(Map<String, dynamic> json) {
    return PasswordPolicyModel(
      minLength: json['minLength'] as int,
      maxLength: json['maxLength'] as int,
      requireUppercase: json['requireUppercase'] as bool,
      requireLowercase: json['requireLowercase'] as bool,
      requireDigit: json['requireDigit'] as bool,
      requireSpecialChar: json['requireSpecialChar'] as bool,
    );
  }

  PasswordPolicy toEntity() {
    return PasswordPolicy(
      minLength: minLength,
      maxLength: maxLength,
      requireUppercase: requireUppercase,
      requireLowercase: requireLowercase,
      requireDigit: requireDigit,
      requireSpecialChar: requireSpecialChar,
    );
  }
}
