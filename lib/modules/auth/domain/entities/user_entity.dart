class UserEntity {
  final String id;
  final String token;
  final String? refreshToken;
  final List<String> roles;

  const UserEntity({
    required this.id,
    required this.token,
    this.refreshToken,
    required this.roles,
  });

  bool get isPassenger => roles.contains('Passenger');
}
