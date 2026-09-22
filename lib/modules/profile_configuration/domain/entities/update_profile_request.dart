class UpdateProfileRequest {
  final String? fullName;
  final String? email;
  final String? phone;
  final String password;

  const UpdateProfileRequest({
    this.fullName,
    this.email,
    this.phone,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        if (fullName != null) 'name': fullName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
      };
}
