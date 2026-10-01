import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_verify_password_reset_code_usecase.dart';

part 'password_verify_code_event.dart';
part 'password_verify_code_state.dart';

class PasswordVerifyCodeBloc
    extends Bloc<PasswordVerifyCodeEvent, PasswordVerifyCodeState> {
  final IVerifyPasswordResetCodeUsecase _verifyPasswordResetCodeUsecase;
  final String email;

  PasswordVerifyCodeBloc(this._verifyPasswordResetCodeUsecase, {required this.email})
      : super(const PasswordVerifyCodeInitial()) {
    on<CodeSubmitted>(_onCodeSubmitted);
  }

  Future<void> _onCodeSubmitted(
    CodeSubmitted event,
    Emitter<PasswordVerifyCodeState> emit,
  ) async {
    emit(const PasswordVerifyCodeSubmitting());

    final result = await _verifyPasswordResetCodeUsecase.call(
      email: email,
      code: event.code,
    );

    result.fold(
      (resetToken) => emit(PasswordVerifyCodeSuccess(resetToken)),
      (error) {
        final (message, requestNewCode) = switch (error) {
          // 409 (código já usado) e 429 (5 tentativas erradas) só têm uma
          // saída: pedir um código novo.
          ConflictException() => (error.message, true),
          RateLimitedException() => (error.message, true),
          ValidationException() => (error.message, false),
          _ => (
              'Erro ao verificar o código. Verifique sua conexão e tente novamente.',
              false,
            ),
        };
        emit(PasswordVerifyCodeError(message, requestNewCode: requestNewCode));
      },
    );
  }
}
