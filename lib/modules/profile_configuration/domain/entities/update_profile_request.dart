class UpdateProfileRequest {
  final String fullName;
  final String email;
  final String? phone;

  const UpdateProfileRequest({
    required this.fullName,
    required this.email,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
        'name': fullName,
        'email': email,
        if (phone != null) 'phone': phone,
      };
}
