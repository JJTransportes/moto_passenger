part of 'password_verify_code_bloc.dart';

sealed class PasswordVerifyCodeEvent {
  const PasswordVerifyCodeEvent();
}

final class CodeSubmitted extends PasswordVerifyCodeEvent {
  final String code;

  const CodeSubmitted(this.code);
}
