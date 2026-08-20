part of 'password_reset_bloc.dart';

sealed class PasswordResetEvent {
  const PasswordResetEvent();
}

final class ResetConfirmSubmitted extends PasswordResetEvent {
  final String code;
  final String newPassword;

  const ResetConfirmSubmitted({
    required this.code,
    required this.newPassword,
  });
}
