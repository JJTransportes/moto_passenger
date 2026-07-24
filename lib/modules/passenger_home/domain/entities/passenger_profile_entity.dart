class PassengerProfileEntity {
  final String id;
  final String fullName;
  final String email;
  final String? photoUrl;

  const PassengerProfileEntity({
    required this.id,
    required this.fullName,
    required this.email,
    this.photoUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PassengerProfileEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fullName == other.fullName &&
          email == other.email &&
          photoUrl == other.photoUrl;

  @override
  int get hashCode =>
      id.hashCode ^ fullName.hashCode ^ email.hashCode ^ photoUrl.hashCode;
}
