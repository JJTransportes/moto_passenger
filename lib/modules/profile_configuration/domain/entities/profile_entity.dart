class ProfileEntity {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? photoUrl;

  const ProfileEntity({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.photoUrl,
  });

  ProfileEntity copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? photoUrl,
    bool clearPhone = false,
    bool clearPhotoUrl = false,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: clearPhone ? null : (phone ?? this.phone),
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fullName == other.fullName &&
          email == other.email &&
          phone == other.phone &&
          photoUrl == other.photoUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      fullName.hashCode ^
      email.hashCode ^
      phone.hashCode ^
      photoUrl.hashCode;
}
