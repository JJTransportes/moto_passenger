part of 'password_reset_bloc.dart';

sealed class PasswordResetState {
  const PasswordResetState();
}

final class PasswordResetInitial extends PasswordResetState {
  const PasswordResetInitial();
}

final class PasswordResetSubmitting extends PasswordResetState {
  const PasswordResetSubmitting();
}

final class PasswordResetSuccess extends PasswordResetState {
  const PasswordResetSuccess();
}

final class PasswordResetError extends PasswordResetState {
  final String message;

  /// `true` apenas no 409 (código já utilizado) — o único caso em que a UI deve
  /// oferecer a ação "Solicitar novo código".
  final bool codeConsumed;

  const PasswordResetError(this.message, {this.codeConsumed = false});

  @override
  bool operator ==(Object other) =>
      other is PasswordResetError &&
      other.message == message &&
      other.codeConsumed == codeConsumed;

  @override
  int get hashCode => Object.hash(message, codeConsumed);
}
