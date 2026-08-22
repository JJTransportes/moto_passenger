class RegisterPassengerRequest {
  final String role;
  final String fullName;
  final String cpf;
  final String rg;
  final String registration;
  final DateTime birthdate;
  final String email;
  final String initialPassword;
  final String? department;
  final String publicPartitionId;

  const RegisterPassengerRequest({
    this.role = 'Passenger',
    required this.fullName,
    required this.cpf,
    required this.rg,
    required this.registration,
    required this.birthdate,
    required this.email,
    required this.initialPassword,
    this.department,
    required this.publicPartitionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'fullName': fullName,
      'cpf': cpf,
      'rg': rg,
      'registration': registration,
      'birthdate':
          '${birthdate.year}-${birthdate.month.toString().padLeft(2, '0')}-${birthdate.day.toString().padLeft(2, '0')}',
      'email': email.trim().toLowerCase(),
      'initialPassword': initialPassword,
      if (department != null && department!.isNotEmpty)
        'department': department,
      'publicPartitionId': publicPartitionId,
    };
  }
}
