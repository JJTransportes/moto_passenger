part of 'register_bloc.dart';

sealed class RegisterEvent {
  const RegisterEvent();
}

final class LoadPartitions extends RegisterEvent {
  const LoadPartitions();
}

final class RegisterSubmitted extends RegisterEvent {
  final String fullName;
  final String cpf;
  final String rg;
  final String registration;
  final DateTime birthdate;
  final String email;
  final String initialPassword;
  final String? department;
  final String publicPartitionId;

  const RegisterSubmitted({
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
}
