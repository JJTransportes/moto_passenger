part of 'password_recovery_bloc.dart';

sealed class PasswordRecoveryState {
  const PasswordRecoveryState();
}

final class PasswordRecoveryInitial extends PasswordRecoveryState {
  const PasswordRecoveryInitial();
}

final class PasswordRecoveryLoading extends PasswordRecoveryState {
  const PasswordRecoveryLoading();
}

/// Emitido em caso de sucesso — inclusive quando o e-mail não está cadastrado
/// (404), de propósito: a tela não pode revelar se um e-mail existe na base.
final class PasswordRecoverySent extends PasswordRecoveryState {
  final String email;

  const PasswordRecoverySent(this.email);

  @override
  bool operator ==(Object other) =>
      other is PasswordRecoverySent && other.email == email;

  @override
  int get hashCode => email.hashCode;
}

final class PasswordRecoveryError extends PasswordRecoveryState {
  final String message;

  const PasswordRecoveryError(this.message);

  @override
  bool operator ==(Object other) =>
      other is PasswordRecoveryError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}
