part of 'password_recovery_bloc.dart';

sealed class PasswordRecoveryEvent {
  const PasswordRecoveryEvent();
}

final class RequestCodeSubmitted extends PasswordRecoveryEvent {
  final String email;

  const RequestCodeSubmitted(this.email);
}
