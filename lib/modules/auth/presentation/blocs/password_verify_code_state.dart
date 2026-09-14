part of 'password_verify_code_bloc.dart';

sealed class PasswordVerifyCodeState {
  const PasswordVerifyCodeState();
}

final class PasswordVerifyCodeInitial extends PasswordVerifyCodeState {
  const PasswordVerifyCodeInitial();
}

final class PasswordVerifyCodeSubmitting extends PasswordVerifyCodeState {
  const PasswordVerifyCodeSubmitting();
}

final class PasswordVerifyCodeSuccess extends PasswordVerifyCodeState {
  final String resetToken;

  const PasswordVerifyCodeSuccess(this.resetToken);

  @override
  bool operator ==(Object other) =>
      other is PasswordVerifyCodeSuccess && other.resetToken == resetToken;

  @override
  int get hashCode => resetToken.hashCode;
}

final class PasswordVerifyCodeError extends PasswordVerifyCodeState {
  final String message;

  /// `true` em 409 (código já utilizado) e 429 (limite de tentativas) — os
  /// únicos casos em que a UI deve oferecer "Solicitar novo código".
  final bool requestNewCode;

  const PasswordVerifyCodeError(this.message, {this.requestNewCode = false});

  @override
  bool operator ==(Object other) =>
      other is PasswordVerifyCodeError &&
      other.message == message &&
      other.requestNewCode == requestNewCode;

  @override
  int get hashCode => Object.hash(message, requestNewCode);
}
