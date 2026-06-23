class PassengerProfileEntity {
  final String id;
  final String fullName;
  final String email;

  const PassengerProfileEntity({
    required this.id,
    required this.fullName,
    required this.email,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PassengerProfileEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fullName == other.fullName &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ fullName.hashCode ^ email.hashCode;
}
